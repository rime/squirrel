    鼠鬚管
    爲物雖微情不淺
    新詩醉墨時一揮
    別後寄我無辭遠

    　　　——歐陽修

今由　[中州韻輸入法引擎／Rime Input Method Engine](https://rime.im)
及其他開源技術強力驅動

【鼠鬚管】輸入法
===
[![Download](https://img.shields.io/github/v/release/rime/squirrel)](https://github.com/rime/squirrel/releases/latest)
[![Build Status](https://github.com/rime/squirrel/actions/workflows/commit-ci.yml/badge.svg)](https://github.com/rime/squirrel/actions/workflows)
[![GitHub Tag](https://img.shields.io/github/tag/rime/squirrel.svg)](https://github.com/rime/squirrel)

式恕堂 版權所無

授權條款：[GPL v3](https://www.gnu.org/licenses/gpl-3.0.en.html)

項目主頁：[rime.im](https://rime.im)

您可能還需要 Rime 用於其他操作系統的發行版：

  * 【中州韻】（ibus-rime、fcitx-rime）用於 Linux
  * 【小狼毫】用於 Windows

安裝輸入法
---

本品適用於 macOS 13.0+

初次安裝，如果在部份應用程序中打不出字，請註銷並重新登錄。

使用輸入法
---

選取輸入法指示器菜單裏的【ㄓ】字樣圖標，開始用鼠鬚管寫字。
通過快捷鍵 `` Ctrl+` `` 或 `F4` 呼出方案選單、切換輸入方式。

定製輸入法
---

定製方法，請參考線上 [幫助文檔](https://rime.im/docs/)。

使用系統輸入法菜單：

  * 選中「在線文檔」可打開以上網址
  * 編輯用戶設定後，選擇「重新部署」以令修改生效

### 修飾鍵提示

此功能預設關閉。在 `~/Library/Rime/squirrel.custom.yaml` 中加入以下設定並重新部署；
若已有 `patch`，只需在其中加入 `"modifier_hint/show": true`。

```yaml
patch:
  "modifier_hint/show": true
```

啓用後，按住 Control `⌃`、Option `⌥`、Shift `⇧` 或 Command `⌘` 時，
文字光標旁會顯示當前按住的組合，全部鬆開後隱藏。
提示整合於既有的中英文狀態提示視窗，使用候選字的字型與字號（`font_face`、`font_point`）。
有候選詞時，修飾鍵顯示於候選窗底部，不影響選詞；沒有候選詞時則顯示為狀態提示。

此功能只在鼠鬚管啓用期間生效，包括英文模式及無候選詞的情況。
應用若無法提供有效的文字光標位置，提示會隱藏；Caps Lock 和 Fn 不在提示範圍內。
設為 `false` 並重新部署即可關閉。

### 聚焦輸入框提示

此功能預設關閉。啓用後，聚焦輸入框且處於非英文模式時，光標旁會顯示當前輸入方案名稱。
切換回中文模式時，原有的「中」提示亦改為輸入方案名稱；英文提示保留原有標籤。
開始打字或超時後隱藏名稱；按住的修飾鍵仍可顯示。兩種提示與中英文切換訊息共用同一個狀態提示視窗、主題及候選字型。

在 `~/Library/Rime/squirrel.custom.yaml` 的 `patch` 中加入以下設定並重新部署：

```yaml
patch:
  "focus_hint/show": true
  "focus_hint/duration": 2
```

`duration` 是顯示秒數，預設為 2；可設為正數，例如 `1.5` 或 `3`。
設為 `"focus_hint/show": false` 可關閉。提示依賴應用提供輸入框啓用通知及有效光標位置。

安裝輸入方案
---

使用 [/plum/](https://github.com/rime/plum) 配置管理器獲取更多輸入方案。

致謝
---

輸入方案設計：

  * 【朙月拼音】系列

    感謝 CC-CEDICT、Android 拼音、新酷音、opencc 等開源項目

程序設計：

  * 佛振
  * Linghua Zhang
  * Chongyu Zhu
  * 雪齋
  * faberii
  * Chun-wei Kuo
  * Junlu Cheng
  * Jak Wings
  * xiehuc

美術：

  * 圖標設計 佛振、梁海、雨過之後
  * 配色方案 Aben、Chongyu Zhu、skoj、Superoutman、佛振、梁海

本品引用了以下開源軟件：

  * Boost C++ Libraries  (Boost Software License)
  * capnproto (MIT License)
  * darts-clone  (New BSD License)
  * google-glog  (New BSD License)
  * Google Test  (New BSD License)
  * LevelDB  (New BSD License)
  * librime  (New BSD License)
  * OpenCC / 開放中文轉換  (Apache License 2.0)
  * plum / 東風破 (GNU Lesser General Public License 3.0)
  * Sparkle  (MIT License)
  * UTF8-CPP  (Boost Software License)
  * yaml-cpp  (MIT License)

感謝王公子捐贈開發用機。

問題與反饋
---

發現程序有 BUG，或建議，或感想，請反饋到 [Rime 代碼之家討論區](https://github.com/rime/home/discussions)

聯繫方式
---

技術交流，歡迎光臨 [Rime 代碼之家](https://github.com/rime/home)，
或致信 Rime 開發者 <rimeime@gmail.com>。

謝謝
