---
title: "Authentication with certificate in Minio"
date: 2022-12-24T22:52:18+01:00
draft: false
tags: ["k8s", "kubernetes", "minio", "db", "tls", "security"]
categories: ["db", "security"]

resources:
- name: "logo"
  src: "logo.png"

featuredImage: "logo"
lightgallery: true

toc:
  auto: false

---
## Authenticate with certificate in Minio using cert manager
### 0. Create bucket with files using `minio/mc`.
{{< admonition tip >}}
This step is optional. It can be skipped if you have already created buckets which can be used for testing.
{{< /admonition >}}
#### auth 
```bash
mc config host add minio-0 https://minio-0.minio.minio.svc.cluster.local:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
```
#### copy file into the bucket
```bash
mc mb --with-lock minio-0/bucket1
touch test.txt
echo "test" > test.txt
mc cp ./test.txt minio-0/bucket1
```
#### list files in the bucket
```bash
mc ls minio-0/bucket1
```

### 1. Generate certificate with proper `commonName` variable. 
Common name variable should be the same as one of the policies in Minio.

{{< admonition note >}}
Minio has predefined policies, but it's also possible to use custom policy.
```yaml
bash-4.4$ mc admin policy list minio-0
consoleAdmin
diagnostics
readonly
readwrite
writeonly
```
{{< /admonition >}}

We are going to use `readonly` policy for testing
```yaml
bash-4.4$ mc admin policy info minio-0 readonly
{
 "PolicyName": "readonly",
 "Policy": {
  "Version": "2012-10-17",
  "Statement": [
   {
    "Effect": "Allow",
    "Action": [
     "s3:GetBucketLocation",
     "s3:GetObject"
    ],
    "Resource": [
     "arn:aws:s3:::*"
    ]
   }
  ]
 }
}
```

Certificate associated with `readonly` policy.
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: minio-readonly-certs
  namespace: minio
  labels:
    app.kubernetes.io/name: minio
spec:
  secretName: minio-readonly-certs
  commonName: readonly
  duration: 9000h
  renewBefore: 180h
  usages:
    - digital signature
    - key encipherment
    - client auth
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  subject:
    organizations:
      - minio
  dnsNames:
    - "localhost"
    - "127.0.0.1"
    - "*.minio.minio.svc.cluster.local"
  issuerRef:
    name: ca-issuer
    kind: Issuer
    group: cert-manager.io
```

### 2. Generate temporary credentials
```bash
curl -X POST \
  --key /tmp/minio/readonly-certs/private.key \
  --cert /tmp/minio/readonly-certs/public.crt \
  --cacert /tmp/minio/certs/ca.crt "https://minio-0.minio.minio.svc.cluster.local:9000?Action=AssumeRoleWithCertificate&Version=2011-06-15&DurationSeconds=3600"
```

{{< admonition example >}}
```xml
<?xml version="1.0" encoding="UTF-8"?>
<AssumeRoleWithCertificateResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
    <AssumeRoleWithCertificateResult>
        <Credentials>
            <AccessKeyId>TBS5LE45EEUOT9NXYNU6</AccessKeyId>
            <SecretAccessKey>Z+qZ2FnhmDbmaROJFe+yOSUP81TAwcYRSgEZ6ogq</SecretAccessKey>
            <SessionToken>
                eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NLZXkiOiJUQlM1TEU0NUVFVU9UOU5YWU5VNiIsImF1ZCI6WyJtaW5pbyJdLCJleHAiOjE2NzE5MTM2MzUsImlzcyI6Imt1a3VsYW0iLCJwYXJlbnQiOiJ0bHM6cmVhZG9ubHkiLCJzdWIiOiJyZWFkb25seSJ9.sriYyaFsqCTwSiV9vhbO2vo3QbNlemm2iGUHqLCMaJIaeR25kRFwiOiIzGSPk7NxH2avOEpHVVsnQRqv86_JSQ
            </SessionToken>
            <Expiration>2022-12-24T20:27:15Z</Expiration>
        </Credentials>
    </AssumeRoleWithCertificateResult>
    <ResponseMetadata>
        <RequestId>1733D151B7222714</RequestId>
    </ResponseMetadata>
</AssumeRoleWithCertificateResponse>
```
{{< /admonition >}}

### 3. Use `amazon/aws-cli` to authenticate
```bash
aws configure set default.s3.signature_version s3v4
aws configure set aws_access_key_id TBS5LE45EEUOT9NXYNU6
aws configure set aws_secret_access_key Z+qZ2FnhmDbmaROJFe+yOSUP81TAwcYRSgEZ6ogq
aws configure set aws_session_token eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NLZXkiOiJUQlM1TEU0NUVFVU9UOU5YWU5VNiIsImF1ZCI6WyJtaW5pbyJdLCJleHAiOjE2NzE5MTM2MzUsImlzcyI6Imt1a3VsYW0iLCJwYXJlbnQiOiJ0bHM6cmVhZG9ubHkiLCJzdWIiOiJyZWFkb25seSJ9.sriYyaFsqCTwSiV9vhbO2vo3QbNlemm2iGUHqLCMaJIaeR25kRFwiOiIzGSPk7NxH2avOEpHVVsnQRqv86_JSQ

touch certs.pem
cat /tmp/minio/readonly-certs/private.key >> certs.pem 
cat /tmp/minio/readonly-certs/public.crt >> certs.pem 
cat /tmp/minio/certs/ca.crt >> certs.pem 
```

### 4. Verify permissions
{{< admonition note >}}
`readonly` policies can only fetch object from all buckets, but it cannot modify any objects.
{{< /admonition >}}


#### verify that it's possible to fetch object from a bucket
```bash
aws --ca-bundle ./certs.pem --endpoint-url https://minio-0.minio.minio.svc.cluster.local:9000 s3 cp s3://bucket1/test.txt ./test2.txt
cat ./test2.txt
```
{{< admonition example >}}
```bash
bash-4.2$ aws --ca-bundle ./certs.pem --endpoint-url https://minio-0.minio.minio.svc.cluster.local:9000 s3 ls
2022-12-24 19:54:01 bucket1
bash-4.2$ aws --ca-bundle ./certs.pem --endpoint-url https://minio-0.minio.minio.svc.cluster.local:9000 s3 cp s3://bucket1/test.txt ./test2.txtdownload: s3://bucket1/test.txt to ./test2.txt
bash-4.2$ cat ./test2.txt
test
```
{{< /admonition >}}

#### verify that it's not possible to upload object to the bucket
```bash
touch test3.txt
echo "test" > test3.txt
aws --ca-bundle ./certs.pem \
  --endpoint-url https://minio-0.minio.minio.svc.cluster.local:9000 \
  s3 cp ./test3.txt s3://bucket1/test3.txt
```

{{< admonition example >}}
```bash
bash-4.2$ aws --ca-bundle ./certs.pem --endpoint-url https://minio-0.minio.minio.svc.cluster.local:9000 s3 cp ./test3.txt s3://bucket1/test3.txt
upload failed: ./test3.txt to s3://bucket1/test3.txt An error occurred (AccessDenied) when calling the PutObject operation: Access Denied.
```
{{< /admonition >}}

## Important note
{{< admonition warning >}}
`minio/mc` does not support `AssumeRoleWithCertificate` mechanism by using `mc config host add`.
{{< /admonition >}}

## Github project
All files which I used to test `AssumeRoleWithCertificate` mechanism are stored in [github repository](https://github.com/kukulam/blog-code-materials/tree/main/authentication-with-client-certificate-in-minio).

## References
- [Minio AssumeRoleWithCertificate docs](https://github.com/minio/minio/blob/master/docs/sts/tls.md)
- [How to generate self signed certificate](https://cert-manager.io/docs/configuration/selfsigned/)
- [How to generate CA](https://cert-manager.io/docs/configuration/ca/)
- [Base64 encoder](https://www.base64encode.org/)
- [Certificates generator](https://certificatetools.com/)

Photo by [Edgar](https://unsplash.com/@ymoran) on [Unsplash](https://unsplash.com)