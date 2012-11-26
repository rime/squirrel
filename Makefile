all: release

LIBRIME = librime/xbuild/lib/Release/librime.dylib

$(LIBRIME):
	cd librime; make -f Makefile.xcode

release: $(LIBRIME)
	xcodebuild -project Squirrel.xcodeproj -configuration Release build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Release/Squirrel.app Squirrel.app

debug: $(LIBRIME)
	xcodebuild -project Squirrel.xcodeproj -configuration Debug build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Debug/Squirrel.app Squirrel.app

install-debug:
	#rm -rf "/Library/Input Methods/Squirrel.app"
	cp -R build/Debug/Squirrel.app "/Library/Input Methods"
	"/Library/Input Methods/Squirrel.app/Contents/Resources/postflight"

install-release:
	rm -rf "/Library/Input Methods/Squirrel.app"
	cp -R build/Release/Squirrel.app "/Library/Input Methods"
	"/Library/Input Methods/Squirrel.app/Contents/Resources/postflight"

clean:
	rm -rf build
	rm build.log
