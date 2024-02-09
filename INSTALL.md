# How to Rime with Squirrel

> Instructions to build Squirrel - the Rime frontend for macOS

## Manually build and install Squirrel

### Prerequisites

Install **Xcode 12.2** or above from App Store, to build Squirrel as a Universal
app. The minimum required version is *Xcode 10* to build for `x86_64` only.

Install **cmake**.

Download from https://cmake.org/download/

or install from [Homebrew](http://brew.sh/):

``` sh
brew install cmake
```

or install from [MacPorts](https://www.macports.org/):

``` sh
port install cmake
```

### Checkout the code

``` sh
git clone --recursive https://github.com/rime/squirrel.git

cd squirrel
```

Optionally, checkout Rime plugins (a list of GitHub repo slugs):

``` sh
bash librime/install-plugins.sh rime/librime-sample # ...
```

Popular plugins include [librime-lua](https://github.com/hchunhui/librime-lua) and [librime-octagram](https://github.com/lotem/librime-octagram)

### Shortcut: get the latest librime release

You have the option to skip the following two sections - building Boost and
librime, by downloading the latest librime binary from GitHub releases.

``` sh
bash ./action-install.sh
```

When this is done, you may move on to [Build Squirrel](#build-squirrel).

### Install Boost C++ libraries

Choose one of the following options.

**Option:** Download and install from source.

``` sh
export BUILD_UNIVERSAL=1

bash librime/install-boost.sh

export BOOST_ROOT="$(pwd)/librime/deps/boost-1.84.0"
```

Let's set `BUILD_UNIVERSAL` to tell `make` that we are building Boost as
universal macOS binaries. Skip this if building only for the native architecture.

After Boost source code is downloaded and a few compiled libraries are built,
be sure to set shell variable `BOOST_ROOT` to its top level directory as above.

You may also set `BOOST_ROOT` to an existing Boost source tree before this step.

**Option:** Install the current version form Homebrew:

``` sh
brew install boost
```

**Note:** with this option, the built Squirrel.app is not portable because it
links to locally installed libraries from Homebrew.

Learn more about the implications of this at
https://github.com/rime/librime/blob/master/README-mac.md#install-boost-c-libraries

**Option:** Install from [MacPorts](https://www.macports.org/):

``` sh
port install boost -no_static
```

### Build Squirrel

* Make sure you have updated all the dependencies. If you cloned squirrel with the command in this guide, you've already done it. But if not, this command will update submodules.

```
git submodule update --init --recursive
```

* With all dependencies ready, build `Squirrel.app`:

``` sh
make
```

To build only for the native architecture, and/or specify the lowest supported macOS version, pass variable `ARCHS` and/or `MACOSX_DEPLOYMENT_TARGET` to `make`:

``` sh
# for Universal macOS App
make ARCHS='arm64 x86_64'

# for ARM macOS App
make ARCHS='arm64'
```

## Install it on your Mac

## Make Package

Just add `package` after `make`

```
make package ARCHS='arm64'
```

Define or echo `DEV_ID` to automatically handle code signing and [notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) (Apple Developer ID needed)

To make this work, you need a `Developer ID Installer: (your name/org)` and set your name/org as `DEV_ID` env variable. 

To make notarization work, you also need to save your credential under the same name as above.

```
xcrun notarytool store-credentials 'your name/org'
```

You **don't** need to define `DEV_ID` if you don't intend to distribute the package.

## Directly Install

**You might need to precede with sudo, and without a logout, the App might not work properly. Direct install is not very recommended.**

Once built, you can install and try it live on your Mac computer:

``` sh
# Squirrel as a Universal app
make install

# for Intel-based Mac only
make ARCHS='x86_64' install
```

That's it, a verbal journal. Thanks for riming with Squirrel.
