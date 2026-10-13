# iOS signing & App Store upload

## Signing identities — two pieces

- **Distribution certificate** (`Apple Distribution`) — proves *who* you are. One per team, in the Keychain / managed by Xcode.
- **Provisioning profile** (`App Store` type) — ties an app ID + certificate + entitlements. For App Store, no device list.

In Xcode (Runner target → Signing & Capabilities):
- **Automatic signing** (recommended for solo/dev) — Xcode creates/refreshes the cert + profile from your Apple ID.
- **Manual signing** (recommended for CI/teams) — you provide a specific cert + profile so builds are reproducible.

## App Store Connect API key (for CI)

Use an **App Store Connect API key**, not an Apple-ID + password (which breaks under 2FA).

App Store Connect → Users and Access → Integrations → API keys. You get:
- a `.p8` private key (download once),
- a **Key ID**,
- an **Issuer ID**.

Store all three in CI secrets. fastlane and `xcrun altool`/`notarytool` all accept these.

## Build the IPA

```bash
flutter build ipa --release \
  --build-name=1.2.3 --build-number=45 \
  --export-options-plist=ios/ExportOptions.plist \
  --obfuscate --split-debug-info=build/symbols
# → build/ios/ipa/*.ipa
```

`ios/ExportOptions.plist` (App Store distribution):
```xml
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>ABCDE12345</string>
  <key>uploadSymbols</key><true/>
</dict>
```

## Upload paths

| Tool | Use |
|------|-----|
| **Transporter** (Mac app) | Manual drag-and-drop of the `.ipa` — simplest one-off. |
| **`xcrun altool` / `notarytool`** | CLI upload with the ASC API key. |
| **fastlane `deliver`/`pilot`** | CI uploads + TestFlight + metadata. |

```bash
xcrun altool --upload-app -f build/ios/ipa/App.ipa -t ios \
  --apiKey $ASC_KEY_ID --apiIssuer $ASC_ISSUER_ID
```

## Distribution flow

Uploaded builds land in **App Store Connect → TestFlight** first. Test there, then submit a build for **App Store review**.

## Common errors

- **"No profiles for 'com.acme.app' were found"** → wrong bundle ID, or manual signing without a matching App Store profile.
- **"Invalid build number / already used"** → bump `--build-number`; it must increase per upload.
- **dSYM / symbol upload missing** → set `uploadSymbols` true; for obfuscated builds also keep `build/symbols` (see `versioning.md`).
- **2FA failures in CI** → switch from Apple-ID auth to the ASC API key.
