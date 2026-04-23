---
name: squirrel-package-flow
description: Build and package Squirrel in this repository with reproducible shell commands. Use when the user mentions 打包, package, pkg, 发布, release build, or asks to verify packaging results.
---

# Squirrel Package Flow

## Purpose

Run a minimal, repeatable packaging flow for this repo and produce the installer package configured by `package/make_package`.

## Constraints

- Prefer command-line build and packaging verification.
- If the user requests a clean verification state, keep non-doc source/config files unchanged.

## Prerequisites

1. `cmake` is available (`cmake --version`).
2. Full Xcode is available via:
   - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
3. Required runtime assets exist:
   - `lib/librime.1.dylib`
   - `lib/rime-plugins/librime-lua.dylib`
   - `lib/rime-plugins/librime-octagram.dylib`
   - `lib/rime-plugins/librime-predict.dylib`
   - `Frameworks/Sparkle.framework` or equivalent package-resolved Sparkle during build

## Minimal Packaging Workflow

Run from repository root.

### 1) Prepare binary assets (if missing)

```sh
bash ./action-install.sh
```

### 2) Build Release app

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Squirrel.xcodeproj \
  -configuration Release \
  -scheme Squirrel \
  -derivedDataPath build \
  COMPILER_INDEX_STORE_ENABLE=YES \
  build
```

### 3) Build installer package

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
bash package/make_package build
```

### 4) Verify output

```sh
ls -la package/*.pkg
```

Expected output includes `package/<configured-package-name>.pkg` (the same filename reported by `pkgbuild` as `Wrote package to ...`).

## Quick Validation Checklist

- Build exits with code `0`.
- `pkgbuild` logs include `Wrote package to <configured-package-name>.pkg`.
- Final artifact exists at `package/<configured-package-name>.pkg`.

## If Build Fails

- Missing Boost headers (`boost/algorithm/string.hpp`):
  - install Boost and retry:
  ```sh
  brew install boost
  ```
- Missing librime plugin `.dylib` files:
  - rerun:
  ```sh
  bash ./action-install.sh
  ```
- `xcodebuild` points to CommandLineTools:
  - use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` prefix on build commands.
