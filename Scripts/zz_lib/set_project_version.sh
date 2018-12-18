#!/bin/bash
### Lib ##################################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir"
bin_dir="$scpt_dir/../zz_bin"
source "$lib_dir/common.sh" || exit 255
##########################################


# Instead of using agvtool, we'll be coding our own version of agvtool
# Why? Because agvtool does not support target-based version setting...


usage() {
	echo "syntax: $0 [--project path_to_xcodeproj] [--targets target1,target2,...] [--bump-build-version|--set-build-version new_version] [--set-marketing-version new_marketing_version] ([--force] [--commit]|[--no-commit])" >/dev/stderr
	echo "   exits with status 1 for syntax error, 2 if repo is dirty and force is not set, 3 on hagvtool error, 4 on commit error after hagvtool updated the version of the project" >/dev/stderr
	echo "   note: --help makes program exit with status 1 too" >/dev/stderr
	exit 1
}


force=0
commit=-1
hagvtool_options=()

new_build_version=
new_marketing_version=
while [ -n "$1" ]; do
	case "$1" in
		--project)
			shift
			[ -n "$1" ] || usage
			hagvtool_options=("${hagvtool_options[@]}" "--project-path=$1")
			;;
		--targets)
			shift
			[ -n "$1" ] || usage
			hagvtool_options=("${hagvtool_options[@]}" "--targets=$1")
			;;
		--bump-build-version)
			new_build_version="BUMP"
			;;
		--set-build-version)
			shift
			new_build_version="$1"
			[ -n "$new_build_version" ] || usage
			[ "$new_build_version" != "BUMP" ] || { echo "New version cannot be set to \"BUMP\""; exit 1; }
			;;
		--set-marketing-version)
			shift
			new_marketing_version="$1"
			[ -n "$new_marketing_version" ] || usage
			;;
		--force)
			force=1
			;;
		--commit)
			commit=1
			;;
		--no-commit)
			commit=0
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


if [ "$commit" = "-1" ]; then
	commit=$((1-force))
fi

test "$force" = "1" || "$lib_dir/is_repo_clean.sh" || exit 1

case "$new_build_version" in
	"BUMP")
		output="$("$bin_dir/hagvtool" "${hagvtool_options[@]}" --porcelain bump-build-number)" || exit 3
		version="$(parse_hagvtool_output "$output")" || exit 3
		test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Bump build number to \"$version\" with hagvtool" ) || exit 4
		;;
	*)
		if [ -n "$new_build_version" ]; then
			output="$("$bin_dir/hagvtool" "${hagvtool_options[@]}" --porcelain set-build-number "$new_build_version")" || exit 3
			version="$(parse_hagvtool_output "$output")" || exit 3
			test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Set build number to \"$version\" with hagvtool" ) || exit 4
		fi
		;;
esac
if [ -n "$new_marketing_version" ]; then
	output="$("$bin_dir/hagvtool" "${hagvtool_options[@]}" --porcelain set-marketing-version "$new_marketing_version")" || exit 3
	version="$(parse_hagvtool_output "$output")" || exit 3
	test "$commit" = "1" && ( "$lib_dir/is_repo_clean.sh" || git commit -am "Set marketing version to \"$version\" with hagvtool" ) || exit 4
fi
