---
title: 'The source :rubygems is deprecated'
date: Thu, 28 Feb 2013 14:01:20 +0000
draft: false
tags: ['Ruby']
---

```
The source :rubygems is deprecated because HTTP requests are insecure.
Please change your source to 'https://rubygems.org' if possible, or 'http://rubygems.org' if not.
```

って表示されたら Gemfile の

```
source :rubygems
```

を

```
source 'https://rubygems.org'
```

に書き換えましょう。 以上
