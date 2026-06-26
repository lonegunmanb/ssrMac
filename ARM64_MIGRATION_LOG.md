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

### T9 vendored dependency projects

- Converted `AFNetworking`, `GCDWebServer`, and `GZIP` from submodules into vendored source directories in the parent repository; `.gitmodules` now only tracks `shadowsocksr-native`.
- Updated the macOS framework targets for `AFNetworking macOS`, `GCDWebServers (Mac)`, and `GZIP` to `MACOSX_DEPLOYMENT_TARGET = 11.0`, `ARCHS = "$(ARCHS_STANDARD)"`, Debug `ONLY_ACTIVE_ARCH = YES`, and Release `ONLY_ACTIVE_ARCH = NO`.
- Removed private `netinet6/in6.h` imports from AFNetworking reachability/session sources; Xcode 26 treats that header as private outside its module.
- Validation: vendored subproject `.pbxproj` files pass `plutil -lint`.
- Validation: `xcodebuild -showBuildSettings` for the three macOS schemes reports `ARCHS = arm64 x86_64`, `MACOSX_DEPLOYMENT_TARGET = 11.0`, and Release `ONLY_ACTIVE_ARCH = NO`.
- Validation: Release arm64 builds succeeded for `AFNetworking.framework`, `GCDWebServers.framework`, and `GZIP.framework`; `lipo -archs` reported `arm64` for all three framework binaries.

### T7 ssrNative arm64 framework

- Converted `shadowsocksr-native` and all nested dependencies from submodules into vendored source directories in the parent repository.
- Removed root and nested `.gitmodules` metadata; the repository no longer requires recursive submodule checkout.
- Updated `ssrNative macOS` to `MACOSX_DEPLOYMENT_TARGET = 11.0`, `ARCHS = "$(ARCHS_STANDARD)"`, Debug `ONLY_ACTIVE_ARCH = YES`, and Release `ONLY_ACTIVE_ARCH = NO`.
- Updated vendored `libuv`, `libsodium`, and `mbedtls` macOS framework targets to the same macOS 11 / `ARCHS_STANDARD` policy.
- Removed stale `pthread-fixes.c` references from the vendored libuv Xcode project; that source file is not present in the vendored libuv revision.
- Validation: `ssrNative.xcodeproj`, `libuv.xcodeproj`, `libsodium.xcodeproj`, and `mbedtls.xcodeproj` pass `plutil -lint`.
- Validation: `xcodebuild -showBuildSettings` for `ssrNative macOS` reports `ARCHS = arm64 x86_64`, `MACOSX_DEPLOYMENT_TARGET = 11.0`, and Release `ONLY_ACTIVE_ARCH = NO`.
- Validation: Release arm64 build succeeded for `ssrNative.framework`; `lipo -archs` reported `arm64` for `ssrNative`, `libuv`, `libsodium`, and `mbedtls` framework binaries.

### T16 build script rewrite

- Replaced the stale `AppProxyCap` / `iphonesimulator` build script with a logged `xcodebuild` entry point for `ssrMac.xcodeproj`, scheme `ssrMac`, Release, and `arm64`.
- Added an optional `scripts/package-arm64-frameworks.sh` hook so T8 dependency packaging can be wired in without changing the public build entry point again.
- Updated Travis metadata from `iphonesimulator` to `macosx` and the `ssrMac` project/scheme.
- Added `scripts/package-arm64-frameworks.sh`, which packages Homebrew `libuv`, `libsodium`, `mbedtls`, and `openssl@3` `libcrypto` static libraries as framework bundles.
- Validation: `bash -n build.sh scripts/package-arm64-frameworks.sh` passed.
- Validation: the packaging script produced `libuv.framework`, `libsodium.framework`, `mbedtls.framework`, and `libcrypto.framework` in a temporary output directory; `lipo -archs` confirmed `arm64` for all four binaries.
- Pending environment validation: full `./build.sh` still requires Xcode first launch/license acceptance and the remaining dependent migration tasks.

### T8 C library arm64 frameworks

- Revalidated `scripts/package-arm64-frameworks.sh`; it packages Homebrew `libuv`, `libsodium`, `mbedtls`, and `libcrypto` framework bundles with `arm64` binaries.
- After vendoring `shadowsocksr-native`, the main build now uses the vendored Xcode subprojects for `libuv`, `libsodium`, and `mbedtls` instead of pre-copying Homebrew frameworks into `BUILT_PRODUCTS_DIR`.
- Updated `build.sh` so external Homebrew framework packaging is opt-in via `PACKAGE_EXTERNAL_FRAMEWORKS=YES`; the default build avoids overwriting Xcode-built vendored framework products.
- Validation: direct `xcodebuild` and default `./build.sh` Release arm64 builds succeeded for `ssrMac.app`.
- Validation: `lipo -archs` reported `arm64` for `ssrMac`, `ssrNative`, `libuv`, `libsodium`, `mbedtls`, `AFNetworking`, `GCDWebServers`, and `GZIP` in the built app bundle.
- Validation: `codesign --verify --deep --strict build/DerivedData/Build/Products/Release/ssrMac.app` passed.

### T13 hardened runtime preparation

- Added `ssrMac/ssrMac.entitlements` with network client/server entitlements for the status-bar app and local PAC/proxy server behavior.
- Enabled `ENABLE_HARDENED_RUNTIME = YES` for the app and helper targets.
- Set `CODE_SIGN_ENTITLEMENTS = ssrMac/ssrMac.entitlements` for the app target Debug and Release configurations.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj ssrMac/ssrMac.entitlements` passed.
- Validation: default `./build.sh` Release arm64 build succeeded with hardened runtime enabled.
- Validation: `codesign --verify --deep --strict build/DerivedData/Build/Products/Release/ssrMac.app` passed.
- Validation: `codesign -dv --verbose=4` reports `flags=0x10002(adhoc,runtime)` and `Runtime Version=26.5.0`.
- Validation: embedded app entitlements include `com.apple.security.network.client` and `com.apple.security.network.server`.
- Pending distribution validation: Developer ID signing, `DEVELOPMENT_TEAM`, `notarytool`, and stapling require Apple Developer credentials and are not completed.

### T15 AFNetworking removal

- Replaced the single GFWList download path in `SWBAppDelegate` with `NSURLSession`.
- Removed AFNetworking from the app target link/copy phases, target dependencies, project references, and runpath search paths.
- Removed the vendored `AFNetworking` source tree from the parent repository.
- Validation: focused Objective-C syntax check passed for `SWBAppDelegate.m` after the `NSURLSession` migration.
- Validation: static search confirmed no remaining app/project references to `AFNetworking`, `AFHTTPSessionManager`, or `AFHTTPResponseSerializer`.
- Validation: default `./build.sh` Release arm64 build succeeded without AFNetworking.
- Validation: built app bundle contains no `AFNetworking.framework`; `lipo -archs` reports `arm64` for `ssrMac`, `ssrNative`, `libuv`, `libsodium`, `mbedtls`, `GCDWebServers`, and `GZIP`.
- Validation: `codesign --verify --deep --strict build/DerivedData/Build/Products/Release/ssrMac.app` passed.

### T14 GitHub Actions validation workflow

- Added `.github/workflows/arm64-validation.yml` as a manual workflow for arm64 build validation on a macOS runner pool.
- Default runner label is `macos-26-xlarge`; it can be overridden at dispatch time for a dedicated/self-hosted macOS arm64 pool.
- Workflow installs Homebrew dependencies, validates optional external framework packaging, runs `./build.sh`, verifies app/framework `arm64` slices, verifies `codesign --deep --strict`, checks hardened runtime entitlements, and uploads build logs plus the app artifact.
- Runtime validation on the dedicated test machine is still pending: helper installation, node connectivity, PAC/global proxy switching, QR display, and proxy restoration on exit.

### T14 SSR link E2E validation entry

- Added an app E2E startup path driven by `--e2e-ssr-url-file` or `--e2e-ssr-url`. It imports the complete `ssr://` link through the production `ShadowsocksRunner openSSURL:` path, enables proxy mode, waits for the local SOCKS listen port, and writes a JSON result file without logging the SSR link contents.
- Updated SSR URL import behavior so the newly imported profile becomes the current profile immediately; this makes both manual import and E2E import use the selected SSR node without an extra menu selection.
- Added `scripts/e2e-youtube.sh` for VM/runtime validation. It accepts `SSR_LINK_FILE` or `SSR_LINK`, optionally installs the bundled helper with `sudo`, starts the app with the E2E arguments, reads the app result file, and verifies YouTube connectivity with `curl --socks5-hostname 127.0.0.1:<port>`.
- Added `.e2e/` to `.gitignore`; real SSR links and runtime result logs should stay local and never be committed.
- Validation: default `./build.sh` Release arm64 build succeeded after adding the E2E entry.
- Validation: `zsh -n scripts/e2e-youtube.sh` passed.
- Pending runtime validation: install Tart or use another Apple Silicon VM/test host, provide a real SSR link file, run `SSR_LINK_FILE=.e2e/ssr-link.txt scripts/e2e-youtube.sh`, and inspect `.e2e/results/` plus Console logs if the YouTube probe fails.

### T14 Parallels VM runtime validation

- Parallels VM `macOS` runs macOS 26.5.1 arm64 at `192.168.65.2`; SSH key access for user `test` is available and local deployment goes to `~/ssrmac-e2e`.
- The first VM E2E launch installed `/Library/Application Support/ssrMac/ssr_mac_sysconf` successfully (`setuid root:admin`, version `1.0.0`) but app startup failed before writing the E2E result.
- Direct VM launch showed dyld rejecting `ssrNative.framework` with Hardened Runtime library validation: `mapping process and mapped file (non-platform) have different Team IDs`.
- Added `com.apple.security.cs.disable-library-validation` to `ssrMac/ssrMac.entitlements` so the self-use ad-hoc signed app can load its bundled frameworks under Hardened Runtime. This is needed for the current ad-hoc/self-use validation path; Developer ID distribution should revisit entitlements before notarization.
- Validation: rebuilt Release arm64 app passed `plutil`, `./build.sh`, and signed entitlement checks; `codesign -d --entitlements -` includes `com.apple.security.cs.disable-library-validation`.
- Validation: deployed rebuilt app plus `scripts/e2e-youtube.sh` and local ignored `secrets` file to the Parallels VM. The E2E script installed the setuid helper, started the app directly via `Contents/MacOS/ssrMac`, imported the SSR link from file without logging it, reported `status=ready` on local SOCKS port `49164`, and `curl` through `socks5h://127.0.0.1:49164` returned HTTP `204` from `https://www.youtube.com/generate_204`.
- Validation: app termination restored VM system proxy settings; final `scutil --proxy` showed `HTTPEnable=0`, `HTTPSEnable=0`, `ProxyAutoConfigEnable=0`, and `SOCKSEnable=0`. E2E artifacts are archived locally under ignored `.e2e/results/parallels-macos-26/`.

### T11 privileged helper decision

- User selected self-use over distribution for the current migration phase and chose to keep the existing setuid helper for now.
- Xcode 26 `SMAppService` headers state that apps containing LaunchDaemons must be notarized, so the modern privileged helper route requires Developer ID signing, notarization, and test-machine admin approval.
- Current self-use builds continue to package `install_helper.sh` and `ssr_mac_sysconf`; helper installation remains part of T14 runtime validation.
- This is not a long-term macOS 28/29 guarantee. If Developer ID/notarization becomes acceptable later, create a new task for `SMAppService` + XPC privileged helper migration.

### Working tree notes

- `AGENTS.md` has been committed to the parent repository as logging guidance.
- Restored `shadowsocksr-native` nested submodule checkouts for `depends/cstl`, `depends/http-parser`, and `depends/libbloom` with `git submodule update --init --force`; recursive submodule status is clean again.