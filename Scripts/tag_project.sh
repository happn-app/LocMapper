#!/bin/bash
### Script ###############################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
bin_dir="$scpt_dir/zz_bin"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################

"$lib_dir/tag_project.sh" "$@"
