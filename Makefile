.PHONY: all install librime data update_brise update_opencc_data deps release debug clean

all: release
install: install-release

LIBRIME = lib/librime.1.dylib
LIBRIME_DEPS = librime/thirdparty/lib/libmarisa.a librime/thirdparty/lib/libleveldb.a librime/thirdparty/lib/libopencc.a librime/thirdparty/lib/libyaml-cpp.a
BRISE = data/brise/default.yaml data/brise/symbols.yaml data/brise/essay.txt
OPENCC_DATA = data/opencc/TSCharacters.ocd data/opencc/TSPhrases.ocd data/opencc/t2s.json
DEPS = $(LIBRIME) $(BRISE) $(OPENCC_DATA)

LIBRIME_OUTPUT = librime/xbuild/lib/Release/librime.1.dylib
RIME_BIN_BUILD_DIR = librime/xbuild/bin/Release
RIME_BIN_DEPLOYER = rime_deployer
RIME_BIN_DICT_MANAGER = rime_dict_manager
OPENCC_DATA_OUTPUT = librime/thirdparty/data/opencc/*.*
DATA_FILES = brise/output/*.*

INSTALL_NAME_TOOL = $(shell xcrun -find install_name_tool)
INSTALL_NAME_TOOL_ARGS = -add_rpath @loader_path/../Frameworks

$(LIBRIME):
	$(MAKE) librime

$(LIBRIME_DEPS):
	$(MAKE) -C librime -f Makefile.xcode thirdparty

$(BRISE):
	$(MAKE) update_brise

$(OPENCC_DATA):
	$(MAKE) update_opencc_data

librime: $(LIBRIME_DEPS)
	$(MAKE) -C librime -f Makefile.xcode release
	cp -L $(LIBRIME_OUTPUT) $(LIBRIME)
	cp $(RIME_BIN_BUILD_DIR)/$(RIME_BIN_DEPLOYER) bin/
	cp $(RIME_BIN_BUILD_DIR)/$(RIME_BIN_DICT_MANAGER) bin/
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/$(RIME_BIN_DEPLOYER)
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/$(RIME_BIN_DICT_MANAGER)

data: update_brise update_opencc_data

update_brise:
	$(MAKE) -C brise preset
	mkdir -p data/brise
	cp $(DATA_FILES) data/brise/

update_opencc_data:
	$(MAKE) -C librime -f Makefile.xcode thirdparty/opencc
	mkdir -p data/opencc
	cp $(OPENCC_DATA_OUTPUT) data/opencc/

deps: librime data

release: $(DEPS)
	xcodebuild -project Squirrel.xcodeproj -configuration Release build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Release/Squirrel.app Squirrel.app

debug: $(DEPS)
	xcodebuild -project Squirrel.xcodeproj -configuration Debug build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Debug/Squirrel.app Squirrel.app

SQUIRREL_APP_PATH = /Library/Input Methods/Squirrel.app

install-debug:
	rm -rf "$(SQUIRREL_APP_PATH)/Contents/Frameworks"
	rm -rf "$(SQUIRREL_APP_PATH)/Contents/MacOS"
	cp -R build/Debug/Squirrel.app "/Library/Input Methods"
	"$(SQUIRREL_APP_PATH)/Contents/Resources/postflight"

install-release:
	rm -rf "$(SQUIRREL_APP_PATH)"
	cp -R build/Release/Squirrel.app "/Library/Input Methods"
	"$(SQUIRREL_APP_PATH)/Contents/Resources/postflight"

clean:
	rm -rf build > /dev/null 2>&1 || true
	rm build.log > /dev/null 2>&1 || true
	rm bin/* > /dev/null 2>&1 || true
	rm lib/* > /dev/null 2>&1 || true
	rm data/brise/* > /dev/null 2>&1 || true
	rm data/opencc/*.ocd > /dev/null 2>&1 || true
	$(MAKE) -C librime -f Makefile.xcode clean
