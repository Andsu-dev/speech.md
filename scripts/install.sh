#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir=$("$project_dir/scripts/bundle.sh" | tail -1)

osascript -e 'quit app "speech.md"' 2>/dev/null || true
for _ in {1..20}; do
    pgrep -f "/Applications/speech.md.app" >/dev/null || break
    sleep 0.25
done

rm -rf "/Applications/speech.md.app"
cp -R "$app_dir" /Applications/
open "/Applications/speech.md.app"

echo "instalado $(plutil -extract CFBundleShortVersionString raw /Applications/speech.md.app/Contents/Info.plist)"
