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
brew install boost
```

You can also install them with [MacPorts](https://www.macports.org/):

``` sh
port install cmake git
port install boost -no_static
```

> If you've built Boost manually instead of installing it with Homebrew or
> MacPorts, please set `BOOST_ROOT` to its top level directory in the terminal.

### Checkout the code

``` sh
git clone --recursive https://github.com/rime/squirrel.git
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
