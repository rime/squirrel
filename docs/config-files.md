# 配置文件索引（开发维护）

本文档汇总本仓库中与构建、运行、打包、发布直接相关的配置文件，便于后续开发快速定位修改入口。

## 1. 主工程（Squirrel）配置

- `Squirrel.xcodeproj/project.pbxproj`
  - Xcode 工程核心配置文件。
  - 记录 Target、Build Phases、资源拷贝规则、依赖 Framework、源码与资源引用、编译参数等。
  - 修改场景：新增源码/资源、调整构建阶段、引入新库、修改打包进 App 的内容。

- `Squirrel.xcodeproj/xcshareddata/xcschemes/Squirrel.xcscheme`
  - Xcode Scheme 配置。
  - 记录 Build/Test/Run/Profile/Archive 使用的配置、启动目标、调试器设置等。
  - 修改场景：调整归档配置、切换默认运行/测试行为。

## 2. 应用元信息与本地化配置

- `resources/Info.plist`
  - 应用与输入法元信息配置。
  - 主要内容：
    - Bundle 信息（如 `CFBundleIdentifier`、`CFBundleVersion`）。
    - 输入法 Source ID 与输入模式（Hans/Hant）。
    - 输入法连接类、运行属性（如 `LSUIElement`）。
    - Sparkle 自动更新配置（如 `SUFeedURL`、`SUPublicEDKey`）。
  - 修改场景：改包名、改输入法 ID、改更新地址、改版本注入方式。

- `resources/InfoPlist.xcstrings`
  - `Info.plist` 字段本地化映射。
  - 主要内容：`CFBundleDisplayName`、`CFBundleName`、输入法名称、多语言版权文案等。

- `resources/Localizable.xcstrings`
  - 应用运行期文案本地化配置。
  - 修改场景：新增或调整 UI 文案的多语言翻译。

## 3. 打包与版本配置（package）

- `package/make_package`
  - 生成 `.pkg` 的核心脚本。
  - 主要内容：`pkgbuild` 参数、安装路径、组件 plist、版本号读取逻辑。

- `package/common.sh`
  - 打包公共函数。
  - 主要内容：项目根目录解析、版本号读取（`agvtool`）、版本号更新。

- `package/Squirrel-component.plist`
  - `pkgbuild --component-plist` 配置。
  - 主要内容：Bundle 覆盖策略、是否可移动、子 Bundle（Sparkle.framework）升级行为。

- `package/PackageInfo`
  - 包安装元信息。
  - 当前包含安装后动作（`postinstall-action`）。

- `package/add_data_files`
  - 维护 `project.pbxproj` 中数据文件与插件库条目的辅助脚本。
  - 修改场景：批量将 `data/plum` 或 `lib/rime-plugins` 新文件接入工程。

## 4. 输入法默认行为配置

- `data/squirrel.yaml`
  - Squirrel 默认行为与样式配置。
  - 主要内容：
    - 键盘布局、通知行为、候选栏布局与样式。
    - 字体、颜色方案、候选格式。
    - 不同应用的输入行为覆盖（`app_options`）。
  - 修改场景：默认体验调优、候选窗 UI 调整、按应用定制行为。

## 5. 资源与图标配置

- `Assets.xcassets/Contents.json`
  - 资源目录元配置（由 Xcode 维护）。

- `Rime.icon/icon.json`
  - 图标工程配置（图层、外观模式、平台支持、材质/阴影等）。
  - 修改场景：更换图标素材、调整浅色/深色显示效果。

## 6. Sparkle 子工程配置

- `Sparkle/Configurations/*.xcconfig`
  - Sparkle 构建参数集合（多个配置文件组合）。
  - 主要内容：
    - 功能开关（pkg/dmg/delta/DSA 等支持）。
    - 版本号与营销版本。
    - 编译宏、最低系统版本、架构、警告级别等。

- `Sparkle/Sparkle.xcodeproj/project.pbxproj`
  - Sparkle 子工程的目标、构建阶段、依赖与资源配置。

- `Sparkle/Sparkle.xcodeproj/xcshareddata/xcschemes/*.xcscheme`
  - Sparkle 各目标的 Scheme 配置（如 `Sparkle`、`sparkle-cli`、`generate_appcast`）。

- `Sparkle/**/Info.plist`
  - Sparkle 各子目标元信息配置（framework、helper、tool、test app 等）。

- `Sparkle/Package.swift`
  - Sparkle Swift Package 分发配置。
  - 主要内容：版本、二进制下载 URL、checksum、平台约束。

## 7. 仓库级配置

- `.gitignore`
  - Git 忽略规则。
  - 主要内容：构建产物、临时文件、下载目录、签名相关文件、pkg 产物等。

## 8. 开发与安装脚本配置

- `scripts/dev-rebuild.sh`
  - 开发态快速重编译与重装脚本。
  - 默认执行 `make install-debug`，可选追加 `--build`（部署方案）和 `--reload`（触发重载通知）。
  - 修改场景：希望缩短“改代码 -> 安装验证”循环时间时。

- `scripts/postinstall`
  - 安装后的注册与启用脚本。
  - 主要内容：注册输入法、按需执行 `--build` 预部署、启用并切换输入源。
  - 修改场景：调整安装后自动行为（注册/启用/部署）时。

## 9. 维护建议（后续开发）

- 修改配置前先定位“作用域”：运行时行为、工程构建、打包分发、还是更新系统。
- 变更 `Info.plist` 与 `InfoPlist.xcstrings` 时保持键名与本地化项一致。
- 修改打包配置后，至少验证一次 `make package` 产物是否可安装与覆盖升级。
- 涉及 Sparkle 版本/能力开关时，同步检查其 `xcconfig` 组合是否一致。
