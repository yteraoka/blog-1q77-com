---
title: 'git-bash (mintty) の color theme'
date: Sat, 06 Jan 2018 11:21:25 +0000
draft: false
tags: ['Windows', 'color', 'mintty']
---

[Docker Toolbox for Windows のインストール](/2017/11/docker-toolbox-for-windows/)で一緒に入った [Git for Windows](http://gitforwindows.org/) (mintty 2.0.3) を使ってて、git-bash 色の変更が Foreground, Background, Cursor しかできなくて残念だなあと思ってたところ、別の環境に Git for Windows の最新版 (Git-2.15.1.2) を単体で入れてみたら次のように Option 設定の Colours 欄に Theme っていう選択肢があるじゃないですか！！ (mintty 2.8.1)

{{< figure src="mintty-options.png" caption="mintty options" >}}

ということで Git for Windows を更新しました。 「Color Scheme Designer」というボタンをクリックすると [4bit Terminal Color Scheme Designer](http://ciembor.github.io/4bit/)

{{< figure src="4bitTerminalColorSchemeDesigner.png" caption="4bit Terminal Color Scheme Designer" >}}

ここでグリグリ調整して右上の「Get Sceheme」ボタンから「mintty」を選択すると ~/.minttyrc に書くための設定が取得できます（Firefox だけで機能し、Chrome, IE, Edge では機能しませんでした）

{{< figure src="export_scheme_to_the_configuration_file.png" caption="export scheme to the configuration file" >}}

次のようなテキストが取得できるので ~/.minttyrc に書くことで色を指定できます。

```
BackgroundColour=13,25,38
ForegroundColour=217,230,242
CursorColour=217,230,242
Black=0,0,0
BoldBlack=38,38,38
Red=184,122,122
BoldRed=219,189,189
Green=122,184,122
BoldGreen=189,219,189
Yellow=184,184,122
BoldYellow=219,219,189
Blue=122,122,184
BoldBlue=189,189,219
Magenta=184,122,184
BoldMagenta=219,189,219
Cyan=122,184,184
BoldCyan=189,219,219
White=217,217,217
BoldWhite=255,255,255
```

しかし、これでは選択式になってる Theme の意味がありません。いくつか用意して切り替えたい場合は `~/.mintty/theme/` フォルダに任意のファイル名で保存すればファイル名が theme 名として表示され選択可能になります。

* [https://github.com/oumu/mintty-color-schemes](https://github.com/oumu/mintty-color-schemes)
* [https://github.com/PhilipDaniels/mintty/tree/master/themes](https://github.com/PhilipDaniels/mintty/tree/master/themes)
* [https://github.com/goreliu/wsl-terminal/tree/master/src/etc/themes](https://github.com/goreliu/wsl-terminal/tree/master/src/etc/themes)

solarized は [https://github.com/karlin/mintty-colors-solarized/](https://github.com/karlin/mintty-colors-solarized/) にあったのでありがたく使わせていただきました。 てなわけで私の設定ファイルは `.minttyrc`

```
$ cat .minttyrc
BoldAsFont=yes
Font=Consolas
FontHeight=11
Term=xterm-256color
BoldAsColour=no
Transparency=low
BellFlash=yes
ScrollMod=off
CopyAsRTF=no
Columns=100
Rows=30
CursorType=block
PgUpDnScroll=yes
BellType=0
ThemeFile=solarized-dark
```

で、`.mintty/themes/solarized-dark` が

```
Black=7,54,66
Red=220,50,47
Green=133,153,0
Yellow=181,137,0
Blue=38,139,210
Magenta=211,54,130
Cyan=42,161,152
White=238,232,213
BoldBlack=0,43,54
BoldRed=203,75,22
BoldGreen=88,110,117
BoldYellow=101,123,131
BoldBlue=131,148,150
BoldMagenta=108,113,196
BoldCyan=147,161,161
BoldWhite=253,246,227
ForegroundColour=238,232,213
BackgroundColour=0,43,54
CursorColour=133,153,0
```

となりました。 [https://github.com/mintty/mintty/wiki/Tips](https://github.com/mintty/mintty/wiki/Tips) ちなみに PuTTY は [https://github.com/AlexAkulov/putty-color-themes/](https://github.com/AlexAkulov/putty-color-themes/blob/master/images/readme.md) に沢山の theme が公開されてます
