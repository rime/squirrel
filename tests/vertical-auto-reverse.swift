import AppKit

// Exercise the real panel, TextKit layout, config loader and hit testing without
// registering an input source or accessing the user's Rime directory.
final class SquirrelInputController {
  enum CommentKind { case commentHighlight, commentWarning }
  var specialCommentIndices: [CommentKind: Set<Int>] = [:]
  func selectCandidate(_ index: Int) -> Bool { true }
  func page(up: Bool) -> Bool { true }
  func moveCaret(forward: Bool) -> Bool { true }
}

@main
struct VerticalAutoReverseTests {
  static var assertions = 0

  static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    assertions += 1
  }

  @MainActor
  static func main() throws {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("squirrel-layout-\(UUID())")
    try FileManager.default.createDirectory(at: directory.appendingPathComponent("build"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let api = rime_get_api_stdbool().pointee
    var traits = RimeTraits.rimeStructInit()
    traits.setCString(directory.path, to: \.shared_data_dir)
    traits.setCString(directory.path, to: \.user_data_dir)
    traits.setCString(directory.path, to: \.log_dir)
    traits.min_log_level = 3
    api.setup(&traits)
    api.initialize(nil)
    defer { api.finalize() }

    func configure(_ panel: SquirrelPanel, enabled: Bool? = true, layout: String = "stacked",
                   orientation: String = "horizontal", override: Bool? = nil) throws {
      var yaml = """
      style:
        candidate_list_layout: \(layout)
        text_orientation: \(orientation)
        color_scheme: test
        color_scheme_dark: test
        font_point: 24
        label_font_point: 18
        comment_font_point: 16
        line_spacing: 6
        spacing: 8
        show_paging: true
        border_width: 4
        border_height: 4
        corner_radius: 6
        candidate_format: '[label]. [candidate] [comment]'
      """
      if let enabled { yaml += "\n  vertical_auto_reverse: \(enabled)" }
      yaml += "\npreset_color_schemes:\n  test:\n    name: Test\n    back_color: 0xffffff\n    hilited_candidate_back_color: 0xeeeeee\n"
      if let override { yaml += "    vertical_auto_reverse: \(override)\n" }
      try yaml.write(to: directory.appendingPathComponent("build/squirrel.yaml"), atomically: true, encoding: .utf8)
      let config = SquirrelConfig()
      check(config.openBaseConfig(), "fixture config must open")
      panel.load(config: config, forDarkMode: false)
      panel.load(config: config, forDarkMode: true)
      config.close()
    }

    func view(_ panel: SquirrelPanel) -> SquirrelView {
      panel.contentView!.subviews.compactMap { $0 as? SquirrelView }.first!
    }

    let words = ["首选", "第二项", "第三项", "第四项", "末项"]
    func update(_ panel: SquirrelPanel, words: [String] = words, preedit: String = "",
                highlighted: Int = 0, page: Int = 0, lastPage: Bool = false, labels: [String] = [], store: Bool = true) {
      panel.update(preedit: preedit, selRange: NSRange(location: 0, length: preedit.utf16.count), caretPos: 0,
                   candidates: words, comments: words.map { _ in "comment" }, labels: labels,
                   highlighted: highlighted, page: page, lastPage: lastPage, update: store)
      view(panel).display()
    }

    func verify(_ panel: SquirrelPanel, reversed: Bool, words: [String] = words) {
      let surface = view(panel)
      check(panel.isReversed == reversed, "unexpected reversal at \(panel.position)")
      check(surface.candidateRanges.count == words.count, "candidate count changed")
      let order = surface.candidateRanges.indices.sorted {
        surface.candidateRanges[$0].location < surface.candidateRanges[$1].location
      }
      check(order == (reversed ? Array(words.indices.reversed()) : Array(words.indices)), "wrong visual order")
      for index in words.indices {
        let range = surface.candidateRanges[index]
        let text = surface.textContentStorage.attributedString!.attributedSubstring(from: range).string
        check(text.contains(words[index]), "candidate identity lost at \(index)")
        var firstRect: CGRect?
        surface.textLayoutManager.enumerateTextSegments(in: surface.convert(range: range)!, type: .selection,
                                                      options: [.rangeNotRequired]) { _, rect, _, _ in
          firstRect = rect
          return false
        }
        let rect = firstRect!
        let point = CGPoint(x: rect.midX + surface.currentTheme.edgeInset.width + surface.currentTheme.pagingOffset,
                            y: rect.midY + surface.currentTheme.edgeInset.height)
        check(surface.click(at: point).0 == index, "mouse selects wrong candidate at \(index)")
      }
    }

    func snapshot(_ panel: SquirrelPanel, name: String) throws {
      guard let output = ProcessInfo.processInfo.environment["SQUIRREL_TEST_SCREENSHOTS"] else { return }
      let content = panel.contentView!
      let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
      content.cacheDisplay(in: content.bounds, to: bitmap)
      try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name + ".png"))
    }

    for screen in NSScreen.screens {
      let frame = screen.frame
      let bottom = NSRect(x: frame.midX, y: frame.minY + 20, width: 2, height: 24)
      let center = NSRect(x: frame.midX, y: frame.midY, width: 2, height: 24)
      let panel = SquirrelPanel(position: bottom)
      defer { panel.hide() }

      try configure(panel, enabled: nil)
      update(panel)
      verify(panel, reversed: false)

      try configure(panel)
      update(panel)
      verify(panel, reversed: true)
      check(panel.frame.minY >= bottom.maxY, "panel must be above caret")
      try snapshot(panel, name: "above")

      panel.position = center
      update(panel)
      verify(panel, reversed: false)
      check(panel.frame.maxY <= center.minY, "panel must be below caret")
      try snapshot(panel, name: "below")

      panel.position = bottom
      update(panel, highlighted: 3)
      verify(panel, reversed: true)
      check(view(panel).hilightedIndex == 3, "highlight must keep logical index")
      update(panel, highlighted: 1, store: false)
      verify(panel, reversed: true)
      check(view(panel).hilightedIndex == 1, "hover must keep logical index")

      update(panel, preedit: "ceshi", page: 1, lastPage: true, labels: ["a", "s", "d", "f", "g"])
      verify(panel, reversed: true)
      check(view(panel).preeditRange.location == 0, "preedit must remain at the top")
      let first = view(panel).candidateRanges[0]
      check(view(panel).textContentStorage.attributedString!.attributedSubstring(from: first).string.hasPrefix("a."), "custom labels changed")
      try snapshot(panel, name: "preedit")

      update(panel, words: [String(repeating: "换行候选", count: 14), "短词", "另一个词"])
      verify(panel, reversed: true, words: [String(repeating: "换行候选", count: 14), "短词", "另一个词"])
      try snapshot(panel, name: "wrapped")

      panel.position = NSRect(x: frame.midX, y: frame.minY + 100, width: 2, height: 24)
      update(panel)
      verify(panel, reversed: true)
      update(panel, words: ["首选"])
      verify(panel, reversed: false, words: ["首选"])

      panel.position = bottom
      try configure(panel, enabled: false)
      update(panel)
      verify(panel, reversed: false)
      try configure(panel, enabled: false, override: true)
      update(panel)
      verify(panel, reversed: true)
      try configure(panel, enabled: true, override: false)
      update(panel)
      verify(panel, reversed: false)

      try configure(panel, layout: "linear")
      update(panel)
      verify(panel, reversed: false)
      try configure(panel, orientation: "vertical")
      update(panel)
      check(!panel.isReversed, "vertical text must not reverse")

      try configure(panel)
      update(panel, words: Array(repeating: String(repeating: "超长候选", count: 15), count: 40))
      check(!panel.isReversed, "fullscreen panel must not reverse")
      update(panel)
      verify(panel, reversed: true)
      panel.updateStatus(long: "状态提示", short: "中")
      panel.hide()
      check(!panel.isReversed && !panel.isVisible, "hide must clear reversal")
      update(panel, words: [], lastPage: true)
      check(!panel.isReversed, "empty candidates must clear reversal")
      print("PASS screen \(frame)")
    }

    for (input, expected) in [(XK_Up, XK_Down), (XK_Down, XK_Up), (XK_KP_Up, XK_KP_Down), (XK_KP_Down, XK_KP_Up)] {
      check(SquirrelKeycode.reverseCandidateNavigation(UInt32(input), modifiers: 0) == UInt32(expected), "plain arrow direction")
      check(SquirrelKeycode.reverseCandidateNavigation(UInt32(input), modifiers: kLockMask.rawValue) == UInt32(expected), "caps lock arrow direction")
      for modifiers in [kShiftMask.rawValue, kControlMask.rawValue, kAltMask.rawValue, kSuperMask.rawValue, kReleaseMask.rawValue] {
        check(SquirrelKeycode.reverseCandidateNavigation(UInt32(input), modifiers: modifiers) == UInt32(input), "modified shortcut must stay unchanged")
      }
    }
    for input in [XK_space, XK_1, XK_2, XK_Left, XK_Right, XK_Prior, XK_Next, XK_Home, XK_End] {
      check(SquirrelKeycode.reverseCandidateNavigation(UInt32(input), modifiers: 0) == UInt32(input), "non-arrow key changed")
    }
    print("PASS \(assertions) assertions")
  }
}
