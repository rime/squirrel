//
//  SquirrelInputHint.swift
//  Squirrel
//

import AppKit

struct SquirrelInputHintState {
  private var focusName: String?
  private var expiresAt = Date.distantPast

  static func modifierText(for modifiers: NSEvent.ModifierFlags) -> String {
    let keys: [(NSEvent.ModifierFlags, String)] = [
      (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")
    ]
    return keys.filter { modifiers.contains($0.0) }.map { $0.1 }.joined(separator: " ")
  }

  mutating func showFocus(name: String, duration: TimeInterval, now: Date = Date()) {
    focusName = name
    let seconds = duration.isFinite && duration > 0 ? duration : 2
    expiresAt = now.addingTimeInterval(seconds)
  }

  mutating func dismissFocus() {
    focusName = nil
  }

  mutating func text(modifiers: NSEvent.ModifierFlags, asciiMode: Bool,
                     showModifiers: Bool, showFocus: Bool, now: Date = Date()) -> String {
    if !showFocus || asciiMode || now >= expiresAt {
      dismissFocus()
    }
    let keys = showModifiers ? Self.modifierText(for: modifiers) : ""
    return [focusName ?? "", keys].filter { !$0.isEmpty }.joined(separator: "  ")
  }
}

struct SquirrelStatusMessageState {
  private var pending = ""
  private var active = ""

  mutating func queue(_ message: String) {
    pending = message
  }

  mutating func consume() -> Bool {
    guard !pending.isEmpty else { return false }
    active = pending
    pending = ""
    return true
  }

  mutating func expire() {
    active = ""
  }

  mutating func clear() {
    pending = ""
    expire()
  }

  func text(with hint: String) -> String {
    if !active.isEmpty && (hint == active || hint.hasPrefix(active + "  ")) {
      return hint
    }
    return [active, hint].filter { !$0.isEmpty }.joined(separator: "  ")
  }
}
