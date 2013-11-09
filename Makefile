.PHONY: all install librime release debug clean

all: release
install: install-release

ESSAY = brise/essay.kct
LIBRIME = lib/librime.0.dylib

LIBRIME_OUTPUT = librime/xbuild/lib/Release/librime.0.dylib
RIME_DEPLOYER_OUTPUT = librime/xbuild/bin/Release/rime_deployer
RIME_DICT_MANAGER_OUTPUT = librime/xbuild/bin/Release/rime_dict_manager

$(ESSAY):
	$(MAKE) essay

$(LIBRIME):
	$(MAKE) librime

essay:
	cd brise; make essay

librime:
	cd librime; make -f Makefile.xcode
	cp -L $(LIBRIME_OUTPUT) $(LIBRIME)
	cp $(RIME_DEPLOYER_OUTPUT) bin/
	cp $(RIME_DICT_MANAGER_OUTPUT) bin/

release: $(ESSAY) $(LIBRIME)
	xcodebuild -project Squirrel.xcodeproj -configuration Release build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Release/Squirrel.app Squirrel.app

debug: $(ESSAY) $(LIBRIME)
	xcodebuild -project Squirrel.xcodeproj -configuration Debug build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Debug/Squirrel.app Squirrel.app

install-debug:
	rm -rf "/Library/Input Methods/Squirrel.app/Contents/Frameworks"
	rm -rf "/Library/Input Methods/Squirrel.app/Contents/MacOS"
	cp -R build/Debug/Squirrel.app "/Library/Input Methods"
	"/Library/Input Methods/Squirrel.app/Contents/Resources/postflight"

install-release:
	rm -rf "/Library/Input Methods/Squirrel.app"
	cp -R build/Release/Squirrel.app "/Library/Input Methods"
	"/Library/Input Methods/Squirrel.app/Contents/Resources/postflight"

clean:
	rm -rf build > /dev/null 2>&1 || true
	rm build.log > /dev/null 2>&1 || true
	rm bin/* > /dev/null 2>&1 || true
	rm lib/* > /dev/null 2>&1 || true
