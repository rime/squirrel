.PHONY: all install deps release debug

all: release
install: install-release

# Change to `xcode/dist-with-icu` if boost is linked to icu libraries.
RIME_DIST_TARGET = xcode/dist

RIME_BIN_DIR = librime/dist/bin
RIME_LIB_DIR = librime/dist/lib

RIME_LIBRARY_FILE_NAME = librime.1.dylib
RIME_LIBRARY = lib/$(RIME_LIBRARY_FILE_NAME)

RIME_DEPS = librime/thirdparty/lib/libmarisa.a \
	librime/thirdparty/lib/libleveldb.a \
	librime/thirdparty/lib/libyaml-cpp.a

DEPS_CHECK = $(RIME_LIBRARY)

INSTALL_NAME_TOOL = $(shell xcrun -find install_name_tool)
INSTALL_NAME_TOOL_ARGS = -add_rpath @loader_path/../Frameworks

.PHONY: librime copy-rime-binaries

$(RIME_LIBRARY):
	$(MAKE) librime

$(RIME_DEPS):
	$(MAKE) -C librime xcode/thirdparty

librime: $(RIME_DEPS)
	$(MAKE) -C librime $(RIME_DIST_TARGET)
	$(MAKE) copy-rime-binaries

copy-rime-binaries:
	cp -L $(RIME_LIB_DIR)/$(RIME_LIBRARY_FILE_NAME) lib/
	cp $(RIME_BIN_DIR)/rime_deployer bin/
	cp $(RIME_BIN_DIR)/rime_dict_manager bin/
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/rime_deployer
	$(INSTALL_NAME_TOOL) $(INSTALL_NAME_TOOL_ARGS) bin/rime_dict_manager

deps: librime

release: $(DEPS_CHECK)
	xcodebuild -project ThoanTaigi.xcodeproj -configuration Release build | grep -v setenv | tee build.log

debug: $(DEPS_CHECK)
	xcodebuild -project ThoanTaigi.xcodeproj -configuration Debug build | grep -v setenv | tee build.log

.PHONY: package archive sign-archive

package: release
	bash package/make_package

archive: package
	bash package/make_archive

sign-archive:
	[ -n "${checksum}" ] || (echo >&2 'ERROR: $$checksum not specified.'; false)
	bash package/make_archive

DSTROOT = /Library/Input Methods
SQUIRREL_APP_ROOT = $(DSTROOT)/ThoanTaigi.app

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(SQUIRREL_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: debug permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Debug/ThoanTaigi.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" RIME_NO_PREBUILD=1 bash scripts/postinstall

install-release: release permission-check
	rm -rf "$(SQUIRREL_APP_ROOT)"
	cp -R build/Release/ThoanTaigi.app "$(DSTROOT)"
	DSTROOT="$(DSTROOT)" bash scripts/postinstall

.PHONY: clean clean-deps

clean:
	rm -rf build > /dev/null 2>&1 || true
	rm build.log > /dev/null 2>&1 || true
	rm bin/* > /dev/null 2>&1 || true
	rm lib/* > /dev/null 2>&1 || true
	rm data/plum/* > /dev/null 2>&1 || true
	rm data/opencc/*.ocd > /dev/null 2>&1 || true

clean-deps:
	$(MAKE) -C plum clean
	$(MAKE) -C librime xcode/clean
