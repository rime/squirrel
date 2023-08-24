#!/usr/bin/env bash

current=$(git describe --tags --abbrev=0)
previous=$(git describe --always --abbrev=0 --tags ${current}^)

echo "**Change log since ${previous}:**"

git log --oneline --decorate ${previous}...${current} --pretty="format:- %h %s" | grep -v Merge
