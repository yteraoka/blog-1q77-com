---
title: 'Cinnamon の remote で carriage return が...'
date: Wed, 22 May 2013 14:01:53 +0000
draft: false
tags: ['Perl', 'anyevent', 'cinnamon']
---

（2013/05/24追記あり） デプロイツールとして [Cinnamon](https://github.com/kentaro/cinnamon) がカジュアルで良いかなぁと思って使い始めているのですが、remote で実行するコマンドが `\r` を `\r\n` 以外で出力するとその後の出力がうまく拾えないという問題が発生しました。 `\r` がどんな場合に出力されるかというと、progress メーターみたいに % 表示する場合ですね。

```perl
for my $i (0 .. 10) {
    my $percent = sprintf "\r%3d%%", $i * 10;
    syswrite(STDOUT, $percent, length($percent));
    sleep 1;
}
print "\n";
```

maven で依存ライブラリをダウンロードするところで引っかかりました。これは `mvn -B` と batch mode にすることで回避することができます。curl で -s を付けない場合にも download の進捗が表示されますね。 そんで、コードを追っかけてみようかなと。Cinnamon の当該部分は [HandleManager.pm](https://github.com/kentaro/cinnamon/blob/master/lib/Cinnamon/HandleManager.pm) の start\_async\_read() の中

```perl
            on_read => sub {
                $handle->push_read(line => sub {
                    my $line = $_[1];
                    push @{$info->{output_lines}}, $line;
                    log info => sprintf "[%s :: %s] %s",
                        $self->{host}, $name, $line;
                });
            },
```

で push\_read の type が line なのは AnyEvent::Handle の↓この部分かな。

```perl
register_read_type line => sub {
   my ($self, $cb, $eol) = @_;

   if (@_ < 3) {
      # this is more than twice as fast as the generic code below
      sub {
         $_[0]{rbuf} =~ s/^([^\015\012]*)(\015?\012)// or return;

         $cb->($_[0], "$1", "$2");
         1
      }
   } else {
      $eol = quotemeta $eol unless ref $eol;
      $eol = qr|^(.*?)($eol)|s;

      sub {
         $_[0]{rbuf} =~ s/$eol// or return;

         $cb->($_[0], "$1", "$2");
         1
      }
   }
};
```

ふむふむ Cinnamon::HandleManager をこう書き換えると期待通りかな？

```
                $handle->push_read(line => sub {
                            ↓
                $handle->push_read(line => qr|\r?\n|, sub {
```

これは AnyEvnet::Handle の問題なんでしょうか？

### ※ 2013/05/24 追記

Cinnamon への Pull Request を merge してもらいました。 [https://github.com/kentaro/cinnamon/pull/23](https://github.com/kentaro/cinnamon/pull/23)
