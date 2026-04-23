---
name: squirrel-dev-test-flow
description: Run fast local development testing for SquirrelFlypy without production packaging. Use when the user mentions 开发测试, debug build, 快速重编译, 热重载, install-debug, or wants to verify changes before making a pkg release.
---

# Squirrel Dev Test Flow

## Purpose

Provide a fast iteration loop for local development testing:

- rebuild Debug app
- reinstall input method
- optionally deploy schemas and reload

Do not run packaging/notarization commands in this flow.

## Use This Skill When

- User asks for development testing instead of release packaging.
- User wants quick compile-install-verify loops.
- User mentions `make install-debug` or `scripts/dev-rebuild.sh`.

## Minimal Workflow

Run from repository root.

### 1) Prepare dependencies (if missing)

```sh
bash ./action-install.sh
```

### 2) Fast rebuild and reinstall (default)

```sh
bash scripts/dev-rebuild.sh
```

This wraps `make install-debug` and installs the Debug app directly to `/Library/Input Methods`.

### 3) Optional deploy/reload actions

```sh
# rebuild + reinstall + schema deploy
bash scripts/dev-rebuild.sh --build

# rebuild + reinstall + runtime reload
bash scripts/dev-rebuild.sh --reload

# rebuild + reinstall + deploy + reload
bash scripts/dev-rebuild.sh --build --reload
```

## Verification Checklist

- Command exits with code `0`.
- App exists at:
  - `/Library/Input Methods/SquirrelFlypy.app`, or
  - `/Library/Input Methods/Squirrel.app`.
- Target behavior change is visible in input method runtime.

## Fallback Commands

If helper script is unavailable, run directly:

```sh
make install-debug
```

Manual optional actions:

```sh
cd "/Library/Input Methods/SquirrelFlypy.app/Contents/SharedSupport"
"../MacOS/SquirrelFlypy" --build
```

```sh
"/Library/Input Methods/SquirrelFlypy.app/Contents/MacOS/SquirrelFlypy" --reload
```

## Notes

- Prefer this flow during development.
- Use package flow only for distribution verification.
