#!/bin/bash

rime_version=1.5.3
rime_variant='rime-with-plugins'

download_archive="${rime_variant}-${rime_version}-osx.zip"
curl -LO "https://github.com/rime/librime/releases/download/${rime_version}/${download_archive}"
# CAVEAT: working copy must be clean. unzip is told not to overwrite files
# when there are conflicting files between source tree and latest release.
# this allows newer rime_api.h headers to be used with stable rime binaries in the ci build.
unzip -n "${download_archive}" -d librime

# skip building librime and opencc-data
make copy-rime-binaries copy-opencc-data

# install Rime recipes as listed in the ci project variable
rime_dir=plum/output bash plum/rime-install ${SQUIRREL_BUNDLED_RECIPES}
make copy-plum-data
