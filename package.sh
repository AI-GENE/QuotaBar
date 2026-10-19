#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
name=QuotaBar
./build.sh
stage=$(mktemp -d /private/tmp/quotabar-dmg.XXXXXX)
chmod 755 "$stage"
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then
    hdiutil detach "$stage/mounted" -quiet || return 1
  fi
  if [[ -d "$stage" && "$stage" == /private/tmp/quotabar-dmg.* ]]; then
    rm -rf -- "$stage"
  fi
}
trap cleanup EXIT
mkdir "$stage/contents" "$stage/mounted"
ditto dist/QuotaBar.app "$stage/contents/QuotaBar.app"
ln -s /Applications "$stage/contents/Applications"
cp INSTALL.txt "$stage/contents/Read Me.txt"
cp Assets/QuotaBar.icns "$stage/contents/.VolumeIcon.icns"
SetFile -c icnC "$stage/contents/.VolumeIcon.icns"
ditto -c -k --keepParent dist/QuotaBar.app "dist/${name}.zip"
hdiutil create -quiet -volname QuotaBar -fs HFS+ -srcfolder "$stage/contents" -format UDRW "$stage/installer-rw.dmg"
hdiutil attach -quiet -nobrowse -mountpoint "$stage/mounted" "$stage/installer-rw.dmg"
mounted=1
SetFile -a C "$stage/mounted"
hdiutil detach "$stage/mounted" -quiet
mounted=0
hdiutil convert -quiet -ov "$stage/installer-rw.dmg" -format UDZO -o "dist/${name}.dmg"
swift Scripts/set-file-icon.swift Assets/QuotaBar.icns "dist/${name}.dmg"
hdiutil verify "dist/${name}.dmg"
(
  cd dist
  shasum -a 256 "${name}.dmg" "${name}.zip" > SHA256SUMS.txt
)
echo "Packaged dist/${name}.dmg and dist/${name}.zip"
zsh Scripts/check-package.sh
