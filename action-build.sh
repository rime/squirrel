#!/usr/bin/env bash

set -e

target="${1:-release}"

export ARCHS='arm64 x86_64'
export BUILD_UNIVERSAL=1

export SQUIRREL_BUNDLED_RECIPES='
  lotem/rime-octagram-data
  lotem/rime-octagram-data@hant
'

# preinstall
./action-install.sh

# build dependencies
# make deps

# build Squirrel
make "${target}"

echo 'Installer package:'
find package -type f -name '*.pkg' -or -name '*.zip'
