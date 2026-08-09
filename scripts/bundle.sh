#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/dist/speech.md.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
mkdir -p ".cache/clang" ".cache/swiftpm"
CLANG_MODULE_CACHE_PATH="$project_dir/.cache/clang" \
SWIFTPM_CACHE_PATH="$project_dir/.cache/swiftpm" \
swift build -c release --disable-sandbox

mkdir -p "$contents_dir/MacOS"
cp ".build/release/speech-md" "$contents_dir/MacOS/speech-md"
cp "App/Info.plist" "$contents_dir/Info.plist"
# Identidade estável (certificado local auto-assinado, só desta máquina).
# Ad-hoc (--sign -) gera uma cdhash nova a cada build, e o TCC amarra
# microfone/tela/acessibilidade a ela — por isso as permissões resetavam
# a cada rebuild. Com identidade fixa, concede-se uma vez só.
signing_identity="${SPEECH_SIGN_IDENTITY:-speech.md Local}"
codesign --force --deep --sign "$signing_identity" "$app_dir"

echo "$app_dir"
