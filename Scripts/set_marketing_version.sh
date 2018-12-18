#!/bin/bash
### Script ###############################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
bin_dir="$scpt_dir/zz_bin"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################


version="$1"
if [ -z "$version" -o "$version" = "--help" ]; then
	echo "syntax: $0 build_number" >/dev/stderr
	echo "   the repo must be clean when running this script" >/dev/stderr
	echo "   note: --help makes program exit with status 1" >/dev/stderr
	exit 1
fi

"$lib_dir/set_project_version.sh" --targets "LocMapperTests,LocMapper App,LocMapper Linter" --set-marketing-version "$version" --commit
