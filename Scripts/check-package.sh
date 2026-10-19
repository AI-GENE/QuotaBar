#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
test -f dist/QuotaBar.dmg
test -f dist/QuotaBar.zip
(
  cd dist
  shasum -a 256 -c SHA256SUMS.txt
)
check_dir=$(mktemp -d /private/tmp/quotabar-package-check.XXXXXX)
mounted=0
cleanup() {
  if [[ "$mounted" == 1 ]]; then hdiutil detach "$check_dir/mounted" -quiet || return 1; fi
  if [[ -d "$check_dir" && "$check_dir" == /private/tmp/quotabar-package-check.* ]]; then
    rm -rf -- "$check_dir"
  fi
}
trap cleanup EXIT
mkdir "$check_dir/mounted"
hdiutil attach -readonly -nobrowse -mountpoint "$check_dir/mounted" dist/QuotaBar.dmg -quiet
mounted=1
cmp Assets/QuotaBar.icns "$check_dir/mounted/.VolumeIcon.icns"
volume_flags=$(GetFileInfo -a "$check_dir/mounted")
[[ "$volume_flags" == *C* ]]
cmp INSTALL.txt "$check_dir/mounted/Read Me.txt"
test "$(readlink "$check_dir/mounted/Applications")" = /Applications
codesign --verify --deep --strict "$check_dir/mounted/QuotaBar.app"
ditto -x -k dist/QuotaBar.zip "$check_dir/extracted"
codesign --verify --deep --strict "$check_dir/extracted/QuotaBar.app"
cmp "$check_dir/mounted/QuotaBar.app/Contents/MacOS/QuotaBar" "$check_dir/extracted/QuotaBar.app/Contents/MacOS/QuotaBar"
xattr -p com.apple.ResourceFork dist/QuotaBar.dmg >/dev/null
echo 'Package names, checksums, volume icon, application signatures and local DMG custom icon passed.'
