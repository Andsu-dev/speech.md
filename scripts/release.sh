#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

version=$(plutil -extract CFBundleShortVersionString raw App/Info.plist)
app_dir=$("$project_dir/scripts/bundle.sh" | tail -1)
zip_path="$project_dir/dist/speech.md-$version.zip"
dmg_path=$("$project_dir/scripts/dmg.sh" | tail -1)

rm -f "$zip_path"
ditto -c -k --keepParent "$app_dir" "$zip_path"
# O zip é o que o cask do brew baixa; o dmg é pra quem instala na mão.
gh release create "v$version" "$zip_path" "$dmg_path" --title "v$version" --generate-notes

echo "version $version"
echo "sha256  $(shasum -a 256 "$zip_path" | awk '{print $1}')"
