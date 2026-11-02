//
//  SquirrelInputHint.swift
//  Squirrel
//

import AppKit

struct SquirrelInputHintState {
  private var focusName: String?
  private var expiresAt = Date.distantPast
  var hasFocusName: Bool { focusName != nil }

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

struct SquirrelInputHintOptions: Equatable {
  let showModifiers: Bool
  let showFocus: Bool
  let focusDuration: TimeInterval

  init?(showModifiers: Bool, showFocus: Bool, focusDuration: TimeInterval = 2) {
    guard showModifiers || showFocus else { return nil }
    self.showModifiers = showModifiers
    self.showFocus = showFocus
    self.focusDuration = focusDuration.isFinite && focusDuration > 0 ? focusDuration : 2
  }
}

final class SquirrelInputHints {
  typealias Cancellation = () -> Void
  typealias Scheduler = (TimeInterval, @escaping () -> Void) -> Cancellation

  struct Dependencies {
    let readFocusName: () -> String?
    let present: (String) -> Void
    let schedule: Scheduler

    init(readFocusName: @escaping () -> String?, present: @escaping (String) -> Void,
         schedule: @escaping Scheduler = SquirrelInputHints.scheduleExpiry) {
      self.readFocusName = readFocusName
      self.present = present
      self.schedule = schedule
    }
  }

  let options: SquirrelInputHintOptions
  private let dependencies: Dependencies
  private var state = SquirrelInputHintState()
  private var modifiers: NSEvent.ModifierFlags = []
  private var asciiMode = false
  private var hasPresentedText = false
  private var cancelExpiry: Cancellation?

  static func create(options: SquirrelInputHintOptions?, dependencies: () -> Dependencies) -> SquirrelInputHints? {
    guard let options else { return nil }
    return SquirrelInputHints(options: options, dependencies: dependencies())
  }

  private init(options: SquirrelInputHintOptions, dependencies: Dependencies) {
    self.options = options
    self.dependencies = dependencies
  }

  func activate(modifiers: NSEvent.ModifierFlags) {
    dismissFocus()
    asciiMode = false
    self.modifiers = modifiers
    if options.showFocus, let name = dependencies.readFocusName(), !name.isEmpty {
      state.showFocus(name: name, duration: options.focusDuration)
      cancelExpiry = dependencies.schedule(options.focusDuration) { [weak self] in
        guard let self else { return }
        self.cancelExpiry = nil
        self.state.dismissFocus()
        self.refresh()
      }
    }
    refresh()
  }

  func dismissFocus() {
    guard state.hasFocusName || cancelExpiry != nil else { return }
    cancelExpiry?()
    cancelExpiry = nil
    state.dismissFocus()
  }

  func update(modifiers: NSEvent.ModifierFlags) {
    guard options.showModifiers || state.hasFocusName || hasPresentedText else { return }
    self.modifiers = modifiers
    refresh()
  }

  func setAsciiMode(_ enabled: Bool) {
    guard options.showFocus, enabled != asciiMode else { return }
    asciiMode = enabled
    if enabled {
      let hadFocusName = state.hasFocusName
      dismissFocus()
      if hadFocusName { refresh() }
    }
  }

  func deactivate() {
    dismissFocus()
    modifiers = []
    refresh()
  }

  private func refresh() {
    let text = state.text(modifiers: modifiers, asciiMode: asciiMode,
                          showModifiers: options.showModifiers, showFocus: options.showFocus)
    guard !text.isEmpty || hasPresentedText else { return }
    dependencies.present(text)
    hasPresentedText = !text.isEmpty
  }

  private static func scheduleExpiry(after seconds: TimeInterval, action: @escaping () -> Void) -> Cancellation {
    let timer = Timer(timeInterval: seconds, repeats: false) { _ in action() }
    RunLoop.main.add(timer, forMode: .common)
    return { timer.invalidate() }
  }

  deinit {
    cancelExpiry?()
  }
}
