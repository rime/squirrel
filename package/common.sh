#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"

bump_version() {
    local version="$1"
    cd "${PROJECT_ROOT}"
    xcrun agvtool new-version "${version}"
}

get_app_version() {
    cd "${PROJECT_ROOT}"
    xcrun agvtool what-version | sed -n 'n;s/^[[:space:]]*\([0-9.]*\)$/\1/;p'
}

# deprecated
get_bundle_version() {
    sed -n '/CFBundleVersion/{n;s/.*<string>\(.*\)<\/string>.*/\1/;p;}' "$@"
}

match_line() {
    grep --quiet --fixed-strings "$@"
}
