# FitForge Play Store Release Guide

## What is already prepared

- Branded launcher icon assets live in `assets/branding/`.
- Android launcher resources now include adaptive icons for modern devices.
- Release signing is wired to `android/key.properties` when you add your keystore.
- The Android build is set up to produce a release bundle once signing is configured.
- The Android package name is now set to `com.fitforge.app`.
- Android Firebase config in the repo is aligned to the `com.fitforge.app` app id.
- Exercise-library download progress now uses a stable total size for the full image pack instead of a moving estimate.

## Remaining manual steps

1. Create an upload keystore and save it outside version control.
2. Copy `android/key.properties.example` to `android/key.properties` and fill in the real values.
3. In Firebase, make sure the Android app `com.fitforge.app` has the SHA-1 and SHA-256 from your upload keystore.
4. Verify `android/app/google-services.json` still contains a `com.fitforge.app` client before each release.
5. If you later decide to align iOS/macOS bundle IDs too, regenerate their Firebase files after that separate bundle-id change.
6. Publish a public privacy policy URL in the Play Console. The in-app screen is useful, but Google Play still expects a hosted URL.
7. Prepare Play Store listing assets:
   - 512 x 512 icon: `assets/branding/fitforge_playstore_icon_512.png`
   - phone screenshots
   - short description
   - full description
   - support email
   - privacy policy URL

## Build commands

After the keystore is configured:

```powershell
flutter build appbundle --release
```

The output bundle will be created at:

`build\app\outputs\bundle\release\app-release.aab`

## Recommended before upload

1. Run a release build on a real Android device.
2. Verify Google Sign-In works with the new Android package and release SHA.
3. Verify notifications still work after reinstall.
4. Check account deletion and privacy policy flows from the Profile screen.
