appDir="build/Release/Squirrel.app"
entitlement="resources/Squirrel.entitlements"

allFiles=$(find "$appDir" -print)
for file in $allFiles; do
	if ! [[ -d "$file" ]]; then
		if [[ -x "$file" ]]; then
			echo "$file"
			codesign --force --entitlements "$entitlement" --options runtime --timestamp --sign "Developer ID Application: $1" "$file";
		fi;
	fi;
done;

codesign -d --entitlements --entitlements "$entitlement" --force --options runtime --timestamp --sign "Developer ID Application: $1" "$appDir";

spctl -a -vv "$appDir";
