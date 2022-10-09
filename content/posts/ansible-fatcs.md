---
title: 'Ansible の fatcs (インベントリ情報) を MongoDB に突っ込む'
date: Mon, 21 Oct 2013 12:52:51 +0000
draft: false
tags: ['Ansible', 'ansible', 'mongodb']
---

前回、1.2 系と 1.3 系で変数の優先順位が変わったという記事を書きましたが、template 周りもちょっと変わってるみたいです。 1.2 では次のような loop 処理で、リストが未定義だった場合もエラーになることなく動作していたのですが、1.3.2 で動かしてみたらエラーになってしまいました。```
{% for filter in iptables\_input\_filters %}
-A INPUT {{filter}}
{% endfor %}

```ということで次のように対応しました。```
{% if iptables\_input\_filters is defined %}
{% for filter in iptables\_input\_filters %}
-A INPUT {{filter}}
{% endfor %}
{% endif %}

```それでは今日の本題です。

### サーバーの情報集めて利用したい

Ansible は Server とか Agent が不要なのが売りなわけで、そこに惹かれて選んでいるのですが Chef Server とかにもちょっと憧れるわけです。情報を一元管理できたらいいなぁって。 そうしたら、なんだか setup モジュールが使えそうだったんですね。 [https://github.com/ansible/ansible/blob/devel/library/system/setup](https://github.com/ansible/ansible/blob/devel/library/system/setup) EXAMPLES の中に次のような例がありました。```
\# Display facts from all hosts and store them indexed by I(hostname) at C(/tmp/facts).
ansible all -m setup --tree /tmp/facts

```これで /tmp/facts にホスト名をファイル名にした JSON ファイルが収集されるんです。よし、じゃあこれを DB に入れちゃおう。（例では使われていませんが ansible に -s オプションをつけてあげると sudo を使うっていう意味で、root じゃないと取得できないデータがあるのでつけた方が良いです） Ansible の Fact って何？って場合はこちらをどうぞ [http://yteraoka.github.io/ansible-tutorial/ansible-in-detail.html#gathering-facts](http://yteraoka.github.io/ansible-tutorial/ansible-in-detail.html#gathering-facts) そして、ohai とか [factor](https://github.com/puppetlabs/facter) の情報も取得できるみたいです。 [Ansibleを支えるfact: プラットフォームの情報を取得](http://tdoc.info/blog/2013/08/23/ansible_fact.html)

### DB っていってもどれにいれようかな？

ってことで最初に試したのは PostgreSQL の JSON 型です。PostgreSQL には慣れてるし、9.3 で JSON 機能が強化されたみたいだしと、早速試したら... ん？エラーで入らない... どうやら 4kB 制限があるっぽい。 4kB 超えたらエラーで INSERT できない。 勘違いでした、別の環境でやり直したら INSERT できました なんだったんだろう？再現テストしてみよう。

> ダメだったのは Linux Mint (Cinnamon) の gnome-terminal で JSON を psql でコピペした場合。Windows から PuTTY で同じ事をしたら問題なかった。gnome-terminal でもファイルにコピペして SQL ファイルとして psql -f したら問題なかった。

他に JSON 突っ込める DB といえば MongoDB!! （今日初めて触る） 今日（もう昨日か）もまた Twitter で dis られてた MongoDB、ガチで使うなら渋谷で人さらいしてこないとダメらしいけど、今回のようなゆるふわ利用なら問題ないんじゃないかなと。 EPEL から yum で入るので簡単に起動までも簡単。```
$ sudo yum -y install mongodb mongodb-server
$ sudo /sbin/service mongod start

```なんか [mongoimport](http://docs.mongodb.org/manual/reference/program/mongoimport/#mongoimport) なるコマンドがあるのでこれ使えるのかな？```
$ mongoimport -d ansible -c facts20131022 --type json --file /tmp/facts/hostname

exception:BSON representation of supplied JSON is too large: code FailedToParse: FailedToParse: Field name expected: offset:1

```ダメポ... 1ドキュメントは1行にしないとダメらしい。 つーことで、こんな感じでまるっとインポート。```
ansible -s -m setup -i hosts -t /tmp/facts all

for file in \`ls /tmp/facts/\*\`
do
  cat $file | tr -d "\\n"
  echo
done | mongoimport -d ansible -c facts$(date +%Y%m%d)  --type json --file -

```（最後の「-」が抜けてることに気づいたので追記 2013-10-24）```
$ mongo
MongoDB shell version: 2.4.6
connecting to: test
> show dbs
ansible	0.203125GB
local	0.078125GB
> use ansible
switched to db ansible
> show collections
facts
facts20131022
system.indexes
> db.facts20131022.find().count()
21

```インポートできたっぽい。コレクション名に日付を入れておいたので過去のも見れるし、不要ならまるっと削除しちゃおう。（update とか面倒） コレクションの削除はこんな感じ。```
$ mongo
MongoDB shell version: 2.4.6
connecting to: test
> show dbs
ansible	0.203125GB
local	0.078125GB
> use ansible
switched to db ansible
> show collections
facts
facts20131022
system.indexes
> db.facts20131022.drop()
true
> show collections
facts
system.indexes
> 

```検索してみる。Xeon のサーバー一覧とOpteron のサーバー一覧```
\> db.facts20131022.find({"ansible\_facts.ansible\_processor": /Xeon/},{"\_id":0,"ansible\_facts.ansible\_hostname":1})
{ "ansible\_facts" : { "ansible\_hostname" : "vm03" } }
{ "ansible\_facts" : { "ansible\_hostname" : "vm04" } }
{ "ansible\_facts" : { "ansible\_hostname" : "vm05" } }
> db.facts20131022.find({"ansible\_facts.ansible\_processor": /Opteron/},{"\_id":0,"ansible\_facts.ansible\_hostname":1})
{ "ansible\_facts" : { "ansible\_hostname" : "vm01" } }
{ "ansible\_facts" : { "ansible\_hostname" : "vm02" } }

```超やっつけですが、一応出来ました。 MAC アドレスからサーバーを探したり、「あの壊れたサーバーのシリアル/サービスタグってなんだっけ？」という場合にも使える。

### カスタム Facts

「あの仮想ゲストはどのホストに載ってたっけなぁ？」を解決するために、VM ホストで /etc/ansible/facts.d/guests.fact を次のようなスクリプトにして作成し、実行権限をつけておけば setup module が実行して収集してくれます。 動的でないものは JSON 書いたテキストファイルで OK。拡張子を .fact にする必要があるのと、ファイル名が JSON のキーになるという仕様。```
$ cat /etc/ansible/facts.d/guests.fact 
#!/bin/sh
guests=( $(virsh list --name) )
list=""
for name in ${guests\[@\]}
do
    let i=i+1
    list="${list}\\"${name}\\""
    if \[ $i -ne ${#guests\[@\]} \] ; then
        list="${list}, "
    fi
done

echo "\[ $list \]"

```こんな感じで収集されます。```
{
    "ansible\_facts": {
        "ansible\_local": {
            "guests": \[
                "guest1",
                "guest2",
                "guest3"
            \]
        }
    }
}

```ホスト名に kibana を含む Guest の Host を探す```
\> db.facts20131022.find({"ansible\_facts.ansible\_local.guests": /kibana/},{"\_id":0,"ansible\_facts.ansible\_hostname":1})
{ "ansible\_facts" : { "ansible\_hostname" : "vm05" } }

```

### setup module の filter 機能

setup module は filter 機能もあるので、必要な情報だけに絞って取り出すこともできます。```
$ ansible all -s -i hosts -m setup -a 'filter=ansible\_product\_\*'

testdb1 | success >> {
    "ansible\_facts": {
        "ansible\_product\_name": "KVM", 
        "ansible\_product\_serial": "NA", 
        "ansible\_product\_uuid": "CFB8DD36-FD8A-3FE5-D8AA-57B60878AD0A", 
        "ansible\_product\_version": "RHEL 6.3.0 PC"
    }, 
    "changed": false
}

```

### MongoDB 以外の選択肢？

ElasticSearch って使えるのかな？ CouchDB ってのも JSON らしいな。 Ansible のインベントリファイル(-i で指定するやつ)はテキストファイルでなくて、スクリプトなどを、指定してDBから引っ張って来させたりできるので、いろいろ発展の余地はありますね。