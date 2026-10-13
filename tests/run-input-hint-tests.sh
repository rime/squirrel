#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/squirrel-input-hint-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
swiftc -swift-version 5 \
  sources/SquirrelInputHint.swift tests/InputHintTests.swift \
  -o "$test_dir/input-hint-tests"
"$test_dir/input-hint-tests"
