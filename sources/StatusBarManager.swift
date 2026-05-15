//
//  StatusBarManager.swift
//  Squirrel
//

import AppKit

final class StatusBarManager {
  private var statusItem: NSStatusItem?

  deinit {
    teardown()
  }

  /// 根据配置初始化或销毁菜单栏图标
  /// - Parameters:
  ///   - enabled: true 创建状态项，false 移除
  ///   - initialText: 初始显示的文本，默认为空字符串
  func setup(enabled: Bool, initialText: String = "") {
    if enabled {
      if statusItem == nil {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      }
      if !initialText.isEmpty {
        statusItem?.button?.title = initialText
      }
    } else {
      teardown()
    }
  }

  /// 更新菜单栏显示的文本
  /// - Parameter text: 要显示的文本，如 "中" 或 "A"
  func updateStatus(text: String) {
    statusItem?.button?.title = text
  }

  /// 清理资源，从菜单栏移除状态项
  func teardown() {
    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
      statusItem = nil
    }
  }
}
