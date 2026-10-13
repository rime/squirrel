import AppKit

@main
struct InputHintTests {
  static func main() {
    modifierText()
    focusLifecycle()
    statusLifecycle()
    disabledRuntime()
    eventDrivenRuntime()
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


  static func disabledRuntime() {
    let probe = HintProbe()
    let disabled = SquirrelInputHints.create(options: .init(showModifiers: false, showFocus: false)) {
      probe.dependencies()
    }
    precondition(disabled == nil)
    for _ in 0..<10_000 {
      disabled?.activate(modifiers: [.command])
      disabled?.dismissFocus()
      disabled?.update(modifiers: [.shift])
      disabled?.setAsciiMode(true)
      disabled?.deactivate()
    }
    precondition(probe.builds == 0 && probe.reads == 0 && probe.tasks.isEmpty && probe.texts.isEmpty)
    print("Disabled hints / 10,000 event sequences: 0 dependency builds, 0 reads, 0 timers, 0 renders")
  }

  static func eventDrivenRuntime() {
    let probe = HintProbe()
    let hints = SquirrelInputHints.create(options: .init(showModifiers: true, showFocus: true)) { probe.dependencies() }!
    hints.activate(modifiers: [.shift])
    precondition(probe.reads == 1 && probe.tasks.count == 1)
    precondition(probe.tasks[0].seconds == 2 && probe.texts.last == "朙月拼音  ⇧")
    probe.tasks[0].fire()
    precondition(probe.texts.last == "⇧" && probe.tasks.count == 1)
    hints.update(modifiers: [])
    precondition(probe.texts.last == "")
    hints.activate(modifiers: [])
    let typingTask = probe.tasks.last!
    hints.dismissFocus()
    hints.update(modifiers: [.command])
    precondition(typingTask.cancelled && probe.texts.last == "⌘")
    for _ in 0..<1_000 { hints.update(modifiers: [.command]) }
    precondition(probe.reads == 2 && probe.tasks.count == 2)
    hints.activate(modifiers: [])
    let modeTask = probe.tasks.last!
    hints.setAsciiMode(true)
    precondition(modeTask.cancelled && probe.texts.last == "")
    hints.activate(modifiers: [.shift])
    let blurTask = probe.tasks.last!
    hints.deactivate()
    precondition(blurTask.cancelled && probe.texts.last == "")

    let modifiers = HintProbe()
    let modifierOnly = SquirrelInputHints.create(options: .init(showModifiers: true, showFocus: false)) { modifiers.dependencies() }!
    modifierOnly.activate(modifiers: [.control])
    precondition(modifiers.reads == 0 && modifiers.tasks.isEmpty && modifiers.texts.last == "⌃")
    modifierOnly.update(modifiers: [])
    precondition(modifiers.texts.last == "" && modifiers.tasks.isEmpty)

    let focus = HintProbe()
    let focusOnly = SquirrelInputHints.create(options: .init(showModifiers: false, showFocus: true, focusDuration: 1.5)) {
      focus.dependencies()
    }!
    focusOnly.activate(modifiers: [.shift])
    precondition(focus.tasks.count == 1 && focus.tasks[0].seconds == 1.5 && focus.texts.last == "朙月拼音")
    focus.tasks[0].fire()
    precondition(focus.texts.last == "" && focus.tasks.count == 1)
    focus.name = nil
    focusOnly.activate(modifiers: [])
    precondition(focus.tasks.count == 1)
  }

}


private final class HintProbe {
  final class Task {
    let seconds: TimeInterval
    let action: () -> Void
    var cancelled = false
    private var fired = false

    init(seconds: TimeInterval, action: @escaping () -> Void) {
      self.seconds = seconds
      self.action = action
    }

    func fire() {
      guard !cancelled, !fired else { return }
      fired = true
      action()
    }
  }

  var builds = 0
  var reads = 0
  var name: String? = "朙月拼音"
  var texts: [String] = []
  var tasks: [Task] = []

  func dependencies() -> SquirrelInputHints.Dependencies {
    builds += 1
    return .init(readFocusName: { self.reads += 1; return self.name },
                 present: { self.texts.append($0) },
                 schedule: { seconds, action in
                   let task = Task(seconds: seconds, action: action)
                   self.tasks.append(task)
                   return { task.cancelled = true }
                 })
  }
}
