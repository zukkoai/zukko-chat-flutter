# Google Play release

## Build an AAB, not an APK

Play **requires** an Android App Bundle. APKs are rejected for new apps.

```bash
flutter build appbundle --release \
  --build-name=1.2.3 --build-number=45 \
  --obfuscate --split-debug-info=build/symbols
# → build/app/outputs/bundle/release/app-release.aab
```

APK (`flutter build apk` / `--split-per-abi`) is only for **sideloading or non-Play stores** (Amazon, Galaxy Store, direct download).

## Play App Signing — two keys

| Key | Who holds it | Purpose |
|-----|--------------|---------|
| **Upload key** | You | You sign each AAB upload with this. |
| **App signing key** | Google | Google re-signs the app that ships to devices. |

Flow: you sign the AAB with the **upload key** → Play verifies it → Play strips your signature and re-signs with the **app signing key** before delivery.

- **Losing the upload key is recoverable** — in Play Console request an upload-key reset (you register a new one; the app signing key is unchanged, so updates still install).
- **The app signing key never leaves Google** under Play App Signing — you can't lose it. (If you *opted out* and self-manage the app signing key, losing it is catastrophic — you'd have to publish a new listing.)
- Confusing the two — e.g. trying to "recover the app signing key" or signing with the wrong one — is a common, avoidable mistake.

## First upload — enrolling Play App Signing

On first release Play offers to generate/hold the app signing key while you keep the upload key. Accept it. If migrating an existing app, you may upload your existing key as the app signing key once.

## Release tracks

| Track | Use |
|-------|-----|
| Internal testing | Fastest, up to 100 testers, minutes to propagate |
| Closed testing | Named tester groups / email lists |
| Open testing | Public opt-in beta |
| Production | Live to everyone; supports staged rollout % |

Promote a build up the tracks rather than re-uploading.

## Common upload errors

- **"Version code N has already been used"** → bump `--build-number`; versionCode must strictly increase.
- **"You uploaded an APK..."** when Play wants AAB → use `flutter build appbundle`.
- **"Not signed with the upload certificate"** → wrong keystore/alias; check `key.properties` matches the registered upload key.
- **Debug-signed / unsigned** → `signingConfig` not wired into `buildTypes.release`.

## CI upload

Use `fastlane supply`, the Gradle Play Publisher plugin, or the Google Play Developer API with a **service-account JSON** (Play Console → API access). Keep that JSON in CI secrets, never in the repo.
