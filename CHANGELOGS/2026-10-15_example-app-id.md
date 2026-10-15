# Example app id -> ai.zukko.chat.sdk

## What
The example app identifier is now `ai.zukko.chat.sdk` (iOS bundle id, Android applicationId/namespace/package). iOS RunnerTests = `ai.zukko.chat.sdk.RunnerTests`. Display name stays "Zukko Chat".

## Why
Owner order: no default or old id (`uz.zukko.chat.example`) may remain.

## Files
- example/ios/Runner.xcodeproj/project.pbxproj (all 6 PRODUCT_BUNDLE_IDENTIFIER entries)
- example/android/app/build.gradle.kts (namespace, applicationId)
- example/android/app/src/main/kotlin/{uz/zukko/chat/example -> ai/zukko/chat/sdk}/MainActivity.kt (package line; old dirs removed)
