# Flutter Flavors + Fastlane + GitHub Actions — Claude Instructions

You are a senior Flutter engineer setting up build flavors and CI/CD. This is an **opt-in infrastructure pass**, invoked only when requested — not part of scaffolding a new project and not part of any feature's "done". Standard: **two flavors — `dev` and `prod`.** Primary target is **Android** (Firebase App Distribution for dev, Play Store bundle for prod); an iOS note is included at the end.

> **Auth uses a service account JSON — never `firebase login:ci` tokens.** Token auth is deprecated and may stop working. CI authenticates via a Google Cloud service account key with the **Firebase App Distribution Admin** role, located through `GOOGLE_APPLICATION_CREDENTIALS` (ADC) or passed to the Fastlane action directly.

---

## What this sets up

1. **Flavors** — `dev` and `prod` with separate `applicationId`, app name, and entry point.
2. **Fastlane** — lanes: `dev` (build + distribute to Firebase App Distribution) and `prod` (build a signed release bundle).
3. **GitHub Actions** — a workflow that builds and distributes the `dev` flavor on push, using repo secrets for signing and Firebase auth.

---

## 1. Flavors

### Dart entry points

Two thin entry points wrap a shared `mainCommon()`:

```dart
// lib/main_dev.dart
import 'core/config/flavor_config.dart';
import 'bootstrap.dart';

void main() {
  FlavorConfig.set(Flavor.dev, apiBaseUrl: 'https://dev.api.example.com');
  bootstrap();
}
```

```dart
// lib/main_prod.dart
import 'core/config/flavor_config.dart';
import 'bootstrap.dart';

void main() {
  FlavorConfig.set(Flavor.prod, apiBaseUrl: 'https://api.example.com');
  bootstrap();
}
```

`bootstrap()` holds the shared startup (the existing `main.dart` body: bindings, EasyLocalization, Firebase, service locator, `runApp`). `main.dart` is no longer the launch target.

### FlavorConfig

```dart
// lib/core/config/flavor_config.dart
enum Flavor { dev, prod }

class FlavorConfig {
  static late final Flavor flavor;
  static late final String apiBaseUrl;

  static void set(Flavor f, {required String apiBaseUrl}) {
    FlavorConfig.flavor = f;
    FlavorConfig.apiBaseUrl = apiBaseUrl;
  }

  static bool get isDev => flavor == Flavor.dev;
  static String get appName => isDev ? 'MyApp Dev' : 'MyApp';
}
```

### Android — `android/app/build.gradle`

```groovy
android {
    // ...
    flavorDimensions "env"

    productFlavors {
        dev {
            dimension "env"
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "MyApp Dev"
        }
        prod {
            dimension "env"
            resValue "string", "app_name", "MyApp"
        }
    }
}
```

In `AndroidManifest.xml`, reference the flavor-driven name:

```xml
<application android:label="@string/app_name" ... >
```

> Newer Flutter projects use the Kotlin DSL (`build.gradle.kts`) — translate the `productFlavors` block to Kotlin syntax if the project uses it.

### Commands

```bash
# Run
flutter run --flavor dev  -t lib/main_dev.dart
flutter run --flavor prod -t lib/main_prod.dart

# Build
flutter build apk        --release --flavor dev  -t lib/main_dev.dart
flutter build appbundle  --release --flavor prod -t lib/main_prod.dart
```

---

## 2. Signing

Create `android/key.properties` (gitignored — never commit):

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=upload-keystore.jks
```

Wire it in `android/app/build.gradle` above `android { }`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release { signingConfig signingConfigs.release }
}
```

---

## 3. Fastlane

`android/Gemfile`:

```ruby
source "https://rubygems.org"
gem "fastlane"
```

Install the plugin once: `fastlane add_plugin firebase_app_distribution`

`android/fastlane/Appfile`:

```ruby
json_key_file("")           # not used for App Distribution
package_name("com.example.myapp")
```

`android/fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  desc "Build dev and distribute to Firebase App Distribution"
  lane :dev do
    sh("flutter build apk --release --flavor dev -t lib/main_dev.dart")

    firebase_app_distribution(
      app: ENV["FIREBASE_APP_ID_DEV"],
      service_credentials_file: ENV["GOOGLE_APPLICATION_CREDENTIALS"],
      android_artifact_type: "APK",
      android_artifact_path: "../build/app/outputs/flutter-apk/app-dev-release.apk",
      groups: "testers",
      release_notes: "CI build #{ENV['GITHUB_RUN_NUMBER'] || 'local'}"
    )
  end

  desc "Build signed prod app bundle"
  lane :prod do
    sh("flutter build appbundle --release --flavor prod -t lib/main_prod.dart")
    # Add upload_to_play_store here once the Play Console service account is set up.
  end
end
```

> Auth: the `service_credentials_file` points at the service account JSON. Locally you can instead run `export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/key.json`. Do **not** use `firebase_token` — it is deprecated.

Run locally: `cd android && bundle exec fastlane dev`

---

## 4. GitHub Actions

`.github/workflows/distribute_dev.yml`:

```yaml
name: Distribute Dev

on:
  push:
    branches: [develop]
  workflow_dispatch:

jobs:
  build-distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.2"
          bundler-cache: true
          working-directory: android

      - name: Restore keystore
        run: echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/upload-keystore.jks

      - name: Create key.properties
        run: |
          cat > android/key.properties <<EOF
          storePassword=${{ secrets.KEYSTORE_PASSWORD }}
          keyPassword=${{ secrets.KEY_PASSWORD }}
          keyAlias=${{ secrets.KEY_ALIAS }}
          storeFile=upload-keystore.jks
          EOF

      - name: Restore service account
        run: echo '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}' > android/firebase-service-account.json

      - name: flutter pub get
        run: flutter pub get

      - name: Fastlane dev
        working-directory: android
        env:
          GOOGLE_APPLICATION_CREDENTIALS: ${{ github.workspace }}/android/firebase-service-account.json
          FIREBASE_APP_ID_DEV: ${{ secrets.FIREBASE_APP_ID_DEV }}
        run: bundle exec fastlane dev
```

---

## 5. Required GitHub Secrets

| Secret | What it is |
|--------|-----------|
| `ANDROID_KEYSTORE_BASE64` | Upload keystore `.jks`, base64-encoded (`base64 -w0 upload-keystore.jks`) |
| `KEYSTORE_PASSWORD` | Keystore store password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias |
| `FIREBASE_SERVICE_ACCOUNT` | Full service account JSON contents (App Distribution Admin role) |
| `FIREBASE_APP_ID_DEV` | The dev flavor's Firebase Android App ID (`1:1234:android:abcd`) |

> The `FIREBASE_APP_ID_DEV` must be the app whose package matches the dev suffix (`...myapp.dev`) — register a separate Android app in Firebase for the dev flavor, or App Distribution returns a 404.

---

## 6. iOS note (if needed later)

iOS flavors use **schemes + build configurations** (Debug-dev / Release-dev / Debug-prod / Release-prod) plus per-flavor `xcconfig` files, set up in Xcode — heavier than Android. Fastlane distributes the `.ipa` with the same `firebase_app_distribution` action and the same service account. Add only when you target iOS; the Android path above is self-sufficient.

---

## Pre-Delivery Checklist

- [ ] `main_dev.dart` / `main_prod.dart` entry points + shared `bootstrap()`
- [ ] `FlavorConfig` with `dev`/`prod` and per-flavor base URL + app name
- [ ] Android `productFlavors` (dev suffix `.dev`) and flavor-driven app name
- [ ] Signing wired from `key.properties` (gitignored); keystore not committed
- [ ] `Gemfile` + `firebase_app_distribution` plugin; `dev` and `prod` lanes
- [ ] Fastlane auth via `service_credentials_file` / `GOOGLE_APPLICATION_CREDENTIALS` — **no** `firebase_token`
- [ ] Workflow restores keystore, `key.properties`, and service account from secrets
- [ ] Separate Firebase Android app registered for the dev package
- [ ] All six secrets present in the repo
- [ ] `flutter analyze` clean; local `bundle exec fastlane dev` succeeds before relying on CI
