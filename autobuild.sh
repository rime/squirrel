make clean clean-deps

bash librime/install-plugins.sh rime/librime-sample lotem/librime-octagram hchunhui/librime-lua

git submodules update --init --recursive

export BUILD_UNIVERSAL=1

export BOOST_ROOT="$(pwd)/librime/deps/boost_1_83_0"

export CMAKE_GENERATOR=Ninja

bash librime/install-boost.sh

make librime deps

make librime install

make deps

make

make install