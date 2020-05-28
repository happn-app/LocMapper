#!/bin/bash
### Script ###############################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
bin_dir="$scpt_dir/zz_bin"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################


if [ -n "$1" -o "$1" = "--help" ]; then
	echo "syntax: $0" >/dev/stderr
	echo "   the repo must be clean when running this script" >/dev/stderr
	echo "   note: --help makes program exit with status 1" >/dev/stderr
	exit 1
fi

"$lib_dir/set_project_version.sh" --targets "LocMapper,LocMapperTests,LocMapper CLI,LocMapper App" --bump-build-version --commit

# Change hard-coded version in LocMapper CLI
version="$("$bin_dir/hagvtool" --porcelain print-build-number 2>/dev/null | grep 'LocMapper CLI' | tail -n1 | cut -d':' -f2)"
sed -i '' -E 's|^.*__VERSION_LINE_TOKEN__.*$|	static var version = "'"$version"'" /* Do not remove this token, it is used by a script: __VERSION_LINE_TOKEN__ */|' "./LocMapper CLI/main.swift"
git commit -a --amend --no-edit
