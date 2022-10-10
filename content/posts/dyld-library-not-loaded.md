---
title: 'dyld: Library not loaded への対応方法'
date: Mon, 30 Nov 2020 15:11:57 +0000
draft: false
tags: ['advent calendar 2020', 'macOS']
---

[Advent Calendar 2020 全部オレシリーズ](https://qiita.com/advent-calendar/2020/yteraoka) 1日目です。完走できるか心配です。

先日、[Homebrew](https://brew.sh/) で [grpc\_cli](https://github.com/grpc/grpc/blob/master/doc/command_line_tool.md) (grpc) をインストールしたんですけれども、実行すると次のように共有ライブラリが見つからないというエラーになりました。

```
$ grpc_cli
dyld: Library not loaded: @rpath/libgrpc++.1.dylib
  Referenced from: /Users/teraoka/.homebrew/bin/grpc_cli
  Reason: image not found
zsh: abort      grpc_cli
```

`libgrpc++.1.dylib` は `/Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/lib/libgrpc++.1.dylib` にあって、`/Users/teraoka/.homebrew/lib/libgrpc++.1.dylib` への symbolic link もありました。

Mac を使い始めて日が浅いし、Homebrew まかせで自分でコンパイルすることもないので良く分かりませんが、Linux での rpath (LD\_RUN\_PATH) には覚えがありますね。

Mac の場合は DYLD\_LIBRARY\_PATH が使えるようです。次のようにすれば実行できました。

```
DYLD_LIBRARY_PATH=/Users/teraoka/.homebrew/lib grpc_cli
```

しかし、この環境変数を .zshrc に書くことの影響も読めないので Linux での compile (link) 時の `-rpath` 指定のようにバイナリに埋め込む path を指定したいものです。

Mac (LLVM) には otool というものがあり、これでバイナリ内の rpath を確認できるっぽいです。

```
$ otool -l /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli | grep -B 1 -A 2 LC_RPATH
Load command 30
          cmd LC_RPATH
      cmdsize 64
         path /tmp/grpc-20201123-11869-1aso5q3/cmake/build (offset 12)
```

rpath はビルド時のテンポラリディレクトリになってるっぽい？

ちなみに、`otool -L` で Linux の ldd コマンドみたいな結果が得られました。

```
$ otool -L /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli
/Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli:
	/Users/teraoka/.homebrew/opt/gflags/lib/libgflags.2.2.dylib (compatibility version 2.2.0, current version 2.2.2)
	/Users/teraoka/.homebrew/opt/protobuf/lib/libprotobuf.25.dylib (compatibility version 26.0.0, current version 26.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1281.100.1)
	@rpath/libgrpc++.1.dylib (compatibility version 1.0.0, current version 1.33.2)
	@rpath/libgrpc++_test_config.1.dylib (compatibility version 1.0.0, current version 1.33.2)
	@rpath/libgrpc.13.dylib (compatibility version 13.0.0, current version 13.0.0)
	@rpath/libgpr.13.dylib (compatibility version 13.0.0, current version 13.0.0)
	@rpath/libaddress_sorting.13.dylib (compatibility version 13.0.0, current version 13.0.0)
	@rpath/libupb.13.dylib (compatibility version 13.0.0, current version 13.0.0)
	/Users/teraoka/.homebrew/opt/openssl@1.1/lib/libssl.1.1.dylib (compatibility version 1.1.0, current version 1.1.0)
	/Users/teraoka/.homebrew/opt/openssl@1.1/lib/libcrypto.1.1.dylib (compatibility version 1.1.0, current version 1.1.0)
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
	/Users/teraoka/.homebrew/opt/c-ares/lib/libcares.2.dylib (compatibility version 2.0.0, current version 2.4.2)
	/usr/lib/libresolv.9.dylib (compatibility version 1.0.0, current version 1.0.0)
	/Users/teraoka/.homebrew/opt/re2/lib/libre2.dylib (compatibility version 0.0.0, current version 0.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1677.104.0)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 902.1.0)
```

Homebrew で rpath を指定する方法はまだ分からないけど、`install_name_tool` というコマンドでバイナリ内の rpath (LC\_RPATH) を変更できることが分かりました。`-add_rpath` で追加するか `-rpath` で変更が可能だと分かりました。

`install_name_tool` はバイナリを書き換えるため、write 権限をつけます。

```
$ chmod u+w /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli
```

`-rpath` で書き換えます。

```
$ install_name_tool \
    -rpath /tmp/grpc-20201123-11869-1aso5q3/cmake/build \
           /Users/teraoka/.homebrew/lib \
    /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli
```

書き換えられました。

```
$ otool -l /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli | grep -B 1 -A 2 LC_RPATH
Load command 30
          cmd LC_RPATH
      cmdsize 48
         path /Users/teraoka/.homebrew/lib (offset 12)
```

`-add_rpath` で追加した場合は次のようになります。

```
$ otool -l /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli | grep -B 1 -A 2 LC_RPATH
Load command 30
          cmd LC_RPATH
      cmdsize 64
         path /tmp/grpc-20201123-11869-1aso5q3/cmake/build (offset 12)
--
--
Load command 33
          cmd LC_RPATH
      cmdsize 48
         path /Users/teraoka/.homebrew/lib (offset 12)

```

どちらの場合も `dyld: Library not loaded` エラーを回避できます。インストールの度にやるのは面倒ですね、Homebrew の設定とかでなんとかならないものか。

と、調べていたら気付きました

```
==> Downloading https://homebrew.bintray.com/bottles/grpc-1.33.2_1.catalina.bottle.tar.gz
```

あれ？ bottles ってお前、バイナリ配布だったのか...

ということで、またその後知った `brew edit` というコマンドでで grpc\_cli を build する args のところに `-DCMAKE_BUILD_RPATH=/Users/teraoka/.homebrew/lib` を追加して

```
$ brew edit grpc
$ brew reinstall --build-from-source grpc
```

とすることで LC\_RPATH が追加されました。

```
$ otool -l /Users/teraoka/.homebrew/Cellar/grpc/1.33.2_1/bin/grpc_cli | grep -B 1 -A 2 LC_RPATH
Load command 30
          cmd LC_RPATH
      cmdsize 48
         path /Users/teraoka/.homebrew/lib (offset 12)
--
--
Load command 31
          cmd LC_RPATH
      cmdsize 64
         path /tmp/grpc-20201130-46642-1oq94ry/cmake/build (offset 12)
```

めでたし、めでたし。

が、コンパイルに時間かかるし、結局 edit しなきゃいけないしうーむ...

付録
--

otool --version

```
$ otool --version
llvm-otool(1): Apple Inc. version cctools-949.0.1
Apple LLVM version 11.0.0 (clang-1100.0.33.17)
  Optimized build.
  Default target: x86_64-apple-darwin19.6.0
  Host CPU: skylake

  Registered Targets:
    aarch64    - AArch64 (little endian)
    aarch64_be - AArch64 (big endian)
    arm        - ARM
    arm64      - ARM64 (little endian)
    armeb      - ARM (big endian)
    thumb      - Thumb
    thumbeb    - Thumb (big endian)
    x86        - 32-bit X86: Pentium-Pro and above
    x86-64     - 64-bit X86: EM64T and AMD64
```

otool usage

```
$ otool
Usage: /Library/Developer/CommandLineTools/usr/bin/otool [-arch arch_type] [-fahlLDtdorSTMRIHGvVcXmqQjCP] [-mcpu=arg] [--version] <object file> ...
	-f print the fat headers
	-a print the archive header
	-h print the mach header
	-l print the load commands
	-L print shared libraries used
	-D print shared library id name
	-t print the text section (disassemble with -v)
	-x print all text sections (disassemble with -v)
	-p start dissassemble from routine name
	-s print contents of section
	-d print the data section
	-o print the Objective-C segment
	-r print the relocation entries
	-S print the table of contents of a library (obsolete)
	-T print the table of contents of a dynamic shared library (obsolete)
	-M print the module table of a dynamic shared library (obsolete)
	-R print the reference table of a dynamic shared library (obsolete)
	-I print the indirect symbol table
	-H print the two-level hints table (obsolete)
	-G print the data in code table
	-v print verbosely (symbolically) when possible
	-V print disassembled operands symbolically
	-c print argument strings of a core file
	-X print no leading addresses or headers
	-m don't use archive(member) syntax
	-B force Thumb disassembly (ARM objects only)
	-q use llvm's disassembler (the default)
	-Q use otool(1)'s disassembler
	-mcpu=arg use `arg' as the cpu for disassembly
	-j print opcode bytes
	-P print the info plist section as strings
	-C print linker optimization hints
	--version print the version of /Library/Developer/CommandLineTools/usr/bin/otool 
```

install\_name\_tool(1)

```
INSTALL_NAME_TOOL(1)                                      INSTALL_NAME_TOOL(1)



NAME
       install_name_tool - change dynamic shared library install names

SYNOPSIS
       install_name_tool  [-change  old  new  ]  ...  [-rpath  old  new  ] ...
       [-add_rpath new ] ... [-delete_rpath new ] ... [-id name] file

DESCRIPTION
       Install_name_tool changes the dynamic shared library install names  and
       or  adds,  changes  or  deletes the rpaths recorded in a Mach-O binary.
       For this tool to work when the install names or rpaths are  larger  the
       binary  should  be  built  with  the ld(1) -headerpad_max_install_names
       option.

       -change old new
              Changes the dependent shared library install name old to new  in
              the specified Mach-O binary.  More than one of these options can
              be specified.  If the Mach-O binary does  not  contain  the  old
              install  name  in  a  specified  -change  option  the  option is
              ignored.

       -id name
              Changes the shared library  identification  name  of  a  dynamic
              shared  library  to name.  If the Mach-O binary is not a dynamic
              shared library and the -id option is specified it is ignored.

       -rpath old new
              Changes the rpath path name old to new in the  specified  Mach-O
              binary.   More  than  one of these options can be specified.  If
              the Mach-O binary does not contain the old rpath path name in  a
              specified -rpath it is an error.

       -add_rpath new
              Adds  the  rpath  path  name new in the specified Mach-O binary.
              More than one of these options can be specified.  If the  Mach-O
              binary  already  contains  the  new rpath path name specified in
              -add_rpath it is an error.

       -delete_rpath old
              deletes the rpath path name old in the specified Mach-O  binary.
              More  than one of these options can be specified.  If the Mach-O
              binary does not contains the old rpath path  name  specified  in
              -delete_rpath it is an error.

SEE ALSO
       ld(1)



Apple, Inc.                      March 4, 2009            INSTALL_NAME_TOOL(1)
```
