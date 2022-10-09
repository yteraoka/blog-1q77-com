---
title: 'doctl の Bash / Zsh 補完'
date: Sun, 21 May 2017 10:15:20 +0000
draft: false
tags: ['Bash', 'DigitalOcean', 'DigitalOcean']
---

[doctl 1.6.1](https://github.com/digitalocean/doctl/releases/tag/v1.6.1) で shell completion 機能が追加されていました [Implementing Bash completion #206](https://github.com/digitalocean/doctl/pull/206)```
$ doctl completion
completion is used to output completion code for bash and zsh shells.

Before using completion features, you have to source completion code
from your .profile or .bashrc/.zshrc file. This is done by adding
following line to one of above files:
	source <(doctl completion SHELL)

Bash users can as well save it to the file and copy it to:
	/etc/bash\_completion.d/

Correct arguments for SHELL are: "bash" and "zsh".

Notes:
1) zsh completions requires zsh 5.2 or newer.
	
2) macOS users have to install bash-completion framework to utilize
completion features. This can be done using homebrew:
	brew install bash-completion

Once installed, you must load bash\_completion by adding following
line to your .profile or .bashrc/.zshrc:
	source $(brew --prefix)/etc/bash\_completion

Usage:
  doctl completion \[command\]

Available Commands:
  bash        generate bash completion code
  zsh         generate zsh completion code

Flags:
  -h, --help   help for completion

Global Flags:
  -t, --access-token string   API V2 Access Token
  -c, --config string         config file (default is $HOME/.config/doctl/config.yaml)
  -o, --output string         output format \[text|json\] (default "text")
      --trace                 trace api access
  -v, --verbose               verbose output

Use "doctl completion \[command\] --help" for more information about a command.

```次のようにすればそのセッションですぐに補完が機能するようになります```
$ source <(doctl completion bash)

```ファイルに書き出したりして bash 起動時やログイン時に自動で読み込まれるようにすることもできますね。方法は環境依存なので(ry ちなみに Kubernetes の kubectl にも同様の機能があります。doctl はここからアイデアが来てるっぽい。```
$ kubectl completion -h
Output shell completion code for the specified shell (bash or zsh). The shell
code must be evalutated to provide interactive completion of kubectl commands.
This can be done by sourcing it from the .bash \_profile. 

Note: this requires the bash-completion framework, which is not installed by
default on Mac.  This can be installed by using homebrew: 

  $ brew install bash-completion
  
Once installed, bash completion must be evaluated.  This can be done by adding
the following line to the .bash profile 

  $ source $(brew --prefix)/etc/bash\_completion
  
Note for zsh users: \[1\] zsh completions are only supported in versions of zsh >=
5.2

Examples:
  # Install bash completion on a Mac using homebrew
  brew install bash-completion
  printf "\\n# Bash completion support\\nsource $(brew
--prefix)/etc/bash\_completion\\n" >> $HOME/.bash\_profile
  source $HOME/.bash\_profile
  
  # Load the kubectl completion code for bash into the current shell
  source <(kubectl completion bash)
  
  # Write bash completion code to a file and source if from .bash\_profile
  kubectl completion bash > ~/.kube/completion.bash.inc
  printf "\\n# Kubectl shell completion\\nsource
'$HOME/.kube/completion.bash.inc'\\n" >> $HOME/.bash\_profile
  source $HOME/.bash\_profile
  
  # Load the kubectl completion code for zsh\[1\] into the current shell
  source <(kubectl completion zsh)

Usage:
  kubectl completion SHELL \[options\]

Use "kubectl options" for a list of global command-line options (applies to all
commands).

```