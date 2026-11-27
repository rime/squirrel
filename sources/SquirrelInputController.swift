//
//  SquirrelInputController.swift
//  Squirrel
//
//  Created by Leo Liu on 5/7/24.
//

import InputMethodKit

final class SquirrelInputController: IMKInputController {
  private static let keyRollOver = 50
  private static var unknownAppCnt: UInt = 0

  private weak var client: IMKTextInput?
  private let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  private var preedit: String = ""
  private var selRange: NSRange = .empty
  private var caretPos: Int = 0
  private var lastModifiers: NSEvent.ModifierFlags = .init()
  private var session: RimeSessionId = 0
  private var schemaId: String = ""
  private var inlinePreedit = false
  private var inlineCandidate = false
  private var chordKeyCodes: [UInt32] = .init(repeating: 0, count: SquirrelInputController.keyRollOver)
  private var chordModifiers: [UInt32] = .init(repeating: 0, count: SquirrelInputController.keyRollOver)
  private var chordKeyCount: Int = 0
  private var chordTimer: Timer?
  private var chordDuration: TimeInterval = 0
  private var currentApp: String = ""

  private var isGridExpanded = false
  private var gridActiveRow = 0
  private var gridActiveCellIndex = 0
  private var gridPreferredCenterX: CGFloat?
  private var gridViewportTopRow = 0
  private var gridHoveredGlobalIndex: Int?
  private var gridCompositionKey = ""
  private var gridCompositionID = 0
  private var gridCandidates: [SquirrelGridCandidate] = []
  private var gridHasMore = false
  private var gridSelectLabels: [String] = []
  private var gridRimePageSize = 5
  private var gridCurrentLayout: SquirrelGridLayout?
  private var gridPanelPreedit = ""
  private var gridPanelSelRange: NSRange = .empty
  private var gridPanelCaretPos = 0

  // swiftlint:disable:next cyclomatic_complexity
  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event else { return false }
    let modifiers = event.modifierFlags
    let changes = lastModifiers.symmetricDifference(modifiers)

    // Return true to consume the key event; return false to pass it to the client app.
    var handled = false

    if session == 0 || !rimeAPI.find_session(session) {
      createSession()
      if session == 0 {
        return false
      }
    }

    self.client ?= sender as? IMKTextInput
    if let app = client?.bundleIdentifier(), currentApp != app {
      currentApp = app
      updateAppOptions()
    }

    switch event.type {
    case .flagsChanged:
      if lastModifiers == modifiers {
        handled = true
        break
      }
      var rimeModifiers: UInt32 = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
      // Some remote desktop tools send flagsChanged with keyCode 0; infer the real modifier key when needed.
      var keyCode = event.keyCode
      if !SquirrelKeycode.modifierKeycodes.contains(keyCode) {
        guard let inferred = SquirrelKeycode.inferModifierKeycode(from: changes) else {
          lastModifiers = modifiers
          rimeUpdate()
          handled = true
          break
        }
        keyCode = inferred
      }
      let rimeKeycode: UInt32 = SquirrelKeycode.osxKeycodeToRime(keycode: keyCode, keychar: nil, shift: false, caps: false)

      if changes.contains(.capsLock) {
        // Rime expects XK_Caps_Lock before the lock mask changes; NSFlagsChanged has already applied it.
        rimeModifiers ^= kLockMask.rawValue
        _ = processKey(rimeKeycode, modifiers: rimeModifiers)
      }

      // Process releases first because some modifier releases arrive with the next keydown.
      var buffer = [(keycode: UInt32, modifier: UInt32)]()
      for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] where changes.contains(flag) {
        if modifiers.contains(flag) {
          buffer.append((keycode: rimeKeycode, modifier: rimeModifiers))
        } else {
          buffer.insert((keycode: rimeKeycode, modifier: rimeModifiers | kReleaseMask.rawValue), at: 0)
        }
      }
      for (keycode, modifier) in buffer {
        _ = processKey(keycode, modifiers: modifier)
      }

      lastModifiers = modifiers
      rimeUpdate()

    case .keyDown:
      // Let client apps handle Command shortcuts.
      if modifiers.contains(.command) {
        break
      }

      let keyCode = event.keyCode
      var keyChars = event.charactersIgnoringModifiers
      let capitalModifiers = modifiers.isSubset(of: [.shift, .capsLock])
      if let code = keyChars?.first,
         (capitalModifiers && !code.isLetter) || (!capitalModifiers && !code.isASCII) {
        keyChars = event.characters
      }
      if let char = keyChars?.first {
        let rimeKeycode = SquirrelKeycode.osxKeycodeToRime(keycode: keyCode, keychar: char,
                                                           shift: modifiers.contains(.shift),
                                                           caps: modifiers.contains(.capsLock))
        if rimeKeycode != 0 {
          let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
          if handleGridKey(rimeKeycode, modifiers: rimeModifiers, eventModifiers: modifiers) {
            handled = true
            break
          }
          handled = processKey(rimeKeycode, modifiers: rimeModifiers)
          rimeUpdate()
        }
      }

    default:
      break
    }

    return handled
  }

  func selectCandidate(_ index: Int) -> Bool {
    let success = rimeAPI.select_candidate_on_current_page(session, index)
    if success {
      rimeUpdate()
    }
    return success
  }

  // swiftlint:disable:next identifier_name
  func page(up: Bool) -> Bool {
    var handled = false
    handled = rimeAPI.change_page(session, up)
    if handled {
      rimeUpdate()
    }
    return handled
  }

  func moveCaret(forward: Bool) -> Bool {
    let currentCaretPos = rimeAPI.get_caret_pos(session)
    guard let input = rimeAPI.get_input(session) else { return false }
    if forward {
      if currentCaretPos <= 0 {
        return false
      }
      rimeAPI.set_caret_pos(session, currentCaretPos - 1)
    } else {
      let inputStr = String(cString: input)
      if currentCaretPos >= inputStr.utf8.count {
        return false
      }
      rimeAPI.set_caret_pos(session, currentCaretPos + 1)
    }
    rimeUpdate()
    return true
  }

  override func recognizedEvents(_ sender: Any!) -> Int {
    return Int(NSEvent.EventTypeMask.Element(arrayLiteral: .keyDown, .flagsChanged).rawValue)
  }

  override func activateServer(_ sender: Any!) {
    self.client ?= sender as? IMKTextInput
    var keyboardLayout = NSApp.squirrelAppDelegate.config?.getString("keyboard_layout") ?? ""
    if keyboardLayout == "last" || keyboardLayout == "" {
      keyboardLayout = ""
    } else if keyboardLayout == "default" {
      keyboardLayout = "com.apple.keylayout.ABC"
    } else if !keyboardLayout.hasPrefix("com.apple.keylayout.") {
      keyboardLayout = "com.apple.keylayout.\(keyboardLayout)"
    }
    if keyboardLayout != "" {
      client?.overrideKeyboard(withKeyboardNamed: keyboardLayout)
    }
    // Activation delivers no flagsChanged event, and NSEvent.modifierFlags
    // only reflects this process's own event stream, so lastModifiers may
    // disagree with the actual Caps Lock state by now. Seed it from the
    // session-wide hardware state; otherwise the next Caps Lock press can
    // compare equal to the stale lastModifiers and be dropped by the
    // early-return in handle().
    if CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift) {
      lastModifiers.insert(.capsLock)
    } else {
      lastModifiers.remove(.capsLock)
    }
    preedit = ""
    if session != 0 {
      let state = rimeAPI.get_option(session, "ascii_mode")
      let label = rimeAPI.get_state_label_abbreviated(session, "ascii_mode", state, true).asString
      NSApp.squirrelAppDelegate.updateStatusIcon(asciiMode: state, schemaLabel: label)
    }
  }

  override init!(server: IMKServer!, delegate: Any!, client: Any!) {
    self.client = client as? IMKTextInput
    super.init(server: server, delegate: delegate, client: client)
    createSession()

    NotificationCenter.default.addObserver(
      forName: .init("SquirrelSetASCIIModeNotification"),
      object: nil,
      queue: nil
    ) { [weak self] notification in
      self?.handleASCIIModeToggle(notification)
    }

    NotificationCenter.default.addObserver(
      forName: .init("SquirrelReportASCIIModeNotification"),
      object: nil,
      queue: nil
    ) { [weak self] notification in
      self?.reportASCIIMode(notification)
    }
  }

  override func deactivateServer(_ sender: Any!) {
    hidePalettes()
    commitComposition(sender)
    client = nil
  }

  override func hidePalettes() {
    resetGridState()
    gridCompositionKey = ""
    NSApp.squirrelAppDelegate.panel?.hide()
    super.hidePalettes()
  }

  override func commitComposition(_ sender: Any!) {
    resetGridState()
    gridCompositionKey = ""
    self.client ?= sender as? IMKTextInput
    if session != 0 {
      if let input = rimeAPI.get_input(session) {
        commit(string: String(cString: input))
        rimeAPI.clear_composition(session)
      }
    }
  }

  override func menu() -> NSMenu! {
    let deploy = NSMenuItem(title: NSLocalizedString("Deploy", comment: "Menu item"), action: #selector(deploy), keyEquivalent: "`")
    deploy.target = self
    deploy.keyEquivalentModifierMask = [.control, .option]
    let sync = NSMenuItem(title: NSLocalizedString("Sync user data", comment: "Menu item"), action: #selector(syncUserData), keyEquivalent: "")
    sync.target = self
    let logDir = NSMenuItem(title: NSLocalizedString("Logs...", comment: "Menu item"), action: #selector(openLogFolder), keyEquivalent: "")
    logDir.target = self
    let setting = NSMenuItem(title: NSLocalizedString("Settings...", comment: "Menu item"), action: #selector(openRimeFolder), keyEquivalent: "")
    setting.target = self
    let wiki = NSMenuItem(title: NSLocalizedString("Rime Wiki...", comment: "Menu item"), action: #selector(openWiki), keyEquivalent: "")
    wiki.target = self
    let update = NSMenuItem(title: NSLocalizedString("Check for updates...", comment: "Menu item"), action: #selector(checkForUpdates), keyEquivalent: "")
    update.target = self

    let menu = NSMenu()
    menu.addItem(deploy)
    menu.addItem(sync)
    menu.addItem(logDir)
    menu.addItem(setting)
    menu.addItem(wiki)
    menu.addItem(update)

    return menu
  }

  @objc func deploy() {
    NSApp.squirrelAppDelegate.deploy()
  }

  @objc func syncUserData() {
    NSApp.squirrelAppDelegate.syncUserData()
  }

  @objc func openLogFolder() {
    NSApp.squirrelAppDelegate.openLogFolder()
  }

  @objc func openRimeFolder() {
    NSApp.squirrelAppDelegate.openRimeFolder()
  }

  @objc func checkForUpdates() {
    NSApp.squirrelAppDelegate.checkForUpdates()
  }

  @objc func openWiki() {
    NSApp.squirrelAppDelegate.openWiki()
  }

  private(set) var specialCommentIndices: [ReservedPropertyKey: Set<Int>] = [:]

  func handleReservedProperty(key rawKey: String, value rawValue: String, for sessionId: RimeSessionId) throws(ReservedPropertyError) {
    guard session == sessionId, session != 0, rimeAPI.find_session(session) else { return }
    guard let key = ReservedPropertyKey(rawValue: rawKey) else { throw .unknownInput(rawKey) }
    let parsed = try ReservedPropertyValue.parse(rawValue)
    switch key {
    case .commentHighlight:
      specialCommentIndices[.commentHighlight] = try parsed.indices()
    case .commentWarning:
      specialCommentIndices[.commentWarning] = try parsed.indices()
    case .refreshUI:
      rimeUpdate(clearReservedComments: false)
    }
  }

  func selectGridCandidate(globalIndex: Int) -> Bool {
    guard session != 0 else { return false }
    let success = rimeAPI.select_candidate(session, globalIndex)
    if success {
      resetGridState()
      gridCompositionKey = ""
      rimeUpdate()
    }
    return success
  }

  func toggleGridExpanded() {
    guard let panel = NSApp.squirrelAppDelegate.panel, panel.isExpandableGridEnabled, !gridCandidates.isEmpty else { return }
    let currentGlobalIndex = gridCurrentLayout.map { $0.allRows[$0.activeRow].cells[$0.activeCellIndexInRow].globalIndex }
    if isGridExpanded {
      isGridExpanded = false
      gridActiveRow = 0
      gridViewportTopRow = 0
      gridPreferredCenterX = nil
      if let layout = rebuildGridLayout(panel: panel),
         let target = currentGlobalIndex,
         let pos = locateGridCandidate(target, in: layout),
         pos.row == 0 {
        gridActiveCellIndex = pos.cell
      } else {
        gridActiveCellIndex = 0
      }
      syncGridHighlightAndRefresh()
    } else {
      isGridExpanded = true
      let targetCount = max(gridCandidates.count, (panel.gridVisibleRowsConfig + 4) * effectiveGridMaxColumns(panel))
      fetchGridCandidates(minCount: targetCount)
      if let layout = rebuildGridLayout(panel: panel),
         let target = currentGlobalIndex,
         let pos = locateGridCandidate(target, in: layout) {
        gridActiveRow = pos.row
        gridActiveCellIndex = pos.cell
        let cell = layout.allRows[pos.row].cells[pos.cell]
        gridPreferredCenterX = cell.xOffset + cell.width / 2
        updateGridViewport(totalRows: layout.allRows.count, panel: panel)
      }
      syncGridHighlightAndRefresh()
    }
  }

  func scrollGrid(rows delta: Int) {
    guard let panel = NSApp.squirrelAppDelegate.panel, panel.isExpandableGridEnabled, !gridCandidates.isEmpty, delta != 0 else { return }
    let maxCols = effectiveGridMaxColumns(panel)
    if !isGridExpanded {
      guard delta > 0, (gridHasMore || (gridCurrentLayout?.allRows.count ?? 1) > 1) else { return }
      isGridExpanded = true
      fetchGridCandidates(minCount: max(gridCandidates.count, (panel.gridVisibleRowsConfig + 4) * maxCols))
    }
    if delta > 0 {
      ensureRowsLoaded(throughRow: gridActiveRow + panel.gridVisibleRowsConfig + 3, maxCols: maxCols)
    }
    guard let layout = rebuildGridLayout(panel: panel) else { return }
    if gridPreferredCenterX == nil {
      let curCell = layout.allRows[layout.activeRow].cells[layout.activeCellIndexInRow]
      gridPreferredCenterX = curCell.xOffset + curCell.width / 2
    }
    let newRow = max(0, min(layout.allRows.count - 1, gridActiveRow + delta))
    gridActiveRow = newRow
    gridActiveCellIndex = cellIndexInRow(layout.allRows[newRow], matchingCenterX: gridPreferredCenterX)
    updateGridViewport(totalRows: layout.allRows.count, panel: panel)
    syncGridHighlightAndRefresh()
  }

  func setGridHover(globalIndex: Int?) {
    guard gridHoveredGlobalIndex != globalIndex else { return }
    gridHoveredGlobalIndex = globalIndex
    refreshGridPanelOnly()
  }

  deinit {
    destroySession()
  }
}

private extension SquirrelInputController {

  func onChordTimer(_: Timer) {
    var processedKeys = false
    if chordKeyCount > 0 && session != 0 {
      // Chord typing releases are synthesized after the configured timeout.
      for i in 0..<chordKeyCount {
        let handled = rimeAPI.process_key(session, Int32(chordKeyCodes[i]), Int32(chordModifiers[i] | kReleaseMask.rawValue))
        if handled {
          processedKeys = true
        }
      }
    }
    clearChord()
    if processedKeys {
      rimeUpdate()
    }
  }

  func updateChord(keycode: UInt32, modifiers: UInt32) {
    for i in 0..<chordKeyCount where chordKeyCodes[i] == keycode {
      return
    }
    if chordKeyCount >= Self.keyRollOver {
      return
    }
    chordKeyCodes[chordKeyCount] = keycode
    chordModifiers[chordKeyCount] = modifiers
    chordKeyCount += 1
    if let timer = chordTimer, timer.isValid {
      timer.invalidate()
    }
    chordDuration = 0.1
    if let duration = NSApp.squirrelAppDelegate.config?.getDouble("chord_duration"), duration > 0 {
      chordDuration = duration
    }
    chordTimer = Timer.scheduledTimer(withTimeInterval: chordDuration, repeats: false, block: onChordTimer)
  }

  func clearChord() {
    chordKeyCount = 0
    if let timer = chordTimer {
      if timer.isValid {
        timer.invalidate()
      }
      chordTimer = nil
    }
  }

  func createSession() {
    let app = client?.bundleIdentifier() ?? {
      SquirrelInputController.unknownAppCnt &+= 1
      return "UnknownApp\(SquirrelInputController.unknownAppCnt)"
    }()
    print("createSession: \(app)")
    currentApp = app
    session = rimeAPI.create_session()
    schemaId = ""

    if session != 0 {
      updateAppOptions()
    }
  }

  func updateAppOptions() {
    if currentApp == "" {
      return
    }
    if let appOptions = NSApp.squirrelAppDelegate.config?.getAppOptions(currentApp) {
      for (key, value) in appOptions {
        print("set app option: \(key) = \(value)")
        rimeAPI.set_option(session, key, value)
      }
    }
    if let reportBundleID = NSApp.squirrelAppDelegate.config?.getBool("unsafe/report_bundleid"), reportBundleID {
      currentApp.withCString { name in
        rimeAPI.set_property(session, "client_app", name)
      }
    }
  }

  func destroySession() {
    if session != 0 {
      _ = rimeAPI.destroy_session(session)
      session = 0
    }
    clearChord()
  }

  func processKey(_ rimeKeycode: UInt32, modifiers rimeModifiers: UInt32) -> Bool {
    if let panel = NSApp.squirrelAppDelegate.panel {
      if panel.linear != rimeAPI.get_option(session, "_linear") {
        rimeAPI.set_option(session, "_linear", panel.linear)
      }
      if panel.vertical != rimeAPI.get_option(session, "_vertical") {
        rimeAPI.set_option(session, "_vertical", panel.vertical)
      }
    }

    let handled = rimeAPI.process_key(session, Int32(rimeKeycode), Int32(rimeModifiers))

    if !handled {
      let isVimBackInCommandMode = rimeKeycode == XK_Escape || ((rimeModifiers & kControlMask.rawValue != 0) && (rimeKeycode == XK_c || rimeKeycode == XK_C || rimeKeycode == XK_bracketleft))
      if isVimBackInCommandMode && rimeAPI.get_option(session, "vim_mode") &&
          !rimeAPI.get_option(session, "ascii_mode") {
        rimeAPI.set_option(session, "ascii_mode", true)
      }
    } else {
      let isChordingKey = switch Int32(rimeKeycode) {
      case XK_space...XK_asciitilde, XK_Control_L, XK_Control_R, XK_Alt_L, XK_Alt_R, XK_Shift_L, XK_Shift_R:
        true
      default:
        false
      }
      if isChordingKey && rimeAPI.get_option(session, "_chord_typing") {
        updateChord(keycode: rimeKeycode, modifiers: rimeModifiers)
      } else if (rimeModifiers & kReleaseMask.rawValue) == 0 {
        clearChord()
      }
    }

    return handled
  }

  func rimeConsumeCommittedText() {
    var commitText = RimeCommit.rimeStructInit()
    if rimeAPI.get_commit(session, &commitText) {
      if let text = commitText.text {
        commit(string: String(cString: text))
      }
      _ = rimeAPI.free_commit(&commitText)
    }
  }

  // Preserve reserved comment marks when librime requests a UI-only refresh.
  func rimeUpdate(clearReservedComments: Bool = true) {
    if clearReservedComments {
      specialCommentIndices = [:]
    }
    rimeConsumeCommittedText()

    var status = RimeStatus_stdbool.rimeStructInit()
    if rimeAPI.get_status(session, &status) {
      // swiftlint:disable:next identifier_name
      if let schema_id = status.schema_id, schemaId == "" || schemaId != String(cString: schema_id) {
        schemaId = String(cString: schema_id)
        NSApp.squirrelAppDelegate.loadSettings(for: schemaId)
        if let panel = NSApp.squirrelAppDelegate.panel {
          inlinePreedit = (panel.inlinePreedit && !rimeAPI.get_option(session, "no_inline")) || rimeAPI.get_option(session, "inline")
          inlineCandidate = panel.inlineCandidate && !rimeAPI.get_option(session, "no_inline")
          rimeAPI.set_option(session, "soft_cursor", !inlinePreedit)
        }
      }
      _ = rimeAPI.free_status(&status)
    }

    var ctx = RimeContext_stdbool.rimeStructInit()
    if rimeAPI.get_context(session, &ctx) {
      let preedit = ctx.composition.preedit.map({ String(cString: $0) }) ?? ""

      let start = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start)), within: preedit) ?? preedit.startIndex
      let end = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end)), within: preedit) ?? preedit.startIndex
      let caretPos = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos)), within: preedit) ?? preedit.startIndex

      if inlineCandidate {
        var candidatePreview = ctx.commit_text_preview.map { String(cString: $0) } ?? ""
        let endOfCandidatePreview = candidatePreview.endIndex
        if inlinePreedit {
          // 左移光標後的情形：
          // preedit:             ^已選某些字[xiang zuo yi dong]|guangbiao$
          // commit_text_preview: ^已選某些字向左移動$
          // candidate_preview:   ^已選某些字[向左移動]|guangbiao$
          // 繼續翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字[xiang zuo]yidong|guangbiao$
          // commit_text_preview: ^已選某些字向左yidong$
          // candidate_preview:   ^已選某些字[向左]yidong|guangbiao$
          // 光標移至當前段落最左端的情形：
          // preedit:             ^已選某些字|[xiang zuo yi dong guang biao]$
          // commit_text_preview: ^已選某些字向左移動光標$
          // candidate_preview:   ^已選某些字|[向左移動光標]$
          // 討論：
          // preedit 與 commit_text_preview 中“已選某些字”部分一致
          // 因此，選中範圍即正在翻譯的碼段“向左移動”中，兩者的 start 值一致
          // 光標位置的範圍是 start ..= endOfCandidatePreview
          if caretPos >= end && caretPos < preedit.endIndex {
            // 從 preedit 截取光標後未翻譯的編碼“guangbiao”
            candidatePreview += preedit[caretPos...]
          }
        } else {
          // 翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字[xiang zuo]yidong|guangbiao$
          // commit_text_preview: ^已選某些字向左yidongguangbiao$
          // candidate_preview:   ^已選某些字[向左???]|$
          // 光標移至當前段落最左端，繼續翻頁至指定更短字詞的情形：
          // preedit:             ^已選某些字|[xiang zuo]yidongguangbiao$
          // commit_text_preview: ^已選某些字向左yidongguangbiao$
          // candidate_preview:   ^已選某些字|[向左]???$
          // FIXME: add librime APIs to support preview candidate without remaining code.
        }
        // preedit can contain additional prompt text before start:
        // ^(prompt)[selection]$
        let start = min(start, candidatePreview.endIndex)
        let caretPos = caretPos <= start ? caretPos : endOfCandidatePreview
        show(preedit: candidatePreview,
             selRange: NSRange(location: start.utf16Offset(in: candidatePreview),
                               length: candidatePreview.utf16.distance(from: start, to: candidatePreview.endIndex)),
             caretPos: caretPos.utf16Offset(in: candidatePreview))
      } else {
        if inlinePreedit {
          show(preedit: preedit, selRange: NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end)), caretPos: caretPos.utf16Offset(in: preedit))
        } else {
          // Use a full-width space placeholder to prevent iTerm2 from echoing raw preedit;
          // half-width placeholders make the Chinese composition baseline unstable.
          show(preedit: preedit.isEmpty ? "" : "　", selRange: NSRange(location: 0, length: 0), caretPos: 0)
        }
      }

      let numCandidates = Int(ctx.menu.num_candidates)
      var candidates = [String]()
      var comments = [String]()
      for i in 0..<numCandidates {
        let candidate = ctx.menu.candidates[i]
        candidates.append(candidate.text.map { String(cString: $0) } ?? "")
        comments.append(candidate.comment.map { String(cString: $0) } ?? "")
      }
      var labels = [String]()
      // swiftlint:disable identifier_name
      if let select_keys = ctx.menu.select_keys {
        labels = String(cString: select_keys).map { String($0) }
      } else if let select_labels = ctx.select_labels {
        let pageSize = Int(ctx.menu.page_size)
        for i in 0..<pageSize {
          labels.append(select_labels[i].map { String(cString: $0) } ?? "")
        }
      }
      // swiftlint:enable identifier_name
      let page = Int(ctx.menu.page_no)
      let lastPage = ctx.menu.is_last_page

      let selRange = NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end))
      if let panel = NSApp.squirrelAppDelegate.panel, panel.isExpandableGridEnabled, numCandidates > 0 {
        let rawInput = rimeAPI.get_input(session).map { String(cString: $0) } ?? ""
        let compositionKey = "\(rawInput)\u{0}\(ctx.composition.cursor_pos)\u{0}\(preedit)"
        if compositionKey != gridCompositionKey {
          resetGridState()
          gridCompositionKey = compositionKey
        }
        gridRimePageSize = max(1, Int(ctx.menu.page_size))
        gridSelectLabels = labels
        gridPanelPreedit = inlinePreedit ? "" : preedit
        gridPanelSelRange = selRange
        gridPanelCaretPos = caretPos.utf16Offset(in: preedit)

        let maxCols = effectiveGridMaxColumns(panel)
        let targetCount = isGridExpanded
          ? max(gridCandidates.count, (gridViewportTopRow + panel.gridVisibleRowsConfig + 4) * maxCols)
          : max(gridCandidates.count, maxCols + 2)
        fetchGridCandidates(minCount: targetCount)
        refreshGridPanelOnly()
      } else {
        resetGridState()
        gridCompositionKey = ""
        showPanel(preedit: inlinePreedit ? "" : preedit, selRange: selRange, caretPos: caretPos.utf16Offset(in: preedit),
                  candidates: candidates, comments: comments, labels: labels, highlighted: Int(ctx.menu.highlighted_candidate_index),
                  page: page, lastPage: lastPage)
      }
      _ = rimeAPI.free_context(&ctx)
    } else {
      resetGridState()
      gridCompositionKey = ""
      hidePalettes()
    }
  }

  func commit(string: String) {
    guard let client = client else { return }

    let forceMarkedText =
      session != 0 &&
      rimeAPI.get_option(session, "force_marked_text_for_direct_commit")

    // Direct commits such as full-width punctuation do not necessarily have an
    // active marked-text phase. Some NSTextInputClient implementations require
    // one before accepting insertText.
    if forceMarkedText && preedit.isEmpty && !string.isEmpty {
      let markedText = NSMutableAttributedString(string: string)
      client.setMarkedText(
        markedText,
        selectionRange: NSRange(location: markedText.length, length: 0),
        replacementRange: .empty
      )
    }

    client.insertText(string, replacementRange: .empty)
    preedit = ""
    hidePalettes()
  }

  func show(preedit: String, selRange: NSRange, caretPos: Int) {
    guard let client = client else { return }
    if self.preedit == preedit && self.caretPos == caretPos && self.selRange == selRange {
      return
    }

    self.preedit = preedit
    self.caretPos = caretPos
    self.selRange = selRange

    let start = selRange.location
    let attrString = NSMutableAttributedString(string: preedit)
    if start > 0 {
      let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSRange(location: 0, length: start))! as! [NSAttributedString.Key: Any]
      attrString.setAttributes(attrs, range: NSRange(location: 0, length: start))
    }
    let remainingRange = NSRange(location: start, length: preedit.utf16.count - start)
    let attrs = mark(forStyle: kTSMHiliteSelectedRawText, at: remainingRange)! as! [NSAttributedString.Key: Any]
    attrString.setAttributes(attrs, range: remainingRange)
    client.setMarkedText(attrString, selectionRange: NSRange(location: caretPos, length: 0), replacementRange: .empty)
  }

  // swiftlint:disable:next function_parameter_count
  func showPanel(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted: Int, page: Int, lastPage: Bool) {
    guard let client = client else { return }
    var inputPos = NSRect()
    client.attributes(forCharacterIndex: 0, lineHeightRectangle: &inputPos)
    if let panel = NSApp.squirrelAppDelegate.panel {
      panel.position = inputPos
      panel.inputController = self
      panel.update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels,
                   highlighted: highlighted, page: page, lastPage: lastPage, update: true)
    }
  }

  private func handleASCIIModeToggle(_ notification: Notification) {
    guard let enableASCII = notification.object as? Bool else { return }
    guard session != 0 && rimeAPI.find_session(session) else { return }

    rimeAPI.set_option(session, "ascii_mode", enableASCII)
    rimeUpdate()
  }

  private func reportASCIIMode(_: Notification) {
    guard client != nil else { return }
    guard session != 0 && rimeAPI.find_session(session) else { return }

    let isASCIIMode = rimeAPI.get_option(session, "ascii_mode")
    let status = isASCIIMode ? "ascii" : "nascii"

    DistributedNotificationCenter.default().postNotificationName(
      .init("SquirrelASCIIModeResponse"),
      object: status
    )
  }

  func resetGridState() {
    isGridExpanded = false
    gridActiveRow = 0
    gridActiveCellIndex = 0
    gridPreferredCenterX = nil
    gridViewportTopRow = 0
    gridHoveredGlobalIndex = nil
    gridCandidates = []
    gridHasMore = false
    gridCurrentLayout = nil
    gridPanelPreedit = ""
    gridPanelSelRange = .empty
    gridPanelCaretPos = 0
    gridCompositionID &+= 1
  }

  func effectiveGridMaxColumns(_ panel: SquirrelPanel) -> Int {
    panel.gridMaxColumnsConfig > 0 ? panel.gridMaxColumnsConfig : max(1, gridRimePageSize)
  }

  func fetchGridCandidates(minCount: Int) {
    guard session != 0 else { return }
    if gridCandidates.count >= minCount {
      return
    }
    var iterator = RimeCandidateListIterator()
    guard rimeAPI.candidate_list_from_index(session, &iterator, Int32(gridCandidates.count)) else {
      gridHasMore = false
      return
    }
    defer { rimeAPI.candidate_list_end(&iterator) }

    var more = false
    while rimeAPI.candidate_list_next(&iterator) {
      let text = iterator.candidate.text.map { String(cString: $0) } ?? ""
      let comment = iterator.candidate.comment.map { String(cString: $0) } ?? ""
      gridCandidates.append(SquirrelGridCandidate(
        globalIndex: Int(iterator.index),
        text: text,
        comment: comment
      ))
      if gridCandidates.count >= minCount {
        more = rimeAPI.candidate_list_next(&iterator)
        break
      }
    }
    gridHasMore = more
  }

  func ensureRowsLoaded(throughRow targetRow: Int, maxCols: Int) {
    guard gridHasMore else { return }
    var safety = 0
    while gridHasMore && safety < 8 {
      let currentRowCount = gridCurrentLayout?.allRows.count ?? 0
      if currentRowCount > targetRow {
        break
      }
      let nextBatch = max(gridCandidates.count + maxCols * 4, (targetRow + 4) * maxCols)
      fetchGridCandidates(minCount: nextBatch)
      if let panel = NSApp.squirrelAppDelegate.panel {
        gridCurrentLayout = rebuildGridLayout(panel: panel)
      }
      safety += 1
    }
  }

  func locateGridCandidate(_ globalIndex: Int, in layout: SquirrelGridLayout) -> (row: Int, cell: Int)? {
    for row in layout.allRows {
      if let cellIdx = row.cells.firstIndex(where: { $0.globalIndex == globalIndex }) {
        return (row.rowIndex, cellIdx)
      }
    }
    return nil
  }

  func cellIndexInRow(_ row: SquirrelGridRow, matchingCenterX targetX: CGFloat?) -> Int {
    guard let targetX, !row.cells.isEmpty else { return 0 }
    var bestIdx = 0
    var bestDist = CGFloat.greatestFiniteMagnitude
    for (idx, cell) in row.cells.enumerated() {
      let centerX = cell.xOffset + cell.width / 2
      let dist = abs(centerX - targetX)
      if dist < bestDist {
        bestDist = dist
        bestIdx = idx
      }
    }
    return bestIdx
  }

  func updateGridViewport(totalRows: Int, panel: SquirrelPanel) {
    let visibleRows = max(1, panel.gridVisibleRowsConfig)
    let bottomMargin = min(max(0, panel.gridBottomMarginConfig), max(0, visibleRows - 1))
    let maxVisualRow = max(0, visibleRows - 1 - bottomMargin)
    let topMargin = min(max(0, panel.gridTopMarginConfig), maxVisualRow)
    if gridActiveRow - gridViewportTopRow > maxVisualRow {
      gridViewportTopRow = gridActiveRow - maxVisualRow
    }
    if gridActiveRow - gridViewportTopRow < topMargin {
      gridViewportTopRow = gridActiveRow - topMargin
    }
    let maxTopRow = max(0, totalRows - visibleRows)
    gridViewportTopRow = max(0, min(gridViewportTopRow, maxTopRow))
  }

  func rebuildGridLayout(panel: SquirrelPanel) -> SquirrelGridLayout? {
    guard !gridCandidates.isEmpty else { return nil }
    let layout = panel.buildGridLayout(
      compositionID: gridCompositionID,
      preedit: gridPanelPreedit,
      selRange: gridPanelSelRange,
      candidates: gridCandidates,
      selectLabels: gridSelectLabels,
      maxColumns: effectiveGridMaxColumns(panel),
      isExpanded: isGridExpanded,
      activeRow: gridActiveRow,
      activeCellIndexInRow: gridActiveCellIndex,
      viewportTopRow: gridViewportTopRow,
      hoveredGlobalIndex: gridHoveredGlobalIndex,
      hasMore: gridHasMore,
      specialCommentIndices: specialCommentIndices
    )
    gridCurrentLayout = layout
    return layout
  }

  func refreshGridPanelOnly() {
    guard let client = client, let panel = NSApp.squirrelAppDelegate.panel else { return }
    var inputPos = NSRect()
    client.attributes(forCharacterIndex: 0, lineHeightRectangle: &inputPos)
    panel.position = inputPos
    panel.inputController = self
    guard let layout = rebuildGridLayout(panel: panel) else { return }
    panel.updateGrid(layout, preedit: gridPanelPreedit, selRange: gridPanelSelRange, caretPos: gridPanelCaretPos)
  }

  func syncGridHighlightAndRefresh() {
    if let panel = NSApp.squirrelAppDelegate.panel, let layout = rebuildGridLayout(panel: panel) {
      let row = layout.allRows[layout.activeRow]
      let cell = row.cells[layout.activeCellIndexInRow]
      gridActiveRow = layout.activeRow
      gridActiveCellIndex = layout.activeCellIndexInRow
      _ = rimeAPI.highlight_candidate(session, cell.globalIndex)
      if inlineCandidate {
        updateInlineCandidatePreview()
      }
      refreshGridPanelOnly()
    }
  }

  func updateInlineCandidatePreview() {
    var ctx = RimeContext_stdbool.rimeStructInit()
    guard rimeAPI.get_context(session, &ctx) else { return }
    defer { _ = rimeAPI.free_context(&ctx) }
    let preedit = ctx.composition.preedit.map { String(cString: $0) } ?? ""
    let start = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start)), within: preedit) ?? preedit.startIndex
    let end = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end)), within: preedit) ?? preedit.startIndex
    let caretPos = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos)), within: preedit) ?? preedit.startIndex
    var candidatePreview = ctx.commit_text_preview.map { String(cString: $0) } ?? ""
    let endOfCandidatePreview = candidatePreview.endIndex
    if inlinePreedit && caretPos >= end && caretPos < preedit.endIndex {
      candidatePreview += preedit[caretPos...]
    }
    let clampedStart = min(start, candidatePreview.endIndex)
    let clampedCaret = caretPos <= clampedStart ? caretPos : endOfCandidatePreview
    show(
      preedit: candidatePreview,
      selRange: NSRange(
        location: clampedStart.utf16Offset(in: candidatePreview),
        length: candidatePreview.utf16.distance(from: clampedStart, to: candidatePreview.endIndex)
      ),
      caretPos: clampedCaret.utf16Offset(in: candidatePreview)
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  func handleGridKey(_ rimeKeycode: UInt32, modifiers _: UInt32, eventModifiers: NSEvent.ModifierFlags) -> Bool {
    guard let panel = NSApp.squirrelAppDelegate.panel, panel.isExpandableGridEnabled, !gridCandidates.isEmpty else {
      return false
    }
    guard eventModifiers.intersection([.command, .option, .control, .shift]).isEmpty else {
      return false
    }
    let maxCols = effectiveGridMaxColumns(panel)
    guard let initialLayout = gridCurrentLayout ?? rebuildGridLayout(panel: panel) else {
      return false
    }

    switch Int32(rimeKeycode) {
    case XK_Down, XK_Page_Down, XK_equal:
      if gridPreferredCenterX == nil {
        let curCell = initialLayout.allRows[initialLayout.activeRow].cells[initialLayout.activeCellIndexInRow]
        gridPreferredCenterX = curCell.xOffset + curCell.width / 2
      }
      if !isGridExpanded {
        guard gridHasMore || initialLayout.allRows.count > 1 else { return true }
        isGridExpanded = true
        fetchGridCandidates(minCount: max(gridCandidates.count, (panel.gridVisibleRowsConfig + 4) * maxCols))
        guard let expandedLayout = rebuildGridLayout(panel: panel) else { return true }
        if expandedLayout.allRows.count > 1 {
          gridActiveRow = 1
          gridActiveCellIndex = cellIndexInRow(expandedLayout.allRows[1], matchingCenterX: gridPreferredCenterX)
        }
        updateGridViewport(totalRows: expandedLayout.allRows.count, panel: panel)
        syncGridHighlightAndRefresh()
        return true
      } else {
        ensureRowsLoaded(throughRow: gridActiveRow + panel.gridVisibleRowsConfig + 2, maxCols: maxCols)
        guard let layout = rebuildGridLayout(panel: panel) else { return true }
        if gridActiveRow + 1 < layout.allRows.count {
          gridActiveRow += 1
          gridActiveCellIndex = cellIndexInRow(layout.allRows[gridActiveRow], matchingCenterX: gridPreferredCenterX)
          updateGridViewport(totalRows: layout.allRows.count, panel: panel)
          syncGridHighlightAndRefresh()
        }
        return true
      }

    case XK_Up, XK_Page_Up, XK_minus:
      guard isGridExpanded else { return true }
      if gridPreferredCenterX == nil {
        let curCell = initialLayout.allRows[initialLayout.activeRow].cells[initialLayout.activeCellIndexInRow]
        gridPreferredCenterX = curCell.xOffset + curCell.width / 2
      }
      if gridActiveRow == 0 {
        isGridExpanded = false
        gridViewportTopRow = 0
        syncGridHighlightAndRefresh()
      } else {
        gridActiveRow -= 1
        gridActiveCellIndex = cellIndexInRow(initialLayout.allRows[gridActiveRow], matchingCenterX: gridPreferredCenterX)
        updateGridViewport(totalRows: initialLayout.allRows.count, panel: panel)
        syncGridHighlightAndRefresh()
      }
      return true

    case XK_Right:
      let curRow = initialLayout.allRows[gridActiveRow]
      if gridActiveCellIndex + 1 < curRow.cells.count {
        gridActiveCellIndex += 1
        let nextCell = curRow.cells[gridActiveCellIndex]
        gridPreferredCenterX = nextCell.xOffset + nextCell.width / 2
        syncGridHighlightAndRefresh()
      } else if gridActiveRow + 1 < initialLayout.allRows.count || gridHasMore {
        let nextGlobalIndex = curRow.cells[gridActiveCellIndex].globalIndex + 1
        if !isGridExpanded {
          isGridExpanded = true
        }
        ensureRowsLoaded(throughRow: gridActiveRow + panel.gridVisibleRowsConfig + 2, maxCols: maxCols)
        guard let layout = rebuildGridLayout(panel: panel) else { return true }
        if let pos = locateGridCandidate(nextGlobalIndex, in: layout) {
          gridActiveRow = pos.row
          gridActiveCellIndex = pos.cell
          let nextCell = layout.allRows[pos.row].cells[pos.cell]
          gridPreferredCenterX = nextCell.xOffset + nextCell.width / 2
          updateGridViewport(totalRows: layout.allRows.count, panel: panel)
          syncGridHighlightAndRefresh()
        } else if gridActiveRow + 1 < layout.allRows.count {
          gridActiveRow += 1
          gridActiveCellIndex = 0
          let nextCell = layout.allRows[gridActiveRow].cells[0]
          gridPreferredCenterX = nextCell.xOffset + nextCell.width / 2
          updateGridViewport(totalRows: layout.allRows.count, panel: panel)
          syncGridHighlightAndRefresh()
        }
      }
      return true

    case XK_Left:
      if !isGridExpanded && gridActiveCellIndex == 0 {
        return false
      }
      if gridActiveCellIndex > 0 {
        gridActiveCellIndex -= 1
        let prevCell = initialLayout.allRows[gridActiveRow].cells[gridActiveCellIndex]
        gridPreferredCenterX = prevCell.xOffset + prevCell.width / 2
        syncGridHighlightAndRefresh()
      } else if gridActiveRow > 0 {
        gridActiveRow -= 1
        let prevRow = initialLayout.allRows[gridActiveRow]
        gridActiveCellIndex = max(0, prevRow.cells.count - 1)
        let prevCell = prevRow.cells[gridActiveCellIndex]
        gridPreferredCenterX = prevCell.xOffset + prevCell.width / 2
        updateGridViewport(totalRows: initialLayout.allRows.count, panel: panel)
        syncGridHighlightAndRefresh()
      } else if isGridExpanded {
        isGridExpanded = false
        gridViewportTopRow = 0
        syncGridHighlightAndRefresh()
      }
      return true

    case XK_space:
      let cell = initialLayout.allRows[initialLayout.activeRow].cells[initialLayout.activeCellIndexInRow]
      return selectGridCandidate(globalIndex: cell.globalIndex)

    default:
      if rimeKeycode >= 0x20 && rimeKeycode <= 0x7e, let scalar = UnicodeScalar(rimeKeycode) {
        let keyChar = String(scalar)
        let slotIndex: Int?
        if gridSelectLabels.count > 1 {
          slotIndex = gridSelectLabels.firstIndex(of: keyChar)
        } else if gridSelectLabels.count == 1, let first = gridSelectLabels.first {
          slotIndex = first.firstIndex(of: Character(keyChar)).map { first.distance(from: first.startIndex, to: $0) }
        } else if keyChar == "0" {
          slotIndex = 9
        } else if let digit = Int(keyChar), digit >= 1 && digit <= 9 {
          slotIndex = digit - 1
        } else {
          slotIndex = nil
        }

        if let slot = slotIndex {
          let activeCells = initialLayout.allRows[initialLayout.activeRow].cells
          if slot < activeCells.count {
            return selectGridCandidate(globalIndex: activeCells[slot].globalIndex)
          }
          if slot < maxCols {
            return true
          }
        }
      }
      return false
    }
  }

}
