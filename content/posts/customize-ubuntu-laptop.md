---
title: 'Ubuntu Laptop のカスタマイズ'
date: 
draft: true
tags: ['Ubuntu']
---

### TouchPadの右クリックが機能しない

私の Vaio は1枚の TouchPad でクリックする場所によって右クリックになるのですが、Ubuntu 18.04 の標準設定ではこれが機能しませんでした。gnome-tweaks をインストールして実行すればこれを有効にする設定項目が現れました。

Gnome Tweaks のインストール```
sudo apt install gnome-tweaks

```

**Tweaks** の **Keyboard & Mouse** から **Mouse Click Emulation** を **Fingers** (Click the touchpad with two Filgers for right-click and three Fingers for middle-click) から **Area** (Click the bottom right of the touchpad for right-click and the bottom middle for middle-click) に変更したら右下のクリックが右クリックになりました。しかし、**Fingers** の説明を読んで実際につかってみるとこっちが便利かも。