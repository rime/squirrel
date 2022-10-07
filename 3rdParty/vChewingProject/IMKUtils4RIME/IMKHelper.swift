// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 注：該檔案的內容針對 RIME SQUIRREL 的開發需求做過調整，與威注音輸入法倉庫內建的檔案有所不同。

import Foundation
import InputMethodKit

// MARK: - IMKHelper by The vChewing Project (MIT License).

public enum IMKHelper {
  /// 威注音有專門統計過，實際上會有差異的英數鍵盤佈局只有這幾種。
  /// 精簡成這種清單的話，不但節省 SwiftUI 的繪製壓力，也方便使用者做選擇。
  public static let arrWhitelistedKeyLayoutsASCII: [String] = [
    "com.apple.keylayout.ABC",
    "com.apple.keylayout.ABC-AZERTY",
    "com.apple.keylayout.ABC-QWERTZ",
    "com.apple.keylayout.British",
    "com.apple.keylayout.Colemak",
    "com.apple.keylayout.Dvorak",
    "com.apple.keylayout.Dvorak-Left",
    "com.apple.keylayout.DVORAK-QWERTYCMD",
    "com.apple.keylayout.Dvorak-Right",
  ]

  public static let arrDynamicBasicKeyLayouts: [String] = [
    "com.apple.keylayout.ZhuyinBopomofo",
    "com.apple.keylayout.ZhuyinEten",
    // 不是威注音输入法，就不用插入威注音自己的 keylayouts 了。
  ]

  public static var currentBasicKeyboardLayout: String {
    get {
      UserDefaults.standard.string(forKey: "BasicKeyboardLayout") ?? ""
    } set {
      // 當且僅當輸入數值有效的時候，才會寫入數值。否則就無視之。
      if let _ = TISInputSource.generate(from: newValue) {
        UserDefaults.standard.set(newValue, forKey: "BasicKeyboardLayout")
      }
    }
  }

  public static var isDynamicBasicKeyboardLayoutEnabled: Bool {
    Self.arrDynamicBasicKeyLayouts.contains(currentBasicKeyboardLayout) || !currentBasicKeyboardLayout.isEmpty
  }

  public static var allowedAlphanumericalTISInputSources: [TISInputSource] {
    arrWhitelistedKeyLayoutsASCII.compactMap { TISInputSource.generate(from: $0) }
  }

  public static var allowedBasicLayoutsAsTISInputSources: [TISInputSource?] {
    // 為了保證清單順序，先弄兩個容器。
    var containerA: [TISInputSource?] = []
    var containerB: [TISInputSource?] = []
    var containerC: [TISInputSource?] = []

    let rawDictionary = TISInputSource.rawTISInputSources(onlyASCII: false)

    Self.arrWhitelistedKeyLayoutsASCII.forEach {
      if let neta = rawDictionary[$0], !arrDynamicBasicKeyLayouts.contains(neta.identifier) {
        containerC.append(neta)
      }
    }

    Self.arrDynamicBasicKeyLayouts.forEach {
      if let neta = rawDictionary[$0] {
        if neta.identifier.contains("com.apple") {
          containerA.append(neta)
        } else {
          containerB.append(neta)
        }
      }
    }

    // 這裡的 nil 是用來讓選單插入分隔符用的。
    if !containerA.isEmpty { containerA.append(nil) }
    if !containerB.isEmpty { containerB.append(nil) }

    return containerA + containerB + containerC
  }

  public struct CarbonKeyboardLayout {
    var strName: String = ""
    var strValue: String = ""
  }
}

// MARK: - 與輸入法的具體的安裝過程有關的命令

public extension IMKHelper {
  @discardableResult static func registerInputMethod() -> Int32 {
    TISInputSource.registerInputMethod() ? 0 : -1
  }
}

// MARK: - Apple Keyboard Converter

public extension NSEvent {
  func convertedFromPhonabets(ignoringModifiers: Bool = false) -> String {
    if type == .flagsChanged { return "" }
    var strProcessed = charactersIgnoringModifiers ?? characters ?? ""
    if !ignoringModifiers {
      strProcessed = characters ?? ""
    }
    if IMKHelper.isDynamicBasicKeyboardLayoutEnabled {
      // 針對不同的 Apple 動態鍵盤佈局糾正大寫英文輸入。
      switch IMKHelper.currentBasicKeyboardLayout {
      case "com.apple.keylayout.ZhuyinBopomofo":
        if strProcessed.count == 1, Character(strProcessed).isLowercase, Character(strProcessed).isASCII {
          strProcessed = strProcessed.uppercased()
        }
      case "com.apple.keylayout.ZhuyinEten":
        switch strProcessed {
        case "ａ": strProcessed = "A"
        case "ｂ": strProcessed = "B"
        case "ｃ": strProcessed = "C"
        case "ｄ": strProcessed = "D"
        case "ｅ": strProcessed = "E"
        case "ｆ": strProcessed = "F"
        case "ｇ": strProcessed = "G"
        case "ｈ": strProcessed = "H"
        case "ｉ": strProcessed = "I"
        case "ｊ": strProcessed = "J"
        case "ｋ": strProcessed = "K"
        case "ｌ": strProcessed = "L"
        case "ｍ": strProcessed = "M"
        case "ｎ": strProcessed = "N"
        case "ｏ": strProcessed = "O"
        case "ｐ": strProcessed = "P"
        case "ｑ": strProcessed = "Q"
        case "ｒ": strProcessed = "R"
        case "ｓ": strProcessed = "S"
        case "ｔ": strProcessed = "T"
        case "ｕ": strProcessed = "U"
        case "ｖ": strProcessed = "V"
        case "ｗ": strProcessed = "W"
        case "ｘ": strProcessed = "X"
        case "ｙ": strProcessed = "Y"
        case "ｚ": strProcessed = "Z"
        default: break
        }
      default: break
      }
      // 注音鍵群。
      switch strProcessed {
      case "ㄝ": strProcessed = ","
      case "ㄦ": strProcessed = "-"
      case "ㄡ": strProcessed = "."
      case "ㄥ": strProcessed = "/"
      case "ㄢ": strProcessed = "0"
      case "ㄅ": strProcessed = "1"
      case "ㄉ": strProcessed = "2"
      case "ˇ": strProcessed = "3"
      case "ˋ": strProcessed = "4"
      case "ㄓ": strProcessed = "5"
      case "ˊ": strProcessed = "6"
      case "˙": strProcessed = "7"
      case "ㄚ": strProcessed = "8"
      case "ㄞ": strProcessed = "9"
      case "ㄤ": strProcessed = ";"
      case "ㄇ": strProcessed = "a"
      case "ㄖ": strProcessed = "b"
      case "ㄏ": strProcessed = "c"
      case "ㄎ": strProcessed = "d"
      case "ㄍ": strProcessed = "e"
      case "ㄑ": strProcessed = "f"
      case "ㄕ": strProcessed = "g"
      case "ㄘ": strProcessed = "h"
      case "ㄛ": strProcessed = "i"
      case "ㄨ": strProcessed = "j"
      case "ㄜ": strProcessed = "k"
      case "ㄠ": strProcessed = "l"
      case "ㄩ": strProcessed = "m"
      case "ㄙ": strProcessed = "n"
      case "ㄟ": strProcessed = "o"
      case "ㄣ": strProcessed = "p"
      case "ㄆ": strProcessed = "q"
      case "ㄐ": strProcessed = "r"
      case "ㄋ": strProcessed = "s"
      case "ㄔ": strProcessed = "t"
      case "ㄧ": strProcessed = "u"
      case "ㄒ": strProcessed = "v"
      case "ㄊ": strProcessed = "w"
      case "ㄌ": strProcessed = "x"
      case "ㄗ": strProcessed = "y"
      case "ㄈ": strProcessed = "z"
      default: break
      }
      // 除了數字鍵區以外的標點符號。
      switch strProcessed {
      case "、": strProcessed = "\\"
      case "「": strProcessed = "["
      case "」": strProcessed = "]"
      case "『": strProcessed = "{"
      case "』": strProcessed = "}"
      case "，": strProcessed = "<"
      case "。": strProcessed = ">"
      default: break
      }
      // 摁了 SHIFT 之後的數字區的符號。
      switch strProcessed {
      case "！": strProcessed = "!"
      case "＠": strProcessed = "@"
      case "＃": strProcessed = "#"
      case "＄": strProcessed = "$"
      case "％": strProcessed = "%"
      case "︿": strProcessed = "^"
      case "＆": strProcessed = "&"
      case "＊": strProcessed = "*"
      case "（": strProcessed = "("
      case "）": strProcessed = ")"
      default: break
      }
      // 摁了 Alt 的符號。
      if strProcessed == "—" { strProcessed = "-" }
      // Apple 倚天注音佈局追加符號糾正項目。
      if IMKHelper.currentBasicKeyboardLayout == "com.apple.keylayout.ZhuyinEten" {
        switch strProcessed {
        case "＿": strProcessed = "_"
        case "：": strProcessed = ":"
        case "？": strProcessed = "?"
        case "＋": strProcessed = "+"
        case "｜": strProcessed = "|"
        default: break
        }
      }
      // 糾正 macOS 內建的的動態注音鍵盤佈局的一個 bug。
      if "-·".contains(strProcessed), keyCode == 50 {
        strProcessed = "`"
      }
    }
    return strProcessed
  }
}
