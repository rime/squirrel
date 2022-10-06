// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// 注：該檔案的內容針對 RIME SQUIRREL 的開發需求做過調整，與威注音輸入法倉庫內建的檔案有所不同。

import Cocoa

// MARK: NSRect Extension

public extension NSRect {
  static var seniorTheBeast: NSRect {
    NSRect(x: 0.0, y: 0.0, width: 0.114, height: 0.514)
  }
}

public extension NSApplication {
  // MARK: - System Dark Mode Status Detector.

  static var isDarkMode: Bool {
    if #available(macOS 10.14, *) {} else { return false }
    if #available(macOS 10.15, *) {
      let appearanceDescription = NSApplication.shared.effectiveAppearance.debugDescription
        .lowercased()
      return appearanceDescription.contains("dark")
    } else if let appleInterfaceStyle = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
      return appleInterfaceStyle.lowercased().contains("dark")
    }
    return false
  }

  // MARK: - Tell whether this IME is running with Root privileges.

  static var isSudoMode: Bool {
    NSUserName() == "root"
  }
}

// MARK: - Real Home Dir for Sandboxed Apps

public extension FileManager {
  /// 如果輸入法有做過 Sandbox 處理的話，那麼這個命令會派上用場。
  static let realHomeDir = URL(
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir, isDirectory: true, relativeTo: nil
  )
}

// MARK: - Trash a file if it exists.

public extension FileManager {
  @discardableResult static func trashTargetIfExists(_ path: String) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: path) {
        // 塞入垃圾桶
        try FileManager.default.trashItem(
          at: URL(fileURLWithPath: path), resultingItemURL: nil
        )
      } else {
        NSLog("Item doesn't exist: \(path)")
      }
    } catch let error as NSError {
      NSLog("Failed from removing this object: \(path) || Error: \(error)")
      return false
    }
    return true
  }
}
