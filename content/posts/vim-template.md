---
title: 'Vim の template'
date: Mon, 07 Jan 2013 15:24:21 +0000
draft: false
tags: ['Linux', 'vim']
---

自作 RPM を作ろうかと思って

```
vim xxx.spec
```

って実行したら

```
Name:
Version:
Release:        1%{?dist}
Summary:

Group:
License:
URL:
Source0:
BuildRoot:      %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:
Requires:

%description


%prep
%setup -q


%build
%configure
"/usr/share/vim/vimfiles/template.spec" 42L, 405C             1,1           Top
```

って表示されて、「えっ！新規ファイルだったはずなのに！？なんで？」と驚いてしまいました。template 機能があるんですね。
`/etc/vimrc` に

```
autocmd BufNewFile *.spec 0r /usr/share/vim/vimfiles/template.spec
```

って書いてありました。

```
:h template
```

で help が出てきます。

* [Big Sky :: ファイルタイプ別にテンプレートを選べるsonictemplate-vim書いた](http://mattn.kaoriya.net/software/vim/20111025154246.htm)
* [blog.paz-para.com » Blog Archive » Vimでテンプレートを挿入する](http://blog.paz-para.com/?p=1733)
