# How to Rime with Squirrel

> Instructions to build Squirrel - the Rime frontend for Mac OS X

## Build Squirrel from Scratch

### Prerequisites

You should already have installed **Xcode with Command Line Tools**.

Install dependencies with [Homebrew](http://mxcl.github.com/homebrew/):

``` sh
# dev tools:
brew install cmake
brew install git

# libraries:
brew install boost
```

> If you've built Boost manually instead of Homebrewing it, set `BOOST_ROOT` to its top level directory in the terminal.

### Checkout the code

``` sh
git clone git@github.com:rime/squirrel.git
# for brise & librime
cd squirrel
git submodule update --init
```

### Build dependencies

Build librime's dependencies:

``` sh
make -C librime -f Makefile.xcode thirdparty
```

> Note: you can also `brew install` the dependent libraries instead of building them with the above.

Then build librime and data files that Squirrel depends on:

``` sh
make deps
```

### Build Squirrel

``` sh
make
# or:
#make debug
```

## Install it on your Mac

Once built, you can install and try it live:

``` sh
sudo make install
# or:
#sudo make install-debug
```

That's it. Thanks for riming with Squirrel.
