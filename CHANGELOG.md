<a name="1.1.1"></a>
## 1.1.1 (2026-01-11)

### 構建 | Build
- build universal binary (2154997)

**Full Changelog**: https://github.com/rime/squirrel/compare/1.1.0...1.1.1

<a name="1.1.0"></a>
## 1.1.0 (2026-01-11)

### Bug 修復 | Bug Fixes
- boundary check to prevent crash (#1044) (1a70873)
- no index offset to an empty string (#1045) (ab1db6c)
- 開啓 `inline_candidate` 選項後移動光標導致崩潰 (#1047) (6137702)
- 橫向候選詞列表末尾元素高亮區域渲染錯誤 (#1071)

### 主要功能更新 | Major Updates
- 「系統原生」風格 `native` 跟隨系統主題切換明暗色調；提高文字對比度 (2fb92e8)
- `librime` 更新至 1.16.0：
  - 優化音節切分算法，調整簡拼、歧義切分路徑的權重
  - 修復糾錯候選排序權重以及與造句的策略衝突
  - 拼寫運算增設容錯規則 `derive/X/Y/correction`
  - 輸入方案自動引用組件默認配置 `default:/{navigator,selector}`

### 構建 | Build
- remove paths filter from release-ci for nightly builds (5232c45)
- fix sign_update call (d9a9155)

**Full Changelog**: https://github.com/rime/squirrel/compare/1.0.3...1.1.0

<a name="1.0.3"></a>
## 1.0.3 (2025-01-23)

#### 主要功能更新
* 新增翻䈎提示，以`style/show_paging: true/false`控制
* `librime` 更新至1.13.0：
  * 數字後標點優化，可用`punctuator/digit_separators`調整
  * `translator`可用多個`tag`
  * 詳見 librime [更新紀錄](https://github.com/rime/librime/blob/master/CHANGELOG.md)，含 1.12、1.13 兩個主要版本更新

#### 其它更新內容
* bug 修復
  * 自emoji面板切換後無法使用的問題
  * 每次開機重新布署的問題

#### Major Update
* Added paging indicator, gated by `style/show_paging: true/false`
* Update `librime` to 1.13.0:
  * Optimized punctuator after digits, customizable by `punctuator/digit_separators`
  * Allow `translator` to take multiple `tag`s
  * See librime [change log](https://github.com/rime/librime/blob/master/CHANGELOG.md) for details, including 1.12 and 1.13 major updates

#### Other Updates
* Bug fixes:
  * IME unavailable after using emoji-selection panel
  * Deploy upon every start-up regardless of changes

**Full Changelog**: https://github.com/rime/squirrel/compare/1.0.2...1.0.3

<a name="1.0.2"></a>
## 1.0.2 (2024-06-07)

#### 其它更新內容
* bug 修復
  * 未設定暗色主題時，配色不生效
  * 橫排時序號偏高
  * 帶 Alt 的快捷鍵不生效
  * App 特定設置 inline 不生效
  * `good_old_caps_lock` 關閉，且 Caps Lock 啓用時，Shift 無法輸入大寫字母
* Edge 瀏覧器默認行內編輯 (修 #906)
* 日誌置於 $TMPDIR/rime.squirrel 內，以便查找

#### Other Updates
* Bug fixes:
  * `color_scheme` doesn't apply in dark mode when `color_scheme_dark` is not set
  * Label baseline too high in horizontal orientation
  * Shortcut with Alt doesn't work
  * inline option in app specific setting doesn't work
  * when `good_old_caps_lock` turned to false, and Caps Lock is on, Shift cannot product upper case letter
* Edge defaults to inline mode (fix #906)
* Logs dir is now $TMPDIR/rime.squirrel for clarity

**Full Changelog**: https://github.com/rime/squirrel/compare/1.0.1...1.0.2

<a name="1.0.1"></a>
## 1.0.1 (2024-06-01)

#### 其它更新內容
* bug 修復
  * 不再注冊爲拉丁輸入法，修復 Caps Lock 切換輸入法時不能切換至西文的問題
  * 修復配色中的 candidate_list_layout, text_orientation 不生效問題
  * 修復字體名無法解析時，字號不生效問題
* 不再支持 `style/horizontal` 和 `style/vertical`

#### Other Updates
* Bug fixes:
  * Remove Latn repertoire so that switching IME by Caps Lock can toggle Squirrel and Latin input
  * Fix: candidate_list_layout, text_orientation do not take effect when put in color scheme
  * Fix: font point is ignored when font face is invalid
* Drop support for `style/horizontal` and `style/vertical`

**Full Changelog**: https://github.com/rime/squirrel/compare/1.0.0...1.0.1

<a name="1.0.0"></a>
## 1.0.0 (2024-05-30)

#### 主要功能更新
* 純 Swift 重寫，代碼更易維護，更易讀，貢獻代碼的門檻更低。今天就來看看源代碼，嘗試動手吧！

#### 其它更新內容
* UI 設置【**敬請留意**】
  * `style/candidate_format` 格式修改爲 `"[label]. [candidate] [comment]"`，原格式仍能使用，但建議遷移至更靈活、直觀的新格式
  * `style/horizontal` 將徹底移除，雖然本版程序仍支持，但會被新控件的默認值覆蓋
    請使用 `candidate_list_layout`: `stacked`/`linear` 和 `text_orientation`: `horizontal`/`vertical`
  * `style/label_hilited_color` 已移除，請使用 `style/hilited_candidate_label_color`
  * `native` 配色小幅修改，減小字號，更像原生輸入法
* UI 
  * 在菜單欄新增日志檔案夾，方便快速進入
  * 序號居中顯示，更像原生輸入法
* 新增 `--help` 命令行命令，以便查詢支持的命令
* bug 修復
  * 減少使用<kbd>⇧</kbd>輸入大寫時造成中英切換的可能性
* librime：使用 stdbool 後綴 API，以便與 Swift 更好橋接

#### Major Update
* Migrated code to pure Swift, which is easier to code, read and learn. Build your own Squirrel today!

#### Other Updates
* UI settings (**Breaking Changes**)
  * `style/candidate_format` now updated to `"[index]. [candidate] [comment]"`, while the old format still works, please consider migrating to this more readable and flexible format at your convenience
  * `style/horizontal` will be dropped, it's still supported but will be overwrite by the default values of new options.
    Please adopt `candidate_list_layout`: `stacked`/`linear` and `text_orientation`: `horizontal`/`vertical`
  * `style/label_hilited_color` is removed, please use `style/hilited_candidate_label_color` instead
  * `native` color scheme is updated with smaller font size, to better match macOS builtin IME
* UI
  * Added a menu item for logs folder with easy access
  * labels will vertically center if label font is smaller than candidate font, to better match macOS builtin IME
* Added `--help` command line argument
* Bug fixes:
  * Reduce the chance that ascii mode may unintentionally switch when pressing <kbd>⇧</kbd> to enter Cap case
* librime: Use stdbool flavored API, for better Swift interoperation

**Full Changelog**: https://github.com/rime/squirrel/compare/0.18...1.0.0

<a name="0.18"></a>
## 0.18 (2024-05-04)

#### 主要功能更新
* 現可設定非高亮候選項背景色：
  * 以 `preset_color_schemes/xxx/candidate_back_color: 0xAABBGGRR` 設定，未設定則不啓用本功能
  * 以 `style/surrounding_extra_expansion` 控制非高亮候選背景大小，正數則相對高亮背景擴大，負數則相對高亮背景收縮，默認爲0
* 更稳定的介面渲染，尤其繪文字無論橫排豎排皆能穩定顯示，行高不會跳變
* 支持鼠標操作：
  * 鼠標懸浮則更改高亮候選，點擊則選定候選，滾輪和觸控板滑動則翻䈎
  * 點擊編碼區則可前後移動光標位置
* 其它介面改進：
  * 解決候選框首次出現可能位於屏幕一角的問題
  * `style/border_height`、`style/border_width`、`style/line_spacing`、`style/spacing`現可正確處理負值
  * 字號可包含小數
  * 序號字號不同於候選字號時，序號居中
  * 可以`style/status_message_type`: `mix`(default) / `long` / `short`控制狀態改變時如何展示狀態標籤，默認短標籤優先，無短標籤則使用完整標籤，不再自動截取完整標籤首字，除非設爲`short`
  * 以`style/memorize_size`: `true`/`false`控制候選標是否在接觸屏幕邊緣時有粘性
  * `style/alpha`可爲0，爲0則完全隱藏候選框
  * 以`style/shadow_size`設定高亮候選背景的陰影，默認爲0，即無陰影
  * 以`style/mutual_exclusive`: `true`/`false`控制半透明顏色是否互相疊加，默認爲`false`，即互相疊加
* `librime` 更新至1.11.2：
  * 詳見 librime [更新紀錄](https://github.com/rime/librime/blob/master/CHANGELOG.md)，含 1.9、1.10、1.11 三個主要版本更新
* librime 插件現單獨構建，不再合併於 librime 內，本安裝包含 `lua`、`octagram`、`predict` 三個插件
* 最低支持的系統應爲 13.0，14.0 以上系統經過較好測試

#### 其它更新內容
* 啓用CI自動構建
* 應用 Clang 格式標準化
* 更新已過時的方法
* 支持沙盒機制

#### Main Updates
* Surrounding high lights for all candidates:
  * Set `preset_color_schemes/xxx/candidate_back_color` to enable (Not specified unless explicitly defined)
  * `style/surrounding_extra_expansion` controls the relative size to the selected candidate's surrounding block. Negative value means smaller, while positive means larger, default to 0.
* More reliable text layout, especially in vertical mode, and with exotic characters like Emoji.
* Mouse interactions:
  * Hover over to change selection, click on any candidate to select, and swipe or scroll to change page
  * Click in preedit area to change caret position
* Other UI improvements:
  * Resolve a issue that Squirrel panel shows in corner on first launch
  * `style/border_height`, `style/border_width`, `style/line_spacing` and `style/spacing` can now be negative.
  * All `font_size` accepts float number.
  * Labels are vertically centered when using a different `label_font_size` from the main `font_size`
  * Add `style/status_message_type`: `mix(default) / long / short` to Handle abbrev status label when status updates
  * Add `style/memorize_size: true/false` to control sticking panel width behavior 
  * `style/alpha: 0` is now valid, setting so completely hides the panel
  * Add `style/shadow_size` to specify shadow under selected candidate. Default to `0` with no shadow.
  * Add `style/mutual_exclusive`: `true`/`false` to allow colors not stacking on each other. Default to `false`
* `librime` updated to 1.11.2:
  * See librime [change log](https://github.com/rime/librime/blob/master/CHANGELOG.md) for details, including 1.9, 1.10 and 1.11 major updates
* librime plugins are built separately, no longer integrated inside librime library. This install package is compiled with `lua`, `octagram` and `predict` plugins
* Minimum OS supported should be 13.0, while 14.0+ is better tested

#### Other Updates
* Adopts CI workflow
* Applies Clang linting
* Modernized several deprecated methods
* Supports sandbox

#### 完整更新列表 Change Log
* build: specify build target OS in makefile by @LEOYoon-Tsaw in https://github.com/rime/squirrel/pull/727
* Consolidated update to Squirrel by @LEOYoon-Tsaw in https://github.com/rime/squirrel/pull/749
* Update INSTALL.md: Fix script by @EdgarDegas in https://github.com/rime/squirrel/pull/800
* fix action-changelog.sh by @hezhizhen in https://github.com/rime/squirrel/pull/794
* Update weasel introduction in README.md by @determ1ne in https://github.com/rime/squirrel/pull/777
* Upgrade GitHub action to v4 by @Bambooin in https://github.com/rime/squirrel/pull/834
* chore: use macos 14 runner with M1 by @Bambooin in https://github.com/rime/squirrel/pull/835
* Add mac app sandbox support. by @ShikiSuen in https://github.com/rime/squirrel/pull/841
* Apply clang format by @Bambooin in https://github.com/rime/squirrel/pull/836
* fix: fix wrong git blame ignore by @Bambooin in https://github.com/rime/squirrel/pull/845
* replace deprecated API calls by @groverlynn in https://github.com/rime/squirrel/pull/846
* fix(SquirrelPanel): text shown in top-left corner by @lotem in https://github.com/rime/squirrel/pull/856
* deps: update librime to 1.11.0 by @ksqsf in https://github.com/rime/squirrel/pull/860
* build(ci): nightly release by @ksqsf in https://github.com/rime/squirrel/pull/861
* ci: disable nightly build in forked repos by @Bambooin in https://github.com/rime/squirrel/pull/862

#### 新增貢獻者 New Contributors
* @EdgarDegas made their first contribution in https://github.com/rime/squirrel/pull/800
* @hezhizhen made their first contribution in https://github.com/rime/squirrel/pull/794
* @determ1ne made their first contribution in https://github.com/rime/squirrel/pull/777
* @ksqsf made their first contribution in https://github.com/rime/squirrel/pull/860

**Full Changelog**: https://github.com/rime/squirrel/compare/0.16.2...0.18

<a name="0.16.2"></a>
## 0.16.2 (2023-02-05)

#### 須知

 * 升級安裝後遇輸入法不可用，須手動重新添加 [#704](https://github.com/rime/squirrel/issues/704)

#### 主要更新

 * 更新 Rime 核心算法庫至 [1.8.5](https://github.com/rime/librime/releases/tag/1.8.5)
 * 修復：橫向候選欄 Tab 鍵應當用作移動插入點 [rime/librime#609](https://github.com/rime/librime/issues/609)
 * 修復：macOS Mojave 及以下版本單擊 Shift 等修飾鍵失效 [#715](https://github.com/rime/squirrel/issues/715)
 * 修復：全新安裝只添加一個輸入法選項（簡體中文） [#714](https://github.com/rime/squirrel/issues/714)


#### Bug Fixes

*   modifier change event in older macOS ([5c2b7e64](https://github.com/rime/squirrel/commit/5c2b7e64980b7e6b7eb3a8b392163ce89d244f37))
*   install one input mode or keep previous ones ([3bc6c2c0](https://github.com/rime/squirrel/commit/3bc6c2c0edbb1adaa22e79da65c6f0116b164de7))



<a name="0.16.1"></a>
## 0.16.1 (2023-01-30)


#### 主要更新

 * 更新 Rime 核心算法庫至 [1.8.4](https://github.com/rime/librime/releases/tag/1.8.4)
 * 修復：橫向候選欄不響應左方向鍵移動插入點



<a name="0.16.0"></a>
## 0.16.0 (2023-01-30)


#### 主要更新

 * 輸入狀態變化時顯示方案中設定的狀態名稱 [#540](https://github.com/rime/squirrel/pull/540)
 * 修正繪文字行高 [#559](https://github.com/rime/squirrel/issues/559)
 * 支持半透明視窗背景 [#589](https://github.com/rime/squirrel/pull/589)
 * 由 GitHub Actions執行自動構建 [#633](https://github.com/rime/squirrel/pull/633)
 * 將鼠鬚管的輸入語言註冊爲簡體中文及繁體中文 [#648](https://github.com/rime/squirrel/pull/648)
 * 可指定使用任意一種系統鍵盤佈局 [#687](https://github.com/rime/squirrel/pull/687)
   例如： `squirrel.yaml:/keyboard_layout: USExtended`
 * 區分左、右修飾鍵 [#688](https://github.com/rime/squirrel/pull/688)
 * 支持以命令行方式同步用戶數據 [#694](https://github.com/rime/squirrel/pull/694)
   命令： `Squirrel --sync`
 * 更新 Rime 核心算法庫至 [1.8.3](https://github.com/rime/librime/releases/tag/1.8.3)



<a name="0.15.2"></a>
## 0.15.2 (2021-02-13)


#### 主要更新

* 切換到其他輸入法或鍵盤時提交未轉換的輸入
* 修復工單 [#513](https://github.com/rime/squirrel/issues/513)
* 重製應用圖標，提升暗色背景下的可見度

#### Bug Fixes

* **SquirrelInputController:**  commit raw input when switching to other IME, closes #146 ([b875d194](https://github.com/rime/squirrel/commit/b875d194d9799ccc74453292c670fcca892799fa))
* **SquirrelPanel:**  use of uninitialized local variable linear, vertical ([e8b87a4f](https://github.com/rime/squirrel/commit/e8b87a4f97994001c6889ecc1d43fa38e7589e66))

#### Features

* **RimeIcon:**  updated app icon ([76d742b8](https://github.com/rime/squirrel/commit/76d742b8ee271c24dae5f98251a93930e57279ec))



<a name="0.15.1"></a>
## 0.15.1 (2021-02-11)


#### 主要更新

* 升級核心算法庫 [librime 1.7.3](https://github.com/rime/librime/blob/master/CHANGELOG.md#173-2021-02-11)
  * 修復若干內存安全問題
  * 修復並擊輸入法回車鍵上屏字符按鍵序列

* 指定候選註釋文字的字體、字號 `style/comment_font_face`, `style/comment_font_point`
* 修復無數字序號的候選樣式 `style/candidate_format`
* 優化界面代碼

#### Performance

* **SquirrelPanel:**  decompose candidate_format when loading theme ([803f6421](https://github.com/rime/squirrel/commit/803f64218384b505cbea1289af85a2b65f8f83f5), closes [#516](https://github.com/rime/squirrel/issues/516))

#### Bug Fixes

*   avoid implicit lossy integer transform ([da4fcbf2](https://github.com/rime/squirrel/commit/da4fcbf2b77ca8298eaa8043937ee2c98f95ee0f))
* **SquirrelPanel:**
  *  vertical glyph in comment text with smaller font ([c2e6f434](https://github.com/rime/squirrel/commit/c2e6f4347413a67278ab12eb388d5225e02e3fb1), closes [#522](https://github.com/rime/squirrel/issues/522))
  *  unspecified comment_font_point falls back to font_point ([8194d95a](https://github.com/rime/squirrel/commit/8194d95a82554c453f84ff4dd30eaa51affd10ae))
* **SquirrelPanel.m:**  error with candidate_format without the label part ([d2b839b6](https://github.com/rime/squirrel/commit/d2b839b6b5c415aa1cdd28e1ef7921949b90ee21), closes [#516](https://github.com/rime/squirrel/issues/516))

#### Features

* **SquirrelPanel:**  comment font config (#511) ([3d0ab6a2](https://github.com/rime/squirrel/commit/3d0ab6a209c31c0ac2b97bd8ab1bddcc269aa9bb))



<a name="0.15.0"></a>
## 0.15.0 (2021-02-06)


#### 主要更新

* 升級核心算法庫 [librime 1.7.1](https://github.com/rime/librime/blob/master/CHANGELOG.md#171-2021-02-06)
  * 遣詞造句性能提升40%
  * 支持拼音輸入法詞典擴展包
  * 升級中日韓統一表意文字和繪文字字符集數據
  * 並擊輸入支持Control、Shift等修飾鍵

* 發行通用二進制代碼，兼容搭載Intel處理器及Apple芯片的Mac電腦

* 界面新功能
  * 在原有界面樣式基礎上新增顯示直書文字的選項 `style/text_orientation`
  * 支持顯示輸入方案自定義的候選序號 `menu/alternative_select_labels`
  * 候選窗超長文字折行顯示
  * 編輯區高亮區塊支持圓角
  * 新增外觀配置項 `border_color`, `preedit_back_color`, `base_offset`（文字基線調整）
  * 支持P3色域
  * 「系統配色」自動適應深淺色外觀，或由用家自選用於深色模式的配色方案
  * 新增明暗兩款Solarized配色方案
    [`squirrel.yaml`](https://github.com/rime/squirrel/blob/master/data/squirrel.yaml)演示了P3色域、自選深淺系配色方案的用法

* 修復及規避若干軟件兼容問題

![有詩爲證](https://github.com/rime/home/raw/master/images/squirrel-vertical-text-light.png)
![有圖爲證](https://github.com/rime/home/raw/master/images/squirrel-vertical-text-dark.png)

#### Bug Fixes

* **SquirrelInputController:**  add back the Chrome address bar hack ([22ed91ea](https://github.com/rime/squirrel/commit/22ed91ea7d2c9807dedc8cd68709c82cdb3a5fd8), closes [#299](https://github.com/rime/squirrel/issues/299))
* **SquirrelPanel:**
  *  properties custom getter got wrong names ([d509c779](https://github.com/rime/squirrel/commit/d509c7791d288722a6782cca8c9afd7d0b440db5), closes [#494](https://github.com/rime/squirrel/issues/494))
  *  label format after candidate repeats label before, Closes #489 ([d2c34107](https://github.com/rime/squirrel/commit/d2c34107bdbec5767865582e4d217e546d576eca))
  *  native color scheme can only use semantic colors ([e6c69598](https://github.com/rime/squirrel/commit/e6c695983e610bd78d8c43b033a4c3602b632730))
  *  reimplement blendColors, tune background color fraction to increase contrast ([9b890f60](https://github.com/rime/squirrel/commit/9b890f60667c291216ff971b176534627f6a1cac))
* **SquirrelPanel.m:**  index out of bounds at drawSmoothLines() ([241b457f](https://github.com/rime/squirrel/commit/241b457fc0378c733ead8cb9352c156c12198cec))
* **build:**
  *  exclude architecture arm64 ([51f62cf7](https://github.com/rime/squirrel/commit/51f62cf7e52d779f8721f2ffcf5fc2b6720155c3))
  *  fix codesign error on Xcode11 ([11486644](https://github.com/rime/squirrel/commit/1148664423ae1fc986df184ef2f794790cd31834))
* **data/squirrel.yaml:**
  *  force inline in Chrome to work around bksp ([69112996](https://github.com/rime/squirrel/commit/69112996441fdae1d1778ac9a32eb98f6a8e7841))
  *  force inline mode in Telegram app ([34f2d382](https://github.com/rime/squirrel/commit/34f2d38216a7483ed8634da5de8409f6a3d7f542))
* **squirrel.yaml:**  unset default value for style/candidate_list_layout to fall back style/horizontal ([a9af3364](https://github.com/rime/squirrel/commit/a9af33644ff6c5ab0b7ea90a2af6715f1113fd68))

#### Features

* **SquirrelConfig:**  support display P3 color space ([8ff5f8d0](https://github.com/rime/squirrel/commit/8ff5f8d024c034f2217c67cf8dc77aa47a5a7b34))
* **SquirrelInputController:**
  *  app option `inline` forces inline mode ([699fee0f](https://github.com/rime/squirrel/commit/699fee0fd2c9808667fd60426f1abc8c09d7ff8d))
  *  support chording with Control, Alt or Shift keys ([118aee61](https://github.com/rime/squirrel/commit/118aee617089b4c7a3e448a42ea0b4c65eae5895))
* **SquirrelPanel:**
  *  optimize window size for big/small text ([150c5533](https://github.com/rime/squirrel/commit/150c5533f8862b242e1837fb0b62e97429cbb2a3))
  *  merge lyc/dark_mode, with slight modifications ([5a587fca](https://github.com/rime/squirrel/commit/5a587fca16d7b6c842682f285949041871ed80bf), closes [#449](https://github.com/rime/squirrel/issues/449))
* **app_options:**  support the `vim_mode` app option ([08ed4f45](https://github.com/rime/squirrel/commit/08ed4f4590e17c969f1536b347bbe1f05737d4aa), closes [#124](https://github.com/rime/squirrel/issues/124))
* **data/squirrel.yaml:**  solarized color schemes ([35b9ea76](https://github.com/rime/squirrel/commit/35b9ea76d2c3c4ce095bc838948ba43761022a12))
* **ui:**  vertical text orientation, rounded corner text with TextStorage, wrapping lone lines and border color ([c6c9302d](https://github.com/rime/squirrel/commit/c6c9302dcd537e0b72af729082390483bc3d07c0))



<a name="0.14.0"></a>
## 0.14.0 (2019-06-23)


#### 主要更新

* 升級核心算法庫 [librime 1.5.3](https://github.com/rime/librime/blob/master/CHANGELOG.md#153-2019-06-22)
  * 修復 `single_char_filter` 組件

* 建設安全、可靠、快速的全自動構建、發佈流程

* 安裝「八股文」語法數據庫（傳承字），可依照 [配方](https://github.com/lotem/rime-octagram-data) 在方案裏啓用

#### Features

* **package/add_data_files:**  update xcode project to install all files under data/plum ([2ab1810e](https://github.com/rime/squirrel/commit/2ab1810e94b963df27e6fd2e399465ccdabba138))
* **travis-ci:**  fetch latest rime binaries in install script, install extra recipes ([027679d5](https://github.com/rime/squirrel/commit/027679d58974845a83a393a313bbd63462a795b1))



<a name="0.13"></a>
## 0.13 (2019-06-17)


#### 主要更新

* 升級核心算法庫 [librime 1.5.2](https://github.com/rime/librime/blob/master/CHANGELOG.md#152-2019-06-17)
  * 修復用戶詞的權重，穩定造句質量、平衡翻譯器優先級 [librime#287](https://github.com/rime/librime/issues/287)

* 安裝預設輸入方案集，避免大多數方案依賴問題 [#279](https://github.com/rime/squirrel/issues/279)

#### Features

* **plum:**  bundle preset recipes ([7885c5fa](https://github.com/rime/squirrel/commit/7885c5fa6006e999c5a07ac1800e9afa15d629a8))



<a name="0.12.0"></a>
## 0.12.0 (2019-06-16)


#### 主要更新

* 升級核心算法庫 [librime 1.5.1](https://github.com/rime/librime/blob/master/CHANGELOG.md#151-2019-06-16)
  * 建設全自動構建、發佈流程
  * 更新第三方庫
  * 將Rime插件納入自動化構建流程。本次發行包含兩款插件：
    - [lbrime-lua](https://github.com/hchunhui/librime-lua)
    - [librime-octagram](https://github.com/lotem/librime-octagram)

#### Bug Fixes

* **squirrel.yaml:**  duplicate YAML key in color scheme dust ([44a4d7ee](https://github.com/rime/squirrel/commit/44a4d7ee3cad94c170616b7c8d9415a4f92c86d5))

#### Features

* **squirrel.yaml:**  udpate UI settings ([d8b1dc56](https://github.com/rime/squirrel/commit/d8b1dc569cc2c168f0fc5e8240ff6e049142fc24))
* **travis-ci:**  deploy release package ([c367b675](https://github.com/rime/squirrel/commit/c367b675bbca4f7e4467b71b9f42adbb888b77a5))



<a name="0.11.0"></a>
## 0.11.0 (2019-01-21)


#### 主要更新

* 安裝完成要求退出登錄，以保證註冊輸入法生效
* 修復升級、部署數據時發生的若干錯誤
* 關閉候選窗對摸蝦未系統深色模式的自動適配，以消除多餘的黑色邊框
* 新增 [拼寫糾錯](https://github.com/rime/librime/pull/228) 選項
  當前僅限 QWERTY 鍵盤佈局及使用 `script_translator` 的方案

#### Features

* **librime:**  update to librime 1.4.0 ([1f07c63c](https://github.com/rime/squirrel/commit/1f07c63c51f60ea5514819c0f3a05c33ee9aba5d))
* **pkg:**  logout after install ([c84001ea](https://github.com/rime/squirrel/commit/c84001ea4348b902543938d89d68306b1ea86b3f))
* **travis-ci:**  add Travis CI automated build ([8855101c](https://github.com/rime/squirrel/commit/8855101c0d90c118d4d1d58b757d11d76354bcda))

#### Bug Fixes

* **app:**  opt out of dark mode ([083817cb](https://github.com/rime/squirrel/commit/083817cba5ccb1f5b9589b7e7a2fbeca4ec4d9dd), closes [#273](https://github.com/rime/squirrel/issues/273))



<a name="0.10.0"></a>
## 0.10.0 (2019-01-01)


#### 主要更新

* 重新設計輸入法介面
* 新增介面配色方案：
  - 幽能／Psionics，作者：雨過之後、佛振，見於 [Rime 主頁](https://rime.im) 效果圖
  - 純粹的形式／Purity of Form
  - 純粹的本質／Purity of Essence
  - 冷漠／Apathy, 作者：LIANG Hai
  - 浮尘／Dust，作者：Superoutman
  - 沙漠夜／Mojave Dark，作者：xiehuc，使用新增的高亮區域圓角特性
  感謝所有 Rime 用家發揮創造力、參與輸入法的藝術加工。新的配色主題層出不窮。
  礙於能量有限，僅收錄了部分貢獻者的配色方案，以展示不同的設計思路和定製技巧。
  請大家利用各種平臺多多分享代碼。
* 改進對全屏遊戲的兼容性
* 修復了並擊輸入（chord-typing）的偶發錯誤
* 升級核心算法庫 [librime 1.3.2](https://github.com/rime/librime/blob/master/CHANGELOG.md#132-2018-11-12)
  * 支持 YAML 節點引用，方便模塊化配置
  * 改進部署流程，在 `build` 子目錄集中存放生成的數據文件
* 精簡安裝包預裝的輸入方案，更多方案可由 [東風破](https://github.com/rime/plum) 取得

#### Features

* **SquirrelPanel:**  add mojave_dark theme and hilited_corner_radius option ([51a1c8c8](https://github.com/rime/squirrel/commit/51a1c8c840cfc9093ad56777873c8a62abc4964f))
* **app icon:**  update app icon ([593ca16e](https://github.com/rime/squirrel/commit/593ca16ebc87852213348b55d1072d898af75ab6))
* **brise:**  new preset configuration; disable prebuilding binary data during install ([43f4eb0a](https://github.com/rime/squirrel/commit/43f4eb0a0f1551f385f517a24ba30ac364af2a8c))
* **chord:**  Tab, BackSpace, Return can be used as chording keys ([997f1539](https://github.com/rime/squirrel/commit/997f15396615de4a3f65e5595ce1f5edf75263a1))
* **data/squirrel.yaml:**  add two more color schemes ([48b5138c](https://github.com/rime/squirrel/commit/48b5138c53d30e433a5c4de95c7a366e51f94e2e))
* **install:**  preload minimal rime data, fetch packages in postinstall script ([d2b174c9](https://github.com/rime/squirrel/commit/d2b174c9bbb263f1cf0953ddb4a607e68525e396))
* **package:**  make package && make archive ([c350c086](https://github.com/rime/squirrel/commit/c350c086d7321157c955275bbc4cec02a7f9b9eb))
* **squirrel.yaml:**
  *  add color schemes `purity_of_essence`, `apathy`, `dust` ([246a5797](https://github.com/rime/squirrel/commit/246a5797c49bd941fff80523523935dcf3c9a14d))
  *  ascii mode by default in hyper.is ([bda9f48e](https://github.com/rime/squirrel/commit/bda9f48e9c49f2514b885e31cceca579204506c3))
* **submodules:**  switch to /plum/ ([56e62287](https://github.com/rime/squirrel/commit/56e62287004b3f4579c966ed654d92e1dfc51f5e))

#### Bug Fixes

* **SquirrelPanel:**
  *  highlight overlapping between adjacent candidates ([128c8f31](https://github.com/rime/squirrel/commit/128c8f310e70112282d445aa3716774850fc846c))
  *  fix rounding errors and highlight rounding corners correctly ([026c6980](https://github.com/rime/squirrel/commit/026c6980b5b5899c2f0b2be2c61d315cc49552c9), closes [#240](https://github.com/rime/squirrel/issues/240))
  *  display panel on top level in the proper way ([cee5c5d7](https://github.com/rime/squirrel/commit/cee5c5d70e523f4ab6c336dfd8941f7d7a7d3c35))
* **chord input:**  unfinished chord often caused by fast tap typing ([672af6c9](https://github.com/rime/squirrel/commit/672af6c972fcb99e532b171488ef0a4a3f06e985))
* **postinstall:**
  *  Revert "fix(postinstall): run rime-install preset packages" ([f0a2f45b](https://github.com/rime/squirrel/commit/f0a2f45bba81cafb5a67df09d4392750a38f0483), closes [#262](https://github.com/rime/squirrel/issues/262))
  *  run rime-install preset packages ([de8f32a2](https://github.com/rime/squirrel/commit/de8f32a2c00c4fac4cd0a23b80722e3129477086))
  *  run `Squirrel --install` as login user; do not update packages during installation ([66948afe](https://github.com/rime/squirrel/commit/66948afe6c50ef1a72a55abd505d2c8ceae4fe37))



<a name="0.9.26.2"></a>
## 鼠鬚管 0.9.26.2 (2014-12-23)

  * 修復：安裝後輸入法在一些 app 中無法啓用 [#43](https://github.com/lotem/squirrel/issues/43)

<a name="0.9.26.1"></a>
## 鼠鬚管 0.9.26.1 (2014-12-22)

  * 修復：0.9.26 版本設置 `translator/enable_user_dict: false` 發生崩潰

<a name="0.9.26"></a>
## 鼠鬚管 0.9.26 (2014-12-16)

#### 【鼠鬚管】變更集

  * 修復：在 Java 程序（如 IntelliJ IDEA）中不能輸入的問題
  * 修復：`app_options:` 在 OS X 10.10 Yosemite 下無效的問題

#### Rime 算法庫變更集

  * 變更：採用 LevelDB 格式的用戶詞典，舊的用戶詞典 `*.kct` 將在部署時升級
  * 優化：新的 `.bin` 固態詞典結構，可節省 20% ~ 50% 空間
  * 新增：中文／西文半角標點切換
  * 改進：摺疊方案選單中的狀態切換選項以顯示更多方案，按空格鍵或選 2 展開選項
  * 改進：向左右移動光標後，回退鍵（BackSpace）用於刪除編碼字符而非撤銷選詞
  * 修復：【地球拼音】兼作聲調的「,」鍵在其他情況下未識別爲逗號
  * 修復：`affix_segmentor` 選擇部分匹配的候選詞後應使標籤繼續有效
  * 修復：OpenCC 配置文件及詞典缺失時輸入法崩潰
  * 新增：`cjk_minifier` 可用作 filter 過濾拼音輸入法中的罕用字
  * 新增：`single_char_filter` 使字型輸入法中的候選單字優先於詞組
  * 新增：匹配編碼並自動上屏，配置項 `speller/auto_select_pattern:`

#### 【東風破】變更集

  * 新增：OpenCC 1.0 詞典及配置文件，提供繁→簡、簡→繁轉換及臺灣、香港用字標準
  * 新增：【拼音加加】雙拼方案，標識爲 `double_pinyin_pyjj`
  * 新增：【朙月拼音】【倉頡五代】用 `/a`、/1` 輸入特殊字符、數字
  * 修復：【注音】省略聲調時，音節切分歧義處理不當
  * 優化：【宮保拼音】自動清除無效的按鍵組合
  * 優化：`symbols.yaml` 調整常用字符的順序
  * 更新：【八股文】【朙月拼音】【地球拼音】【粵拼】【中古漢語拼音】

<a name="0.9.25"></a>
## 鼠鬚管 0.9.25 (2014-03-29)

#### Rime 算法庫變更集

  * 新增：中西文切換方式 `clear`，切換時清除未完成的輸入
  * 改進：長按 Shift（或 Control）鍵不觸發中西文切換
  * 改進：並擊輸入，若按回車鍵則上屏按鍵對應的字符
  * 改進：支持對用戶設定中的列表元素打補靪，例如 `switcher/@0/reset: 1`
  * 改進：缺少詞典源文件 `*.dict.yaml` 時利用固態詞典 `*.table.bin` 完成部署
  * 修復：自動組詞的詞典部署時未檢查【八股文】的變更，導致索引失效、候選字缺失
  * 修復：`comment_format` 會對候選註釋重複使用多次的BUG

#### 【東風破】變更集

  * 新增：快捷鍵 `Control+.` 切換中西文標點
  * 更新：【八股文】【朙月拼音】【地球拼音】【五筆畫】
  * 改進：【朙月拼音·語句流】`/0` ~ `/10` 輸入數字符號

<a name="0.9.24.2"></a>
## 鼠鬚管 0.9.24.2 (2013-12-25)

#### 【鼠鬚管】變更集

  * 修復：MySQL Workbench 崩潰

#### Rime 算法庫變更集

  * 更新：librime 升級到 1.1
  * 新增：固定方案選單排列順序的選項 `default.yaml`: `switcher/fix_schema_list_order: true`
  * 修復：正確匹配嵌套的“‘彎引號’”
  * 改進：碼表輸入法自動上屏及頂字上屏（[示例](https://gist.github.com/lotem/f879a020d56ef9b3b792)）<br/>
    若有 `speller/auto_select: true`，則選項 `speller/max_code_length:` 限定第N碼無重碼自動上屏
  * 優化：爲詞組自動編碼時，限制因多音字而產生的組合數目，避免窮舉消耗過量資源

#### 【東風破】變更集

  * 新增：【注音·臺灣正體】
  * 更新：【粵拼】匯入衆多粵語詞彙
  * 優化：調整部分異體字的字頻

<a name="0.9.23"></a>
## 鼠鬚管 0.9.23 (2013-12-01)

#### 【鼠鬚管】變更集

  * 新增：非嵌入式編碼行，`style/inline_preedit: false`
  * 變更：候選窗默認英文字體設爲 Lucida Grande，非嵌入模式中較爲美觀
  * 改進：高亮候選的背景色延伸到候選註釋區域，新增配色選項 `hilited_comment_text_color:`
  * 改進：提示（碼表輸入法）大字符集開關狀態「通用／增廣」
  * 修復：[Issue 509](https://code.google.com/p/rimeime/issues/detail?id=509) 打開方案選單時設定 `style/label_color` 被重置

#### Rime 算法庫變更集

  * 更新：librime 升級到 1.0
  * 修復：`table_translator` 按字符集過濾候選字，修正對 CJK-D 漢字的判斷

#### 【東風破】變更集

  * 優化：【粵拼】兼容[教育學院拼音方案](http://zh.wikipedia.org/wiki/%E6%95%99%E8%82%B2%E5%AD%B8%E9%99%A2%E6%8B%BC%E9%9F%B3%E6%96%B9%E6%A1%88)
  * 更新：`symbols.yaml` 由 Patricivs 重新整理符號表
  * 更新：Emoji 提供更加豐富的繪文字
  * 更新：【八股文】【朙月拼音】【地球拼音】【中古全拼】修正錯別字、註音錯誤

<a name="0.9.22"></a>
## 鼠鬚管 0.9.22 (2013-11-09)

#### 【鼠鬚管】變更集

  * 變更：不再支持 OS X 10.6，因切換到 libc++
  * 修復：安裝後重新登錄系統，鼠鬚管從輸入法列表中消失的BUG
  * 優化：更換狀態欄圖標，與系統自帶輸入法風格一致

#### Rime 算法庫變更集

  * 優化：同步用戶資料時自動備份自定義短語等 .txt 文件
  * 修復：【地球拼音】反查拼音失效的問題
  * 變更：編碼提示不再添加括弧（，）及逗號，可自行設定樣式

#### 輸入方案設計支持

  * 新增：`affix_segmentor` 分隔編碼的前綴、後綴
  * 改進：`translator` 支持匹配段落標籤
  * 改進：`simplifier` 支持多個實例，匹配段落標籤
  * 新增：`switches:` 輸入方案選項支持多選一
  * 新增：`reverse_lookup_filter` 爲候選字標註指定種類的輸入碼

#### 【東風破】變更集

  * 更新：【粵拼】補充大量單字的註音
  * 更新：【朙月拼音】【地球拼音】導入 Unihan 讀音資料
  * 改進：【地球拼音】【注音】啓用自定義短語
  * 修復：【朙月拼音·簡化字】通過快捷鍵 `Control+Shift+4` 簡繁切換
  * 改進：【倉頡五代】開啓繁簡轉換時，提示簡化字對應的傳統漢字
  * 變更：間隔號採用「·」`U+00B7`

<a name="0.9.21.1"></a>
## 鼠鬚管 0.9.21.1 (2013-10-09)

  * 修復：從上一個版本升級【倉頡】輸入方案不會自動更新的問題

<a name="0.9.21"></a>
## 鼠鬚管 0.9.21 (2013-10-06)

  * 新增：【倉頡】開啓自動造詞<br/>
    連續上屏的5字（依設定）以內的組合，或以連打方式上屏的短語，
    按構詞規則記憶爲新詞組；再次輸入該詞組的編碼時，顯示「☯」標記
  * 變更：【五筆】開啓自動造詞；從碼表中刪除與一級簡碼重碼的鍵名字
  * 變更：【地球拼音】當以簡拼輸入時，爲5字以內候選標註完整帶調拼音
  * 新增：【五筆畫】輸入方案（`stroke`），取代 `stroke_simp`
  * 新增：支持在輸入方案中設置介面樣式（`style:`）<br/>
    如字體、字號、橫排／直排等；配色方案除外
  * 改進：在 MacVim 中按 `^C` 或 `^[` 退出插入模式時自動切換輸入法
  * 改進：碼表輸入法連打，按 `Shift+BackSpace`、←鍵以字、詞爲單位回退
  * 修復：多次按「.」鍵翻頁後繼續輸入，不應視爲網址而在編碼中插入「.」
  * 修復：開啓候選字的字符集過濾，導致有時不出現連打候選詞的 BUG
  * 更新：修訂【八股文】詞典、【朙月拼音】【地球拼音】【粵拼】【吳語】
  * 更新：2013款 Rime 輸入法圖標

<a name="0.9.20.4"></a>
## 鼠鬚管 0.9.20.4 (2013-07-25)

  * 修復：原生配色方案候選序號顏色不正確

<a name="0.9.20.3"></a>
## 鼠鬚管 0.9.20.3 (2013-07-24)

  * 修復：0.9.20 版本引入【朙月拼音】詞典缺失詞組的BUG<br/>
    若其他詞典有相同問題，請刪除對應的 `.bin` 文件再重新部署
  * 修復：【地球拼音】「-」鍵輸入第一聲失效的BUG
  * 更新：`symbols.yaml` 增加一批特殊符號

<a name="0.9.20"></a>
## 鼠鬚管 0.9.20 (2013-07-24)

  * 新增：支持全角模式
  * 新增：【倉頡】按快趣取碼規則生成常用詞組
  * 更新：拼音、粵拼、中古漢語等輸入方案、繁簡轉換詞典
  * 修復：大陸與臺灣異讀的字「微」「檔」「蝸」「垃圾」等
  * 變更：設置 `show_notifications_when: never` 不再提示輸入法狀態
  * 修復：自定義中西文切換鍵 `Control+space` 無法切回中文模式
  * 修復：用戶詞典未能完整支持 `derive` 拼寫運算產生的歧義切分
  * 新增：（輸入方案設計用）干預多個 translator 之間的結果排序<br/>
    選項 `translator/initial_quality: 0`

<a name="0.9.19"></a>
## 鼠鬚管 0.9.19 (2013-06-24)

  * 新增：切換輸入法狀態時在光標處延時顯示當前狀態
  * 修復：無法同步／合併 Windows 系統下生成的用戶詞典快照
  * 改進：方案選單按選用輸入方案的時間排列
  * 新增：快捷鍵 Control+Shift+1 切換至下一個輸入方案
  * 新增：快捷鍵 Control+Shift+2~5 切換輸入模式
  * 改進：綜合候選詞的詞頻和詞條質量比較不同 translator 的結果
  * 修復：自定義短語不應參與組詞
  * 修復：「链」「坂」「喂」在簡化字模式下無法組詞（須清除用戶字頻）
  * 新增：對特定類型候選字不做繁簡轉換<br/>
    例如不轉換反查字 `simplifier/exclude_types: [ reverse_lookup ]`

<a name="0.9.18"></a>
## 鼠鬚管 0.9.18 (2013-04-26)

  * 新增：配色方案【曬經石】／Solarized Rock
  * 新增：Control+BackSpace 或 Shift+BackSpace 回退一個音節
  * 新增：固態詞典可引用多份碼表文件以實現分類詞庫
  * 新增：在輸入方案中加載翻譯器的多個具名實例
  * 新增：以選項 `translator/user_dict:` 指定用戶詞典的名稱
  * 新增：支持從用戶文件夾加載文本碼表作爲自定義短語詞典<br/>
    【朙月拼音】系列自動加載名爲 `custom_phrase.txt` 的碼表
  * 修復：繁簡轉換使無重碼自動上屏失效的 BUG
  * 修復：若非以 Caps Lock 鍵進入西文模式，
    按 Caps Lock 只切換大小寫，不返回中文模式
  * 變更：Alfred 2 初始進入西文模式
  * 變更：`r10n_translator` 更名爲 `script_translator`，舊名稱仍可使用
  * 變更：用戶詞典快照改爲文本格式
  * 改進：【八股文】導入《萌典》詞彙，並修正了不少錯詞
  * 改進：【倉頡五代】打單字時，以拉丁字母和倉頡字母並列顯示輸入碼
  * 改進：使自動生成的 YAML 文檔更合理地縮排、方便閱讀
  * 改進：碼表中 `# no comments` 行之後不再識別註釋，以支持 `#` 作文字內容
  * 改進：檢測到因斷電造成用戶詞典損壞時，自動在後臺線程恢復數據文件

<a name="0.9.17"></a>
## 鼠鬚管 0.9.17 (2013-01-31)

  * 改進：安裝完畢自動啓用鼠鬚管
  * 變更：Caps Lock 燈亮時默認輸出大寫字母 [Gist](https://gist.github.com/2981316)
  * 新增：支持設定候選行間距 `style/line_spacing:`
  * 新增：支持並擊輸入；並擊速度選項 `chord_duration:`<br/>
    並擊輸入方案【宮保拼音】
  * 新增：無重碼自動上屏 `speller/auto_select:`<br/>
    輸入方案【倉頡・快打模式】
  * 改進：允許以空格做輸入碼，或作爲符號頂字上屏<br/>
    `speller/use_space:`, `punctuator/use_space:`
  * 改進：【注音】輸入方案以空格輸入第一聲（陰平）
  * 新增：特殊符號表 `symbols.yaml` 用法見↙
  * 改進：【朙月拼音・簡化字】以 `/ts` 等形式輸入特殊符號
  * 改進：標點符號註明〔全角〕〔半角〕
  * 優化：同步用戶資料時更聰明地備份用戶自定義的 YAML 文件
  * 修復：避免創建、使用不完整的詞典文件
  * 修復：糾正用戶詞典中無法調頻的受損詞條

<a name="0.9.16"></a>
## 鼠鬚管 0.9.16 (2013-01-18)

  * 新增：支持設定候選序號的字體和顏色 `squirrel.yaml`
  * 改進：支持備用字體列表，以「`,`」分隔字體名稱
  * 改進：支持在配色方案中設定字體、窗口樣式等選項
  * 新增：預設配色方案「簡約白」by Chongyu Zhu
  * 新增：可選用 OS X 10.8 的通知中心顯示輸入法狀態通知
    感謝 Chongyu Zhu 爲鼠鬚管添加以上新功能。
  * 修復：手動升級後直到註銷登錄仍在使用舊版本的問題
  * 修復：0.9.15 版本安裝了錯誤的詞典文件</br>
    如果除【朙月拼音】外還有其他詞典用 0.9.15 版本編譯後出錯，
    請刪除用戶文件夾中對應的 `.bin` 文件，再用新版本部署。

<a name="0.9.15.1"></a>
## 鼠鬚管 0.9.15.1 (2013-01-17)

  * 新增：Caps Lock 點亮時，切換到西文模式，輸出小寫字母<br/>
    選項 `ascii_composer/switch_key/Caps_Lock:`
  * 新增：支持 Emacs 風格的編輯鍵 Control + 字母
  * 修復：一處內存泄漏
  * 修復：用戶詞典有可能因讀取時 I/O 錯誤導致部份詞序無法調整

<a name="0.9.14.5"></a>
## 鼠鬚管 0.9.14.5 (2013-01-10)

  * 新增：接收外部應用請求重新部署的通知，及命令行選項 Squirrel --reload
  * 修復：從 0.9.11 及更早的版本升級用戶詞典出錯</br>
    如果因此丟失詞彙，手動恢復的方法是：執行「同步用戶資料」

<a name="0.9.14"></a>
## 鼠鬚管 0.9.14 (2013-01-07)

  * 新增：同步用戶詞典，詳見 [Wiki » UserGuide](https://code.google.com/p/rimeime/wiki/UserGuide)
  * 新增：上屏錯誤的詞組後立即按回退鍵（BackSpace）撤銷組詞
  * 改進：拼音輸入法中，按左方向鍵以音節爲單位移動光標
  * 修復：【地球拼音】不能以 - 鍵輸入第一聲
  * 新增：設定候選字及序號格式的選項 `squirrel.yaml`: `style/candidate_format:`

<a name="0.9.13"></a>
## 鼠鬚管 0.9.13 (2012-12-26)

  * 優化：在編碼行分別標記已選定文字和未轉換的編碼
  * 修復：按左右鍵在編碼行移動插入焦點，光標位置更新不及時
  * 新增：切換狀態時是否顯示氣泡通知的選項 `show_notifications_when:`

<a name="0.9.12"></a>
## 鼠鬚管 0.9.12 (2012-12-23)

  * 新增：切換模式、輸入方案時彈出氣泡提示（安裝 Growl 效果最佳）
  * 新增：配色方案「Google」
  * 修復BUG：首次使用用戶目錄缺少 `squirrel.yaml`，部署之後才出現
  * 修復BUG：語句流輸入方案不記憶直接回車上屏的詞
  * 新增：分別以 `` ` ' `` 標誌編碼反查的開始結束，例如 `` `wbb'yuepinyin ``
  * 改進：形碼與拼音混打的設定下，降低簡拼候選的優先級，以降低對逐鍵提示的干擾
  * 優化：控制用戶詞典文件大小，提高大容量（詞條數>100,000）時的查詢速度
  * 刪除：因有用家向用戶詞典導入巨量詞條，故取消自動備份的功能，後續代之以用戶詞典同步

<a name="0.9.11"></a>
## 鼠鬚管 0.9.11 (2012-10-17)

  * 修復：選中的輸入方案、繁簡轉換等選項關機時不會保存的BUG
  * 變更：爲免除困惑，在代碼編輯器中恢復中文狀態（MacVim 除外）
  * 變更：部署快捷鍵由 Cmd+Option+R 改爲 Control+Option+`
  * 改進：部署時自動編譯輸入方案的自訂依賴項，如 emoji 表情
  * 改進：未曾翻頁時按減號鍵，不上屏候選字及符號「-」以免誤操作
  * 新增：開關碼表輸入法連打功能的設定項 `translator/enable_sentence`
  * 更新：《朙月拼音》《地球拼音》《粵拼》，修正多音字
  * 更新：《上海吳語》《上海新派》，修正註音
  * 新增：寒寒豆作《蘇州吳語》輸入方案，方案標識爲 `soutzoe`

<a name="0.9.10"></a>
## 鼠鬚管 0.9.10 (2012-09-19)

  * 修復：全新安裝無法建立用戶文件夾 `~/Library/Rime`
  * 修復：在 Quicksilver 中默認關閉漢字輸入的配置無效

<a name="0.9.9"></a>
## 鼠鬚管 0.9.9 (2012-09-17)

  * 新增：碼表輸入法啓用用戶詞典、字頻調整
  * 優化：自動編譯輸入方案依賴項，如五筆・拼音的反查詞典
  * 修改：日誌系統改用 glog，輸出到 `$TMPDIR/rime.squirrel.*`
  * 新增：針對特定程序禁用漢字輸入，如終端、代碼編輯器等
  * 優化：改進對 MacVim 命令模式的支持
  * 優化：適合 Retina 屏的輸入法圖標，感謝 leon.guan 幫忙！
  * 新增：【emoji表情】輸入方案，用法見 Wiki 《定製指南》
  * 更新：【明月拼音】【粵拼】【吳語】修正註音錯誤、缺字

<a name="0.9.8"></a>
## 鼠鬚管 0.9.8 (2012-07-08)

  * 新的 Rime logo
  * 新特性：碼表方案支持與反查碼混合輸入，無需切換或引導鍵
  * 新特性：碼表方案可在選單中使用字符集過濾開關
  * 新方案：【五筆86】衍生的【五筆・拼音】混合輸入
  * 新方案：《廣韻》音系的中古漢語全拼、三拼輸入法
  * 新方案：X-SAMPA 國際音標輸入法
  * 更新：【吳語】碼表，審定一些字詞的讀音，統一字形
  * 更新：【朙月拼音】碼表，修正多音字

<a name="0.9.7"></a>
## 鼠鬚管 0.9.7 (2012-06-10)

  * 提供指定候選窗邊界高度、寬度的選項 [Gist](https://gist.github.com/2290714)
  * 修復在 M$Office、BBEdit 等軟件中按Cmd鍵會清除選中文字的問題
  * 修復以 `rime_dict_manager` 導入文本碼表不生效的BUG（請升級該工具）；<br/>
    部署時檢查並修復已存在於用戶詞典中的無效條目
  * 檢測到用戶詞典文件損壞時重建詞典並從備份中恢復資料

<a name="0.9.6"></a>
## 鼠鬚管 0.9.6 (2012-06-0x)

  * 候選窗圓角效果、自定義色彩，感謝 waynezhang 貢獻代碼
  * 提供與【小狼毫】相當的一組配色方案
  * 新增「部署」熱鍵 Option+Command+R 、打開設定目錄的菜單項
  * 切換其他輸入法時，未完成的輸入立即上屏
  * 未經轉換的輸入如網址等不再顯示候選窗
  * 可於 `default.custom.yaml` 中設定全局的頁候選數
  * 可於導入【八股文】詞庫時限制詞語的長度、詞頻
  * 【倉頡】支持連續輸入多個字的編碼（不會記憶）
  * 【注音】改爲語句輸入風格，更接近臺灣用戶的習慣
  * 較少用的【筆順五碼】、【速記打字法】不再隨鼠鬚管發行
  * 修改BUG：簡拼 zhzh 因切分歧義使部分用戶詞失效

<a name="0.9.5"></a>
## 鼠鬚管 0.9.5 (2012-05-06)

  * 用 Shift+Del 刪除已記入用戶詞典的詞條，詳見 Issue 117
  * 可選用Shift或Control爲中西文切換鍵，詳見 Issue 133
  * 數字後的句號鍵識別爲小數點、分號鍵識別爲時分秒分隔符
  * 候選字的編碼提示以灰色顯示

<a name="0.9.4"></a>
## 鼠鬚管 0.9.4 (2012-04-15)

  * 探測失敗的啓動，預防設定不當導致持續崩潰、系統響應緩慢
  * 使用 `express_editor` 的輸入方案中，數字、符號鍵直接上屏
  * 輸入簡拼、模糊音時提示正音，【粵拼】【吳語】中默認開啓
  * 拼音反查支持預設的多音節詞、形碼反查可開啓編碼補全
  * 修復整句模式運用定長編碼頂字功能導致崩潰的問題
  * 修復碼表輸入法候選排序問題
  * 修復【朙月拼音】lo、yo 等音節的候選錯誤
  * 修復【地球拼音】聲調顯示不正確、部分字的註音缺失問題
  * 【五笔86】反查引導鍵改爲 z、反查詞典換用簡化字拼音
  * 更新【粵拼】詞典，調整常用粵字的排序、增補粵語常用詞
  * 新增輸入方案【筆順五碼】

<a name="0.9.3"></a>
## 鼠鬚管 0.9.3 (2012-04-04)

  * 支持非US鍵盤佈局
  * 支持多顯示器
  * 支持候選橫排
  * 支持自訂候選窗字體、字號、透明度
  * 通過語言欄菜單執行佈署操作
  * 通過Appcast檢查更新
  * 記憶繁簡轉換、全／半角符號開關狀態
  * 支持定長編碼頂字上屏
  * 延遲加載繁簡轉換、編碼反查詞典，降低資源佔用
  * 純單字構詞時不調頻
  * 新增輸入方案【速成】，速成、倉頡詞句連打
  * 新增【智能ABC雙拼】、【速記打字法】

<a name="0.9.2.1"></a>
## 鼠鬚管 0.9.2.1

  * 消除對第三方庫的依賴（用戶安裝失敗）
  * 新增安裝步驟：預編譯輸入方案，提升首次啓動速度

<a name="0.9.1"></a>
## 鼠鬚管 0.9.1

  * 新增備選輸入方案【注音】、【地球拼音】

<a name="0.9"></a>
## 鼠鬚管 0.9

  * 初試鋒芒
