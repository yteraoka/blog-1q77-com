---
title: "gopass を使ってパスワード共有を試す"
date: 2025-03-29T09:57:32+09:00
draft: false
tags: ['password']
image: cover.png
author: "@yteraoka"
categories:
  - IT
---

## gopass とは

[Postgres Weekly](https://postgresweekly.com/issues/594) を眺めていて [Creating Postgres Roles with Passwords Stored in Gopass](https://domm.plix.at/perl/2025_03_create_postgres_roles_with_gopass.html) という記事で [gopass](https://github.com/gopasspw/gopass) というものの存在を知りました。

名前から分かるように Go 言語で書かれており、マルチプラットフォームのパスワード管理用コマンドラインツールです。
GPG を使って暗号化し、Git で管理します。
GPG の公開鍵暗号を使って複数人で複合することが可能になっており、任意の人とパスワードを共有することが可能です。

[pass](https://www.passwordstore.org/) というツールと 100% の API 互換性があるようです。(こちらも使ったことが無いのでよくわからない)

複数人に共有できるというのがちょっと気になったので試してみます。

いまどきはクラウドサービスには Secret Manager の類があるし、1password を使っていてもあまり共有機能を使うことは多くないけど。
家庭内の方が共有するものは多い気がする。


## インストール

Go 言語なので go build でも良いですが、[ドキュメント](https://www.gopass.pw/#install)にあるとおり各 Linux distribution 用の package や Homebrew、Windows 向けにも用意されています。

Debian 系の apt repository で提供されている gopass ([aviau/gopass](https://github.com/aviau/gopass)) はまた別物らしいです。[#1849](https://github.com/gopasspw/gopass/issues/1849#issuecomment-802789285)

今回は WSL2 の Ubuntu で試すためひとまず deb package で入れてみました。

```bash
wget https://github.com/gopasspw/gopass/releases/download/v1.15.15/gopass_1.15.15_linux_amd64.deb
sudo dpkg -i gopass_1.15.15_linux_amd64.deb
```

確認

```bash
$ gopass version
gopass 1.15.15 go1.23.3 linux amd64
```

## セットアップ

`gopass setup` コマンドがあります。デフォルトでは gpg による暗号と git のストレージが選択されます。

<details>
<summary><code>gopass setup --help</code></summary>

```
NAME:
   gopass setup - Initialize a new password store

USAGE:
   gopass setup [command options]

DESCRIPTION:
   This command is automatically invoked if gopass is started without any existing password store. This command exists so users can be provided with simple one-command setup instructions.

OPTIONS:
   --remote value   URL to a git remote, will attempt to join this team
   --alias value    Local mount point for the given remote
   --create         Create a new team (default: false, i.e. join an existing team) (default: false)
   --name value     Firstname and Lastname for unattended GPG key generation
   --email value    EMail for unattended GPG key generation
   --crypto value   Select crypto backend [age gpgcli plain]
   --storage value  Select storage backend [fossilfs fs gitfs]
   --help, -h       show help
```

</details>

```bash
$ gopass setup

   __     _    _ _      _ _   ___   ___
 /'_ '\ /'_'\ ( '_'\  /'_' )/',__)/',__)
( (_) |( (_) )| (_) )( (_| |\__, \\__, \
'\__  |'\___/'| ,__/''\__,_)(____/(____/
( )_) |       | |
 \___/'       (_)

🌟 Welcome to gopass!
🌟 Initializing a new password store ...
🔐 No useable cryptographic keys. Generating new key pair
🧪 Creating cryptographic key pair (gpg) ...
🎩 Gathering information for the gpg key pair ...
🚶 What is your name? [yteraoka]:
📧 What is your email? [xxxxxxxxxx@example.com]:
⚠ Do you want to enter a passphrase? (otherwise we generate one for you) [y/N/q]:
✅ Key pair for gpg generated
Passphrase: daycare common selective cryptic
⚠ You need to remember this very well!
⚠ 🔐 We need to unlock your newly created private key now! Please enter the passphrase you just generated.
Do you want to export your public key to "0x937CA4A73B4FBEDF.pub.key"? [y/N/q]:
✅ Key pair 0x937CA4A73B4FBEDF validated
🔐 Cryptographic keys generated
🌟 Configuring your password store ...
❓ Do you want to add a git remote? [y/N/q]:
✅ Configuration written
```

すべてデフォルトのまま実行し、パスフレーズを指定しなかったので `daycare common selective cryptic` が自動生成されてます。
**What is your name?**, **What is your email?** は GPG の key pair 生成に必要な情報で `--name`, `--email` で指定することも可能。git config から取得したりするようだ。

生成された GPG の鍵を確認する。

```bash
$ gpg --list-secret-keys
/home/yteraoka/.gnupg/pubring.kbx
---------------------------------
sec   rsa2048 2025-03-29 [SCEA]
      E0D2B5052793D97E44AF83C7937CA4A73B4FBEDF
uid           [ultimate] yteraoka <xxxxxxxxxx@example.com>
ssb   rsa2048 2025-03-29 [SEA]
```

root という store が git で作成されている。

```bash
$ ls -la ~/.local/share/gopass/stores/root
total 24
drwx------ 4 yteraoka yteraoka 4096 Mar 29 10:46 .
drwx------ 3 yteraoka yteraoka 4096 Mar 29 10:45 ..
drwx------ 8 yteraoka yteraoka 4096 Mar 29 10:46 .git
-rw------- 1 yteraoka yteraoka   15 Mar 29 10:46 .gitattributes
-rw------- 1 yteraoka yteraoka   19 Mar 29 10:46 .gpg-id
drwx------ 2 yteraoka yteraoka 4096 Mar 29 10:46 .public-keys
```

## gopass create でパスワードを登録

`gopass create` コマンドでパスワード情報を登録することができます。

<details>
<summary><code>gopass create --help</code></summary>

```
NAME:
   gopass create - Easy creation of new secrets

USAGE:
   gopass create [command options] [secret]

DESCRIPTION:
   This command starts a wizard to aid in creation of new secrets.

OPTIONS:
   --store value, -s value  Which store to use
   --force, -f              Force path selection (default: false)
   --help, -h               show help
```

</details>

```bash
$ gopass create
🌟 Welcome to the secret creation wizard (gopass create)!
🧪 Hint: Use 'gopass edit -c' for more control!
[ 0] Website login
[ 1] PIN Code (numerical)

Please select the type of secret you would like to create (q to abort) [0]:
0
🧪 Creating Website login
  [1] Website URL                            []: https://www.example.com/
  [2] Username                               []: yteraoka
  [3] Generate Password?                     [Y/n/q]:
    [a] Human-pronounceable passphrase?      [y/N/q]:
    [b] How long?                            (q to abort) [24]:
    [c] Include symbols?                     [y/N/q]:
    [d] Strict rules?                        [y/N/q]:
✅ Credentials saved to "websites/www.example.com/yteraoka"
✔ Copied websites/www.example.com/yteraoka to clipboard. Will clear in 45 seconds.
```

Website URL と Username 以外はデフォルトのままとしたのでパスワードは自動生成されました。

### プロンプトの定義

`gopass create` コマンドでは 0 が website 用、1 が PIN 用などと prompt が表示されますが、
これは `~/.local/share/gopass/stores/root/.gopass/create/` ディレクトリに定義ファイルが作成されていました。

```bash
$ ls ~/.local/share/gopass/stores/root/.gopass/create
0-websites.yml  1-pin.yml
```

#### 0-websites.yml

```yaml
---
priority: 0
name: "Website login"
prefix: "websites"
name_from:
  - "url"
  - "username"
welcome: "🧪 Creating Website login"
attributes:
  - name: "url"
    type: "hostname"
    prompt: "Website URL"
    min: 1
    max: 255
  - name: "username"
    type: "string"
    prompt: "Username"
    min: 1
  - name: "password"
    type: "password"
    prompt: "Password for the Website"
```

prefix の "websites" + url の hostname + username が path として使われるようです


#### 1-pin.yml

```yaml
---
priority: 1
name: "PIN Code (numerical)"
prefix: "pin"
name_from:
  - "authority"
  - "application"
welcome: "🧪 Creating numerical PIN"
attributes:
  - name: "authority"
    type: "string"
    prompt: "Authority"
    min: 1
  - name: "application"
    type: "string"
    prompt: "Entity"
    min: 1
  - name: "password"
    type: "password"
    prompt: "Pin"
    charset: "0123456789"
    min: 1
    max: 64
  - name: "comment"
    type: "string"
```

こちらの path は prefix の "pin" + authority + application となりそうです。


## パスワードの確認

パスワードの一覧を確認。デフォルトでは tree 表示となる。

```bash
$ gopass list
gopass
└── websites/
    └── www.example.com/
        └── yteraoka
```

`-f` (`--flat`) で show などで指定する値をそのまま表示できます。

```bash
$ gopass list -f
websites/www.example.com/yteraoka
```

中身を確認するために `gopass show` コマンドを実行してみます。

ここでは GPG 秘密鍵のパスワードの入力が求められます。1度入力すると短時間ですがキャッシュされ、その間は入力を求められなくなります。

```
┌───────────────────────────────────────────────────────────────┐
│ Please enter the passphrase to unlock the OpenPGP secret key: │
│ "yteraoka <xxxxxxxxxx@example.com>"                           │
│ 2048-bit RSA key, ID 4656A5FBBBBCE038,                        │
│ created 2025-03-29 (main key ID 937CA4A73B4FBEDF).            │
│                                                               │
│                                                               │
│ Passphrase: _________________________________________________ │
│                                                               │
│         <OK>                                   <Cancel>       │
└───────────────────────────────────────────────────────────────┘
```

<details>
<summary><code>gopass show --help</code></summary>

```
NAME:
   gopass show - Display the content of a secret

USAGE:
   gopass show [command options] [secret]

DESCRIPTION:
   Show an existing secret and optionally put its first line on the clipboard. If put on the clipboard, it will be cleared after 45 seconds.

OPTIONS:
   --yes, -y                   Always answer yes to yes/no questions (default: false)
   --clip, -c                  Copy the password value into the clipboard (default: false)
   --alsoclip, -C              Copy the password and show everything (default: false)
   --qr                        Print the password as a QR Code (default: false)
   --qrbody                    Print the body as a QR Code (default: false)
   --unsafe, -u, --force, -f   Display unsafe content (e.g. the password) even if safecontent is enabled (default: false)
   --password, -o              Display only the password. Takes precedence over all other flags. (default: false)
   --revision value, -r value  Show a past revision. Does NOT support RCS specific shortcuts. Use exact revision or -<N> to select the Nth oldest revision of this entry.
   --noparsing, -n             Do not parse the output. (default: false)
   --nosync                    Disable auto-sync (default: false)
   --chars value               Print specific characters from the secret
   --help, -h                  show help
```
</details>

```
$ gopass show websites/www.example.com/yteraoka
Secret: websites/www.example.com/yteraoka

BWg9akSYVlMdP8JiVpDnwqsN
url: https://www.example.com/
username: yteraoka
```

`-c` (`--clip`) オプションを指定するとクリップボードにパスワードだけがコピーされます。

```bash
$ gopass show -c websites/www.example.com/yteraoka
✔ Copied websites/www.example.com/yteraoka to clipboard. Will clear in 45 seconds.
```

`-o` (`--password`) オプションを指定するとパスワードだけが出力されます。




## gopass insert でパスワードを登録

`gopass insert` コマンドでもパスワード情報 (Secret) を登録することができます。
create の時の用は url とか username のような項目はありません。

<details>
<summary><code>gopass insert --help</code></summary>

```
NAME:
   gopass insert - Insert a new secret

USAGE:
   gopass insert [command options] [secret]

DESCRIPTION:
   Insert a new secret. Optionally, echo the secret back to the console during entry. Or, optionally, the entry may be multiline. Prompt before overwriting existing secret unless forced.

OPTIONS:
   --echo, -e       Display secret while typing (default: false)
   --multiline, -m  Insert using $EDITOR (default: false)
   --force, -f      Overwrite any existing secret and do not prompt to confirm recipients (default: false)
   --append, -a     Append data read from STDIN to existing data (default: false)
   --help, -h       show help
```

</details>

`gopass insert` では任意の key に対してパスワードを登録します。

```bash
$ gopass insert my-secret-1
Enter password for my-secret-1:
Retype password for my-secret-1:
```

登録されたことを一覧で確認。

```bash
$ gopass list
gopass
├── my-secret-1
└── websites/
    └── www.example.com/
        └── yteraoka
```

`gopass show` で中身を確認。

```
$ gopass show my-secret-1
Secret: my-secret-1

nWepn8XW2keYSLrd
```

標準入力からデータを流し込むか、`-m` (`--multiline`) でエディタを使えば複数行の値を入れることも可能です、

`-a` (`--append`) で標準入力から値を渡すと既存の値に追加することが可能です。存在しない key を指定すれば新規作成になります。

## GitHub に同期させる

`gopass git` コマンドは git コマンドを password store ディレクトリで実行してくれるだけなので、普通に git コマンドを実行するのと変わりません。

```bash
$ gopass git remote add origin git@github.com:yteraoka/gopass-example.git
⚠ Running 'git remote add origin git@github.com:yteraoka/gopass-example.git' in /home/yteraoka/.local/share/gopass/stores/root...
```

`gopass sync` コマンドで git pull & git push が行われます。初回なので pull は失敗しますが、その後の push は成功しています。

```
$ gopass sync
🚥 Syncing with all remotes ...
[<root>]
   gitfs pull and push ... ⚠ Failed to pull before git push: exit status 1: fatal: couldn't find remote ref master
OK (no changes)
   done
✅ All done
```

この状態にした後は sync コマンドを実行せずともパスワードの作成や変更がすぐに GitHub に反映されます。(後で分かりましたがこれは root store だけの挙動なのかもしれない)

## パスワード更新

`gopass generate` コマンドで新規にパスワードを作成したり、既存のものを更新することができます。

<details>
<summary><code>gopass generate --help</code></summary>

```
NAME:
   gopass generate - Generate a new password

USAGE:
   gopass generate [command options] [secret [key [length]|length]]

DESCRIPTION:
   Dialog to generate a new password and write it into a new or existing secret. By default, the new password will replace the first line of an existing secret (or create a new one).

OPTIONS:
   --clip, -c                                  Copy the generated password to the clipboard (default: false)
   --print, -p                                 Print the generated password to the terminal (default: false)
   --force, -f                                 Force to overwrite existing password (default: false)
   --edit, -e                                  Open secret for editing after generating a password (default: false)
   --symbols, -s                               Use symbols in the password (default: false)
   --generator value, -g value                 Choose a password generator, use one of: cryptic, memorable, xkcd or external. Default: cryptic
   --strict                                    Require strict character class rules (default: false)
   --force-regen, -t                           Force full re-generation, incl. evaluation of templates. Will overwrite the entire secret! (default: false)
   --sep value, --xkcdsep value, --xs value    Word separator for generated passwords. If no separator is specified, the words are combined without spaces/separator and the first character of words is capitalised.
   --lang value, --xkcdlang value, --xl value  Language to generate password from, currently only en (english, default) or de are supported (default: "en")
   --help, -h                                  show help
```

</details>


```
$ gopass generate -f websites/www.example.com/yteraoka 20
✅ Password for entry "websites/www.example.com/yteraoka" generated
Not printing secrets by default. Use 'gopass show websites/www.example.com/yteraoka' to display the password.
```

## パスワードの共有

### 共有用の store を作成する

これまで触ってきた root store とは別に共有するための GitHub Repository も作成し、shared という store を作成します。

```
gopass init --store shared
```

実行例


```bash
$ gopass init --store shared
🍭 Initializing a new password store ...
❌ Store is already initialized!
🔑 Searching for usable private Keys ...
⚠ Hint: Use 'gopass init <subkey> to use subkeys!'
✅ Wrote recipients to .gpg-id
git initialized at /home/yteraoka/.local/share/gopass/stores/shared
git configured at /home/yteraoka/.local/share/gopass/stores/shared
Initialized gitfs repository (gitfs) for yteraoka / xxxxxxxxxx@example.com...
🏁 Password store /home/yteraoka/.local/share/gopass/stores/shared initialized for:
📩 0x937CA4A73B4FBEDF - yteraoka <xxxxxxxxxx@example.com>
```

GitHub と紐づける

```bash
$ gopass git --store shared remote add origin git@github.com:yteraoka/gopass-example-shared.git
⚠ Running 'git remote add origin git@github.com:yteraoka/gopass-example-shared.git' in /home/yteraoka/.local/share/gopass/stores/shared...
```

shared store にパスワードを作成する

```bash
$ gopass create --store shared
🌟 Welcome to the secret creation wizard (gopass create)!
🧪 Hint: Use 'gopass edit -c' for more control!
[ 0] Website login
[ 1] PIN Code (numerical)

Please select the type of secret you would like to create (q to abort) [0]:
0
🧪 Creating Website login
  [1] Website URL                            []: https://mysite.example.com/
  [2] Username                               []: shared-user
  [3] Generate Password?                     [Y/n/q]:
    [a] Human-pronounceable passphrase?      [y/N/q]:
    [b] How long?                            (q to abort) [24]:
    [c] Include symbols?                     [y/N/q]:
    [d] Strict rules?                        [y/N/q]:
✅ Credentials saved to "shared/websites/mysite.example.com/shared-user"
✔ Copied shared/websites/mysite.example.com/shared-user to clipboard.
```

GitHub に push する

```bash
$ gopass sync --store shared
🚥 Syncing with all remotes ...
[shared]
   gitfs pull and push ... ⚠ Failed to pull before git push: exit status 1: fatal: couldn't find remote ref master
OK (no changes)
   done
✅ All done
```

### 共有される人の環境で gopass をセットアップする

最初に `gopass setup` したのとほぼ同じだが、GPG key par 用の username, email を変えてみた。

今回は GPG の公開鍵をどうせ export する必要があるのであらかじめ export しておいたが、別途 export する場合は次のようにする。

```bash
gpg --armor --export **********@example.com > pub.key
```

gopass setup の実行

```bash
[user2]$ gopass setup

   __     _    _ _      _ _   ___   ___
 /'_ '\ /'_'\ ( '_'\  /'_' )/',__)/',__)
( (_) |( (_) )| (_) )( (_| |\__, \\__, \
'\__  |'\___/'| ,__/''\__,_)(____/(____/
( )_) |       | |
 \___/'       (_)

🌟 Welcome to gopass!
🌟 Initializing a new password store ...
🔐 No useable cryptographic keys. Generating new key pair
🧪 Creating cryptographic key pair (gpg) ...
🎩 Gathering information for the gpg key pair ...
🚶 What is your name? [Yoshinori Teraoka]: Taro Yamada
📧 What is your email? [**********@example.com]: **********@example.com
⚠ Do you want to enter a passphrase? (otherwise we generate one for you) [y/N/q]:
✅ Key pair for gpg generated
Passphrase: refurnish oil outright pushcart
⚠ You need to remember this very well!
⚠ 🔐 We need to unlock your newly created private key now! Please enter the passphrase you just generated.
Do you want to export your public key to "0xFF8DEAC915F553F8.pub.key"? [y/N/q]: y
✴ Public key exported to "0xFF8DEAC915F553F8.pub.key"
✅ Key pair 0xFF8DEAC915F553F8 validated
🔐 Cryptographic keys generated
🌟 Configuring your password store ...
❓ Do you want to add a git remote? [y/N/q]:
✅ Configuration written
```

shared store を clone で追加する

```bash
[user2]$ gopass clone git@github.com:yteraoka/gopass-example-shared.git shared

   __     _    _ _      _ _   ___   ___
 /'_ '\ /'_'\ ( '_'\  /'_' )/',__)/',__)
( (_) |( (_) )| (_) )( (_| |\__, \\__, \
'\__  |'\___/'| ,__/''\__,_)(____/(____/
( )_) |       | |
 \___/'       (_)

🌟 Welcome to gopass!
🌟 Cloning an existing password store from "git@github.com:yteraoka/gopass-example-shared.git" ...
⚠ Cloning gitfs repository "git@github.com:yteraoka/gopass-example-shared.git" to "/root/.local/share/gopass/stores/shared" ...
⚠ Failed to commit .gitattributes to git
git configured at /root/.local/share/gopass/stores/shared
Mounted password store /root/.local/share/gopass/stores/shared at mount point `shared` ...
⚠ Configuring gitfs repository ...
🎩 Gathering information for the git repository ...
🚶 What is your name? [Taro Yamada]:
📧 What is your email? [**********@gmail.com]:
⚠ Failed to commit .gitattributes to git
Your password store is ready to use! Have a look around: `gopass list shared`

⚠ Please ask the owner of the password store to add one of your keys: 0xFF8DEAC915F553F8
⚠ The missing keys were exported to the password store. Run `gopass sync` to push them.
```

この時、`gopass setup` 時に export しておいた `0xFF8DEAC915F553F8.pub.key` ファイルが見つかったということで .public-keys ディレクトリに追加され GitHub に push されている。
このファイルは公開鍵の import に利用することができる。


### 共有先ユーザーの公開鍵を import

元の owner 側の環境で `gpg --import` で公開鍵を import する。
公開鍵なので受け渡し方法はあまり気にしないが、前項で説明したように .public-keys ディレクトリに追加されている場合はこれを使うことができる。

```bash
$ gpg --import < .local/share/gopass/stores/shared/.public-keys/0xFF8DEAC915F553F8
gpg: key FF8DEAC915F553F8: public key "Taro Yamada <xxxxxxxxxx@example.com>" imported
gpg: Total number processed: 1
gpg:               imported: 1
```

HTTP(S) でアクセス可能な場所にある場合は `gpg --fetch-keys` という手もあるらしい。


### 共有範囲の変更

import した key の中から共有相手を選択して追加すると再暗号化が行われて新たに追加された人も複合が可能になる。

これを `gopass recipients add` コマンドで行うことができる。

```bash
$ gopass recipients add --store shared
⚠ Fetching available recipients. Please wait...
[ 0] 0x937CA4A73B4FBEDF - yteraoka <xxxxxxxxxx@example.com>
[ 1] 0xFF8DEAC915F553F8 - Taro Yamada <**********@example.com>

Add Recipient - (q to abort) [0]: 1
1
Do you want to add "0xFF8DEAC915F553F8 - Taro Yamada <**********@example.com>" (key "0xFF8DEAC915F553F8") as a recipient to the store "shared"? [y/N/q]: y
Reencrypting existing secrets. This may take some time ...
Starting reencrypt
] 1 / 1 [Goooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooopass] 100.00%

Added 1 recipients
You need to run 'gopass sync' to push these changes
```

この場合は自動で GitHub に同期してくれないようで、出力されたメッセージどおりに `gopass sync` を実行して GitHub に push する。

その後、共有される側でも `gopass sync` を実行すると `gopass list` や `gopass show` で確認することが可能になっている。

```bash
[user2]$ gopass show shared/websites/mysite.example.com/shared-user
Secret: shared/websites/mysite.example.com/shared-user

YEdMWWlY2zCRs7CYTlnILKW8
url: https://mysite.example.com/
username: shared-user
```

## 共有された側での更新

共有された側でパスワードを変更する。

```bash
[user2]$ gopass generate -f shared/websites/mysite.example.com/shared-user 20
✅ Password for entry "shared/websites/mysite.example.com/shared-user" generated
Not printing secrets by default. Use 'gopass show shared/websites/mysite.example.com/shared-user' to display the password.
```

`gopass sync` で push する。

共有元だった側で `gopass sync` で pull した後に `gopass show` で変更されていることを確認する。

```bash
[user1]$ 
$ gopass show shared/websites/mysite.example.com/shared-user
Secret: shared/websites/mysite.example.com/shared-user

N100JIKv1w2RtUD2gwHS
url: https://mysite.example.com/
username: shared-user
```

root store は更新コマンドを実行するたびに GitHub に push されていたのにこの shared store ではなぜか `gopass sync` を実行しないと push されなかった。よって、定期的な sync で他者の変更を取り込む必要がありそう。

そしてうっかりすると簡単に conflict が発生してしまうため注意が必要。
管理者以外に git への push 権限を渡さないのが良さそう。

Deploy keys で試したからか Read-only の場合 `gopass sync` で push しようとしてエラーが発生する場合があり、その場合は `gopass git --store shared pull` とする。

## Web Browser での入力補助

[Gopass Bridge](https://github.com/gopasspw/gopassbridge) というものがあり、Web Browser でのパスワード入力を助けてくれるようだがまだ試せていない。

こんなファイルを作るって言うんで Windows の Chrome + WSL2 上の gopass では無理そうだ。

```
Manifest File (/home/yteraoka/.config/google-chrome/NativeMessagingHosts/com.justwatch.gopass.json):
{
    "name": "com.justwatch.gopass",
    "description": "Gopass wrapper to search and return passwords",
    "path": "/home/yteraoka/.config/gopass/gopass_wrapper.sh",
    "type": "stdio",
    "allowed_origins": [
        "chrome-extension://kkhfnlkhiapbiehimabddjbimfaijdhk/"
    ]
}
```


## GPG のメモ

GPG で複数人が複合できるように暗号化するにはまず、対象者の公開鍵を import した上で次のようにする

```
echo "plain text" | gpg --encrypt --armor --recipient 受信者1 --recipient 受信者2 > encrypted.txt
```

複合する側では

```
gpg --decrypt encrypted.txt
```

(コピペで複合側に持っていけるように ascii 出力するために `--armor` をつけた)
