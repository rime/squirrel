all: release

debug: librime squirrel-debug
release: librime squirrel

# both Debug and Relase builds of squirrel link to the Release build of librime
librime: librime-release
squirrel: squirrel-release
install: install-release

librime-debug:
	mkdir -p ../librime/xdebug
	cd ../librime/xdebug; cmake -G Xcode -DBUILD_STATIC=ON ..
	cd ../librime/xdebug; xcodebuild -project rime.xcodeproj -configuration Debug build | grep -v setenv | tee build.log
	@echo 'built librime for testing and debugging with its command line tools.'
	@echo 'CAVEAT: the Debug build of squirrel does NOT link to this target either.'

librime-release:
	mkdir -p ../librime/xbuild
	cd ../librime/xbuild; cmake -G Xcode -DBUILD_STATIC=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON ..
	cd ../librime/xbuild; xcodebuild -project rime.xcodeproj -configuration Release build | grep -v setenv | tee build.log

squirrel-release:
	xcodebuild -project Squirrel.xcodeproj -configuration Release build | grep -v setenv | tee build.log
	rm -f build/Squirrel.app
	cd build ; ln -s Release/Squirrel.app Squirrel.app

squirrel-debug:
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
