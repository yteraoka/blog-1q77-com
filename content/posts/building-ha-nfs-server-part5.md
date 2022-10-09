---
title: 'GlusterFS + NFS-Ganesha で HA な NFS サーバーを構築する (5)'
date: Sat, 10 Jun 2017 13:34:49 +0000
draft: false
tags: ['GlusterFS', 'GlusterFS']
---

今回は NFS の ACL についてです。通常の NFS サーバーであれば `/etc/exports` などでどのホストにどのディレクトリを公開するか、Read-Only か Read-Write かなどを設定できます。 Ganesha NFS ではどのようにすれば良いでしょうか。 `/usr/libexec/ganesha/create-export-ganesha.sh` では次のような `export.vol1.conf` ファイルが生成されます。```
\# WARNING : Using Gluster CLI will overwrite manual
# changes made to this file. To avoid it, edit the
# file and run ganesha-ha.sh --refresh-config.
EXPORT{
      Export\_Id = 2;
      Path = "/vol1";
      FSAL {
           name = GLUSTER;
           hostname="localhost";
          volume="vol1";
           }
      Access\_type = RW;
      Disable\_ACL = true;
      Squash="No\_root\_squash";
      Pseudo="/vol1";
      Protocols = "3", "4" ;
      Transports = "UDP","TCP";
      SecType = "sys";
     }

````Access_type` を `RW` から `RO` にすれば Read-Only での公開になりますが、クライアントホストの限定はできません。 `EXPORT` ブロック内には次のような `client` ブロックを入れることができ、ここでクライアント毎の `access_type` を上書き可能です。```
client {
        clients = "10.xx.xx.xx";  # IP of the client.
        allow\_root\_access = true;
        access\_type = "RO"; # Read-only permissions
        Protocols = "3"; # Allow only NFSv3 protocol.
        anonymous\_uid = 1440;
        anonymous\_gid = 72;
  }

````EXPORT` 内の `access_type` を `none` にしておいて、`client` 内で `RO` や `RW` と指定すればその `clients` で指定した接続元IPアドレス毎のアクセス権設定が可能になります。`client` ブロックは次のように複数定義できます。```
EXPORT {
    ...
    access\_type = none;
    ...
    client {
        clients = 192.168.122.71;
        access\_type = RW;
    }
    client {
        clients = 192.168.122.0/24;
        access\_type = RO;
    }
}

```これで 192.168.122.71 からは書き込み可、192.168.122.0/24 内の他のホストからは読み込み専用、その他のホストからはマウント不可となります。 このファイルは変更後に次のコマンドで反映させる必要があります。```
\# /usr/libexec/ganesha/ganesha-ha.sh --refresh-config /var/run/gluster/shared\_storage/nfs-ganesha vol1
Refresh-config completed on gluster2.
Success: refresh-config completed.

```GlusterFS 側の制限のとの兼ね合いがあるため、NFS でアクセスさせる volume と glusterfs でアクセスさせる volume が混在する場合はちょっと面倒。glusterfs は volume 毎に port が割り当てられるのでそのあたりと組み合わせることもできるけど、どの volume がどの port かは固定ができそうにない。証明書を持ったクライアントからしか接続させないという機能もあるけれども Ganensha NFS では使えないらしい。