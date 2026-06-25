# ssrMac → Apple Silicon (arm64) 迁移任务清单

> 关联 issue: [#1 将 ssrMac 迁移到 Apple Silicon (arm64)，兼容未来 macOS（27 Golden Gate / 28）](https://github.com/lonegunmanb/ssrMac/issues/1)
> 基线提交: `e98b90ace09e9452aea1e7164330386b7b686912`

## 使用说明（给后续 agent）

本文件把迁移工作拆分成**有先后依赖**的原子任务，供 agent 逐个领取、逐个完成。

- 每个任务用 `T<编号>` 标识，包含：目标、依赖、涉及文件、操作步骤、验收标准。
- **必须按依赖顺序执行**：一个任务的全部 `依赖` 都标记为 `[x] 完成` 后才能开始它。
- 完成一个任务后：
  1. 勾选该任务标题旁的复选框；
  2. 在「进度看板」表中把状态改为 `done`；
  3. 提交一次独立 commit（commit message 引用任务编号，如 `T3: ...`）。
- 任务分为两类：
  - **🔴 阻塞性**：不完成则 arm64 无法构建/运行。
  - **🟢 增强性**：提升可分发性与长期可维护性，非「跑起来」必需。
- 若某任务执行中发现新的子问题，**不要扩大当前任务范围**，在「附录：新发现」中追加记录，必要时拆成新任务。

## 阶段总览

| 阶段 | 主题 | 包含任务 | 性质 |
|---|---|---|---|
| 0 | 环境与子模块准备 | T1, T2 | 🔴 阻塞 |
| 1 | 构建系统现代化 | T3, T4, T5, T6 | 🔴 阻塞 |
| 2 | 依赖 arm64 化 | T7, T8, T9 | 🔴 阻塞 |
| 3 | 弃用 API 替换 | T10, T11 | T10🔴 / T11🟢 |
| 4 | 代码签名与公证 | T12, T13 | T12🔴 / T13🟢 |
| 5 | 测试与验证 | T14 | 🔴 阻塞 |
| 6 | 长期增强（可选） | T15, T16 | 🟢 增强 |

## 进度看板

| 任务 | 标题 | 性质 | 依赖 | 状态 |
|---|---|---|---|---|
| T1 | 拉取并初始化全部子模块 | 🔴 | — | done |
| T2 | 准备 arm64 工具链与依赖库 | 🔴 | T1 | done |
| T3 | 升级工程格式与部署目标 | 🔴 | T1 | done |
| T4 | 设置 arm64 架构构建参数 | 🔴 | T3 | done |
| T5 | 清理死引用与 Intel 路径假设 | 🔴 | T3 | done |
| T6 | 清理 iOS 残留 configuration | 🔴 | T3 | done |
| T7 | 重编 ssrNative.framework (arm64) | 🔴 | T2, T4 | pending |
| T8 | 产出 4 个 C 库 arm64 framework | 🔴 | T2, T4 | pending |
| T9 | 子工程依赖 arm64 化 | 🔴 | T4 | pending |
| T10 | WebView → 原生二维码 (CIQRCodeGenerator) | 🔴 | T3 | done |
| T11 | 提权机制现代化 (SMAppService/XPC) | 🟢 | T4 | pending |
| T12 | 启用代码签名（最低 ad-hoc） | 🔴 | T4 | done |
| T13 | Hardened Runtime + 公证 | 🟢 | T12, T7, T8, T9, T10 | pending |
| T14 | 全链路构建与运行验证 | 🔴 | T7, T8, T9, T10, T12 | pending |
| T15 | AFNetworking → URLSession | 🟢 | T14 | pending |
| T16 | 重写 build.sh / CI | 🟢 | T4 | done |

## 依赖关系图

```
T1 ─┬─> T2 ─┬─────────────> T7 ─┐
    │       └─────────────> T8 ─┤
    └─> T3 ─┬─> T4 ─┬─> T9 ─────┤
            │       ├─> T11      │
            │       ├─> T12 ─────┼─> T14 ─> T15
            │       └─> T16      │
            ├─> T5               │
            ├─> T6               │
            └─> T10 ─────────────┤
                                 └─> T13
T13 还依赖 T7/T8/T9/T10（全部产物就绪后才能整体公证）
T14 依赖 T7/T8/T9/T10/T12
```

---

## 阶段 0 — 环境与子模块准备

### [x] T1 · 拉取并初始化全部子模块 🔴

- **依赖**: 无
- **背景**: `.gitmodules` 声明了 4 个子模块（`GCDWebServer`、`GZIP`、`AFNetworking`、`shadowsocksr-native`），当前工作区均未 checkout（`git submodule status` 四行均以 `-` 前缀）。后续所有重编任务都依赖它们存在。
- **涉及文件**: `.gitmodules`，各子模块目录
- **步骤**:
  1. `git submodule update --init --recursive`
  2. 确认 `shadowsocksr-native/ios/ssrNative.xcodeproj` 存在（T7 依赖）。
  3. 确认 `AFNetworking`、`GCDWebServer`、`GZIP` 各自的 `.xcodeproj` 存在（T9 依赖）。
- **验收标准**:
  - `git submodule status` 四行均以空格（已 checkout）开头，无 `-` 前缀。
  - 上述 4 个 `.xcodeproj` 路径均可访问。

### [x] T2 · 准备 arm64 工具链与依赖库 🔴

- **依赖**: T1
- **背景**: arm64 Homebrew 默认前缀为 `/opt/homebrew`（Intel 为 `/usr/local`）。T8 需要这些库的 arm64 头文件与静态库来交叉编译/打包 framework。
- **涉及文件**: 无（仅本机环境）
- **步骤**:
  1. 确认已安装 Xcode ≥ 16，并 `xcode-select -p` 指向其 Developer 目录。
  2. `brew install libsodium libuv mbedtls openssl@3 automake autoconf libtool pkg-config cmake`
  3. 记录各库在 `/opt/homebrew` 下的实际安装路径（供 T8 引用）。
- **验收标准**:
  - `brew --prefix` 返回 `/opt/homebrew`。
  - `lipo -archs $(brew --prefix libsodium)/lib/libsodium.a` 等输出包含 `arm64`。
  - `xcodebuild -version` 显示 Xcode ≥ 16。

---

## 阶段 1 — 构建系统现代化

> 全部围绕 `ssrMac.xcodeproj/project.pbxproj`。当前 `objectVersion = 46`（L6）、`compatibilityVersion = "Xcode 3.2"`（L666）、`LastUpgradeCheck = 1010`（L654）。
> 配置块映射（务必精确改对目标）：
> - PBXProject 级 configuration list：Debug L1019、Release L1075（含 iOS 残留：`SDKROOT = iphoneos` L1070/L1118、`IPHONEOS_DEPLOYMENT_TARGET` L1065/L1113、`TARGETED_DEVICE_FAMILY` L1071/L1119、`MACOSX_DEPLOYMENT_TARGET = 10.8` L1066/L1114）。
> - `ssrMac` app target configuration list：Debug L1124、Release L1161（含 `HEADER_SEARCH_PATHS = /usr/local/include` L1148/L1187、`LIBRARY_SEARCH_PATHS = /usr/local/lib` L1151/L1190）。
> - `ssr_mac_sysconf` target configuration list：Debug L963、Release L992。

### [x] T3 · 升级工程格式与部署目标 🔴

- **依赖**: T1
- **背景**: 部署目标 10.8 早于首个支持 arm64 的 macOS 11 (Big Sur)；工程格式停留在 Xcode 3.2 时代。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 用 Xcode 打开工程，执行 "Update to recommended settings"（升级 `objectVersion`/`compatibilityVersion`/`LastUpgradeCheck`）。
  2. 将所有 `MACOSX_DEPLOYMENT_TARGET = 10.8`（L1066、L1114）改为 `11.0`（或更高）。
  3. 确认 `Info.plist` 的 `LSMinimumSystemVersion` 仍继承 `${MACOSX_DEPLOYMENT_TARGET}`（`ssrMac/ssrMac-Info.plist`），无需手改。
- **验收标准**:
  - 工程内不再出现 `MACOSX_DEPLOYMENT_TARGET = 10.8`。
  - `compatibilityVersion` 升级为现代 Xcode 值；工程在 Xcode ≥ 16 中无格式告警。

### [x] T4 · 设置 arm64 架构构建参数 🔴

- **依赖**: T3
- **背景**: 主工程未硬编码 `i386/x86_64`，默认走 `ARCHS_STANDARD`（含 arm64）。本任务显式固化架构设置，避免歧义，并为 Debug/Release 区分 `ONLY_ACTIVE_ARCH`。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 在 `ssrMac` 与 `ssr_mac_sysconf` 两个 target 显式设 `ARCHS = "$(ARCHS_STANDARD)"`。
  2. Debug 配置设 `ONLY_ACTIVE_ARCH = YES`，Release 设 `ONLY_ACTIVE_ARCH = NO`。
  3. **不要**添加 `EXCLUDED_ARCHS` 或 `VALID_ARCHS`。
- **验收标准**:
  - 工程内无 `EXCLUDED_ARCHS`。
  - `xcodebuild ... -showBuildSettings | grep ARCHS` 显示含 `arm64`。

### [x] T5 · 清理死引用与 Intel 路径假设 🔴

- **依赖**: T3
- **背景**: 三条 `/usr/local/lib/*.a` 为历史死引用（`libuv.a` L266、`libsodium.a` L273、`libcrypto.a` L274，均在 `<group>` 中未参与链接）；`LIBRARY_SEARCH_PATHS`/`HEADER_SEARCH_PATHS` 指向 Intel Homebrew 路径。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 删除 L266/L273/L274 三条 `.a` PBXFileReference 及其在 `<group>`（L480-L482 附近）中的引用。
  2. 将 `LIBRARY_SEARCH_PATHS = /usr/local/lib`（L1151、L1190）与 `HEADER_SEARCH_PATHS = /usr/local/include`（L1148、L1187）改为 `/opt/homebrew/lib` / `/opt/homebrew/include`，或删除（取决于 T8 最终如何提供 framework；若全部走 `BUILT_PRODUCTS_DIR` 则可删除）。
- **验收标准**:
  - 工程内不再出现 `/usr/local/`。
  - 删除死引用后 Xcode 工程可正常解析、无悬空引用。

### [x] T6 · 清理 iOS 残留 configuration 🔴

- **依赖**: T3
- **背景**: PBXProject 级 Debug/Release 含 iOS 专属设置，对 macOS 构建无意义且易误导。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 移除 `SDKROOT = iphoneos`（L1070、L1118），PBXProject 级统一为 `macosx`。
  2. 移除 `IPHONEOS_DEPLOYMENT_TARGET`（L1065、L1113）、`TARGETED_DEVICE_FAMILY`（L1071、L1119）。
  3. 移除 iOS 用的 `CODE_SIGN_IDENTITY = "iPhone Developer"` 及 `[sdk=iphoneos*]` 变体（L1044/L1045、L1100/L1101）、`HEADER_SEARCH_PATHS = "OpenSSL-for-iPhone/include/"`（L1064、L1112）、`PROVISIONING_PROFILE[sdk=iphoneos*]` 等。
- **验收标准**:
  - 工程内不再出现 `iphoneos`、`IPHONEOS_DEPLOYMENT_TARGET`、`OpenSSL-for-iPhone`、`iPhone Developer`。
  - 两个 macOS target 仍能正常加载。

---

## 阶段 2 — 依赖 arm64 化（核心阻塞）

> 主 app 的 Frameworks 构建阶段（L364-L383）链接 7 个第三方产物，均为 `sourceTree = BUILT_PRODUCTS_DIR`：`ssrNative.framework`（L368）、`GZIP.framework`、`mbedtls.framework`、`AFNetworking.framework`、`libsodium.framework`、`GCDWebServers.framework`、`libuv.framework`。其中 `libuv/libsodium/mbedtls` framework **没有子工程依赖**，需手工产出。

### [ ] T7 · 重编 ssrNative.framework (arm64) 🔴

- **依赖**: T2, T4
- **背景**: C 核心 `ssrNative.framework` 来自子工程 `shadowsocksr-native/ios/ssrNative.xcodeproj`（引用见 L267；子工程依赖配置 `PBXContainerItemProxy` L82-L95、`PBXTargetDependency` "ssrNative macOS" L896-L903 区域）。这是整条链的根。
- **涉及文件**: `shadowsocksr-native/ios/ssrNative.xcodeproj`，`shadowsocksr-native` C 源码
- **步骤**:
  1. 确认 `ssrNative.xcodeproj` 的 macOS target `ARCHS` 含 arm64、部署目标 ≥ 11.0。
  2. 检查其内部 C 源码无 `__x86_64__` 等架构假设（issue 评估为低风险，但需验证）。
  3. 为 arm64 重新编译，产出 `ssrNative.framework`。
- **验收标准**:
  - `lipo -archs <产物>/ssrNative.framework/Versions/A/ssrNative` 含 `arm64`。
  - 主工程链接阶段无 "missing arm64 slice" 相关错误。

### [ ] T8 · 产出 4 个 C 库 arm64 framework 🔴

- **依赖**: T2, T4
- **背景**: `libuv`/`libsodium`/`mbedtls`/`openssl(libcrypto)` 不在子模块内，是外部预编译，需自行为 arm64 产出并放入 `BUILT_PRODUCTS_DIR`。这是工作量最大的阻塞项。
- **涉及文件**: `BUILT_PRODUCTS_DIR` 中的 framework 产物；可能新增打包脚本
- **步骤**:
  1. 用 T2 安装的 arm64 库，为 `libuv`、`libsodium`、`mbedtls` 各打包成 framework，放入构建产物目录（匹配 L258-L260、L268-L270 期望的产物名）。
  2. openssl 的 `libcrypto` 同理（注意 app 链接的是 framework，不是 L274 那条已删的 `.a`）。
  3. 每个产物用 `lipo -info` / `lipo -archs` 校验确含 `arm64` slice。
  4. 建议把打包过程脚本化，纳入 build 流程（与 T16 协同）。
- **验收标准**:
  - 4 个 framework 的二进制 `lipo -archs` 均含 `arm64`。
  - 主工程链接阶段对这 4 个库无 "undefined symbols for arm64"。

### [ ] T9 · 子工程依赖 arm64 化 🔴

- **依赖**: T4
- **背景**: `GCDWebServer`、`GZIP`、`AFNetworking` 作为子工程依赖随主工程一起编（`PBXTargetDependency` "AFNetworking macOS" L906、"GCDWebServers (Mac)" L911、"GZIP-macOS" L916 区域；projectReferences L678-L695）。
- **涉及文件**: `AFNetworking/`、`GCDWebServer/`、`GZIP/` 各 `.xcodeproj`
- **步骤**:
  1. 确认三个子工程的 macOS target 部署目标 ≥ 11.0、架构走 `ARCHS_STANDARD`。
  2. 随主工程编译，确保产出对应 framework 到 `BUILT_PRODUCTS_DIR`。
- **验收标准**:
  - 三个 framework 的 `lipo -archs` 均含 `arm64`。
  - 主工程链接阶段无相关缺失架构错误。

---

## 阶段 3 — 弃用 API 替换

### [x] T10 · WebView → 原生二维码 (CIQRCodeGenerator) 🔴

- **依赖**: T3
- **背景**: 旧版 WebKit `WebView` 在现代 macOS 上已移除/弃用。当前二维码窗口用 `WebView` 加载 `qrcode.htm` + `jquery.min.js` + `qrcode.min.js` 渲染。引用点：`SWBQRCodeWindowController.h` L14（`IBOutlet WebView *webView`）、`SWBQRCodeWindowController.m` L25/L31/L72；`qrCodeOnScreen.m`；`WebKit.framework` 链接（L378，文件引用 L317 指向 `MacOSX10.9.sdk`，资源打包 L847-L849）。
- **涉及文件**: `ssrMac/SWBQRCodeWindowController.{h,m}`、`ssrMac/qrCodeOnScreen.{h,m}`、`ssrMac/QRCodeWindow.xib`、`ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. **推荐方案**：用 Core Image `CIQRCodeGenerator` 原生生成二维码 `NSImage`，替换 `generateImageFromWebView:`。
  2. 删除 HTML+JS 依赖：`qrcode.htm`、`jquery.min.js`、`qrcode.min.js`（资源引用 L581-L582、L598、L847-L849）。
  3. 从 Frameworks 阶段移除 `WebKit.framework`（L378）及其文件引用（L317、L492）。
  4. 更新 `QRCodeWindow.xib`，移除 `WebView` outlet，改用 `NSImageView`。
  5. 备选方案（不推荐）：仅把 `WebView` 换成 `WKWebView`，保留 HTML 渲染。
- **验收标准**:
  - 工程内不再引用 `WebView`、`WebKit.framework`、`qrcode.htm`、`jquery.min.js`。
  - 运行时二维码窗口能正确显示当前节点的 ssr 链接二维码。

### [ ] T11 · 提权机制现代化 (SMAppService/XPC) 🟢

- **依赖**: T4
- **背景**: `ssr_mac_sysconf/main.m` 用已弃用的 `AuthorizationCreate`（L44）+ `SCPreferencesCreateWithAuthorization`（L66）提权，并通过 `install_helper.sh`（setuid `chmod +s`）安装到 `/Library/Application Support/ssrMac/`。该工具被当作 resource 打包（L838）。`SCPreferences*` 系统代理逻辑（main.m L65-L100）在 arm64 上仍可用，**仅需替换提权外壳**。
- **涉及文件**: `ssr_mac_sysconf/main.m`、`ssrMac/install_helper.sh`、`ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 将 setuid + `install_helper.sh` 模式迁移到 `SMAppService`（macOS 13+）或 `SMJobBless` + XPC helper。
  2. 保留 `doSettingProxy` 中的 `SCPreferences*` 代理设置逻辑（L65-L100），仅替换其提权获取方式。
  3. 更新打包/安装流程，移除 `chmod +s` 的 setuid 安装。
- **验收标准**:
  - 不再依赖 setuid 二进制；helper 通过 `SMAppService`/`SMJobBless` 注册。
  - 在 arm64（公证后）上切换 auto/global/off 代理均生效，退出后系统代理正确还原。
- **备注**: 非「能跑」必需，但阻塞「公证后能正常提权」。可在 T13 之前完成。

---

## 阶段 4 — 代码签名与公证

> 当前全工程 `CODE_SIGN_IDENTITY = ""`（L970、L999、L1132、L1169）、`CODE_SIGN_STYLE = Automatic`、`DEVELOPMENT_TEAM = ""`；不存在 `ENABLE_HARDENED_RUNTIME`、`CODE_SIGN_ENTITLEMENTS` 或任何 `.entitlements`。各 framework 的 CopyFiles 已设 `CodeSignOnCopy`（如 L23），方向正确。

### [x] T12 · 启用代码签名（最低 ad-hoc）🔴

- **依赖**: T4
- **背景**: Apple Silicon 强制所有可执行代码必须签名（哪怕 ad-hoc）。Intel 上未签名可跑，arm64 上不行。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`
- **步骤**:
  1. 本地自用最低配置：把 `CODE_SIGN_IDENTITY` 设为 `"-"`（ad-hoc），让 arm64 能启动。
  2. 确认两个 target（app 与 helper）及随附 framework 均被签名（CopyFiles 的 `CodeSignOnCopy` 已就绪）。
- **验收标准**:
  - `codesign --verify --deep --strict ssrMac.app` 通过。
  - 在 Apple Silicon 上原生（非 Rosetta）双击可启动，不被 Gatekeeper 直接杀掉。

### [ ] T13 · Hardened Runtime + 公证 🟢

- **依赖**: T12, T7, T8, T9, T10
- **背景**: 分发（非自用）必需。缺 Hardened Runtime 时公证会被拒。
- **涉及文件**: `ssrMac.xcodeproj/project.pbxproj`、新增 `ssrMac/ssrMac.entitlements`
- **步骤**:
  1. 填 `DEVELOPMENT_TEAM`、`CODE_SIGN_IDENTITY = "Developer ID Application"`、`ENABLE_HARDENED_RUNTIME = YES`。
  2. 新建 `ssrMac.entitlements`，按需加入网络客户端/服务端、（若 WKWebView 需要）JIT 等 entitlement，设 `CODE_SIGN_ENTITLEMENTS`。
  3. 保持各 framework `CodeSignOnCopy`，用 `xcrun notarytool` 公证 + `stapler` 装订。
- **验收标准**:
  - `spctl -a -vvv ssrMac.app` 显示 accepted / Notarized Developer ID。
  - `codesign -d --entitlements - ssrMac.app` 显示预期 entitlements，且 Hardened Runtime 标志开启。

---

## 阶段 5 — 测试与验证

### [ ] T14 · 全链路构建与运行验证 🔴

- **依赖**: T7, T8, T9, T10, T12
- **背景**: 验证「阻塞性三件套 + 部署目标」全部落地后 arm64 可构建可运行。
- **涉及文件**: 无（验证为主）
- **步骤**:
  1. `xcodebuild -project ssrMac.xcodeproj -scheme ssrMac -configuration Release -arch arm64` 构建成功。
  2. `lipo -archs ssrMac.app/Contents/MacOS/ssrMac` 确认含 arm64。
  3. 对每个内嵌 framework 跑 `lipo -info` 验证 slice。
  4. 在 Apple Silicon 上原生启动，逐项验证：节点连接、PAC/全局代理切换（提权流程）、二维码显示、退出后系统代理正确还原。
- **验收标准**:
  - 构建零错误；主二进制与所有内嵌 framework 均含 `arm64`。
  - 上述四项功能验证全部通过。

---

## 阶段 6 — 长期增强（可选）

### [ ] T15 · AFNetworking → URLSession 🟢

- **依赖**: T14
- **背景**: AFNetworking 已归档（4.x 仍支持 arm64，故非阻塞）。长期可维护性建议迁移到原生 `URLSession`，最终可移除该子模块依赖。
- **涉及文件**: 使用 AFNetworking 的 app 源码、`AFNetworking` 子模块引用、`project.pbxproj`
- **步骤**:
  1. 定位所有 `AFNetworking` 使用点，逐个改写为 `URLSession`。
  2. 移除 AFNetworking 子工程依赖与 framework 链接。
- **验收标准**: 工程不再依赖 AFNetworking，相关网络功能回归测试通过。

### [x] T16 · 重写 build.sh / CI 🟢

- **依赖**: T4
- **背景**: 现有 `build.sh` 已失效（`cd AppProxyCap/` 指向不存在目录，且用 `xcodebuild -sdk iphonesimulator`）；`.travis.yml` 同样指向 `iphonesimulator` 并调用该脚本。
- **涉及文件**: `build.sh`、`.travis.yml`（或迁移到 GitHub Actions）
- **步骤**:
  1. 重写 `build.sh` 为：`xcodebuild -project ssrMac.xcodeproj -scheme ssrMac -configuration Release -arch arm64`（并串接 T8 的依赖库打包步骤）。
  2. 更新/替换 CI 配置，使用 macOS（Apple Silicon）runner。
- **验收标准**: 在干净 checkout 上执行 `build.sh` 可一键完成 arm64 构建。

---

## 附录：新发现

> 执行任务中发现的、超出当前任务范围的问题记录于此，必要时升级为新任务。

- （暂无）
