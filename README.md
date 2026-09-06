# speech.md

Voice transcription for macOS that runs entirely on your device. No server, no
account, no audio leaving your Mac.

Built on `SpeechAnalyzer` and `SpeechTranscriber` (Apple Speech), with
`ScreenCaptureKit` to capture what the other people in a call are saying.

## What it does

**Dictate** — a global hotkey in any app: hold it, speak, release, and the text
is pasted wherever your cursor is. A short tap keeps it listening until the
next tap.

**Meetings** — records a meeting on two separate channels, your microphone and
the system audio, each with its own analyzer. Both transcripts stream in live,
side by side.

**Files** — drop in an audio file and get a transcript, along with how many
times faster than real time it ran.

**Dictionary** — voice shortcuts: say "my email" and your full address comes
out.

**Markdown** — optional. An on-device model (Foundation Models) reformats the
dictation before pasting, turning spoken lists into bullets and fixing
punctuation.

## Performance

Measured on an Apple M5, macOS 26.5, `pt-BR` locale, low-latency mode. 27.7s of
audio generated with `say`, three runs.

| Measure | Result |
| --- | ---: |
| File transcription | **75× real time** (27.7s of audio in 0.37s) |
| Markdown formatting, 14 words | 0.62s (0.43–0.93) |
| Markdown formatting, 56 words | 1.02s (0.90–1.12) |

Formatting only runs when enabled, and it runs *after* transcription — it adds
latency between releasing the hotkey and the text appearing, not while you
speak.

The real-time figure measures file throughput, not the live experience. The
targets for sustained use — first partial under 300 ms, sustained lag under
600 ms — have not been measured over a long real session yet.

## Install

```sh
brew tap Andsu-dev/tap
brew trust andsu-dev/tap
brew install --cask --no-quarantine speech-md
```

`--no-quarantine` matters: the app is signed with a local certificate, not
notarized by Apple, so Gatekeeper would otherwise ask you to right-click and
Open on the first launch.

Or build it yourself, see [Build](#build).

## Requirements

- Apple Silicon
- macOS 26 or later
- Xcode 26 or later

## Build

```sh
./scripts/bundle.sh
open dist/speech.md.app
```

### Release

```sh
./scripts/release.sh
```

Builds, zips the bundle, publishes a GitHub Release and prints the `version` and
`sha256` to paste into `Casks/speech-md.rb` in the tap.

### Signing

The script signs with the identity in `SPEECH_SIGN_IDENTITY` (default:
`speech.md Local`). This matters more than it looks: macOS ties privacy
permissions to the app's signature, and an ad-hoc signature
(`codesign --sign -`) produces a new hash on every build — the system treats
each rebuild as a different app and asks for microphone, screen and
accessibility access again, every time.

To create a stable local identity, once:

```sh
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 \
  -nodes -subj "/CN=speech.md Local" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "basicConstraints=critical,CA:false"
openssl pkcs12 -export -legacy -out cert.p12 -inkey key.pem -in cert.pem \
  -passout pass:yourpassword -name "speech.md Local"
security import cert.p12 -k ~/Library/Keychains/login.keychain-db \
  -P yourpassword -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db cert.pem
```

Or export `SPEECH_SIGN_IDENTITY` with an Apple Development identity you already
have.

## Permissions

| Permission | Why |
| --- | --- |
| Microphone | Transcribe your voice |
| Screen Recording | Capture audio from the other participants |
| Accessibility | Paste dictated text into the focused app |

Screen Recording is only needed for the "Others" channel. Turn off "Áudio dos
outros participantes" in Settings and meetings run on the microphone alone,
without that permission.

## Architecture

```
Sources/SpeechMD/
├── App/          entry point
├── Speech/       SpeechPipeline, system audio capture
├── Dictation/    global dictation and text insertion
├── Meetings/     two-channel meeting recording
├── Files/        file transcription
├── Snippets/     voice shortcut dictionary
├── Formatting/   on-device Markdown pass
├── Island/       floating indicator by the notch
├── Settings/     preferences, global hotkey, permissions
└── Notetaker/    interface shell
```

Partial transcription never waits on formatting, summarization or persistence.
Those consumers receive events and can drop work when they fall behind.

## Status

Personal project, work in progress. Meetings and dictations live in memory —
closing the app discards them. Persistence is next.

The interface is in Brazilian Portuguese.

## License

MIT — see [LICENSE](LICENSE).
