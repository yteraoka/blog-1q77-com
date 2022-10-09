---
title: 'FluentdでPostfixのログをつなぎ合わせる'
date: Thu, 29 Oct 2015 14:38:28 +0000
draft: false
tags: ['Postfix', 'Redis', 'Ruby', 'fluentd']
---

前からやろうやろうと思ってなかなか手をつけられずにいたのですが、やっと実装しました。 （エラーハンドリングとかまだだけど） Postfix に限らず SMTP サーバーのログは from と to などが別の行として出力されます。 そして、各行ごとに出力される項目が異なります。from の行には size と nrcpt など。to には relay 先、delay, delays, status など。接続元や message-id はまた別の行です。 そこで [IOS　ビッグデータ技術ブログ: Postfixのログをfluentdを使ってTreasureDataに送る](http://sstd-bigdata.blogspot.jp/2014/08/postfixfluentdtreasuredata.html) を見つけてとりあえず [fluent-plugin-multi-format-parser](https://github.com/repeatedly/fluent-plugin-multi-format-parser) を使って elasticsearch に送って配信エラー監視したり kibana で確認したりしてましたが、to の行で bounced になってるのを見て from は何かなと思ったら queue id から from を検索して確認するのがかなり面倒なのでやっぱりこれは1行にまとめなければと。 大雑把には to 以外のデータを redis なり memcached に登録しておいて to でそれを引っ張りだして返せば良いわけだけども、どうやって実装するのかなと。 最初は Filter プラグインで実装しようかと考えていましたが redis なり memcached なりを使うとするとそこでエラーになる可能性があるため、エラーの場合にリトライできるように BufferedOutput で実装を始めました。が、処理した結果をまた fluentd に戻す方法がわからなくて、困ってしまいました。どうしようかなって fluentd のリポジトリを眺めているうちに out\_exec\_filter というものがあることに気づいてこれだ！！ということで実装しました。 エラーハンドリングがないけど

```ruby
#!/opt/td-agent/embedded/bin/ruby

require 'redis'
require 'json'

redis = Redis.new

while line = STDIN.gets
  record = JSON.load(line)
  if record.has_key?('from')
    # time は to のもので上書きされてしまうので from の時の値を別名で保存しておく
    record['received_at'] = Time.at(record['time'].to_i).strftime('%Y-%m-%dT%H:%M:%S%:z')
  end

  if record.has_key?('qid')
    key = record['host'] + ':' + record['qid']

    stored = redis.hgetall(key) || {}

    if record.has_key?('to')
      print JSON.generate(stored.merge(record)) + "\n"
    elsif record['message'] == 'removed'
      redis.del(key)
    else
      redis.mapped_hmset(key, stored.merge(record))
      # postfix の bounce_queue_lifetime の値に合わせて expire を設定する
      redis.expire(key, 86400)
    end
  end
end
```

Postfix のログの parse を fluent-plugin-multi-format-parser ではなく Parser プラグインを書きました。gem 化してないので td-agent では /etc/td-agent/plugin/ ディレクトリに置いて使います。

```ruby
module Fluent
  class TextParser
    class PostfixLogParser < Parser
      Plugin.register_parser('postfix_log_parser', self)

      config_param :time_format, :string, :default => nil

      def configure(conf)
        super
        @time_parser = TimeParser.new(@time_format)
        @addr_keys = ['to', 'from', 'orig_to']
      end

      def parse_message(message)
        log = {}

        if m = message.match(/^(?<qid>[A-F0-9]+):\s+/)
          log['qid'] = m['qid']
          message.gsub!(/^[A-F0-9]+:\s+/, '')
        else
          log['message'] = message
          return log
        end

        if m = message.match(/, status=(?<status>\S+)\s+(?<message>.*)$/)
          log['status'] = m['status']
          log['message'] = m['message']
          message.gsub!(/, status=.*$/, '')
        end

        if ! message.match(/^[a-z0-9\-]+=/)
          log['message'] = message
          return log
        end

        message.split(/, /).each do |kv|
          (key, value) = kv.split('=')
          if @addr_keys.include?(key)
            log[key] = value.gsub!(/^\<(.*)\>$/, '\1')
          else
            log[key] = value
          end
        end

        log
      end

      # to や from のドメインで集計したいこともあるのでドメイン抽出
      def domain(addr)
        local, domain = addr.split('@', 2)
        parts = domain.split('.').reverse
        # 属性型JPドメインでは後ろから3つ分 (ISPとかのサブドメインを無視する)
        if parts[0] == 'jp' and parts[1].length == 2
          return [parts[2], parts[1], parts[0]].join('.')
        elsif parts.length >= 2
          return [parts[1], parts[0]].join('.')
        else
          return domain
        end
      end

      def parse(text)
        m = text.match(/^(?<time>\S+\s+\S+\s+\S+)\s+(?<host>\S+)\s+(?<process>[^\[]+)\[(?<pid>\d+)\]:\s+(?<message>.*)/)
        time = @time_parser.parse(m['time'])
        record = parse_message(m['message'])
        record['host']    = m['host']
        record['process'] = m['process']
        record['pid']     = m['pid']

        # nrcpt は後ろに "(queue active)" とかついてるけど削って数値として扱えるようにしておく
        if record.has_key?('nrcpt')
          record['nrcpt'].gsub!(/\s.*$/, '')
        end
        if record.has_key?('to')
          record['to_domain'] = domain(record['to'].downcase)
        end
        if record.has_key?('from') && record['from'] != ''
          record['from_domain'] = domain(record['from'].downcase)
        end

        yield time, record
      end
    end
  end
end
```

td-agent.conf はこんな感じ(必要に応じて Buffer まわりの調整を)

```
<source>
  type tail
  format postfix_log_parser
  time_format %b %e %T
  path /var/log/maillog
  pos_file /var/lib/td-agent/mail.pos
  tag mail.syslog
</source>

<match mail.syslog>
  type exec_filter
  command /etc/td-agent/exec_filter/postfix_log_binder.rb
  in_format json
  out_format json
  tag mail.filtered
  time_key time
</match>

<match mail.filtered>
  type elasticsearch
  hosts kibana2:9200,kibana3:9200
  type_name postfix
  logstash_format true
  logstash_prefix postfix
  flush_interval 5s
</match>
```

/var/log/maillog はそのままでは td-agent ユーザーでは読めないので rsyslog の設定を変更します。

```
$DirCreateMode 0750
$FileCreateMode 0640
$DirGroup sys
$FileGroup sys
```

td-agent ユーザーを sys グループに所属させます。

```
sudo usermod -a -G sys td-agent
```

プラグインの書き方は公式ドキュメントを参照しました [http://docs.fluentd.org/articles/plugin-development](http://docs.fluentd.org/articles/plugin-development) 昔 [fluent-plugin-fortigate-log-parser](https://github.com/yteraoka/fluent-plugin-fortigate-log-parser) ってのを書いたけど Parser なのに Output プラグインとして実装してしまったので書き直したいな。
