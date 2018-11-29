#!/bin/bash
### FL Script Header V2 ##################
set -e
[ "${0:0:1}" != "/" ] && _prefix="$(pwd)/"
scpt_dir="$_prefix$(dirname "$0")"
lib_dir="$scpt_dir/zz_lib"
ast_dir="$scpt_dir/zz_assets"
source "$lib_dir/common.sh" || exit 255
cd "$(dirname "$0")"/../ || exit 42
##########################################

if [ "$(uname)" != "Darwin" ]; then
	echo "This script should be run on macOS" >/dev/stderr
	exit 1
fi

treeish=$1
builder_image_name="locmapper-builder:latest"

cd "$ast_dir"
docker build -t "$builder_image_name" .

cd "$scpt_dir/.."
readonly BUILD_FOLDER_PATH="$(pwd)/linux_build"
docker run --rm -v "$BUILD_FOLDER_PATH":"/mnt/output" -v "$HOME/.ssh/id_rsa":"/root/.ssh/id_rsa" -v "$(pwd)/Scripts/ask_pass.sh":"/usr/local/bin/ask_pass.sh" -e SSH_ASKPASS="/usr/local/bin/ask_pass.sh" -e DISPLAY="dummy" "$builder_image_name" "git@github.com:happn-app/locmapper.git=$treeish"
