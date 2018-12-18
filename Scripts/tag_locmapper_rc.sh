#!/bin/bash
### Script ###############################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
bin_dir="$scpt_dir/zz_bin"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################


marketing_version="$1"
locmapper_build_number="$2"
if [ "$1" = "--help" -o -z "$marketing_version" -o -z "$locmapper_build_number" ]; then
	echo "syntax: $0 marketing_version locmapper_build_number" >/dev/stderr
	echo "   the repo must be clean when running this script" >/dev/stderr
	echo "   note: --help makes program exit with status 1" >/dev/stderr
	exit 1
fi

"$lib_dir/tag_project.sh" --project-name "LocMapper" --style "release-candidate" "$locmapper_build_number" "LocMapper" "$marketing_version"
