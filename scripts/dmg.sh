#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

version=$(plutil -extract CFBundleShortVersionString raw App/Info.plist)
app_dir=$("$project_dir/scripts/bundle.sh" | tail -1)
dmg="$project_dir/dist/speech.md-$version.dmg"
volume="speech.md"

stage=$(mktemp -d)
cp -R "$app_dir" "$stage/"
ln -s /Applications "$stage/Applications"
mkdir "$stage/.background"
swift scripts/dmg-background.swift "$stage/bg.png" "$stage/bg@2x.png"
tiffutil -cathidpicheck "$stage/bg.png" "$stage/bg@2x.png" \
    -out "$stage/.background/background.tiff" >/dev/null
rm "$stage/bg.png" "$stage/bg@2x.png"
cp App/AppIcon.icns "$stage/.VolumeIcon.icns"

# Imagem gravável primeiro: o layout do Finder mora no .DS_Store do volume,
# e só dá pra escrever ele com o disco montado read-write.
work=$(mktemp -d)
hdiutil create -srcfolder "$stage" -volname "$volume" -fs HFS+ \
    -format UDRW -ov "$work/rw.dmg" >/dev/null
mount=$(hdiutil attach -nobrowse -noverify -owners on "$work/rw.dmg" |
    grep -o '/Volumes/.*' | tail -1)
SetFile -a C "$mount" 2>/dev/null || true

osascript <<APPLESCRIPT >/dev/null
tell application "Finder"
    tell disk "$volume"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 548}
        set options to the icon view options of container window
        set arrangement of options to not arranged
        set icon size of options to 128
        set text size of options to 13
        set background picture of options to POSIX file "$mount/.background/background.tiff"
        set position of item "speech.md.app" of container window to {170, 210}
        set position of item "Applications" of container window to {430, 210}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$mount" >/dev/null
rm -f "$dmg"
hdiutil convert "$work/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$dmg" >/dev/null
rm -rf "$stage" "$work"

echo "$dmg"
