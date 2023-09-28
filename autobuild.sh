make clean clean-deps

# git submodule update --init --recursive

bash librime/install-plugins.sh rime/librime-sample lotem/librime-octagram hchunhui/librime-lua

export BUILD_UNIVERSAL=1
bash librime/install-boost.sh
export BOOST_ROOT="$(pwd)/librime/deps/boost_1_83_0"

export CMAKE_GENERATOR=Ninja
export PATH="/opt/homebrew/opt/llvm/bin:/usr/local/opt/llvm/bin:$PATH"
make -C librime ARCHS="arm64;x86_64" test
make -C librime ARCHS="arm64;x86_64" install

make deps
make ARCHS="arm64;x86_64" install
