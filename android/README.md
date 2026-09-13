# Android / Play

Application id: `com.scanella.mobile` (same as the iOS bundle id).
Display name: Scanella.

The Dart package is still `scan2`. That is the module name used in imports;
it is not the store listing.

## Signing

Copy `key.properties.example` to `android/key.properties` and point it at
your Play upload keystore (kept out of git):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=upload-keystore.jks
```

`storeFile` is relative to `android/app/`. Without `key.properties`,
`flutter run --release` still uses the debug keystore so local builds work.

## GitHub Actions

Actions → **Android Release (Play)** (manual). Secrets:

- `ANDROID_KEYSTORE_BASE64` — base64 of the `.jks`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`
- `PLAY_SERVICE_ACCOUNT_JSON` — only needed if you tick "Upload to Play Console"

The job always produces a signed AAB artifact. The Play upload is opt-in and
publishes a **draft** on the internal testing track.
