#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
install_root="${HEADPHONE_BATTERY_INSTALL_DIR:-/Applications}"
if [[ ! -w "$install_root" ]]; then
    install_root="$HOME/Applications"
    mkdir -p "$install_root"
fi
destination="$install_root/Headphone Battery Bar.app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
build_root="$(mktemp -d)"
backup_root="$(mktemp -d)"
previous_app="$backup_root/Headphone Battery Bar.app"
replaced=false
complete=false

cleanup() {
    local status=$?
    trap - EXIT
    if [[ "$complete" != true && "$replaced" == true ]]; then
        if [[ -e "$destination" ]]; then
            mv "$destination" "$backup_root/Failed Headphone Battery Bar.app"
        fi
        if [[ -e "$previous_app" ]]; then
            mv "$previous_app" "$destination"
            "$lsregister" -f "$destination" >/dev/null 2>&1 || true
            open "$destination" || true
        fi
    fi
    rm -rf "$build_root" "$backup_root"
    exit "$status"
}
trap cleanup EXIT

built_app="$("$repo_root/Scripts/build-app.sh" "$build_root")"
# Kill only this app's executable, including a copy launched from the development build.
pkill -x HeadphoneBatteryBar >/dev/null 2>&1 || true
if [[ -e "$destination" ]]; then
    mv "$destination" "$previous_app"
fi
replaced=true
ditto "$built_app" "$destination"
codesign --verify --deep --strict "$destination"
"$lsregister" -f "$destination" >/dev/null
open "$destination"
complete=true
echo "$destination"
