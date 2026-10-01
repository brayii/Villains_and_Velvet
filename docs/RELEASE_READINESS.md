# Release Readiness

Run the release checks from the game repository:

```powershell
python tools/verify_project_structure.py
python tools/verify_card_assets.py
python tools/verify_release_config.py
python tools/verify_release_archive.py path\to\VillainsAndVelvet-Windows.zip
```

The repository-controlled release configuration now passes its verifier.
Packaging and store-delivery checks below remain required for a release.

Do not trust the packaging process exit code alone. The LTS 2026 command-line
worker has returned success after creating an unreadable ZIP and after creating
no requested ZIP. `verify_release_archive.py` independently opens the archive,
checks CRCs and required Windows/GameMaker payloads, and prints the SHA-256 used
to identify the verified artifact.

## Repository-controlled configuration

- Android Compile SDK and Target SDK: 36.
- Android package identity: `com.borii.VillainsAndVelvet`.
- Windows publisher: `BORII Games`.
- Windows copyright: `Copyright © 2026 BORII Games. All rights reserved.`
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

1. Point GameMaker at the verified local toolchain and confirm its preferences
   still use these paths after IDE or runtime updates:
   - SDK: `D:\Android\Sdk`
   - NDK: `D:\Android\Sdk\ndk\30.0.15729638`
   - JDK: `D:\Android\Android Studio\jbr`
2. Compile Android VM and YYC from a clean build state.
3. Produce a production-signed AAB with a securely backed-up keystore.
4. Upload to Google Play Internal Testing and install the Play-delivered build.
5. Test pause/resume, audio, touch, controller input, and common phone/tablet
   landscape aspect ratios on physical devices.
6. Complete a Windows release-candidate build and Steam installation test.

The current interface is deliberately documented as supporting 16:9 through
16:10. Wider device coverage requires layout work and physical-device testing;
changing the canvas cap alone would only create unused space or distortion.

## Verified local Android toolchain

The development machine was checked on September 29, 2026. No Android install is
needed for the current GameMaker LTS 2026 requirements:

- Android Studio Quail 2 family (`261.25134.95.0-AI`) is installed at
  `D:\Android\Android Studio`.
- Android API 36 and 36.1 are installed.
- Android Build Tools 37.0.0 are installed.
- Android Platform Tools 37.0.1 are installed.
- Android NDK 30.0.15729638 is installed.
- Android Studio's bundled JBR is OpenJDK 21.0.10.

## Current build verification

On September 30, 2026, the GameMaker LTS 2026 command-line worker loaded and
serialized the current project using the configured SDK, NDK, and JBR paths.
The unattended Android compile then stopped before source generation because no
Android device was attached and this runtime attempted to query the connected
device for its target architecture. This is a build-environment limitation, not
evidence that Android compilation passed or failed for the current source.

The same current project compiled for Windows VM and entered the runner's main
loop after the hero progression test and interface changes. Repository structure,
artwork, and tool tests also pass. Android VM, Android YYC, signed AAB packaging,
Play delivery, and physical-device behavior remain unverified for this revision.

For the next Android build session, attach an authorized device with USB
debugging enabled before invoking the command-line worker, or run the build from
the GameMaker IDE with an explicit target architecture. Record the source commit
and artifact hash with the result.

The current shell also contains stale compatibility variables pointing at
`C:\Users\angel\AppData\Local\Android\Sdk` and `D:\NVPACK\android-ndk-r14b`.
Build scripts should set `ANDROID_SDK_HOME` and `ANDROID_NDK_ROOT` to the verified
D: paths when those legacy variables are consulted. `ANDROID_HOME`,
`ANDROID_SDK_ROOT`, and `ANDROID_NDK_HOME` already point to the verified installs.

## Authoritative Android references

- [GameMaker LTS 2026 required SDKs](https://github.com/YoYoGames/GameMaker-Bugs/wiki/2026.0)
- [GameMaker Android setup guide](https://github.com/YoYoGames/GameMaker-Bugs/wiki/Android-GMS2)
- [GameMaker Android packaging guide](https://gamemaker.io/en/help/articles/android-compiling-your-app)
