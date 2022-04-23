#!/usr/bin/env bash

# export BUILD_UNIVERSAL=1

# preinstall
./action-install.sh

# build dependencies
# make deps

# build Squirrel
make

# debug only for finding pkg path
find . -type f  -name "*.pkg"
