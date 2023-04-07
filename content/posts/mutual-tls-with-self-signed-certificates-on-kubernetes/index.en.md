---
title: "Mutual TLS with self-signed certificates on kubernetes"
date: 2023-04-03T19:09:19+02:00
draft: false
tags: ["k8s", "kubernetes", "mtls", "tls", "security"]
categories: ["kubernetes", "security"]

resources:
- name: "logo"
  src: "logo.png"

featuredImage: "logo"
lightgallery: true
---

## Mutual TLS with self-signed certificates on kubernetes

During my daily work very often I need to set up mutual tls for given service
or database. The problem appears during local development, because on local Kubernetes 
cluster mutual authentication is not provided. In that case, [cert manager](https://cert-manager.io) will help us
to solve this problem. 

{{< admonition warning >}}
Self-signed certificates are very useful for local development and testing, but
they shouldn't be used in production environment. In that case, you can use [Vault](https://www.vaultproject.io/).
{{< /admonition >}}

## 0. Prepare necessary configuration files
### **certconfig.txt**
```text
[ req ]
default_md = sha256
prompt = no
string_mask = utf8only
req_extensions = req_ext
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
commonName = kukulam
organizationName = kukulam.dev
[ req_ext ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
extendedKeyUsage=critical,serverAuth,clientAuth
basicConstraints=critical,CA:true
subjectAltName = @alt_names
[ alt_names ]
DNS.0 = localhost
```

### **csrconfig.txt**
```text
[ req ]
default_md = sha256
prompt = no
string_mask = utf8only
req_extensions = req_ext
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
commonName = kukulam
organizationName = kukulam.dev
[ req_ext ]
keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign
extendedKeyUsage=critical,serverAuth,clientAuth
basicConstraints=critical,CA:true
subjectAltName = @alt_names
[ alt_names ]
DNS.0 = localhost
```
### **generate-cert.sh** 

{{< admonition tip >}}
If bash commands are too nerdy for you, there is website which could do the same job.
You can generate certificate by using [certificatetools](https://certificatetools.com/).
{{< /admonition >}}

Script generates `tls.crt` and `tls.key` file using configs: `csrconfig.txt`, `certconfig.txt`.
```bash
# Generate the RSA private key
openssl genpkey -outform PEM -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out tls.key

# Create the CSR
openssl req -new -nodes -key tls.key -config csrconfig.txt -nameopt utf8 -utf8 -out cert.csr

# Self-sign your CSR
openssl req -x509 -nodes -in cert.csr -days 365 -key tls.key -config certconfig.txt -extensions req_ext -nameopt utf8 -utf8 -out tls.crt

# Clean up
rm cert.csr
```

#### Result:
```bash
» ./generate-cert.sh
.+++
..........................................................................................................................................................................+++
» ls
certconfig.txt   csrconfig.txt    generate-cert.sh tls.crt          tls.key
» cat tls.crt
-----BEGIN CERTIFICATE-----
MIIDcDCCAligAwIBAgIJAJ29UKxmiWYsMA0GCSqGSIb3DQEBCwUAMCgxEDAOBgNV
BAMMB2t1a3VsYW0xFDASBgNVBAoMC2t1a3VsYW0uZGV2MB4XDTIzMDQwMzE5MjYw
N1oXDTI0MDQwMjE5MjYwN1owKDEQMA4GA1UEAwwHa3VrdWxhbTEUMBIGA1UECgwL
a3VrdWxhbS5kZXYwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDP9N29
vvDTt7R6izGtUDK7IyrwwZmCHXn5wrle8nXBFvBrHO2lHyyCUARrO986wInW4mXs
UbRyVe8O2Q9ArrRZcMCL55VDEpDDQTROpoxYyYlp30EtOdKDw1cwYQAGGFIjCVrI
IhMaxmP1j7s2FgdNHym6wADEcYzJPLHJxRv9NUd62aTm6UQgjz2bB5CWG6ipYdcO
sMcwaAOhR8pMC1b23gcauVY2ZfhbLVNTZpvfZj9q0IpIds7EjfjzPETKcbvnEtqo
fk6Dm7GO7dusQMZEXccHfLT1HsbIedU9VzXX0l9QIzIo9YhcllkM0l582O9zCvXT
daw0FggHQJCi/sBzAgMBAAGjgZwwgZkwHQYDVR0OBBYEFHWKDAByGkn+vQT0rJG5
EpSJ7xUDMB8GA1UdIwQYMBaAFHWKDAByGkn+vQT0rJG5EpSJ7xUDMA4GA1UdDwEB
/wQEAwICpDAgBgNVHSUBAf8EFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDwYDVR0T
AQH/BAUwAwEB/zAUBgNVHREEDTALgglsb2NhbGhvc3QwDQYJKoZIhvcNAQELBQAD
ggEBABu7JecWhZAx06GL65NSlLicSr8Ie8OmU56uFNY8PWvGt17Hirv47/nCgyLz
ATeDU5TJGLSB/xiOsdUU5i4K8SqTFfunay6rXKkr2We29xR6CLz+LvE27bP7eZ5X
twPeoiuOaFtqQejS4qBEAH3LqSH86sFP1sM69P9MHpoFOZLo4GYMMG8hbmw0vHN6
vSdtZ8FdM+38QkL9Jcjqgh5zSU2GZ+D21TjX5bLr2udxxHRKh+b3IgVz6CbUCWc+
UFQQn55sYUVN6WvA+DZkPr5Mo8KEmd1OwMF8wV/quzvchxbSJq4193ZmgGu7oFAW
BmNdqsdlVXQw5cyATjb5CcG/oTM=
-----END CERTIFICATE-----
» cat tls.key
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDP9N29vvDTt7R6
izGtUDK7IyrwwZmCHXn5wrle8nXBFvBrHO2lHyyCUARrO986wInW4mXsUbRyVe8O
2Q9ArrRZcMCL55VDEpDDQTROpoxYyYlp30EtOdKDw1cwYQAGGFIjCVrIIhMaxmP1
j7s2FgdNHym6wADEcYzJPLHJxRv9NUd62aTm6UQgjz2bB5CWG6ipYdcOsMcwaAOh
R8pMC1b23gcauVY2ZfhbLVNTZpvfZj9q0IpIds7EjfjzPETKcbvnEtqofk6Dm7GO
7dusQMZEXccHfLT1HsbIedU9VzXX0l9QIzIo9YhcllkM0l582O9zCvXTdaw0FggH
QJCi/sBzAgMBAAECggEAGKBl1f+To27g15Y+Rsj1iQXMIwC6Phdhh3tQ2naaDUi7
JeQiHGjJq5DwRQatE9cTO7hJ26d9WADnM3nu/Xjy8JiSpL7DBVNgg07oc9vzSNxt
AnWm0UVEscfjPl5uU0p0B6Qm9QZb/tK5qa3gvLH1IWPsXCo6rQjJZFdksoE+JEkB
TKUITpQ0zyMLJiPTPBg+pX1YOZwV0rYCHexnIX2FlAm1Hith48wA5y92KdImQA7B
qFpSGT4QnKY9xn0kSXPA6EKG/VRgqKRFwg5RgFByYRTmU1KdTWlII7vagTQnPl3G
jbritQSVVu320fUOhcxqSe+iwaWDL6gZ1JXRRjAWgQKBgQDoqNeQsiMfSo7Aa+eN
2EJfATtzsRqwXqfQIUnBf6bgnOG7lOJFSnP7X1bAYPe9z4l8viIU6kN0gRofYBE6
AW0BarRRdZvNcHELgWhIOFlrRx0ye/FnW5UmF26zXY0amc6/gHyFPq3oPKcdzYlB
tX5zZV6xdktZK20XphsH5TEZQQKBgQDk0ZnyC8oF+7WJYfTaeBGaN06bV+cN2qEi
cuFE7zQad/W5zBUkisYPvwizS+EX+kG0jZwi/Bi0hWUwuzcW1pttVRoujzteCy+3
GG/8MZJcr+Rnzzt1LnKV8BQyCP/kEs12/dDyyBB2SEQDJD3ZOrShg2aDUuXilLTl
iaGhSEwYswKBgQCAHiH+qynOHGd5rLHpGVKLMImFjtxMjQNKCFquNFY30Aw6GKV1
VKeDoB+MdplWK8fhKm5oKAyXRlSVPHigAZL+Ob0sMmBmg+msVUmQo38SJSn91+S6
buM2A6dRHE4MfPAt4lovobFwdp3sOne/+Gq2rvazMJoTc2dyo2S1N0+PQQKBgCOM
xQQr/LktQCkWBPqkSOfSy+2qnIU0gHBftMwG9ete09iH8oj43oi3v1xL367f/LFW
hvmQfS4ew3fsvkRYF1HHNQgizLBxwHoL2+ossXahBTVzpuMv0jGlWR3k9Ay1NyLT
kFEH8DbQR3DNgqZrToEBbz3b9UdcnzZCSdBK8TetAoGADxvNI9KyZ2MPT3PDrPAT
i40dcVcOprKouwxcHEaPwwHSkgvEegpLUl3KLgjI3CF2RwmKsf7p2lqTrh7by/pP
G9YcwpMhaG9juXBtsox2mGm0I7KvWYxg/F2FeiFP09mAjwTPFRf7i0XBMqBAWkxD
fGdZQsJxw8Ly+8ANLZG4lEU=
-----END PRIVATE KEY-----
```

## 1. Encode certificate with base64
{{< admonition note >}}
To encode you can use the bash command `base64`
```bash
» echo "text" | base64
dGV4dAo=
```
or you can use [base64encode](https://www.base64encode.org/) website.
{{< /admonition >}}
### Encode `tls.crt`
```text
LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURjRENDQWxpZ0F3SUJBZ0lKQUoyOVVLeG1pV1lzTUEwR0NTcUdTSWIzRFFFQkN3VUFNQ2d4RURBT0JnTlYKQkFNTUIydDFhM1ZzWVcweEZEQVNCZ05WQkFvTUMydDFhM1ZzWVcwdVpHVjJNQjRYRFRJek1EUXdNekU1TWpZdwpOMW9YRFRJME1EUXdNakU1TWpZd04xb3dLREVRTUE0R0ExVUVBd3dIYTNWcmRXeGhiVEVVTUJJR0ExVUVDZ3dMCmEzVnJkV3hoYlM1a1pYWXdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFEUDlOMjkKdnZEVHQ3UjZpekd0VURLN0l5cnd3Wm1DSFhuNXdybGU4blhCRnZCckhPMmxIeXlDVUFSck85ODZ3SW5XNG1YcwpVYlJ5VmU4TzJROUFyclJaY01DTDU1VkRFcEREUVRST3BveFl5WWxwMzBFdE9kS0R3MWN3WVFBR0dGSWpDVnJJCkloTWF4bVAxajdzMkZnZE5IeW02d0FERWNZekpQTEhKeFJ2OU5VZDYyYVRtNlVRZ2p6MmJCNUNXRzZpcFlkY08Kc01jd2FBT2hSOHBNQzFiMjNnY2F1VlkyWmZoYkxWTlRacHZmWmo5cTBJcElkczdFamZqelBFVEtjYnZuRXRxbwpmazZEbTdHTzdkdXNRTVpFWGNjSGZMVDFIc2JJZWRVOVZ6WFgwbDlRSXpJbzlZaGNsbGtNMGw1ODJPOXpDdlhUCmRhdzBGZ2dIUUpDaS9zQnpBZ01CQUFHamdad3dnWmt3SFFZRFZSME9CQllFRkhXS0RBQnlHa24rdlFUMHJKRzUKRXBTSjd4VURNQjhHQTFVZEl3UVlNQmFBRkhXS0RBQnlHa24rdlFUMHJKRzVFcFNKN3hVRE1BNEdBMVVkRHdFQgovd1FFQXdJQ3BEQWdCZ05WSFNVQkFmOEVGakFVQmdnckJnRUZCUWNEQVFZSUt3WUJCUVVIQXdJd0R3WURWUjBUCkFRSC9CQVV3QXdFQi96QVVCZ05WSFJFRURUQUxnZ2xzYjJOaGJHaHZjM1F3RFFZSktvWklodmNOQVFFTEJRQUQKZ2dFQkFCdTdKZWNXaFpBeDA2R0w2NU5TbExpY1NyOEllOE9tVTU2dUZOWThQV3ZHdDE3SGlydjQ3L25DZ3lMegpBVGVEVTVUSkdMU0IveGlPc2RVVTVpNEs4U3FURmZ1bmF5NnJYS2tyMldlMjl4UjZDTHorTHZFMjdiUDdlWjVYCnR3UGVvaXVPYUZ0cVFlalM0cUJFQUgzTHFTSDg2c0ZQMXNNNjlQOU1IcG9GT1pMbzRHWU1NRzhoYm13MHZITjYKdlNkdFo4RmRNKzM4UWtMOUpjanFnaDV6U1UyR1orRDIxVGpYNWJMcjJ1ZHh4SFJLaCtiM0lnVno2Q2JVQ1djKwpVRlFRbjU1c1lVVk42V3ZBK0Raa1ByNU1vOEtFbWQxT3dNRjh3Vi9xdXp2Y2h4YlNKcTQxOTNabWdHdTdvRkFXCkJtTmRxc2RsVlhRdzVjeUFUamI1Q2NHL29UTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ==
```
### Encode `tls.key`
```text
LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRRFA5TjI5dnZEVHQ3UjYKaXpHdFVESzdJeXJ3d1ptQ0hYbjV3cmxlOG5YQkZ2QnJITzJsSHl5Q1VBUnJPOTg2d0luVzRtWHNVYlJ5VmU4TwoyUTlBcnJSWmNNQ0w1NVZERXBERFFUUk9wb3hZeVlscDMwRXRPZEtEdzFjd1lRQUdHRklqQ1ZySUloTWF4bVAxCmo3czJGZ2ROSHltNndBREVjWXpKUExISnhSdjlOVWQ2MmFUbTZVUWdqejJiQjVDV0c2aXBZZGNPc01jd2FBT2gKUjhwTUMxYjIzZ2NhdVZZMlpmaGJMVk5UWnB2ZlpqOXEwSXBJZHM3RWpmanpQRVRLY2J2bkV0cW9mazZEbTdHTwo3ZHVzUU1aRVhjY0hmTFQxSHNiSWVkVTlWelhYMGw5UUl6SW85WWhjbGxrTTBsNTgyTzl6Q3ZYVGRhdzBGZ2dIClFKQ2kvc0J6QWdNQkFBRUNnZ0VBR0tCbDFmK1RvMjdnMTVZK1JzajFpUVhNSXdDNlBoZGhoM3RRMm5hYURVaTcKSmVRaUhHakpxNUR3UlFhdEU5Y1RPN2hKMjZkOVdBRG5NM251L1hqeThKaVNwTDdEQlZOZ2cwN29jOXZ6U054dApBbldtMFVWRXNjZmpQbDV1VTBwMEI2UW05UVpiL3RLNXFhM2d2TEgxSVdQc1hDbzZyUWpKWkZka3NvRStKRWtCClRLVUlUcFEwenlNTEppUFRQQmcrcFgxWU9ad1YwcllDSGV4bklYMkZsQW0xSGl0aDQ4d0E1eTkyS2RJbVFBN0IKcUZwU0dUNFFuS1k5eG4wa1NYUEE2RUtHL1ZSZ3FLUkZ3ZzVSZ0ZCeVlSVG1VMUtkVFdsSUk3dmFnVFFuUGwzRwpqYnJpdFFTVlZ1MzIwZlVPaGN4cVNlK2l3YVdETDZnWjFKWFJSakFXZ1FLQmdRRG9xTmVRc2lNZlNvN0FhK2VOCjJFSmZBVHR6c1Jxd1hxZlFJVW5CZjZiZ25PRzdsT0pGU25QN1gxYkFZUGU5ejRsOHZpSVU2a04wZ1JvZllCRTYKQVcwQmFyUlJkWnZOY0hFTGdXaElPRmxyUngweWUvRm5XNVVtRjI2elhZMGFtYzYvZ0h5RlBxM29QS2NkellsQgp0WDV6WlY2eGRrdFpLMjBYcGhzSDVURVpRUUtCZ1FEazBabnlDOG9GKzdXSllmVGFlQkdhTjA2YlYrY04ycUVpCmN1RkU3elFhZC9XNXpCVWtpc1lQdndpelMrRVgra0cwalp3aS9CaTBoV1V3dXpjVzFwdHRWUm91anp0ZUN5KzMKR0cvOE1aSmNyK1Juenp0MUxuS1Y4QlF5Q1Ava0VzMTIvZER5eUJCMlNFUURKRDNaT3JTaGcyYURVdVhpbExUbAppYUdoU0V3WXN3S0JnUUNBSGlIK3F5bk9IR2Q1ckxIcEdWS0xNSW1GanR4TWpRTktDRnF1TkZZMzBBdzZHS1YxClZLZURvQitNZHBsV0s4ZmhLbTVvS0F5WFJsU1ZQSGlnQVpMK09iMHNNbUJtZyttc1ZVbVFvMzhTSlNuOTErUzYKYnVNMkE2ZFJIRTRNZlBBdDRsb3ZvYkZ3ZHAzc09uZS8rR3EycnZhek1Kb1RjMmR5bzJTMU4wK1BRUUtCZ0NPTQp4UVFyL0xrdFFDa1dCUHFrU09mU3krMnFuSVUwZ0hCZnRNd0c5ZXRlMDlpSDhvajQzb2kzdjF4TDM2N2YvTEZXCmh2bVFmUzRldzNmc3ZrUllGMUhITlFnaXpMQnh3SG9MMitvc3NYYWhCVFZ6cHVNdjBqR2xXUjNrOUF5MU55TFQKa0ZFSDhEYlFSM0ROZ3FaclRvRUJiejNiOVVkY256WkNTZEJLOFRldEFvR0FEeHZOSTlLeVoyTVBUM1BEclBBVAppNDBkY1ZjT3ByS291d3hjSEVhUHd3SFNrZ3ZFZWdwTFVsM0tMZ2pJM0NGMlJ3bUtzZjdwMmxxVHJoN2J5L3BQCkc5WWN3cE1oYUc5anVYQnRzb3gybUdtMEk3S3ZXWXhnL0YyRmVpRlAwOW1BandUUEZSZjdpMFhCTXFCQVdreEQKZkdkWlFzSnh3OEx5KzhBTkxaRzRsRVU9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0=
```

## 2. Setup `ClusterIssuer` with `cert-manager` on kubernetes

{{< admonition note >}}
You can use `Issuer` instead of `ClusterIssuer` if you want to 
isolate resource within single namespace. `ClusterIssuer` is visible globally
on kubernetes cluster.
{{< /admonition >}}

### cluster-issuer-secrets.yml
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ca-issuer-certs
  namespace: cert-manager
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURjRENDQWxpZ0F3SUJBZ0lKQUoyOVVLeG1pV1lzTUEwR0NTcUdTSWIzRFFFQkN3VUFNQ2d4RURBT0JnTlYKQkFNTUIydDFhM1ZzWVcweEZEQVNCZ05WQkFvTUMydDFhM1ZzWVcwdVpHVjJNQjRYRFRJek1EUXdNekU1TWpZdwpOMW9YRFRJME1EUXdNakU1TWpZd04xb3dLREVRTUE0R0ExVUVBd3dIYTNWcmRXeGhiVEVVTUJJR0ExVUVDZ3dMCmEzVnJkV3hoYlM1a1pYWXdnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFEUDlOMjkKdnZEVHQ3UjZpekd0VURLN0l5cnd3Wm1DSFhuNXdybGU4blhCRnZCckhPMmxIeXlDVUFSck85ODZ3SW5XNG1YcwpVYlJ5VmU4TzJROUFyclJaY01DTDU1VkRFcEREUVRST3BveFl5WWxwMzBFdE9kS0R3MWN3WVFBR0dGSWpDVnJJCkloTWF4bVAxajdzMkZnZE5IeW02d0FERWNZekpQTEhKeFJ2OU5VZDYyYVRtNlVRZ2p6MmJCNUNXRzZpcFlkY08Kc01jd2FBT2hSOHBNQzFiMjNnY2F1VlkyWmZoYkxWTlRacHZmWmo5cTBJcElkczdFamZqelBFVEtjYnZuRXRxbwpmazZEbTdHTzdkdXNRTVpFWGNjSGZMVDFIc2JJZWRVOVZ6WFgwbDlRSXpJbzlZaGNsbGtNMGw1ODJPOXpDdlhUCmRhdzBGZ2dIUUpDaS9zQnpBZ01CQUFHamdad3dnWmt3SFFZRFZSME9CQllFRkhXS0RBQnlHa24rdlFUMHJKRzUKRXBTSjd4VURNQjhHQTFVZEl3UVlNQmFBRkhXS0RBQnlHa24rdlFUMHJKRzVFcFNKN3hVRE1BNEdBMVVkRHdFQgovd1FFQXdJQ3BEQWdCZ05WSFNVQkFmOEVGakFVQmdnckJnRUZCUWNEQVFZSUt3WUJCUVVIQXdJd0R3WURWUjBUCkFRSC9CQVV3QXdFQi96QVVCZ05WSFJFRURUQUxnZ2xzYjJOaGJHaHZjM1F3RFFZSktvWklodmNOQVFFTEJRQUQKZ2dFQkFCdTdKZWNXaFpBeDA2R0w2NU5TbExpY1NyOEllOE9tVTU2dUZOWThQV3ZHdDE3SGlydjQ3L25DZ3lMegpBVGVEVTVUSkdMU0IveGlPc2RVVTVpNEs4U3FURmZ1bmF5NnJYS2tyMldlMjl4UjZDTHorTHZFMjdiUDdlWjVYCnR3UGVvaXVPYUZ0cVFlalM0cUJFQUgzTHFTSDg2c0ZQMXNNNjlQOU1IcG9GT1pMbzRHWU1NRzhoYm13MHZITjYKdlNkdFo4RmRNKzM4UWtMOUpjanFnaDV6U1UyR1orRDIxVGpYNWJMcjJ1ZHh4SFJLaCtiM0lnVno2Q2JVQ1djKwpVRlFRbjU1c1lVVk42V3ZBK0Raa1ByNU1vOEtFbWQxT3dNRjh3Vi9xdXp2Y2h4YlNKcTQxOTNabWdHdTdvRkFXCkJtTmRxc2RsVlhRdzVjeUFUamI1Q2NHL29UTT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ==
  tls.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRRFA5TjI5dnZEVHQ3UjYKaXpHdFVESzdJeXJ3d1ptQ0hYbjV3cmxlOG5YQkZ2QnJITzJsSHl5Q1VBUnJPOTg2d0luVzRtWHNVYlJ5VmU4TwoyUTlBcnJSWmNNQ0w1NVZERXBERFFUUk9wb3hZeVlscDMwRXRPZEtEdzFjd1lRQUdHRklqQ1ZySUloTWF4bVAxCmo3czJGZ2ROSHltNndBREVjWXpKUExISnhSdjlOVWQ2MmFUbTZVUWdqejJiQjVDV0c2aXBZZGNPc01jd2FBT2gKUjhwTUMxYjIzZ2NhdVZZMlpmaGJMVk5UWnB2ZlpqOXEwSXBJZHM3RWpmanpQRVRLY2J2bkV0cW9mazZEbTdHTwo3ZHVzUU1aRVhjY0hmTFQxSHNiSWVkVTlWelhYMGw5UUl6SW85WWhjbGxrTTBsNTgyTzl6Q3ZYVGRhdzBGZ2dIClFKQ2kvc0J6QWdNQkFBRUNnZ0VBR0tCbDFmK1RvMjdnMTVZK1JzajFpUVhNSXdDNlBoZGhoM3RRMm5hYURVaTcKSmVRaUhHakpxNUR3UlFhdEU5Y1RPN2hKMjZkOVdBRG5NM251L1hqeThKaVNwTDdEQlZOZ2cwN29jOXZ6U054dApBbldtMFVWRXNjZmpQbDV1VTBwMEI2UW05UVpiL3RLNXFhM2d2TEgxSVdQc1hDbzZyUWpKWkZka3NvRStKRWtCClRLVUlUcFEwenlNTEppUFRQQmcrcFgxWU9ad1YwcllDSGV4bklYMkZsQW0xSGl0aDQ4d0E1eTkyS2RJbVFBN0IKcUZwU0dUNFFuS1k5eG4wa1NYUEE2RUtHL1ZSZ3FLUkZ3ZzVSZ0ZCeVlSVG1VMUtkVFdsSUk3dmFnVFFuUGwzRwpqYnJpdFFTVlZ1MzIwZlVPaGN4cVNlK2l3YVdETDZnWjFKWFJSakFXZ1FLQmdRRG9xTmVRc2lNZlNvN0FhK2VOCjJFSmZBVHR6c1Jxd1hxZlFJVW5CZjZiZ25PRzdsT0pGU25QN1gxYkFZUGU5ejRsOHZpSVU2a04wZ1JvZllCRTYKQVcwQmFyUlJkWnZOY0hFTGdXaElPRmxyUngweWUvRm5XNVVtRjI2elhZMGFtYzYvZ0h5RlBxM29QS2NkellsQgp0WDV6WlY2eGRrdFpLMjBYcGhzSDVURVpRUUtCZ1FEazBabnlDOG9GKzdXSllmVGFlQkdhTjA2YlYrY04ycUVpCmN1RkU3elFhZC9XNXpCVWtpc1lQdndpelMrRVgra0cwalp3aS9CaTBoV1V3dXpjVzFwdHRWUm91anp0ZUN5KzMKR0cvOE1aSmNyK1Juenp0MUxuS1Y4QlF5Q1Ava0VzMTIvZER5eUJCMlNFUURKRDNaT3JTaGcyYURVdVhpbExUbAppYUdoU0V3WXN3S0JnUUNBSGlIK3F5bk9IR2Q1ckxIcEdWS0xNSW1GanR4TWpRTktDRnF1TkZZMzBBdzZHS1YxClZLZURvQitNZHBsV0s4ZmhLbTVvS0F5WFJsU1ZQSGlnQVpMK09iMHNNbUJtZyttc1ZVbVFvMzhTSlNuOTErUzYKYnVNMkE2ZFJIRTRNZlBBdDRsb3ZvYkZ3ZHAzc09uZS8rR3EycnZhek1Kb1RjMmR5bzJTMU4wK1BRUUtCZ0NPTQp4UVFyL0xrdFFDa1dCUHFrU09mU3krMnFuSVUwZ0hCZnRNd0c5ZXRlMDlpSDhvajQzb2kzdjF4TDM2N2YvTEZXCmh2bVFmUzRldzNmc3ZrUllGMUhITlFnaXpMQnh3SG9MMitvc3NYYWhCVFZ6cHVNdjBqR2xXUjNrOUF5MU55TFQKa0ZFSDhEYlFSM0ROZ3FaclRvRUJiejNiOVVkY256WkNTZEJLOFRldEFvR0FEeHZOSTlLeVoyTVBUM1BEclBBVAppNDBkY1ZjT3ByS291d3hjSEVhUHd3SFNrZ3ZFZWdwTFVsM0tMZ2pJM0NGMlJ3bUtzZjdwMmxxVHJoN2J5L3BQCkc5WWN3cE1oYUc5anVYQnRzb3gybUdtMEk3S3ZXWXhnL0YyRmVpRlAwOW1BandUUEZSZjdpMFhCTXFCQVdreEQKZkdkWlFzSnh3OEx5KzhBTkxaRzRsRVU9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0=
```

### cluster-issuer.yml
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: ca-issuer-certs
```

### Apply manifests
```bash
kubectl apply -f cluster-issuer-secrets.yml
kubectl apply -f cluster-issuer.yml
```

#### Result
```bash
» kubectl apply -f cluster-issuer-secrets.yml
secret/ca-issuer-certs created
» kubectl apply -f cluster-issuer.yml
clusterissuer.cert-manager.io/ca-issuer created
» kubectl get secrets -n cert-manager
NAME                      TYPE     DATA   AGE
ca-issuer-certs           Opaque   2      43s
cert-manager-webhook-ca   Opaque   3      23h
» kubectl get clusterissuers.cert-manager.io -n cert-manager
NAME        READY   AGE
ca-issuer   True    57s
```

## 3. Setup certificate on kubernetes
### certificate.yml
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-certificate
  namespace: mtls
  labels:
    app.kubernetes.io/name: mtls
spec:
  isCA: false
  secretName: mtls-certs
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
  dnsNames:
    - "localhost"
    - "127.0.0.1"
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
    group: cert-manager.io
```
### Apply manifest
```bash
kubectl apply -f certificate.yml
```

#### Result
```bash
» kubectl apply -f certificate.yml
certificate.cert-manager.io/example-certificate created
» kubectl get certificates -n mtls
NAME                  READY   SECRET       AGE
example-certificate   True    mtls-certs   34s
» kubectl describe certificate example-certificate -n mtls
Name:         example-certificate
Namespace:    mtls
Labels:       app.kubernetes.io/name=mtls
Annotations:  <none>
API Version:  cert-manager.io/v1
Kind:         Certificate
Metadata:
  Creation Timestamp:  2023-04-07T17:26:54Z
  Generation:          1
  Managed Fields:
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:conditions:
          .:
          k:{"type":"Ready"}:
            .:
            f:lastTransitionTime:
            f:message:
            f:observedGeneration:
            f:reason:
            f:status:
            f:type:
        f:notAfter:
        f:notBefore:
        f:renewalTime:
    Manager:      cert-manager-certificates-readiness
    Operation:    Update
    Subresource:  status
    Time:         2023-04-07T17:26:54Z
    API Version:  cert-manager.io/v1
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          .:
          f:kubectl.kubernetes.io/last-applied-configuration:
        f:labels:
          .:
          f:app.kubernetes.io/name:
      f:spec:
        .:
        f:dnsNames:
        f:duration:
        f:isCA:
        f:issuerRef:
          .:
          f:group:
          f:kind:
          f:name:
        f:privateKey:
          .:
          f:algorithm:
          f:encoding:
          f:size:
        f:renewBefore:
        f:secretName:
        f:usages:
    Manager:         kubectl-client-side-apply
    Operation:       Update
    Time:            2023-04-07T17:26:54Z
  Resource Version:  52466
  UID:               ea79b5b7-6ca3-4277-89a9-717e88352364
Spec:
  Dns Names:
    localhost
    127.0.0.1
  Duration:  9000h0m0s
  Issuer Ref:
    Group:  cert-manager.io
    Kind:   ClusterIssuer
    Name:   ca-issuer
  Private Key:
    Algorithm:   RSA
    Encoding:    PKCS1
    Size:        2048
  Renew Before:  180h0m0s
  Secret Name:   mtls-certs
  Usages:
    digital signature
    key encipherment
    client auth
Status:
  Conditions:
    Last Transition Time:  2023-04-07T17:26:54Z
    Message:               Certificate is up to date and has not expired
    Observed Generation:   1
    Reason:                Ready
    Status:                True
    Type:                  Ready
  Not After:               2024-04-11T22:03:41Z
  Not Before:              2023-04-02T22:03:41Z
  Renewal Time:            2024-04-04T10:03:41Z
Events:                    <none>
» kubectl get secrets -n mtls
NAME         TYPE                DATA   AGE
mtls-certs   kubernetes.io/tls   3      4d19h

```
## 4. Generated certificate is stored in kubernetes secrets
```bash
» kubectl describe secret mtls-certs -n mtls
Name:         mtls-certs
Namespace:    mtls
Labels:       <none>
Annotations:  cert-manager.io/alt-names: localhost,127.0.0.1
              cert-manager.io/certificate-name: example-certificate
              cert-manager.io/common-name:
              cert-manager.io/ip-sans:
              cert-manager.io/issuer-group: cert-manager.io
              cert-manager.io/issuer-kind: ClusterIssuer
              cert-manager.io/issuer-name: ca-issuer
              cert-manager.io/uri-sans:

Type:  kubernetes.io/tls

Data
====
ca.crt:   1253 bytes
tls.crt:  1159 bytes
tls.key:  1675 bytes
```

## References
- [How to generate self signed certificate](https://cert-manager.io/docs/configuration/selfsigned/)
- [How to generate CA](https://cert-manager.io/docs/configuration/ca/)
- [ClusterIssuer vs Issuer](https://cert-manager.io/docs/concepts/issuer/)
- [Base64 encoder](https://www.base64encode.org/)
- [Certificates generator](https://certificatetools.com/)

Photo by [Muhammad Zaqy Al Fattah](https://unsplash.com/@dizzydizz?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText") on [Unsplash](https://unsplash.com/photos/Lexcm-6FHRU?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText")

  

