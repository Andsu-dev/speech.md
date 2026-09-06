cask "speech-md" do
  version "0.3.0"
  sha256 "f39dd3921816adb769f7c0743edb62f0436371d30019743c4d43bb7ba63fc377"

  url "https://github.com/Andsu-dev/speech.md/releases/download/v#{version}/speech.md-#{version}.zip"
  name "speech.md"
  desc "On-device voice transcription for macOS"
  homepage "https://github.com/Andsu-dev/speech.md"

  depends_on macos: ">= :tahoe"

  app "speech.md.app"

  caveats <<~CAVEATS
    speech.md is signed with a local certificate, not notarized by Apple.
    Install it with --no-quarantine, or the first launch needs
    right-click, then Open.
  CAVEATS

  zap trash: "~/Library/Preferences/dev.anderson.speech-md.plist"
end
