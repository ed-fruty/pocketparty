# Google Play upload files

App: **4 Players Game Offline**  
Package: **com.frutylabs.pocketparty**  
Latest upload: **0.3.2, version code 6**
Support: **ed.fruty@gmail.com**  
Privacy policy: https://raw.githubusercontent.com/ed-fruty/pocketparty/main/PRIVACY_POLICY.md  
Source: https://github.com/ed-fruty/pocketparty

## Upload order

1. Create or open the Play Console app for this package. Use the English listing text in `listing/en-US/`.
2. Upload `bundle/com.frutylabs.pocketparty-v6.aab` to the test or release track you intend to use. Version code 6 includes the final NetPlay policy/disclosure updates, refreshed store screenshots, and aligns player fields with their finger controls and adds player-colored field borders. It includes NetPlay over local Wi-Fi. Earlier AABs were delivered separately; do not attempt to replace an already-uploaded build with the same version code.
3. Upload `graphics/app-icon-512.png` as the app icon and `graphics/feature-graphic-1024x500.png` as the feature graphic.
4. Upload screenshots from the corresponding phone, 7-inch tablet, and 10-inch tablet folders. The first three phone gameplay screenshots can be ordered Snake Clash, Pair Peek, and Let's Dance; the library screenshot may follow them.
5. Set the support email and privacy URL above. `store-settings.json` records the recommended listing values.
6. Complete Play Console's Data safety, app access, ads, content-rating, target-audience, distribution, and any testing/account-verification steps presented for your developer account. Use DATA_SAFETY.md for the build-specific guidance. These account-specific declarations are not automatically submitted by these files.

## App-content facts for the current build

- No online login or account is needed. All mini-games are accessible locally.
- No ads, in-app purchases, freeform chat, user-generated posts, or analytics. Optional NetPlay supports direct local-network gameplay without publisher-operated servers.
- Local progress contains gold, owned/equipped skins, and preferences. It stays on the device; the release manifest requests INTERNET for optional local-network gameplay.
- Data safety must be reassessed for NetPlay before uploading this version. The publisher receives no gameplay data, but optional local-network sessions transmit temporary connection information, skins, inputs and match state between devices. Review ephemeral processing and user-initiated transfer rules; do not automatically reuse the previous no-network answers. The privacy page describes the feature and voluntary email support.
- No account-deletion URL is required for the app's current local-only player seats, because the app has no account-creation system. Local progress can be erased by clearing app storage or uninstalling.
- Choose your intended audience and complete the IARC questionnaire yourself. The game includes non-graphic cartoon snake predation and obstacle elimination; there is no blood, gambling, real-money currency, or player communication. An official content rating has not been assigned by these files.

## Signing material: keep separate

The new upload key and password are in `builds/play-console-private/`, outside this upload package and outside Git. Back up that entire private directory securely. `upload-certificate.pem` is public and may be supplied to Google if requested. The private `.jks` and `signing.json` must not be uploaded to GitHub or to the store listing.

For future builds, restore the same signing material, increment the Google Play preset's version code, and run:

```sh
python3 tools/build_google_play.py
python3 tools/verify_google_play.py
python3 tools/package_google_play.py
```

Android Gradle build files and caches are generated locally. The repository does not contain a signing password or private key. A fresh checkout needs Godot 4.7.2 export templates, Android SDK, JDK 17, and your backed-up signing material.

## Verification included

The verification folder contains the decoded release manifest, Google bundletool validation, BundleConfig, signing details, and ARM64 ELF segment alignment results. Checks cover package ID, target API 36, absence of a debuggable release flag, INTERNET as the only Android permission, both ARM architectures, and 16 KB bundle/native alignment. This is structural verification; no 16 KB Android-device runtime test is claimed.

All screenshots are direct captures of the current application rendered at the stated phone/tablet layout sizes, without marketing overlays or device frames. No release was submitted to Play Console by this preparation task.

## Reference requirements

- Google Play preview assets: https://support.google.com/googleplay/android-developer/answer/9866151
- Google Play User Data policy: https://support.google.com/googleplay/android-developer/answer/10144311
- Android 16 KB pages: https://developer.android.com/guide/practices/page-sizes
- Godot Android export and signing: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html


## NetPlay update — disclosure review required

This release adds optional same-Wi-Fi multiplayer and Android INTERNET permission. The earlier no-network build declarations must be reviewed before uploading this update. Read docs/NETPLAY.md and the updated PRIVACY_POLICY.md. NetPlay exchanges temporary connection information, skins, inputs and match state directly between devices. It has no publisher backend, analytics, names or chat; transport is not end-to-end encrypted. Do not declare all transmitted data encrypted. Review Data safety collection/ephemeral processing and user-initiated sharing exceptions against Google’s current definitions.
