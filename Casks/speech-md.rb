cask "speech-md" do
  version "0.3.0"
  sha256 "d9c3b85d870dfa990273cdd78806ed84b1e4b87fe782e9de8c8a0f248ff44e47"

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
