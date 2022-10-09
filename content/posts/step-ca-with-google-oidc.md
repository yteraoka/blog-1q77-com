---
title: 'Google 認証でクライアント証明書発行のセルフサービス化'
date: Sat, 10 Apr 2021 14:44:13 +0000
draft: false
tags: ['TLS', 'TLS', 'smallstep']
---

以前、[caddy について調べて](/2020/08/one-liner-https-reverse-proxy-caddy/)て発見した [smallstep](https://smallstep.com/) でクライアント証明書発行を便利にできないかなということで調査です。([Hashicorp Vault](https://www.vaultproject.io/) でもできるっぽいけど用途的にわざわざクラスタ組むの面倒だなあって)

[Connect your identity provider and issue X.509 certificates for user authentication to services](https://smallstep.com/docs/tutorials/user-authentication) というドキュメントを参考に進めます。前提に [Getting Started](https://smallstep.com/docs/step-ca/getting-started) でセットアップした step-ca が起動していることとあるので、まずはこちらから。

Getting Started
---------------

まずは、[step](https://smallstep.com/docs/step-cli) と [step-ca](https://smallstep.com/docs/step-ca) コマンドをインストール。Homebrew でもインストールできます。

### CA の初期化

ファイルの保存場所をカレントディレクトリ配下にしておきます。デフォルトでは `$HOME/.step` となっています。

```
export STEPPATH=./step
```

`step ca init` で root と intermediate 証明書を作成します。`$STEPPATH/config/defaults.json` と `$STEPPATH/config/ca.json` というファイルも生成されます。`defaults.json` の方は `step` コマンド用で、`ca.json` は CA 用の設定で `step-ca` が読み込みます。

```
$ step ca init
✔ What would you like to name your new PKI? (e.g. Smallstep): myself
✔ What DNS names or IP addresses would you like to add to your new CA? (e.g. ca.smallstep.com[,1.1.1.1,etc.]): localhost
✔ What address will your new CA listen at? (e.g. :443): 127.0.0.1:8443
✔ What would you like to name the first provisioner for your new CA? (e.g. you@smallstep.com): user@example.com
✔ What do you want your password to be? [leave empty and we'll generate one]: 
✔ Password: 00;zj3z3Z/|"8gW_7aaAO,f$n{l90gxD

Generating root certificate... 
all done!

Generating intermediate certificate... 
all done!

✔ Root certificate: ./step/certs/root_ca.crt
✔ Root private key: ./step/secrets/root_ca_key
✔ Root fingerprint: 9d6e69dbb2915e5bd8f794d6b4d992b4fba5273ffcaa85c0db11514b650db1d7
✔ Intermediate certificate: ./step/certs/intermediate_ca.crt
✔ Intermediate private key: ./step/secrets/intermediate_ca_key
✔ Database folder: step/db
✔ Default configuration: ./step/config/defaults.json
✔ Certificate Authority configuration: ./step/config/ca.json

Your PKI is ready to go. To generate certificates for individual services see 'step help ca'.

FEEDBACK 😍 🍻
      The step utility is not instrumented for usage statistics. It does not
      phone home. But your feedback is extremely valuable. Any information you
      can provide regarding how you’re using `step` helps. Please send us a
      sentence or two, good or bad: feedback@smallstep.com or join
      https://github.com/smallstep/certificates/discussions.
```

What DNS names or IP addresses would you like to add to your new CA? (e.g. ca.smallstep.com\[,1.1.1.1,etc.\]) で `localhost` と指定している名前は step-ca サーバーのサーバ証明書の **Subject Alternative Name** として使われます。これは `step-ca` 起動時、リロード時などに都度発行されるようで `config/ca.json` の `dnsNames` を後から書き換えても大丈夫。`config/defaults.json` の `ca-url` のホスト名がこの `dnsName` に含まれるようにしておく必要があります。

What address will your new CA listen at? (e.g. :443) は `step-ca` が listen するアドレスです。

### Certificate Authority の実行 (step-ca の起動)

`step ca init` 時に指定した、もしくは自動生成された private key のパスワードの入力を求められます。自動起動のためにはパスワードを書いたファイルの path を `--password-file` で指定します。

```
$ step-ca $(step path)/config/ca.json
badger 2021/04/10 00:03:17 INFO: All 0 tables opened in 0s
Please enter the password to decrypt ./step/secrets/intermediate_ca_key: 
2021/04/10 00:03:27 Serving HTTPS on 127.0.0.1:8443 ...
```

### 試しに localhost のサーバ証明書を発行してみる

`step ca certificate` コマンドで証明書の発行ができます。`--san` で任意の数の **Subject Alternative Name** を設定できます(複数回指定可能)。`--not-after=1h` とすると有効期間を1時間にできます。

```
$ step ca certificate localhost srv.crt srv.key
✔ Provisioner: user@example.com (JWK) [kid: JAffF2XYO3U1qpRkLzSDDqZR8SSZPwGf23i6xO9dyAg]
✔ Please enter the password to decrypt the provisioner key: (init 時の password を入力) 
✔ CA: https://localhost:8443
✔ Certificate: srv.crt
✔ Private Key: srv.key
```

パスワード入力をコマンドラインで指定するためには `--provisioner` と `--provisioner-password` を指定します。`user@example.com` というのは `step ca init` 時に first provisioner として指定した値です。

```
step ca certificate example.com example.crt example.key \
  --provisioner user@example.com --provisioner-password-file password.txt
```

生成された証明書ファイルです。

```
$ cat srv.crt
-----BEGIN CERTIFICATE-----
MIICJDCCAcqgAwIBAgIRALOhvX+yzcdRtESGXIt0nSEwCgYIKoZIzj0EAwIwMjEP
MA0GA1UEChMGbXlzZWxmMR8wHQYDVQQDExZteXNlbGYgSW50ZXJtZWRpYXRlIENB
MB4XDTIxMDQwOTE1MjA0OFoXDTIxMDQxMDE1MjE0OFowFDESMBAGA1UEAxMJbG9j
YWxob3N0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAER5Ss0fIkHglM0Gy7pA8o
Th/uQbbDIKZ+w8Y6bOhxixe0Wf11ctpz2hNhX2RXMM/Fjtop83MG2tNGPWa9uYMd
dqOB3jCB2zAOBgNVHQ8BAf8EBAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsG
AQUFBwMCMB0GA1UdDgQWBBQ/Xp+RQ1rNKwymALq/NBNM5LDNHzAfBgNVHSMEGDAW
gBRkV6X/rjHYGF3SCaj8MdmDlFBw1jAUBgNVHREEDTALgglsb2NhbGhvc3QwVAYM
KwYBBAGCpGTGKEABBEQwQgIBAQQQdXNlckBleGFtcGxlLmNvbQQrSkFmZkYyWFlP
M1UxcXBSa0x6U0REcVpSOFNTWlB3R2YyM2k2eE85ZHlBZzAKBggqhkjOPQQDAgNI
ADBFAiEA5JbgGVX7M9oroBu/DHMxWhpRKy0T8WkeekItnCaJYFQCIBXExx5GaCiQ
ZS2tubNai9HHyx2OAmkVFj95yP5KoWmt
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIBwTCCAWegAwIBAgIRAMsNU1wV7Pe2Bu8BzBmqjW0wCgYIKoZIzj0EAwIwKjEP
MA0GA1UEChMGbXlzZWxmMRcwFQYDVQQDEw5teXNlbGYgUm9vdCBDQTAeFw0yMTA0
MDkxNDU4MjVaFw0zMTA0MDcxNDU4MjVaMDIxDzANBgNVBAoTBm15c2VsZjEfMB0G
A1UEAxMWbXlzZWxmIEludGVybWVkaWF0ZSBDQTBZMBMGByqGSM49AgEGCCqGSM49
AwEHA0IABFB9zHmlOnlSffs6FkVmXhP1TTl3WlsLoaoDcXbQqH3OkoB2uNXDljIu
ufKlTaeMG3pArn13wcvjs5FBAGqlzCWjZjBkMA4GA1UdDwEB/wQEAwIBBjASBgNV
HRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBRkV6X/rjHYGF3SCaj8MdmDlFBw1jAf
BgNVHSMEGDAWgBRNrE8AQGvyj8adZxT9j799lSGP2TAKBggqhkjOPQQDAgNIADBF
AiAYZz8AUdLe6Qa4rpraG048UVkIt8pPtPaB/pzYaaXWIgIhALLAAjOUE8rM7cp2
+o14WqC5T6vcb/V/+Fh1ME85c7GZ
-----END CERTIFICATE-----
```

"**myself Intermediate CA**" によって署名されています。**myself** というのは `step ca init` 時に What would you like to name your new PKI? (e.g. Smallstep) で指定した値です。

生成した証明書の中身は次のようになっています。

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            b3:a1:bd:7f:b2:cd:c7:51:b4:44:86:5c:8b:74:9d:21
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: O=myself, CN=myself Intermediate CA
        Validity
            Not Before: Apr  9 15:20:48 2021 GMT
            Not After : Apr 10 15:21:48 2021 GMT
        Subject: CN=localhost
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub: 
                    04:47:94:ac:d1:f2:24:1e:09:4c:d0:6c:bb:a4:0f:
                    28:4e:1f:ee:41:b6:c3:20:a6:7e:c3:c6:3a:6c:e8:
                    71:8b:17:b4:59:fd:75:72:da:73:da:13:61:5f:64:
                    57:30:cf:c5:8e:da:29:f3:73:06:da:d3:46:3d:66:
                    bd:b9:83:1d:76
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier: 
                3F:5E:9F:91:43:5A:CD:2B:0C:A6:00:BA:BF:34:13:4C:E4:B0:CD:1F
            X509v3 Authority Key Identifier: 
                keyid:64:57:A5:FF:AE:31:D8:18:5D:D2:09:A8:FC:31:D9:83:94:50:70:D6

            X509v3 Subject Alternative Name: 
                DNS:localhost
            1.3.6.1.4.1.37476.9000.64.1: 
                0B.....user@example.com.+JAffF2XYO3U1qpRkLzSDDqZR8SSZPwGf23i6xO9dyAg
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:21:00:e4:96:e0:19:55:fb:33:da:2b:a0:1b:bf:0c:
         73:31:5a:1a:51:2b:2d:13:f1:69:1e:7a:42:2d:9c:26:89:60:
         54:02:20:15:c4:c7:1e:46:68:28:90:65:2d:ad:b9:b3:5a:8b:
         d1:c7:cb:1d:8e:02:69:15:16:3f:79:c8:fe:4a:a1:69:ad
```

この後、テスト用の HTTPS サーバーを書いて実行し、curl でアクセスしてみるという手順になっています。サーバーは Intermediate 証明書も返してくるので root 証明書があれば検証可能です。これは `[step ca root](https://smallstep.com/docs/step-cli/reference/ca/root)` コマンドで取得可能です。`step ca root root.crt` などとファイル名も指定すればファイルに書き出されます。

```
$ step ca root root.crt
The root certificate has been saved in root.crt.
```

Personal certificates via OAuth OpenID Connect
----------------------------------------------

それでは元に戻って、OIDC 連携を進めます。

### OIDC Provisioner の追加

```
step ca provisioner add Google --type oidc --ca-config $(step path)/config/ca.json \
    --client-id ${CLIENT_ID} \
    --client-secret ${CLIENT_SECRET} \
    --configuration-endpoint https://accounts.google.com/.well-known/openid-configuration \
    --domain example.com \
    --listen-address :10000
```

`--listen-address` はドキュメントの例にありませんでしたが、この provisioner の場合、`[step oauth](https://smallstep.com/docs/step-cli/reference/oauth)` コマンドが手元で実行されて、それが Google での認証後の redirect を待ち受けます。port 指定がないと毎回違う port で listen するため [Google 側の OAuth 設定](https://console.cloud.google.com/apis/credentials)の **Authorized redirect URIs** で指定することができません。

追加した後は step-ca プロセスに SIGHUP を送って (`pkill -HUP -x step-ca`) リロードさせる必要があります。step-ca の起動時にパスワードをファイルで渡していない場合、リロードに失敗してしまいます。その場合は再起動させましょう。

パスワードが指定されていなくてリロードに失敗した場合のログ

```
Please enter the password to decrypt /Users/teraoka/work/20210409-smallstep/step/secrets/intermediate_ca_key: 
2021/04/10 09:43:00 Reload failed because the CA with new configuration could not be initialized.
2021/04/10 09:43:00 Continuing to run with the original configuration.
2021/04/10 09:43:00 You can force a restart by sending a SIGTERM signal and then restarting the step-ca.
2021/04/10 09:43:00 error reloading server: x509: decryption password incorrect
error decrypting /Users/teraoka/work/20210409-smallstep/step/secrets/intermediate_ca_key
```

設定は `$(step path)/config/ca.json` の `authority.provisioners` に追加されています。設定内容の詳細は "[OAUTH/OIDC SINGLE SIGN-ON](https://smallstep.com/docs/step-ca/configuration#oauthoidc-single-sign-on)" にあります。

追加した provisioner を削除するには次のようにします。

```
step ca provisioner remove Google --type oidc
```

### 証明書の発行

次のコマンドを実行すると provisioner の選択メニューが現れます。

```
step ca certificate teraoka@example.com personal.crt personal.key
```

ここで Google を指定するとブラウザで OAuth の認証・認可に進みます。URL も表示されるため、開かれたブラウザが期待のものでなかった場合はその URL をコピペして開くと良いでしょう。

```
$ step ca certificate teraoka@example.com teraoka.crt teraoka.key
Use the arrow keys to navigate: ↓ ↑ → ← 
What provisioner key do you want to use?
  ▸ user@example.com (JWK) [kid: JAffF2XYO3U1qpRkLzSDDqZR8SSZPwGf23i6xO9dyAg]
    Google (OIDC) [client: 123456789012-aiquu3ehoh6aix7diezoh2Aekeepe4ah.apps.googleusercontent.com]
```

指定したメールアドレスと Google アカウントのメールアドレスが異なる場合は拒否されます。

```
token email 'authenticated@example.com' and argument 'teraoka@example.com' do not match
```

oidc provisioner には admin メールアドレスを指定する設定があり、admin に指定されたメールアドレスでログインすれば別のメールアドレスでの証明書も発行できます。

作成された証明書の確認。

```
$ openssl x509 -text -noout -in personal.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            74:d9:d9:ec:ed:2a:fb:fd:ce:fb:21:4c:e6:03:33:c4
    Signature Algorithm: ecdsa-with-SHA256
        Issuer: O=myself, CN=myself Intermediate CA
        Validity
            Not Before: Apr 10 01:37:03 2021 GMT
            Not After : Apr 11 01:38:03 2021 GMT
        Subject: CN=XXXXXXXXXXXXXXXXXXXXX
        Subject Public Key Info:
            Public Key Algorithm: id-ecPublicKey
                Public-Key: (256 bit)
                pub: 
                    04:32:71:c4:87:a4:51:78:6f:67:fe:3d:8b:61:49:
                    54:67:43:2c:0d:13:20:95:5c:51:a4:0b:23:40:29:
                    44:b2:03:3d:a1:90:cf:f2:a9:8a:2b:c4:c9:8f:b1:
                    11:e6:9b:30:87:23:14:e8:e6:da:8b:65:eb:70:d8:
                    63:07:56:cf:9b
                ASN1 OID: prime256v1
                NIST CURVE: P-256
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Key Identifier: 
                B0:AC:D7:9A:83:5F:0D:92:EC:B7:80:66:F1:90:F0:7C:0A:ED:37:7F
            X509v3 Authority Key Identifier: 
                keyid:64:57:A5:FF:AE:31:D8:18:5D:D2:09:A8:FC:31:D9:83:94:50:70:D6

            X509v3 Subject Alternative Name: 
                email:teraoka@example.com, URI:https://accounts.google.com#XXXXXXXXXXXXXXXXXXXXX
            1.3.6.1.4.1.37476.9000.64.1: 
                0U.....Google.H123456789012-aiquu3ehoh6aix7diezoh2Aekeepe4ah.apps.googleusercontent.com
    Signature Algorithm: ecdsa-with-SHA256
         30:45:02:21:00:d5:5d:bd:31:9e:8c:ba:63:76:74:52:1f:5d:
         47:a1:f3:65:e3:64:f4:d5:74:ba:9a:cb:0a:a0:a8:85:d2:cb:
         76:02:20:3d:65:d6:de:8f:bf:ce:93:33:c6:49:19:66:6a:4c:
         80:d9:51:11:43:cb:3f:ff:a4:8a:de:32:d2:de:2a:77:bb
```

openssl コマンドを使わなくても `step certificate inspect personal.crt [--short]` で確認できました。

### 証明書の Revoke

紛失したり、不要になった証明書は失効させる必要があります。**ただし、現状 smallstep は CRL や OCSP をサポートしておらず、revoke された証明書は更新できなくなるだけです。**

```
step ca revoke <serial-number>
step ca revoke --cert certfile --key keyfile
```

Serial Number は openssl コマンドで取得できる16進のやつではダメなので `step certificate inspect` で取得します。`step certificate inspect personal.crt --format json | jq -r .serial_number`

証明書と、秘密鍵のファイルがあるならそれを指定することでも失効可能。

`[step ca revoke](https://smallstep.com/docs/step-cli/reference/ca/revoke)` コマンド実行時にも provisioner の選択メニューが表示されるのですが、ここでは Google じゃなくて JWK の方を選択して、init 時のパスワードを入力する必要がありました。Google の方を使うと token subject と serial number が一致しないというエラーになって revoke できませんでした。後でわかりましたが、Google provisioner の場合は serial number ではなくて、代わりに CN の値を指定すれば Revoke できました。また、`--cert--key` を指定した場合は認証が不要でした。鍵で認証できるからでしょうね。

```
token subject '101631527727627020288' and serial number '155321595983482556839109003173565772740' do not match
```

リモートサーバー
--------

証明書発行の流れはわかりましたが、複数人で使うためにはサーバーを用意して使うことになります。全部手元にある環境で試していたので分離してより理解を深めてみます。

GCE の debian 10 で nginx + Let's Encrypt の背後に step-ca を配置する構成にしてみます。

```
step (CLI) --(https)--> nginx (Let's Encrypt) --(https)--> step-ca
```

### nginx と Let's Encrypt で TLS な Reverse Proxy をセットアップ

```
$ sudo apt-get update && sudo apt-get install -y python3-certbot-nginx
```

```
$ sudo certbot --nginx -d step.teraoka.me --post-hook "/usr/sbin/nginx -s reload" --agree-tos -m メールアドレス
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator nginx, Installer nginx
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Would you be willing to share your email address with the Electronic Frontier
Foundation, a founding partner of the Let's Encrypt project and the non-profit
organization that develops Certbot? We'd like to send you email about our work
encrypting the web, EFF news, campaigns, and ways to support digital freedom.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
(Y)es/(N)o: N
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for step.teraoka.me
Waiting for verification...
Cleaning up challenges
Running post-hook command: /usr/sbin/nginx -s reload
Deploying Certificate to VirtualHost /etc/nginx/sites-enabled/default
Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
1: No redirect - Make no further changes to the webserver configuration.
2: Redirect - Make all requests redirect to secure HTTPS access. Choose this for
new sites, or if you're confident your site works on HTTPS. You can undo this
change by editing your web server's configuration.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Select the appropriate number [1-2] then [enter] (press 'c' to cancel): 2
Redirecting all traffic on port 80 to ssl in /etc/nginx/sites-enabled/default
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Congratulations! You have successfully enabled https://step.teraoka.me
You should test your configuration at:
!https://www.ssllabs.com/ssltest/analyze.html?d=step.teraoka.me
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/step.teraoka.me/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/step.teraoka.me/privkey.pem
   Your cert will expire on 2021-07-09. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot again
   with the "certonly" option. To non-interactively renew *all* of
   your certificates, run "certbot renew"
 - Your account credentials have been saved in your Certbot
   configuration directory at /etc/letsencrypt. You should make a
   secure backup of this folder now. This configuration directory will
   also contain certificates and private keys obtained by Certbot so
   making regular backups of this folder is ideal.
 - If you like Certbot, please consider supporting our work by:
   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le
```

これで `/etc/nginx/sites-available/default` に https 設定が挿入されます。`/etc/cron.d/certbot` に自動更新のための設定もあります。

step-ca の default port は 4343 だったので `/etc/nginx/sites-available/default` をさらに編集して `/` を 127.0.0.1:4343 に proxy するように設定する。

```
location / {
    proxy_pass https://127.0.0.1:4343;
}
```

変更を反映させる。

```
sudo nginx -s reload
```

### step, step-ca コマンドをインストール

```
curl -LO https://github.com/smallstep/cli/releases/download/v0.15.14/step-cli_0.15.14_amd64.deb
sudo dpkg -i step-cli_0.15.14_amd64.deb
```

```
curl -LO https://github.com/smallstep/certificates/releases/download/v0.15.11/step-ca_0.15.11_amd64.deb
sudo dpkg -i step-ca_0.15.11_amd64.deb
```

### step-ca 用のユーザーを作成

```
sudo useradd -m -s /bin/bash step
```

### step ca init

```
sudo -iu step
dd if=/dev/urandom count=1 bs=48 | base64 > password.txt
step ca init --name smallstep \
  --address 127.0.0.1:4343 \
  --dns step.teraoka.me,127.0.0.1 \
  --provisioner admin \
  --password-file password.txt
```

```
Generating root certificate... 
all done!
Generating intermediate certificate... 
all done!
✔ Root certificate: /home/step/.step/certs/root_ca.crt
✔ Root private key: /home/step/.step/secrets/root_ca_key
✔ Root fingerprint: 926633fc1ef97f58ca359e665ca509093080e4ed1d3a3d289493935eaf528694
✔ Intermediate certificate: /home/step/.step/certs/intermediate_ca.crt
✔ Intermediate private key: /home/step/.step/secrets/intermediate_ca_key
✔ Database folder: /home/step/.step/db
✔ Default configuration: /home/step/.step/config/defaults.json
✔ Certificate Authority configuration: /home/step/.step/config/ca.json
Your PKI is ready to go. To generate certificates for individual services see 'step help ca'.
FEEDBACK 😍 🍻
      The step utility is not instrumented for usage statistics. It does not
      phone home. But your feedback is extremely valuable. Any information you
      can provide regarding how you’re using `step` helps. Please send us a
      sentence or two, good or bad: feedback@smallstep.com or join
      https://github.com/smallstep/certificates/discussions.
```

### Google OIDC Provisioner の追加

```
step ca provisioner add Google --type oidc --ca-config $(step path)/config/ca.json \
    --client-id ${CLIENT_ID} \
    --client-secret ${CLIENT_SECRET} \
    --configuration-endpoint https://accounts.google.com/.well-known/openid-configuration \
    --domain teraoka.me \
    --listen-address :10000
```

### systemd で step-ca が起動するようにする

```
sudo cat > /etc/systemd/system/step-ca.service <<EOF
[Unit]
Description=Smallstep CA Server
Documentation=https://smallstep.com/docs
After=network.target
[Service]
Type=simple
Environment=SETPPATH=/home/step/.step
User=step
ExecStart=/usr/bin/step-ca /home/step/.step/config/ca.json --password-file /home/step/password.txt
Restart=always
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start step-ca
sudo systemctl status step-ca
sudo systemctl enable step-ca
```

### ネットワーク越しに step コマンドでアクセスする

`$(step path)/config/defaults.json` の存在しない状態で動作確認します。サーバーの URL を `--ca-url` で指定します。

```
$ step ca health --ca-url https://step.teraoka.me
'step ca health' requires the '--root' flag
```

`--root` で CA の証明書ファイル指定する必要があるみたいです。ローカルで試していた時は `defaults.json` で `$(step path)/certs/root_ca.crt` が指定してありました。これはサーバー側から持ってくる必要があります。サーバー側で `step ca root` すれば取得できるのでこれを `ca.crt` として保存して試します。

```
$ step ca health --ca-url https://step.teraoka.me --root ca.crt
The certificate authority encountered an Internal Server Error. Please see the certificate authority logs for more info.
Re-run with STEPDEBUG=1 for more info.
```

Internal Server Error ???  
STEPDEBUG=1 を設定して実行すると次のメッセージが表示されました。証明書が問題のようです。

```
Get "https://step.teraoka.me/health": x509: certificate signed by unknown authority
client.Health; client GET https://step.teraoka.me/health failed
(以下省略)
```

が、curl でアクセスした場合は問題ありません。どうやら step コマンドが証明書の検証に使うのが `--root` で指定したファイルにある証明書だけのようです。よって Let's Encrypt の DST Root CA X3 の証明書を ca.crt に追加しました。

```
$ step ca health --ca-url https://step.teraoka.me --root ca.crt
ok
```

成功です。nginx が邪魔だったみたい。

でもこれでわかりました。step-ca サーバーを別建てにした場合、step コマンドを実行したい端末に root ca の証明書を配る必要がありました。それだけ。Google からの redirect を受ける `step oauth` コマンドもクライアント側で実行されるため **Authorized redirect URIs** も localhost のままで大丈夫です。

root ca の証明書は fingerprint が分かれば `step ca root` コマンドで取得可能っぽい。

デフォルトの証明書の期限は 24h だったので、必要なら config/ca.json 書き換える必要がある。

残す謎は oidc provisioner の admin 機能がうまく機能しなかったこと。step コマンドには admin 判定処理はないのに、step コマンド側で email と argument が違うと言って弾いちゃってるんだよなあ。

まあ、admin 相当の人は [JWK Provisioner](https://smallstep.com/docs/step-ca/configuration#jwk) を使えば任意の証明書を発行できるので良いか。担当者の数だけ作れるし。

```
step ca provisioner add admin-1@example.com --create --password-file password.txt
```

この処理は `ca.json` への追加で、reload も必要なのでリモートからはできない。

CSR を作って署名する
------------

Google Workspace のアカウントがない人向けの証明書作成においても Private Key のやりとりは避けたいので CSR を送ってもらって署名するという運用にしたいものです。

`[step certificate create](https://smallstep.com/docs/step-cli/reference/certificate/create)` に `--csr` をつけると証明書をいきなり作成するのではなく CSR と Private Key が作成されます。`--insecure` と `--no-password` の両方を追加すると Private Key へのパスワードが不要になります。(まあ後からでもなんとでもなりますけど)

```
step certificate create teraoka@example.com teraoka.csr teraoka.key --csr [--insecure --no-password]
```

`step certificate inspect` で CSR も確認できます。

CSR に対して署名するには `[step ca sign](https://smallstep.com/docs/step-cli/reference/ca/sign)` を使います。

```
step ca sign teraoka.csr teraoka.crt

```
