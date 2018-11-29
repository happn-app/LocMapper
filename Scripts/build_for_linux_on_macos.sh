#!/bin/bash

set -e

if [ "$(uname)" != "Darwin" ]; then
	echo "This script should be run on macOS" >/dev/stderr
	exit 1
fi

treeish=$1
builder_image_name="locmapper-builder:latest"

cd "$(dirname "$0")"
docker build -t "$builder_image_name" .

cd ..
BUILD_FOLDER_PATH="$(pwd)/linux_build"
docker run --rm -v "$BUILD_FOLDER_PATH":"/mnt/output" -v "$HOME/.ssh/id_rsa":"/root/.ssh/id_rsa" -v "$(pwd)/Scripts/ask_pass.sh":"/usr/local/bin/ask_pass.sh" -e SSH_ASKPASS="/usr/local/bin/ask_pass.sh" -e DISPLAY="dummy" "$builder_image_name" "git@github.com:happn-app/locmapper.git=$treeish"
