#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_root="${1:-$repo_root/.build/app-bundle}"
app_path="$output_root/Headphone Battery Bar.app"

swift build --package-path "$repo_root" --configuration release --jobs 2 >&2
binary_dir="$(swift build --package-path "$repo_root" --configuration release --show-bin-path 2>/dev/null | tail -n 1)"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
ditto "$repo_root/Packaging/Info.plist" "$app_path/Contents/Info.plist"
ditto "$binary_dir/HeadphoneBatteryBar" "$app_path/Contents/MacOS/HeadphoneBatteryBar"
chmod 755 "$app_path/Contents/MacOS/HeadphoneBatteryBar"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
echo "$app_path"
