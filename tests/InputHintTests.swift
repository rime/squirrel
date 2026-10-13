import AppKit

@main
struct InputHintTests {
  static func main() {
    modifierText()
    focusLifecycle()
    statusLifecycle()
    print("Input hint tests passed")
  }

  static func modifierText() {
    let flags: [NSEvent.ModifierFlags] = [.control, .option, .shift, .command]
    let expected = [
      "", "⌃", "⌥", "⌃ ⌥", "⇧", "⌃ ⇧", "⌥ ⇧", "⌃ ⌥ ⇧",
      "⌘", "⌃ ⌘", "⌥ ⌘", "⌃ ⌥ ⌘", "⇧ ⌘", "⌃ ⇧ ⌘", "⌥ ⇧ ⌘", "⌃ ⌥ ⇧ ⌘"
    ]
    precondition(SquirrelInputHintState.modifierText(for: []) == "")
    for mask in expected.indices {
      var modifiers: NSEvent.ModifierFlags = [.capsLock, .numericPad, .function]
      for (index, flag) in flags.enumerated() where mask & (1 << index) != 0 {
        modifiers.insert(flag)
      }
      precondition(SquirrelInputHintState.modifierText(for: modifiers) == expected[mask])
    }
  }

  static func focusLifecycle() {
    let now = Date(timeIntervalSince1970: 100)
    var hint = SquirrelInputHintState()
    hint.showFocus(name: "朙月拼音", duration: 2, now: now)
    precondition(hint.text(modifiers: [], asciiMode: false, showModifiers: false, showFocus: true, now: now) == "朙月拼音")
    precondition(hint.text(modifiers: [.shift], asciiMode: false, showModifiers: true, showFocus: true, now: now) == "朙月拼音  ⇧")
    precondition(hint.text(modifiers: [.shift], asciiMode: false, showModifiers: true, showFocus: true,
                           now: now.addingTimeInterval(2)) == "⇧")
    hint.showFocus(name: "朙月拼音", duration: 5, now: now)
    precondition(hint.text(modifiers: [], asciiMode: false, showModifiers: false, showFocus: true,
                           now: now.addingTimeInterval(3)) == "朙月拼音")
    hint.dismissFocus()
    precondition(hint.text(modifiers: [.command], asciiMode: false, showModifiers: true, showFocus: true, now: now) == "⌘")
    hint.showFocus(name: "朙月拼音", duration: 2, now: now)
    precondition(hint.text(modifiers: [.shift], asciiMode: true, showModifiers: true, showFocus: true, now: now) == "⇧")
    precondition(hint.text(modifiers: [], asciiMode: false, showModifiers: true, showFocus: true, now: now).isEmpty)
    hint.showFocus(name: "朙月拼音", duration: 2, now: now)
    precondition(hint.text(modifiers: [], asciiMode: false, showModifiers: true, showFocus: false, now: now).isEmpty)
    hint.showFocus(name: "朙月拼音", duration: .nan, now: now)
    precondition(hint.text(modifiers: [], asciiMode: false, showModifiers: false, showFocus: true,
                           now: now.addingTimeInterval(2)).isEmpty)
  }

  static func statusLifecycle() {
    var status = SquirrelStatusMessageState()
    status.queue("英文")
    precondition(status.consume())
    precondition(!status.consume())
    precondition(status.text(with: "⇧") == "英文  ⇧")
    status.expire()
    precondition(status.text(with: "⇧") == "⇧")
    status.queue("朙月拼音")
    status.expire()
    precondition(status.consume())
    precondition(status.text(with: "朙月拼音") == "朙月拼音")
    precondition(status.text(with: "朙月拼音  ⇧") == "朙月拼音  ⇧")
    status.clear()
    precondition(!status.consume())
    precondition(status.text(with: "⇧") == "⇧")
  }

}
