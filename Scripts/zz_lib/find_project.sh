#!/bin/bash
### Lib ##################################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir"
bin_dir="$scpt_dir/../zz_bin"
source "$lib_dir/common.sh" || exit 255
##########################################


usage() {
	echo "syntax: $0 [--project-type project_extension] [--output-type absolute|relative|basename]" >/dev/stderr
	echo "   output-type is relative by default" >/dev/stderr
	echo "   project-type is \"xcodeproj\" by default" >/dev/stderr
	echo "   exits with status 1 for syntax error, 2 if not exactly one project are in PWD" >/dev/stderr
	echo "   note: --help makes program exit with status 1 too" >/dev/stderr
	exit 1
}


output_type="relative"
project_type="xcodeproj"
while [ -n "$1" ]; do
	case "$1" in
		--project-type)
			shift
			[ -n "$1" ] || usage
			project_type="$1"
			;;
		--output-type)
			shift
			[ "$1" = "absolute" -o "$1" = "relative" -o "$1" = "basename" ] || usage
			output_type="$1"
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

if [ $(ls -d *."$project_type" 2>/dev/null | wc -l) -ne 1 ]; then exit 2; fi

case "$output_type" in
	absolute)
		echo $(pwd)/$(basename *."$project_type")
		;;
	relative)
		echo $(basename *."$project_type")
		;;
	basename)
		echo $(basename *."$project_type" ".$project_type")
		;;
esac
