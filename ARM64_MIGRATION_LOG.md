# ARM64 Migration Log

## 2026-06-25

### T2 environment check

- Xcode app found at `/Applications/Xcode.app`; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` reports Xcode 26.5 / build 17F42.
- System `xcode-select` still points to CommandLineTools, so plain `xcodebuild` fails until `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` is run.
- Xcode license has not been accepted; `xcodebuild` prompts for license acceptance before project parsing/builds can run.
- Homebrew C libraries checked from `/opt/homebrew`; `libsodium`, `libuv`, `mbedtls`, and `openssl@3` library artifacts include `arm64` slices.

### T2 environment verified

- `xcode-select -p` now returns `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -version` reports Xcode 26.5 / build 17F42.
- `brew --prefix` returns `/opt/homebrew`.
- Required Homebrew formulas are installed: `libsodium`, `libuv`, `mbedtls`, `openssl@3`, `automake`, `autoconf`, `libtool`, `pkg-config`, and `cmake`.
- Validation: `lipo -archs` reports `arm64` for `libsodium.a`, `libuv.a`, `libmbedtls.a`, `libmbedx509.a`, `libmbedcrypto.a`, and `libcrypto.a`.

### T3 project modernization

- Updated `ssrMac.xcodeproj/project.pbxproj` to Xcode 26 project markers: `objectVersion = 77` and `LastUpgradeCheck = 1700`.
- Raised project-level `MACOSX_DEPLOYMENT_TARGET` from `10.8` to `11.0` for Debug and Release.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed no remaining `MACOSX_DEPLOYMENT_TARGET = 10.8` or `compatibilityVersion = "Xcode 3.2"` in the main project file.

### T4 arm64 build settings

- Added target-level `ARCHS = "$(ARCHS_STANDARD)"` to Debug and Release for `ssrMac` and `ssr_mac_sysconf`.
- Added target-level `ONLY_ACTIVE_ARCH = YES` for Debug and `ONLY_ACTIVE_ARCH = NO` for Release on both targets.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed no `EXCLUDED_ARCHS` or `VALID_ARCHS` settings were introduced.
- Pending environment validation: `xcodebuild -showBuildSettings` remains blocked until the Xcode license is accepted.

### T5 Intel path cleanup

- Removed dead PBX file references for `/usr/local/lib/libuv.a`, `/usr/local/lib/libsodium.a`, and `/usr/local/lib/libcrypto.a`.
- Removed those three dead `.a` entries from the Frameworks group.
- Changed the app target `HEADER_SEARCH_PATHS` and `LIBRARY_SEARCH_PATHS` from `/usr/local` to `/opt/homebrew` for Debug and Release.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed the main project file no longer contains `/usr/local`, `libuv.a`, `libsodium.a`, or `libcrypto.a` references.

### T6 iOS configuration cleanup

- Removed project-level iOS-only build settings: `iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET`, `TARGETED_DEVICE_FAMILY`, `OpenSSL-for-iPhone`, `iPhone Developer`, and iPhoneOS provisioning-profile variants.
- Set project-level Debug and Release `SDKROOT` to `macosx`.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed no remaining T6 iOS-only strings in the main project file.

### T12 ad-hoc signing

- Set `CODE_SIGN_IDENTITY = "-"` for Debug and Release on `ssrMac` and `ssr_mac_sysconf`.
- Kept existing framework `CodeSignOnCopy` settings unchanged.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed four target-level ad-hoc signing identities.
- Pending product validation: `codesign --verify --deep --strict ssrMac.app` requires a successful app build.

### T10 native QR rendering

- Replaced the QR window `WebView` outlet with an `NSImageView` and native `CIQRCodeGenerator` rendering.
- Removed `qrcode.htm`, `jquery.min.js`, and `qrcode.min.js` from the project and filesystem.
- Removed `WebKit.framework` from the project and linked `CoreImage.framework` explicitly.
- Updated screen QR scanning to avoid full proxy URL logging; logs now include only display index, payload length, and success/failure context.
- Replaced the unavailable `CGDisplayCreateImage` screen capture path with `SCScreenshotManager` on macOS 15.2+ and weak-linked `ScreenCaptureKit.framework`.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: `xmllint --noout ssrMac/QRCodeWindow.xib` passed.
- Validation: focused Objective-C syntax check passed for `SWBQRCodeWindowController.m` and `qrCodeOnScreen.m` against the Xcode 26 SDK.
- Validation: static search confirmed no remaining `WebView`, `WebKit`, old QR HTML/JS resource references, `CGDisplayCreateImage`, or full QR payload logging.
- Validation: temporary executable test generated a `256x256` QR `NSImage` for a sample `ssr://` payload.
- Pending environment validation: `ibtool` and full `xcodebuild` validation remain blocked until Xcode first launch/license acceptance is completed.

### T9 subproject dependency note

- `AFNetworking`, `GCDWebServer`, and `GZIP` are checked out at detached HEADs with upstream public HTTPS remotes.
- T9 changes should not be committed inside those submodules until a writable fork/remote strategy is chosen; otherwise the parent repository could point to submodule commits that other clones cannot fetch.

### T16 build script rewrite

- Replaced the stale `AppProxyCap` / `iphonesimulator` build script with a logged `xcodebuild` entry point for `ssrMac.xcodeproj`, scheme `ssrMac`, Release, and `arm64`.
- Added an optional `scripts/package-arm64-frameworks.sh` hook so T8 dependency packaging can be wired in without changing the public build entry point again.
- Updated Travis metadata from `iphonesimulator` to `macosx` and the `ssrMac` project/scheme.
- Added `scripts/package-arm64-frameworks.sh`, which packages Homebrew `libuv`, `libsodium`, `mbedtls`, and `openssl@3` `libcrypto` static libraries as framework bundles.
- Validation: `bash -n build.sh scripts/package-arm64-frameworks.sh` passed.
- Validation: the packaging script produced `libuv.framework`, `libsodium.framework`, `mbedtls.framework`, and `libcrypto.framework` in a temporary output directory; `lipo -archs` confirmed `arm64` for all four binaries.
- Pending environment validation: full `./build.sh` still requires Xcode first launch/license acceptance and the remaining dependent migration tasks.

### Working tree notes

- `shadowsocksr-native` was already dirty before migration edits due to dirty nested submodules: `depends/cstl`, `depends/http-parser`, and `depends/libbloom`.
- `AGENTS.md` is present but untracked and was not included in migration task commits.