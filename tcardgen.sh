#!/bin/bash

markdown_file=$1
output_file=$(dirname $markdown_file)/cover.png

if [ $# -ne 1 ] ; then
  echo "Usage: $0 content/posts/xxx/index.md"
  exit 1
fi

if [ ! -f "${markdown_file}" ] ; then
  echo "${markdown_file} does not exist" 1>&2
  exit 2
fi

tcardgen -c tcardgen/tcardgen.yaml -f tcardgen/fonts/kintosans "${markdown_file}" -o "${output_file}"
