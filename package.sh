#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
version=1.0.0-preview.1
name="QuotaBar-${version}-macos-arm64"
./build.sh
stage=$(mktemp -d /private/tmp/quotabar-dmg.XXXXXX)
chmod 755 "$stage"
cleanup() {
  if [[ -d "$stage" && "$stage" == /private/tmp/quotabar-dmg.* ]]; then
    rm -rf -- "$stage"
  fi
}
trap cleanup EXIT
ditto dist/QuotaBar.app "$stage/QuotaBar.app"
ln -s /Applications "$stage/Applications"
cp INSTALL.txt "$stage/Read Me.txt"
ditto -c -k --keepParent dist/QuotaBar.app "dist/${name}.zip"
hdiutil create -quiet -ov -volname QuotaBar -srcfolder "$stage" -format UDZO "dist/${name}.dmg"
hdiutil verify "dist/${name}.dmg"
(
  cd dist
  shasum -a 256 "${name}.dmg" "${name}.zip" > SHA256SUMS.txt
)
echo "Packaged dist/${name}.dmg and dist/${name}.zip"
