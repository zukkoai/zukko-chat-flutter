# Android signing (Kotlin DSL)

Current `flutter create` generates `build.gradle.kts` (Kotlin DSL) and `settings.gradle.kts`. Configure release signing there — **not** in a legacy Groovy `build.gradle`.

## Contents
1. [Generate an upload keystore](#1-generate-an-upload-keystore)
2. [key.properties (NEVER commit)](#2-keyproperties-never-commit)
3. [build.gradle.kts](#3-buildgradlekts)
4. [CI without a properties file](#4-ci-without-a-properties-file)
5. [Verify](#verify)

## 1. Generate an upload keystore

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store the `.jks` **outside** the repo (e.g. `~/`). This is your **upload key**.

## 2. key.properties (NEVER commit)

`android/key.properties`:
```properties
storePassword=••••••
keyPassword=••••••
keyAlias=upload
storeFile=/Users/you/upload-keystore.jks
```

Add to `.gitignore`:
```gitignore
android/key.properties
**/*.jks
**/*.keystore
```

Committing either file is the single worst release-security mistake — anyone with the keystore can sign apps as you.

## 3. build.gradle.kts

```kotlin
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.acme.app"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.acme.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode      // from pubspec +N
        versionName = flutter.versionName       // from pubspec version
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

Key differences from Groovy (the common AI mistake):
- `import java.util.Properties` / `java.io.FileInputStream` at the top — required in Kotlin DSL.
- `create("release")` not `release { }`; `getByName("release")` not bare `release`.
- `=` assignments (`keyAlias = ...`), casts (`as String?`), `isMinifyEnabled` not `minifyEnabled`.

## 4. CI without a properties file

In CI, base64-decode the keystore from a secret and read passwords from env instead of `key.properties`:

```kotlin
storeFile = System.getenv("KEYSTORE_PATH")?.let { file(it) } ?: ...
storePassword = System.getenv("STORE_PASSWORD") ?: keystoreProperties["storePassword"] as String?
```

## Verify

```bash
flutter build appbundle --release
# build/app/outputs/bundle/release/app-release.aab — confirm it's signed, not debug
```
