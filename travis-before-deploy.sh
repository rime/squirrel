#!/bin/bash
get_app_version() {
    sed -n '/CFBundleVersion/{n;s/.*<string>\(.*\)<\/string>.*/\1/;p;}' $@
}
app_version="$(get_app_version 'Info.plist')"
git_hash="$(git rev-parse HEAD | cut -c -7)"
built_archive="package/archives/Squirrel-${app_version}.zip"
upload_archive="package/archives/Squirrel-${app_version}+git${git_hash}.zip"
mv "${built_archive}" "${upload_archive}"
sed -i '.bak' "{
  s/{{app_version}}/${app_version}/g
  s/{{git_hash}}/${git_hash}/g
}" travis-deploy-package.json
