#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift test
# Keep private build-machine paths out of compiler-emitted metadata. SwiftPM's
# generated resource accessor also contains the scratch path, so use a neutral one.
scratch=$(mktemp -d /private/tmp/quotabar-build.XXXXXX)
cleanup() {
  # Only the exact directory created above may be removed, never an unset path.
  if [[ -d "$scratch" && "$scratch" == /private/tmp/quotabar-build.* ]]; then
    rm -rf -- "$scratch"
  fi
}
trap cleanup EXIT
swift build -c release --scratch-path "$scratch" \
  -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/QuotaBar" \
  -Xswiftc -file-prefix-map -Xswiftc "$PWD=/QuotaBar"
app="$scratch/package/QuotaBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist
cp "$scratch/release/QuotaBar" "$app/Contents/MacOS/QuotaBar"
cp Info.plist "$app/Contents/Info.plist"
cp LICENSE "$app/Contents/Resources/LICENSE.txt"
ditto "$scratch/release/QuotaBar_QuotaCore.bundle" "$app/Contents/Resources/QuotaBar_QuotaCore.bundle"
codesign --force --sign - --identifier io.github.ai-gene.quotabar "$app"
codesign --verify --deep --strict "$app"
# Swap only after successful signing. Never merge stale files into a new bundle.
if [[ -e dist/QuotaBar.app ]]; then
  mv dist/QuotaBar.app "$scratch/previous-QuotaBar.app"
fi
mv "$app" dist/QuotaBar.app
echo "Built dist/QuotaBar.app"
