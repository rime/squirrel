#!/bin/bash

set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

work="$(mktemp -d "${TMPDIR:-/tmp}/squirrel-localized-resources.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

resources="${work}/resources"
mkdir -p "${resources}"

distribution="${package_dir}/Distribution"
if [[ ! -f "${distribution}" ]]; then
    echo "missing Distribution: ${distribution}" >&2
    exit 1
fi
cp "${distribution}" "${resources}/Distribution"

# Copy an unlocalized conclusion.html when the tree still has one.
# productbuild prefers that file over .lproj resources, which is the regression.
if [[ -f "${package_dir}/conclusion.html" ]]; then
    cp "${package_dir}/conclusion.html" "${resources}/conclusion.html"
fi

stage_locale() {
    local locale="$1"
    local source="${package_dir}/${locale}.lproj/conclusion.html"
    if [[ ! -f "${source}" ]]; then
        echo "missing localized conclusion: ${source}" >&2
        exit 1
    fi
    mkdir -p "${resources}/${locale}.lproj"
    cp "${source}" "${resources}/${locale}.lproj/conclusion.html"
}

stage_locale en
stage_locale zh_CN
stage_locale zh_TW

pkgbuild \
    --nopayload \
    --identifier im.rime.inputmethod.Squirrel \
    --version 0.0.0 \
    "${work}/Squirrel-component.pkg"

(
    cd "${resources}"
    productbuild \
        --distribution Distribution \
        --package-path "${work}" \
        --resources . \
        "${work}/Squirrel.pkg"
)

expanded="${work}/expanded"
pkgutil --expand "${work}/Squirrel.pkg" "${expanded}"

product_resources="${expanded}/Resources"
if [[ ! -d "${product_resources}" ]]; then
    echo "product resources directory is missing: ${product_resources}" >&2
    exit 1
fi
if [[ -e "${product_resources}/conclusion.html" ]]; then
    echo "unlocalized conclusion.html is present in the product resources" >&2
    exit 1
fi

expect_conclusion() {
    local source_locale="$1"
    local product_locale="$2"
    local expected="${package_dir}/${source_locale}.lproj/conclusion.html"
    local actual="${product_resources}/${product_locale}.lproj/conclusion.html"
    if [[ ! -f "${actual}" ]]; then
        echo "missing product conclusion for ${source_locale}: ${actual}" >&2
        exit 1
    fi
    if ! cmp -s "${expected}" "${actual}"; then
        echo "conclusion contents differ for ${source_locale} (${product_locale})" >&2
        exit 1
    fi
}

# productbuild renames zh_CN.lproj to zh-Hans.lproj and zh_TW.lproj to zh-Hant.lproj.
expect_conclusion en en
expect_conclusion zh_CN zh-Hans
expect_conclusion zh_TW zh-Hant

echo "ok: localized conclusions are the only conclusion resources"
