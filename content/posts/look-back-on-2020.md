---
title: '2020年のOSS活動ふり返り'
date: Fri, 25 Dec 2020 00:46:56 +0900
draft: false
tags: ['Uncategorized', 'Advent Calendar 2020']
---

ほとんどサボってしまった [Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) ですが、最後の日は 2020 年の OSS 活動について振り返ってみる。

2月頃は Vitess を触ってみてましたね。で、helm chart におかしなところがあったから issue を上げた。あの頃は Kubernetes Operator もまだ若かったし、諸々完成度はまだまだって感じだった。planet scale のやつの方が良さそうだなと思ったけど、その後触ってないからもう良く知らない。

https://github.com/vitessio/vitess/issues/5843

4月頃は Amazon ES にログを入れようかなって思って、Elasticsearch の template やら ingest pipeline やら watcher Alerting 設定をどうしようかなと思ってて、[mihirsoni/odfe-monitor-cli](https://github.com/mihirsoni/odfe-monitor-cli) が使えるんじゃないかと調べてました。

[#7](https://github.com/mihirsoni/odfe-monitor-cli/pull/7) は書き出すファイルを上書きするんだけど、truncate しないから、上書きする方が元のサイズよりも小さいと後ろにゴミが残るというバグ修正。ホントは一時ファイルに書き出して rename する方が安全だけど。

https://github.com/mihirsoni/odfe-monitor-cli/pull/7

[#8](https://github.com/mihirsoni/odfe-monitor-cli/pull/8) はなぜかデフォルトで Basic 認証のユーザー名、パスワードが指定されてて、それに気付かずハマったのでデフォルトでは無効にしない？って言ってみたけど受け入れてもらえなかったやつ。

https://github.com/mihirsoni/odfe-monitor-cli/pull/8

[#9](https://github.com/mihirsoni/odfe-monitor-cli/pull/9) は Alerting の Action Throttle 機能への対応。だいぶ経ってから Merge されたみたい。

https://github.com/mihirsoni/odfe-monitor-cli/pull/9

でも odfe-monitor-cli だと terraform の中で shell script を実行するのも気持ち悪いしなあと思って、[terraform-provider-elasticsearch](https://github.com/phillbaker/terraform-provider-elasticsearch) でもいいんじゃね？ json 管理辛いけど、、、となりかけたところで、やっぱり Elasticsearch はやめて CloudWatch Logs にすることにしたのでした。

6月、[terraform-aws-lambda module](https://github.com/terraform-module/terraform-aws-lambda) で output の変数名と実態がずれていたので直してもらった

https://github.com/terraform-module/terraform-aws-lambda/issues/10

こちらも6月、Kubernetes のログをどうやってもれなく集めようか、ということで docker のログ出力先を journald にして、それを Fluent Bit で読み出そうとしてた (そうすることで、docker のログのローテーション間隔やタイミングの問題での取りこぼしを回避できるかと考えた) ら SIGTERM での停止時に読み込んだけどまだ buffer に書かれていないデータなのかな？が失われてしまう問題が見つかったので報告。

https://github.com/fluent/fluent-bit/issues/2277

7月、[このツイート](https://x.com/danielepolencic/status/1275786970610843648) を見て kubectl-isolate っていう shell script を書いた。実際にこれを役立てたことはまだないけど。

https://github.com/yteraoka/kubectl-isolate

7月にもう一つ、と言ってもしばらく放置したので merge されたのは9月。Prometheus のメトリクスは Grafana で見ることがほとんどで、その場合は TYPE コメントの型が counter だろうが gauge だろうが問題ないのですが、たまたま sysdig monitor を使う機会があり、当時の sysdig ではその型が意味を持っていたので counter であるべきものはそうなるように修正。ただ、その後 sysdig も native な Prometheus 対応をしたのでもしかしたらもうあまり重要ではないかもしれない...

https://github.com/fluent/fluent-plugin-prometheus/pull/163

7月の終わりにもう一つ。Fluentd の file buffer でレースコンディション問題があるっぽいので報告。

https://github.com/fluent/fluentd/issues/3089

9月、[Kuberhealthy](https://github.com/Comcast/kuberhealthy) の helm chart で tolerations を指定する方法が無かったので追加。

https://github.com/Comcast/kuberhealthy/pull/641

11月は Google の Container Registry で古い image の削除を行いたいけど AWS の ECR みたいに機能が用意されていないため、ツールを作ろうかと思っていたところ、[gcr-lifecycle-policy](https://github.com/marekaf/gcr-lifecycle-policy) ってのを見つけたのでこれ使えるんじゃね？ということで試したらまあ、いろいろ問題があったのでした... そのうち Google さんが機能を追加してくれるだろうと信じています

まずは、Container Registry にしか対応してなかったのを Artifact Registry に対応させる

https://github.com/marekaf/gcr-lifecycle-policy/issues/6

次に sort 順が逆だよという指摘

https://github.com/marekaf/gcr-lifecycle-policy/pull/7

お次はヨーロッパスタイルの日付表示は辛いよ

https://github.com/marekaf/gcr-lifecycle-policy/issues/9

このツールは Kubernetes クラスタ内で使われているイメージは削除しないという機能があるのだけれど、それが機能しないパターンがいくつかあったので修正

https://github.com/marekaf/gcr-lifecycle-policy/pull/10

Image の tag が特定のパターンにマッチするものは消さないという指定ができるように機能追加

https://github.com/marekaf/gcr-lifecycle-policy/pull/13

と、こんなところでした。お疲れ様でした。みなさま良いお年を。
