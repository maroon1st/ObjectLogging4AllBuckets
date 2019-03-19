#!/bin/bash

function create_bucket () {
  REGION=$1
  BUCKET_NAME=$2
  PREFIX=$3
  TMP_FILE=$4

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text || error_exit)

  echo Check S3 Bucket: $BUCKET_NAME
  aws s3api get-bucket-location \
    --bucket $BUCKET_NAME \
    --region $REGION &> /dev/null

  if [ $? -ne 0 ]; then
    echo Create S3 Bucket: $BUCKET_NAME
    aws s3api create-bucket \
      --bucket $BUCKET_NAME \
      --region $REGION \
      --create-bucket-configuration LocationConstraint=$REGION || error_exit
  fi

  cat <<EOS > $TMP_FILE
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck20150319",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    },
    {
      "Sid": "AWSCloudTrailWrite20150319",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/${PREFIX}AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {"StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}}
    }
  ]
}
EOS

  echo Put Bucket Policy: $BUCKET_NAME
  aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --policy "file://${TMP_FILE}" || error_exit
}

function create_trail () {
  REGION=$1
  TRAIL_NAME=$2
  BUCKET_NAME=$3
  PREFIX=$4

  echo Create Trail: $TRAIL_NAME
  aws cloudtrail create-trail \
    --region $REGION \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$BUCKET_NAME" \
    --s3-key-prefix "$PREFIX" \
    --include-global-service-events \
    --is-multi-region-trail \
    --no-enable-log-file-validation || error_exit

  echo Start Logging: $TRAIL_NAME
  aws cloudtrail start-logging \
    --region $REGION \
    --name "$TRAIL_NAME" || error_exit
}

function put_selector_config () {
  REGION=$1
  TRAIL_NAME=$2
  EXCLUDE_BUCKET=$3
  TMP_FILE=$4
  LIST_BUCKETS=$(aws s3api list-buckets --query Buckets[].Name --output text || error_exit)
#  BUCKETS=$(echo $LIST_BUCKETS | sed "s/\\ ${EXCLUDE_BUCKET}\\ /\\ /" | \
#    sed 's/^/{"type":"AWS::S3::Object","values":["arn:aws:s3:::/' | \
#    sed 's/$/"]}/' | sed 's/ /"]},\n{"type":"AWS::S3::Object","values":["arn:aws:s3:::/g' || error_exit)
  BUCKETS=$(echo $LIST_BUCKETS | sed "s/\\ ${EXCLUDE_BUCKET}\\ /\\ /" | \
    sed 's/^/"arn:aws:s3:::/' | sed 's/$/\/"/' | \
    sed 's/ /\/", \n"arn:aws:s3:::/g' || error_exit)
#  BUCKETS=$(echo $LIST_BUCKETS | sed 's/^/"/' | sed 's/$/"/' | sed 's/ /", \n"arn:aws:s3:::/g' | grep -v "^\"arn:aws:s3:::${EXCLUDE_BUCKET}" || error_exit)

  cat <<EOS > $TMP_FILE
{
  "TrailName": "${TRAIL_NAME}",
  "EventSelectors": [
    {
      "ReadWriteType": "All",
      "IncludeManagementEvents": false,
      "DataResources": [
        {
          "Type": "AWS::S3::Object",
          "Values": [
$BUCKETS
  ] } ] } ] }
EOS

  echo Put Event Selectors: $TRAIL_NAME
  cat $TMP_FILE
  aws cloudtrail put-event-selectors \
    --region $REGION \
    --cli-input-json "file://${TMP_FILE}" || error_exit
}

atexit() {
  [[ -n ${tmpfile1-} ]] && rm -f "$tmpfile1"
  [[ -n ${tmpfile2-} ]] && rm -f "$tmpfile2"
}

usage_exit() {
        echo "Usage: $0 -r <region> -t <trail name> -b <S3 bucket name> [-p <prefix>]" 1>&2
        exit 1
}

error_exit() {
        exit 1
}

while getopts r:t:b:p: OPT
do
    case $OPT in
        r)  REGION=$OPTARG
            ;;
        t)  TRAIL_NAME=$OPTARG
            ;;
        b)  BUCKET_NAME=$OPTARG
            ;;
        p)  PREFIX=$OPTARG
            ;;
        \?) usage_exit
            ;;
    esac
done

shift $((OPTIND - 1))

[ "${REGION}"      = "" ] && usage_exit
[ "${TRAIL_NAME}"  = "" ] && usage_exit
[ "${BUCKET_NAME}" = "" ] && usage_exit

trap atexit EXIT
trap 'atexit; exit $?' INT PIPE TERM

tmpfile1=$(mktemp "/tmp/${0##*/}.1.tmp.XXXXXX")

create_bucket $REGION $BUCKET_NAME "$PREFIX" $tmpfile1 || error_exit

create_trail $REGION $TRAIL_NAME $BUCKET_NAME "$PREFIX"  || error_exit

tmpfile2=$(mktemp "/tmp/${0##*/}.2.tmp.XXXXXX")

put_selector_config $REGION $TRAIL_NAME $BUCKET_NAME $tmpfile2 || error_exit 

echo end
