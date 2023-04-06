---
title: "Android App on Ubuntu"
date: 2023-04-05T13:07:19+09:00
draft: true
tags: ["Ubuntu", "Android"]
---

```
$ snap info anbox
name:      anbox
summary:   Android in a Box
publisher: Simon Fels (morphis)
store-url: https://snapcraft.io/anbox
contact:   https://anbox.io
license:   GPL-3.0+
description: |
  Runtime for Android applications which runs a full Android system
  in a container using Linux namespaces (user, ipc, net, mount) to
  separate the Android system fully from the host.
  
  You can find further details in our documentation at
  https://github.com/anbox/anbox/blob/master/README.md
snap-id: Nr9K6UJaIOD8wHpDEQl16nabFFt9LLEQ
channels:
  latest/stable:    –                                    
  latest/candidate: –                                    
  latest/beta:      4-56c25f1     2020-01-02 (186) 391MB devmode
  latest/edge:      4+gitr7a0bee7 2022-09-14 (214) 407MB devmode
```

stable は無いし、beta も古いので edge をインストールする

```
sudo snap install --devmode --edge anbox
```

