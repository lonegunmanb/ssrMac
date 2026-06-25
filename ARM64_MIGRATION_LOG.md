# ARM64 Migration Log

## 2026-06-25

### T2 environment check

- Xcode app found at `/Applications/Xcode.app`; `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version` reports Xcode 26.5 / build 17F42.
- System `xcode-select` still points to CommandLineTools, so plain `xcodebuild` fails until `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` is run.
- Xcode license has not been accepted; `xcodebuild` prompts for license acceptance before project parsing/builds can run.
- Homebrew C libraries checked from `/opt/homebrew`; `libsodium`, `libuv`, `mbedtls`, and `openssl@3` library artifacts include `arm64` slices.

### T3 project modernization

- Updated `ssrMac.xcodeproj/project.pbxproj` to Xcode 26 project markers: `objectVersion = 77` and `LastUpgradeCheck = 1700`.
- Raised project-level `MACOSX_DEPLOYMENT_TARGET` from `10.8` to `11.0` for Debug and Release.
- Validation: `plutil -lint ssrMac.xcodeproj/project.pbxproj` passed.
- Validation: static search confirmed no remaining `MACOSX_DEPLOYMENT_TARGET = 10.8` or `compatibilityVersion = "Xcode 3.2"` in the main project file.

### Working tree notes

- `shadowsocksr-native` was already dirty before migration edits due to dirty nested submodules: `depends/cstl`, `depends/http-parser`, and `depends/libbloom`.
- `AGENTS.md` is present but untracked and was not included in migration task commits.