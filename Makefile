.PHONY: all install librime release debug clean

all: release
install: install-release

ESSAY = brise/essay.kct
LIBRIME = librime/xbuild/lib/Release/librime.dylib

$(ESSAY):
	cd brise; make essay

essay:
	cd brise; make essay

$(LIBRIME):
	cd librime; make -f Makefile.xcode

librime:
	cd librime; make -f Makefile.xcode

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
	rm -rf build
	rm build.log
