# ObjectLogging4AllBuckets

CloudTrail Object Logging for All S3 Buckets

このツールはAmazon S3の全バケットに対して Object-Level Logging を設定します。

## 概要

ObjectLogging4AllBucketsは以下の形式で実行オプションを指定します。

``` shell
ObjectLogging4AllBuckets.sh
    -r <region>
    -t <trail name>
    -b <S3 bucket name>
    [-p <prefix>]
```

## オプション

- -r \<region\> CloudTrail Logを集約するS3 Bucketを作成するリージョンです。
- -t \<trail name\> 作成するCloudTrailの名前です。
- -b \<S3 bucket name\> 作成するS3 Bucketの名前です。
- \[-p \<prefix\>\] ログをS3に保存するときのPrefixです。

## 注意

- 指定したS3 Bucketを新規に作成します。
- ログはS3 Bucketの`<prefix>AWSLogs/<Account ID>/`以下に保存します。

## 参考

[全S3バケットのオブジェクトログを一発で出力するツールを作りました](https://dev.classmethod.jp/cloud/aws/cloudtrail-object-logging-for-all-s3-buckets-tool/)
