#!/bin/bash

get_app_version() {
    sed -n '/CFBundleVersion/{n;s/.*<string>\(.*\)<\/string>.*/\1/;p;}' $@
}
app_version="$(get_app_version 'Info.plist')"
version_name="${app_version}"

if [[ -n "${TRAVIS_TAG}" ]]
then
    package_name='release'
    version_name="${TRAVIS_TAG}"
    version_desc="鼠鬚管 ${version_name}"
    publish=false
    sed "{
        s/{{package_name}}/${package_name}/g
        s/{{version_name}}/${version_name}/g
        s/{{version_desc}}/${version_desc}/g
        s/{{publish}}/${publish}/g
    }" travis-deploy-package.json.template > travis-deploy-package-release.json
else
    package_name='testing'
    git_hash="$(git rev-parse HEAD | cut -c -7)"
    version_name="${app_version}+git${git_hash}"
    version_desc="鼠鬚管測試版 ${version_name}"
    publish=true
    sed "{
        s/{{package_name}}/${package_name}/g
        s/{{version_name}}/${version_name}/g
        s/{{version_desc}}/${version_desc}/g
        s/{{publish}}/${publish}/g
    }" travis-deploy-package.json.template > travis-deploy-package-testing.json
fi

built_archive="package/archives/Squirrel-${app_version}.zip"
upload_archive="package/archives/Squirrel-${version_name}.zip"
if [[ "${built_archive}" != "${upload_archive}" ]]
then
    mv "${built_archive}" "${upload_archive}"
fi
