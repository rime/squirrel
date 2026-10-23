#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Requires the normal Squirrel build dependencies and an active macOS display.
mkdir -p build/tests
xcrun swiftc -swift-version 5 -enable-bare-slash-regex -target "$(uname -m)-apple-macos13.0" \
  -import-objc-header sources/Squirrel-Bridging-Header.h \
  -I librime/include -I librime/src -L lib -l rime.1 \
  -Xlinker -rpath -Xlinker "$PWD/lib" \
  sources/BridgingFunctions.swift sources/MacOSKeyCodes.swift sources/SquirrelConfig.swift \
  sources/SquirrelTheme.swift sources/SquirrelView.swift sources/SquirrelPanel.swift \
  tests/vertical-auto-reverse.swift -o build/tests/vertical-auto-reverse
build/tests/vertical-auto-reverse
