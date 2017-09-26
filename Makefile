.PHONY: all install librime data update-brise update-opencc-data deps release debug package archive test-archive permission-check install-debug install-release clean

all: release
install: install-release

LIBRIME = lib/librime.1.dylib
LIBRIME_DEPS = librime/thirdparty/lib/libmarisa.a librime/thirdparty/lib/libleveldb.a librime/thirdparty/lib/libopencc.a librime/thirdparty/lib/libyaml-cpp.a
BRISE = bin/rime-install data/brise/default.yaml data/brise/symbols.yaml data/brise/essay.txt
OPENCC_DATA = data/opencc/TSCharacters.ocd data/opencc/TSPhrases.ocd data/opencc/t2s.json
DEPS = $(LIBRIME) $(BRISE) $(OPENCC_DATA)

LIBRIME_OUTPUT = librime/xbuild/lib/Release/librime.1.dylib
RIME_BIN_BUILD_DIR = librime/xbuild/bin/Release
RIME_BIN_DEPLOYER = rime_deployer
RIME_BIN_DICT_MANAGER = rime_dict_manager
OPENCC_DATA_OUTPUT = librime/thirdparty/data/opencc/*.*
DATA_FILES = brise/output/*.*
RIME_PACKAGE_INSTALLER = brise/rime-install

INSTALL_NAME_TOOL = $(shell xcrun -find install_name_tool)
INSTALL_NAME_TOOL_ARGS = -add_rpath @loader_path/../Frameworks

$(LIBRIME):
	$(MAKE) librime

$(LIBRIME_DEPS):
	$(MAKE) -C librime -f Makefile.xcode thirdparty

$(BRISE):
	$(MAKE) update-brise

$(OPENCC_DATA):
	$(MAKE) update-opencc-data

librime: $(LIBRIME_DEPS)
	$(MAKE) -C librime -f Makefile.xcode release
	cp -L $(LIBRIME_OUTPUT) $(LIBRIME)
	cp $(RIME_BIN_BUILD_DIR)/$(RIME_BIN_DEPLOYER) bin/
	cp $(RIME_BIN_BUILD_DIR)/$(RIME_BIN_DICT_MANAGER) bin/
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/$(RIME_BIN_DEPLOYER)
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/$(RIME_BIN_DICT_MANAGER)

data: update-brise update-opencc-data

update-brise:
	$(MAKE) -C brise minimal
	mkdir -p data/brise
	cp $(DATA_FILES) data/brise/
	cp $(RIME_PACKAGE_INSTALLER) bin/

update-opencc-data:
	$(MAKE) -C librime -f Makefile.xcode thirdparty/opencc
	mkdir -p data/opencc
	cp $(OPENCC_DATA_OUTPUT) data/opencc/

deps: librime data

release: $(DEPS)
	xcodebuild -project Squirrel.xcodeproj -configuration Release build | grep -v setenv | tee build.log

debug: $(DEPS)
	xcodebuild -project Squirrel.xcodeproj -configuration Debug build | grep -v setenv | tee build.log

package: release
	bash package/make_package

archive: package
	bash package/create_archive

test-archive: package
	testing=1 bash package/create_archive

DSTROOT = /Library/Input Methods
SQUIRREL_APP_ROOT = $(DSTROOT)/Squirrel.app

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(SQUIRREL_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: debug permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Debug/Squirrel.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" RIME_NO_PREBUILD=1 bash scripts/postinstall

install-release: release permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Release/Squirrel.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" bash scripts/postinstall

clean:
	rm -rf build > /dev/null 2>&1 || true
	rm build.log > /dev/null 2>&1 || true
	rm bin/* > /dev/null 2>&1 || true
	rm lib/* > /dev/null 2>&1 || true
	rm data/brise/* > /dev/null 2>&1 || true
	rm data/opencc/*.ocd > /dev/null 2>&1 || true
	$(MAKE) -C librime -f Makefile.xcode clean
