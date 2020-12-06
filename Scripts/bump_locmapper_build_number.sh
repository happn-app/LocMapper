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

"$lib_dir/set_project_version.sh" --targets "LocMapper" --targets "LocMapperTests" --targets "LocMapper CLI" --targets "LocMapper App" --bump-build-version --commit || exit 3

# Change hard-coded version in LocMapper CLI
version="$(hagvtool --output-format json --targets "LocMapper CLI" get-versions | jq -r .reduced_build_version_for_all)" || exit 3
sed -i '' -E 's|^.*__VERSION_LINE_TOKEN__.*$|	static var version = "'"$version"'" /* Do not remove this token, it is used by a script: __VERSION_LINE_TOKEN__ */|' "./LocMapper CLI/main.swift"
git commit -a --amend --no-edit
