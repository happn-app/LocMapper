#!/bin/bash
### Lib ##################################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir"
source "$lib_dir/common.sh" || exit 255
##########################################


usage() {
	echo "syntax: $0 [--check-for-untracked-files]" >/dev/stderr
	echo "   use --check-for-untracked-files to check if untracked files are present in the repo (by default, only diff to HEAD is checked)"
	echo "   exits with status 0 if project is clean, 1 if project is dirty, 2 if a git error occurred, 255 on syntax error" >/dev/stderr
	echo "   note: --help makes program exit with status 255 too" >/dev/stderr
	exit 255
}

check_untracked=0
while [ -n "$1" ]; do
	case "$1" in
		--check-for-untracked-files)
			check_untracked=1
			;;
		--)
			shift
			break
			;;
		*)
			break
			;;
	esac
	shift
done
[ -z "$1" ] || usage

status="$(git status --porcelain 2>/dev/null)" || exit 2
echo "$status" | grep -Eq '^[^?]' && exit 1
if [ $check_untracked -ne 0 ]; then echo "$status" | grep -Eq '^\?' && exit 1; fi
exit 0
