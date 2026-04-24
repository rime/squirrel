//
//  QuickAddWordPanel.swift
//  Squirrel
//
//  Created by Codex on 4/23/26.
//

import AppKit

/// Receives events from the quick add word panel.
protocol QuickAddWordPanelDelegate: AnyObject {
  /// Handles a confirmed quick-add request with validated UI values.
  func quickAddWordPanel(_ panel: QuickAddWordPanel, didConfirmWord word: String, code: String)
  /// Handles panel dismissal through cancel actions.
  func quickAddWordPanelDidCancel(_ panel: QuickAddWordPanel)
}

/// Provides a small floating panel for quickly collecting phrase and code values.
final class QuickAddWordPanel: NSObject, NSWindowDelegate {
  private let panel: NSWindow
  private let wordField: NSTextField
  private let codeField: NSTextField
  weak var delegate: QuickAddWordPanelDelegate?

  /// Creates the quick add word panel and all form controls.
  override init() {
    panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 220), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    wordField = NSTextField(frame: .zero)
    codeField = NSTextField(frame: .zero)
    super.init()
    setupPanel()
  }

  /// Displays the panel and optionally pre-fills form fields.
  func show(prefillWord: String?, prefillCode: String?) {
    wordField.stringValue = prefillWord ?? ""
    codeField.stringValue = prefillCode ?? ""
    panel.center()
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
    if wordField.stringValue.isEmpty {
      panel.makeFirstResponder(wordField)
    } else {
      panel.makeFirstResponder(codeField)
    }
  }

  /// Hides the panel if it is currently visible.
  func hide() {
    panel.orderOut(nil)
  }

  /// Forwards close-window behavior to the cancel delegate callback.
  func windowWillClose(_ notification: Notification) {
    delegate?.quickAddWordPanelDidCancel(self)
  }
}

private extension QuickAddWordPanel {
  /// Builds panel controls and binds buttons to selector actions.
  func setupPanel() {
    panel.isReleasedWhenClosed = false
    panel.title = "快速加词"
    panel.delegate = self
    panel.hidesOnDeactivate = false
    panel.level = .normal
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
    panel.contentView = contentView

    let wordLabel = NSTextField(labelWithString: "词条")
    wordLabel.frame = NSRect(x: 24, y: 152, width: 60, height: 22)
    contentView.addSubview(wordLabel)

    wordField.frame = NSRect(x: 88, y: 148, width: 340, height: 24)
    wordField.placeholderString = "请输入词条"
    contentView.addSubview(wordField)

    let codeLabel = NSTextField(labelWithString: "编码")
    codeLabel.frame = NSRect(x: 24, y: 110, width: 60, height: 22)
    contentView.addSubview(codeLabel)

    codeField.frame = NSRect(x: 88, y: 106, width: 340, height: 24)
    codeField.placeholderString = "请输入编码"
    contentView.addSubview(codeField)

    let cancelButton = NSButton(frame: NSRect(x: 248, y: 44, width: 84, height: 32))
    cancelButton.title = "取消"
    cancelButton.keyEquivalent = "\u{1b}"
    cancelButton.bezelStyle = .rounded
    cancelButton.target = self
    cancelButton.action = #selector(cancel)
    contentView.addSubview(cancelButton)

    let confirmButton = NSButton(frame: NSRect(x: 344, y: 44, width: 84, height: 32))
    confirmButton.title = "确定"
    confirmButton.keyEquivalent = "\r"
    confirmButton.bezelStyle = .rounded
    confirmButton.target = self
    confirmButton.action = #selector(confirm)
    contentView.addSubview(confirmButton)
  }

  /// Emits a confirm event with trimmed form values.
  @objc func confirm() {
    let word = wordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let code = codeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    delegate?.quickAddWordPanel(self, didConfirmWord: word, code: code)
  }

  /// Emits a cancel event and hides the panel.
  @objc func cancel() {
    panel.close()
  }
}
