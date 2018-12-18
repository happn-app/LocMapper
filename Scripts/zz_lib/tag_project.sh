#!/bin/bash
### Lib ##################################
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir"
bin_dir="$scpt_dir/../zz_bin"
source "$lib_dir/common.sh" || exit 255
##########################################


usage() {
	echo "syntax: $0 --style style [--project-name project_name] [--skip-xcode-info] [--output-tag-name] [--force] [tree-ish]" >/dev/stderr
	echo "   style can be either:" >/dev/stderr
	echo "      - alpha build_number archive_scheme" >/dev/stderr
	echo "      - beta build_number archive_scheme" >/dev/stderr
	echo "      - release-candidate build_number archive_scheme marketing_version" >/dev/stderr
	echo "      - release source_tag marketing_version" >/dev/stderr
	echo "   if project_name is not given, it is inferred with find_project.sh" >/dev/stderr
	echo "   if tree-ish is no present, uses HEAD" >/dev/stderr
	echo "   exits with status 1 for syntax error, 2 if no projects are found (when project name is not given), 3 for git errors" >/dev/stderr
	echo "   note: --help makes program exit with status 1 too" >/dev/stderr
	exit 1
}


current_tty="$(tty)"
[ -n "$current_tty" ] || echo "warning: cannot get tty; git tag might fail (GPG might fail because pinentry would if tty access is needed to input private key password)"

tagged_commit="HEAD"
project_name=; # Default is set later if option is not set

style=
source_tag=
build_number=
archive_scheme=
marketing_version=

force=0
skip_xcode_info=0
output_tag_name=0
while [ -n "$1" ]; do
	case "$1" in
		--style)
			shift
			style="$1"
			case "$style" in
				alpha|beta)
					shift; build_number="$1"
					shift; archive_scheme="$1"
					;;
				release-candidate)
					shift; build_number="$1"
					shift; archive_scheme="$1"
					shift; marketing_version="$1"
					;;
				release)
					shift; source_tag="$1"
					shift; marketing_version="$1"
					;;
				*)
					usage
					;;
			esac
			;;
		--project-name)
			shift
			project_name="$1"
			;;
		--skip-xcode-info)
			skip_xcode_info=1
			;;
		--output-tag-name)
			output_tag_name=1
			;;
		--force)
			force=1
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
[ -n "$style" ] || usage
if [ -n "$1" ]; then tagged_commit="$1"; shift; fi
[ -z "$1" ] || usage

if [ -z "$project_name" ]; then
	project_name="$("$lib_dir/find_project.sh" --output-type basename)" || exit 2
fi
project_name_underscored="$(echo "$project_name" | sed -E 's/ /_/g')"

xcode_version_info=
if [ $skip_xcode_info -eq 0 ]; then
	xcode_version_info="


Xcode and SDK versions:

$(xcodebuild -version -sdk)"
fi

tag_name=
tag_message=
case "$style" in
	alpha)
		[ -n "$project_name" ] || usage
		[ -n "$archive_scheme" ] || usage
		echo "$build_number" | grep -qE '^[0-9]+$' || fail_with_message 1 "Invalid build number ($build_number)"
		tag_name="$project_name_underscored-${build_number}a"
		tag_message="$project_name $build_number (alpha), archived with scheme \"$archive_scheme\"$xcode_version_info"
		;;
	beta)
		[ -n "$project_name" ] || usage
		[ -n "$archive_scheme" ] || usage
		echo "$build_number" | grep -qE '^[0-9]+$' || fail_with_message 1 "Invalid build number ($build_number)"
		tag_name="$project_name_underscored-${build_number}b"
		tag_message="$project_name $build_number (beta), archived with scheme \"$archive_scheme\"$xcode_version_info"
		;;
	release-candidate)
		[ -n "$project_name" ] || usage
		[ -n "$archive_scheme" ] || usage
		echo "$build_number-$marketing_version" | grep -qE '^[0-9]+-[0-9.]+$' || fail_with_message 1 "Invalid build number ($build_number) or marketing version ($marketing_version)"
		tag_name="$project_name_underscored-$build_number"
		tag_message="$project_name $build_number, release candidate for $marketing_version, archived with scheme \"$archive_scheme\"$xcode_version_info"
		;;
	release)
		[ -n "$source_tag" ] || usage
		echo "$marketing_version" | grep -qE '^[0-9.]+$' || fail_with_message 1 "Invalid marketing version ($marketing_version)"
		tag_name="$project_name_underscored-v$marketing_version"
		tag_message="$project_name $marketing_version ($source_tag)"
		;;
esac

git_tag_flag=-s
if [ $force -ne 0 ]; then git_tag_flag="${git_tag_flag}f"; fi
GPG_TTY="$current_tty" git tag $git_tag_flag -m "$tag_message" "$tag_name" "$tagged_commit" || exit 3

if [ $output_tag_name -ne 0 ]; then echo "$tag_name"; fi
