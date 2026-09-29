# Release Readiness

Run the release checks from the game repository:

```powershell
python tools/verify_project_structure.py
python tools/verify_card_assets.py
python tools/verify_release_config.py
```

The release-config verifier intentionally remains red until the permanent
publisher decisions below are entered. Do not replace them with guessed values.

## Publisher decisions required

- Replace Android's placeholder `com.company.game` package identity with the
  permanent reverse-domain identifier used for the first Play app record.
- Fill the Windows company/publisher and copyright fields with the legal
  publishing identity.

## Repository-controlled configuration

- Android Compile SDK and Target SDK: 36.
- Android ARM64: enabled.
- LTS 2026 Gradle: 8.13.
- LTS 2026 Android Gradle Plugin: 8.13.0.
- Explicit Bluetooth and Internet permissions: disabled because the project
  contains no networking, Bluetooth, extension, or online-service calls.
- Android TV and Leanback declarations: disabled because the current product
  targets desktop and landscape mobile interfaces.
- Signing keys and local Android configuration are ignored by Git.
- Every Sound resource is registered in the YYP and owns an existing source
  file; obsolete `datafiles/audio` Included Files are forbidden.

## Package validation still required

Repository checks cannot replace packaging and store delivery. Before release:

1. Install the exact Android SDK, NDK, Build Tools, Platform Tools, and bundled
   OpenJDK documented for the installed GameMaker runtime.
2. Compile Android VM and YYC from a clean build state.
3. Produce a production-signed AAB with a securely backed-up keystore.
4. Upload to Google Play Internal Testing and install the Play-delivered build.
5. Test pause/resume, audio, touch, controller input, and common phone/tablet
   landscape aspect ratios on physical devices.
6. Complete a Windows release-candidate build and Steam installation test.

The current interface is deliberately documented as supporting 16:9 through
16:10. Wider device coverage requires layout work and physical-device testing;
changing the canvas cap alone would only create unused space or distortion.

## Authoritative Android references

- [GameMaker LTS 2026 required SDKs](https://github.com/YoYoGames/GameMaker-Bugs/wiki/2026.0)
- [GameMaker Android setup guide](https://github.com/YoYoGames/GameMaker-Bugs/wiki/Android-GMS2)
- [GameMaker Android packaging guide](https://gamemaker.io/en/help/articles/android-compiling-your-app)
