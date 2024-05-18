appDir="build/Release/Squirrel.app"
entitlement="resources/Squirrel.entitlements"

codesign --deep --force --options runtime --timestamp --sign "Developer ID Application: $1" --entitlements "$entitlement" --verbose "$appDir";

spctl -a -vv "$appDir";
