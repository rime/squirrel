make clean clean-deps

bash librime/install-plugins.sh rime/librime-sample lotem/librime-octagram hchunhui/librime-lua

git submodules update --init --recursive

export BUILD_UNIVERSAL=1

make -C librime xcode/deps/boost

export BOOST_ROOT="$(pwd)/librime/deps/boost_1_81_0"

export BUILD_UNIVERSAL=1

make deps

make

make install