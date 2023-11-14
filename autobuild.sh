make clean clean-deps

# git submodule update --init --recursive

bash librime/install-plugins.sh lotem/librime-octagram hchunhui/librime-lua rime/librime-predict

export CMAKE_GENERATOR=Ninja
export BUILD_UNIVERSAL=1
bash librime/install-boost.sh
export BOOST_ROOT="$(pwd)/librime/deps/boost_1_83_0"
make -C librime deps

# export PATH="/opt/homebrew/opt/llvm/bin:/usr/local/opt/llvm/bin:$PATH"
make -C librime

make deps
make install
