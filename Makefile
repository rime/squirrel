all: debug

librime:
	mkdir -p ../librime/xbuild
	cd ../librime/xbuild; cmake -G Xcode ..
	cd ../librime/xbuild; xcodebuild -project rime.xcodeproj -configuration Release build
	cd ../librime/xbuild; xcodebuild -project rime.xcodeproj -configuration Debug build

release:
	xcodebuild -project Squirrel.xcodeproj -configuration Release build
	rm -f build/Squirrel.app
	cd build ; ln -s Release/Squirrel.app Squirrel.app

debug:
	xcodebuild -project Squirrel.xcodeproj -configuration Debug build
	rm -f build/Squirrel.app
	cd build ; ln -s Debug/Squirrel.app Squirrel.app

install:
	rm -rf "/Library/Input Methods/Squirrel.app"
	cp -R build/Debug/Squirrel.app "/Library/Input Methods"

install-release:
	rm -rf "/Library/Input Methods/Squirrel.app"
	cp -R build/Release/Squirrel.app "/Library/Input Methods"

clean:
	rm -rf build


