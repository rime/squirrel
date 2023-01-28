#!/usr/bin/env bash

set -e

# export BUILD_UNIVERSAL=1

# preinstall
./action-install.sh

# build dependencies
# make deps

# build Squirrel
make package

echo 'Installer package:'
find . -type f -name "*.pkg"
