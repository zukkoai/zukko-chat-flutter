# Signing secrets — base64 in, decode at runtime

## Contents
- [1. The rule](#1-the-rule)
- [2. Encode locally](#2-encode-locally)
- [3. Decode in CI](#3-decode-in-ci)
- [4. iOS App Store Connect key](#4-ios-app-store-connect-key)
- [5. .gitignore](#5-gitignore)

## 1. The rule

Never commit keystores, `key.properties`, service-account JSON, or App Store Connect `.p8` keys. Store each as a **base64-encoded CI secret**, decode it to a file during the job, and delete it after. Committing any of these is the top CI security mistake.

## 2. Encode locally

```bash
base64 -i upload.jks            | pbcopy   # macOS → paste into KEYSTORE_BASE64 secret
base64 -i AuthKey_ABC123.p8     | pbcopy   # → ASC_KEY_BASE64
base64 -i play-service-account.json | pbcopy  # → PLAY_JSON_BASE64
# Linux: base64 -w0 file
```
Add each to the CI provider's encrypted secrets (GitHub: Settings → Secrets → Actions). Also store plaintext passwords (`STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`) as separate secrets.

## 3. Decode in CI

```yaml
- name: Restore Android signing
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/upload.jks
    cat > android/key.properties <<EOF
    storeFile=upload.jks
    storePassword=${{ secrets.STORE_PASSWORD }}
    keyAlias=${{ secrets.KEY_ALIAS }}
    keyPassword=${{ secrets.KEY_PASSWORD }}
    EOF
```
- Write decoded files **outside** version control paths or to gitignored locations.
- Secrets are masked in logs — but don't `echo` a decoded secret yourself.

## 4. iOS App Store Connect key

```yaml
- name: Restore ASC API key
  run: |
    mkdir -p ~/private_keys
    echo "${{ secrets.ASC_KEY_BASE64 }}" | base64 -d > ~/private_keys/AuthKey_${{ secrets.ASC_KEY_ID }}.p8
  # fastlane reads key_id / issuer_id / key_filepath (see fastlane.md)
```
Use the **API key** (`.p8` + `ASC_KEY_ID` + `ASC_ISSUER_ID`) — not an Apple-ID + password, which fails under 2FA.

## 5. .gitignore

Ensure these never enter VCS:
```
android/key.properties
android/app/*.jks
android/app/*.keystore
ios/private_keys/
**/AuthKey_*.p8
**/play-service-account*.json
```
Cross-ref `release` for the local signing setup these secrets mirror.
