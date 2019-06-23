# How to Rime with Squirrel

> Instructions to build Squirrel - the Rime frontend for macOS

## Manually build and install Squirrel

### Prerequisites

If you haven't already got the Xcode toolchain, install **Xcode Command Line Tools**:

``` sh
xcode-select --install
```

Install dependencies with [Homebrew](http://brew.sh/):

Optional: set the [USTC mirror](https://lug.ustc.edu.cn/wiki/mirrors/help/brew.git) to speed up the `brew install` process in mainland China.

``` sh
# dev tools:
brew install cmake
brew install git

# libraries:
brew install boost@1.60
brew link --force boost@1.60
```

> **Note:**
>
> Starting from version 1.68, homebrewed `boost` libraries depends on `icu4c`,
> which is not provided by macOS.
>
> librime's make target `xcode/{debug,release,dist}-with-icu` links to ICU libraries
> but the built app cannot run on machines without ICU libraries installed.
>
> To make the build portable, either install an earlier version of `boost` via
> homebrew, or build from source with bootstrap option `--without-icu`.

You can also install them with [MacPorts](https://www.macports.org/):

``` sh
port install cmake git
port install boost -no_static
```

> If you've built Boost manually instead of installing it with Homebrew or
> MacPorts, please set shell variable `BOOST_ROOT` to its top level directory.

### Checkout the code

``` sh
git clone --recursive https://github.com/rime/squirrel.git

cd squirrel
```

Optionally, checkout Rime plugins (a list of GitHub repo slugs):

``` sh
bash librime/install-plugins.sh rime/librime-sample # ...
```

### Build dependencies

Build librime, dependent third-party libraries and data files:

``` sh
make deps
```

### Build Squirrel

``` sh
make
```

## Install it on your Mac

Once built, you can install and try it live:

``` sh
sudo make install
```

That's it. Thanks for riming with Squirrel.
