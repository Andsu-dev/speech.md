# Local signing

`scripts/bundle.sh` signs with the identity in `SPEECH_SIGN_IDENTITY` (default:
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

None of this is notarization: the build is not signed with an Apple Developer
ID, so a download from the browser is still blocked by Gatekeeper. The brew
cask clears the quarantine flag on install, which is why it opens on the first
click.
