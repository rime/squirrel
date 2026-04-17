//
//  SquirrelInputController.swift
//  Squirrel
//
//  Created by Leo Liu on 5/7/24.
//

import InputMethodKit
import Carbon

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
  // for chord-typing
  private var chordKeyCodes: [UInt32] = .init(repeating: 0, count: SquirrelInputController.keyRollOver)
  private var chordModifiers: [UInt32] = .init(repeating: 0, count: SquirrelInputController.keyRollOver)
  private var chordKeyCount: Int = 0
  private var chordTimer: Timer?
  private var chordDuration: TimeInterval = 0
  private var currentApp: String = ""

  // swiftlint:disable:next cyclomatic_complexity
  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    guard let event = event else { return false }
    let modifiers = event.modifierFlags
    let changes = lastModifiers.symmetricDifference(modifiers)

    // Return true to indicate the the key input was received and dealt with.
    // Key processing will not continue in that case.  In other words the
    // system will not deliver a key down event to the application.
    // Returning false means the original key down will be passed on to the client.
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
      // print("[DEBUG] FLAGSCHANGED client: \(sender ?? "nil"), modifiers: \(modifiers)")
      var rimeModifiers: UInt32 = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
      // For flags-changed event, keyCode is available since macOS 10.15 (#715)
      // Some remote desktop software (e.g. Parsec) sends flagsChanged events with
      // keyCode defaulting to 0 (kVK_ANSI_A) instead of the actual modifier keycode,
      // causing a ghost 'a' keypress. Validate and infer the correct keycode from
      // the changed modifier flags when necessary. (#825)
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
        // NOTE: rime assumes XK_Caps_Lock to be sent before modifier changes,
        // while NSFlagsChanged event has the flag changed already.
        // so it is necessary to revert kLockMask.
        rimeModifiers ^= kLockMask.rawValue
        _ = processKey(rimeKeycode, modifiers: rimeModifiers)
      }

      // Need to process release before modifier down. Because
      // sometimes release event is delayed to next modifier keydown.
      var buffer = [(keycode: UInt32, modifier: UInt32)]()
      for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] where changes.contains(flag) {
        if modifiers.contains(flag) { // New modifier
          buffer.append((keycode: rimeKeycode, modifier: rimeModifiers))
        } else { // Release
          buffer.insert((keycode: rimeKeycode, modifier: rimeModifiers | kReleaseMask.rawValue), at: 0)
        }
      }
      for (keycode, modifier) in buffer {
        _ = processKey(keycode, modifiers: modifier)
      }

      lastModifiers = modifiers
      rimeUpdate()

    case .keyDown:
      // ignore Command+X hotkeys.
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

      // translate osx keyevents to rime keyevents
      // Some applications (e.g. SecureCRT) may have Cocoa/Carbon keyboard mapping issues
      // where event.characters returns empty. Fall back to using keyCode directly.
      let char = keyChars?.first
      let rimeKeycode = SquirrelKeycode.osxKeycodeToRime(keycode: keyCode, keychar: char,
                                                         shift: modifiers.contains(.shift),
                                                         caps: modifiers.contains(.capsLock))
      if rimeKeycode != 0 && rimeKeycode != UInt32(XK_VoidSymbol) {
        let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
        handled = processKey(rimeKeycode, modifiers: rimeModifiers)
        rimeUpdate()
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
    preedit = ""

    // Start Qt compatibility handler for apps that don't work with InputMethodKit
    if let bundleId = client?.bundleIdentifier(), QtCompatHandler.isQtApp(bundleId) {
      let handler = QtCompatHandler.shared
      handler.rimeAPI = rimeAPI
      handler.sessionId = session
      handler.getTextClient = { [weak self] in self?.client }
      handler.shouldHandle = { [weak self] in
        guard let self = self, self.session != 0 else { return false }
        return true
      }
      handler.isAsciiMode = { [weak self] in
        guard let self = self else { return false }
        return self.rimeAPI.get_option(self.session, "ascii_mode")
      }
      handler.commitText = { [weak self] text in
        self?.commit(string: text)
      }
      handler.showPreedit = { [weak self] preedit, selRange, caretPos in
        self?.show(preedit: preedit, selRange: selRange, caretPos: caretPos)
      }
      handler.hidePanel = { [weak self] in
        self?.hidePalettes()
      }
      handler.updateCandidates = { [weak self] in
        self?.rimeUpdate()
      }
      handler.start()
    }
  }

  override init!(server: IMKServer!, delegate: Any!, client: Any!) {
    self.client = client as? IMKTextInput
    // print("[DEBUG] initWithServer: \(server ?? .init()) delegate: \(delegate ?? "nil") client:\(client ?? "nil")")
    super.init(server: server, delegate: delegate, client: client)
    createSession()
  }

  override func deactivateServer(_ sender: Any!) {
    // print("[DEBUG] deactivateServer: \(sender ?? "nil")")
    QtCompatHandler.shared.stop()
    hidePalettes()
    commitComposition(sender)
    client = nil
  }

  override func hidePalettes() {
    NSApp.squirrelAppDelegate.panel?.hide()
    super.hidePalettes()
  }

  /*!
   @method
   @abstract   Called when a user action was taken that ends an input session.
   Typically triggered by the user selecting a new input method
   or keyboard layout.
   @discussion When this method is called your controller should send the
   current input buffer to the client via a call to
   insertText:replacementRange:.  Additionally, this is the time
   to clean up if that is necessary.
   */
  override func commitComposition(_ sender: Any!) {
    self.client ?= sender as? IMKTextInput
    // print("[DEBUG] commitComposition: \(sender ?? "nil")")
    //  commit raw input
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

  deinit {
    destroySession()
  }
}

private extension SquirrelInputController {

  func onChordTimer(_: Timer) {
    // chord release triggered by timer
    var processedKeys = false
    if chordKeyCount > 0 && session != 0 {
      // simulate key-ups
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
    // print("[DEBUG] update chord: {\(chordKeyCodes)} << \(keycode)")
    for i in 0..<chordKeyCount where chordKeyCodes[i] == keycode {
      return
    }
    if chordKeyCount >= Self.keyRollOver {
      // you are cheating. only one human typist (fingers <= 10) is supported.
      return
    }
    chordKeyCodes[chordKeyCount] = keycode
    chordModifiers[chordKeyCount] = modifiers
    chordKeyCount += 1
    // reset timer
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
  }

  func destroySession() {
    // print("[DEBUG] destroySession:")
    if session != 0 {
      _ = rimeAPI.destroy_session(session)
      session = 0
    }
    clearChord()
  }

  func processKey(_ rimeKeycode: UInt32, modifiers rimeModifiers: UInt32) -> Bool {
    // TODO add special key event preprocessing here

    // with linear candidate list, arrow keys may behave differently.
    if let panel = NSApp.squirrelAppDelegate.panel {
      if panel.linear != rimeAPI.get_option(session, "_linear") {
        rimeAPI.set_option(session, "_linear", panel.linear)
      }
      // with vertical text, arrow keys may behave differently.
      if panel.vertical != rimeAPI.get_option(session, "_vertical") {
        rimeAPI.set_option(session, "_vertical", panel.vertical)
      }
    }

    let handled = rimeAPI.process_key(session, Int32(rimeKeycode), Int32(rimeModifiers))
    // print("[DEBUG] rime_keycode: \(rimeKeycode), rime_modifiers: \(rimeModifiers), handled = \(handled)")

    // TODO add special key event postprocessing here

    if !handled {
      let isVimBackInCommandMode = rimeKeycode == XK_Escape || ((rimeModifiers & kControlMask.rawValue != 0) && (rimeKeycode == XK_c || rimeKeycode == XK_C || rimeKeycode == XK_bracketleft))
      if isVimBackInCommandMode && rimeAPI.get_option(session, "vim_mode") &&
          !rimeAPI.get_option(session, "ascii_mode") {
        rimeAPI.set_option(session, "ascii_mode", true)
        // print("[DEBUG] turned Chinese mode off in vim-like editor's command mode")
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
        // non-chording key pressed
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

  // swiftlint:disable:next cyclomatic_complexity
  func rimeUpdate() {
    // print("[DEBUG] rimeUpdate")
    rimeConsumeCommittedText()

    var status = RimeStatus_stdbool.rimeStructInit()
    if rimeAPI.get_status(session, &status) {
      // enable schema specific ui style
      // swiftlint:disable:next identifier_name
      if let schema_id = status.schema_id, schemaId == "" || schemaId != String(cString: schema_id) {
        schemaId = String(cString: schema_id)
        NSApp.squirrelAppDelegate.loadSettings(for: schemaId)
        // inline preedit
        if let panel = NSApp.squirrelAppDelegate.panel {
          inlinePreedit = (panel.inlinePreedit && !rimeAPI.get_option(session, "no_inline")) || rimeAPI.get_option(session, "inline")
          inlineCandidate = panel.inlineCandidate && !rimeAPI.get_option(session, "no_inline")
          // if not inline, embed soft cursor in preedit string
          rimeAPI.set_option(session, "soft_cursor", !inlinePreedit)
        }
      }
      _ = rimeAPI.free_status(&status)
    }

    var ctx = RimeContext_stdbool.rimeStructInit()
    if rimeAPI.get_context(session, &ctx) {
      // update preedit text
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
        // caret can be either before or after the selected range.
        let caretPos = caretPos <= start ? caretPos : endOfCandidatePreview
        show(preedit: candidatePreview,
             selRange: NSRange(location: start.utf16Offset(in: candidatePreview),
                               length: candidatePreview.utf16.distance(from: start, to: candidatePreview.endIndex)),
             caretPos: caretPos.utf16Offset(in: candidatePreview))
      } else {
        if inlinePreedit {
          show(preedit: preedit, selRange: NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end)), caretPos: caretPos.utf16Offset(in: preedit))
        } else {
          // TRICKY: display a non-empty string to prevent iTerm2 from echoing
          // each character in preedit. note this is a full-shape space U+3000;
          // using half shape characters like "..." will result in an unstable
          // baseline when composing Chinese characters.
          show(preedit: preedit.isEmpty ? "" : "　", selRange: NSRange(location: 0, length: 0), caretPos: 0)
        }
      }

      // update candidates
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
      showPanel(preedit: inlinePreedit ? "" : preedit, selRange: selRange, caretPos: caretPos.utf16Offset(in: preedit),
                candidates: candidates, comments: comments, labels: labels, highlighted: Int(ctx.menu.highlighted_candidate_index),
                page: page, lastPage: lastPage)
      _ = rimeAPI.free_context(&ctx)
    } else {
      hidePalettes()
    }
  }

  func commit(string: String) {
    guard let client = client else { return }
    // print("[DEBUG] commitString: \(string)")
    client.insertText(string, replacementRange: .empty)
    preedit = ""
    hidePalettes()
  }

  func show(preedit: String, selRange: NSRange, caretPos: Int) {
    guard let client = client else { return }
    // print("[DEBUG] showPreeditString: '\(preedit)'")
    if self.preedit == preedit && self.caretPos == caretPos && self.selRange == selRange {
      return
    }

    self.preedit = preedit
    self.caretPos = caretPos
    self.selRange = selRange

    // print("[DEBUG] selRange.location = \(selRange.location), selRange.length = \(selRange.length); caretPos = \(caretPos)")
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
    // print("[DEBUG] showPanelWithPreedit:...:")
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
}

// MARK: - Qt Compatibility Handler

/// Handles keyboard events for Qt applications that don't work properly with InputMethodKit
final class QtCompatHandler {
  /// Known Qt-based application bundle identifiers that have IMK compatibility issues
  static let qtAppBundleIds: Set<String> = [
    "com.vandyke.SecureCRT",
    "com.vandyke.SecureFX",
    // Add other Qt apps that have similar issues
  ]

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var isActive = false

  /// RIME API reference
  var rimeAPI: RimeApi_stdbool?
  /// RIME session ID
  var sessionId: RimeSessionId = 0
  /// Callback to commit text
  var commitText: ((String) -> Void)?
  /// Callback to show/update preedit
  var showPreedit: ((String, NSRange, Int) -> Void)?
  /// Callback to hide panel
  var hidePanel: (() -> Void)?
  /// Callback to check if should handle
  var shouldHandle: (() -> Bool)?
  /// Callback to check if in ascii mode
  var isAsciiMode: (() -> Bool)?
  /// Callback to get text client for ascii mode input
  var getTextClient: (() -> IMKTextInput?)?
  /// Callback when candidate selected
  var updateCandidates: (() -> Void)?

  /// Last modifier state
  private var lastModifiers: NSEvent.ModifierFlags = []

  /// Singleton instance
  static let shared = QtCompatHandler()

  private init() {}

  /// Check if the given app is a known Qt app with IMK issues
  static func isQtApp(_ bundleId: String?) -> Bool {
    guard let bundleId = bundleId else { return false }
    return qtAppBundleIds.contains(bundleId)
  }

  /// Start monitoring keyboard events for Qt apps
  func start() {
    guard !isActive else { return }

    // Check if we have accessibility permissions
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)

    guard trusted else {
      print("QtCompatHandler: Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility")
      // Request permission with dialog
      _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
      return
    }

    // Create event tap for keyDown and flagsChanged events
    let eventMask = (1 << CGEventType.keyDown.rawValue) |
                    (1 << CGEventType.keyUp.rawValue) |
                    (1 << CGEventType.flagsChanged.rawValue)

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        let handler = Unmanaged<QtCompatHandler>.fromOpaque(refcon!).takeUnretainedValue()
        return handler.handleEvent(type: type, event: event)
      },
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      print("QtCompatHandler: Failed to create event tap")
      return
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    isActive = true
    print("QtCompatHandler: Started monitoring keyboard events")
  }

  /// Stop monitoring
  func stop() {
    guard isActive, let tap = eventTap else { return }

    CGEvent.tapEnable(tap: tap, enable: false)
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
    }

    eventTap = nil
    runLoopSource = nil
    isActive = false
    lastModifiers = []
    print("QtCompatHandler: Stopped monitoring")
  }

  /// Handle a CGEvent
  private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    // Only process for Qt apps
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
          Self.isQtApp(frontmostApp) else {
      return Unmanaged.passRetained(event)
    }

    // Check if we should handle this event
    guard shouldHandle?() != false,
          sessionId != 0 else {
      return Unmanaged.passRetained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

    switch type {
    case .keyDown:
      // Ignore command combinations - pass through to app
      if flags.contains(.command) {
        return Unmanaged.passRetained(event)
      }

      // Check if in ascii mode for special handling
      let asciiMode = isAsciiMode?() ?? false

      // In ascii mode, handle Backspace and ForwardDelete specially - pass through to app
      if asciiMode && (keyCode == UInt16(kVK_Delete) || keyCode == UInt16(kVK_ForwardDelete)) {
        return Unmanaged.passRetained(event)
      }

      if processKeyDown(keyCode: keyCode, modifiers: flags) {
        // Event was handled, don't pass to app
        return nil
      }

    case .flagsChanged:
      if let api = rimeAPI {
        processFlagsChanged(keyCode: keyCode, modifiers: flags, api: api)
      }

    default:
      break
    }

    return Unmanaged.passRetained(event)
  }

  /// Process a key down event
  private func processKeyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
    // Check if in ascii mode
    let asciiMode = isAsciiMode?() ?? false

    if asciiMode {
      // In ascii mode, directly insert the character
      return processAsciiKeyDown(keyCode: keyCode, modifiers: modifiers)
    }

    // In Chinese mode, use RIME
    guard let api = rimeAPI else { return false }

    let rimeKeycode = SquirrelKeycode.osxKeycodeToRime(
      keycode: keyCode,
      keychar: nil,
      shift: modifiers.contains(.shift),
      caps: modifiers.contains(.capsLock)
    )

    guard rimeKeycode != 0 && rimeKeycode != UInt32(XK_VoidSymbol) else {
      return false
    }

    let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)
    let handled = api.process_key(sessionId, Int32(rimeKeycode), Int32(rimeModifiers))

    if handled {
      updateUI(api: api)
      return true
    }

    return false
  }

  /// Process key in ascii mode - directly insert character
  private func processAsciiKeyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
    // Get character from keycode
    guard let client = getTextClient?() else { return false }

    // Map keycode to character
    let char = keycodeToCharacter(keyCode: keyCode, modifiers: modifiers)
    guard let charStr = char else { return false }

    // Check for special keys
    switch keyCode {
    case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
      client.insertText("\n", replacementRange: .empty)
      return true
    case UInt16(kVK_Tab):
      client.insertText("\t", replacementRange: .empty)
      return true
    case UInt16(kVK_Space):
      client.insertText(" ", replacementRange: .empty)
      return true
    case UInt16(kVK_Delete):
      // Backspace - pass through
      return false
    default:
      // Regular character
      if !charStr.isEmpty {
        client.insertText(charStr, replacementRange: .empty)
        return true
      }
      return false
    }
  }

  /// Map keycode to character string
  private func keycodeToCharacter(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String? {
    let shift = modifiers.contains(.shift)
    let caps = modifiers.contains(.capsLock)
    let control = modifiers.contains(.control)
    let option = modifiers.contains(.option)

    // Control combinations
    if control && !option {
      switch keyCode {
      case UInt16(kVK_ANSI_A): return "\u{01}"
      case UInt16(kVK_ANSI_B): return "\u{02}"
      case UInt16(kVK_ANSI_C): return "\u{03}"
      case UInt16(kVK_ANSI_D): return "\u{04}"
      case UInt16(kVK_ANSI_E): return "\u{05}"
      case UInt16(kVK_ANSI_F): return "\u{06}"
      case UInt16(kVK_ANSI_G): return "\u{07}"
      case UInt16(kVK_ANSI_H): return "\u{08}"
      case UInt16(kVK_ANSI_I): return "\u{09}"
      case UInt16(kVK_ANSI_J): return "\u{0A}"
      case UInt16(kVK_ANSI_K): return "\u{0B}"
      case UInt16(kVK_ANSI_L): return "\u{0C}"
      case UInt16(kVK_ANSI_M): return "\u{0D}"
      case UInt16(kVK_ANSI_N): return "\u{0E}"
      case UInt16(kVK_ANSI_O): return "\u{0F}"
      case UInt16(kVK_ANSI_P): return "\u{10}"
      case UInt16(kVK_ANSI_Q): return "\u{11}"
      case UInt16(kVK_ANSI_R): return "\u{12}"
      case UInt16(kVK_ANSI_S): return "\u{13}"
      case UInt16(kVK_ANSI_T): return "\u{14}"
      case UInt16(kVK_ANSI_U): return "\u{15}"
      case UInt16(kVK_ANSI_V): return "\u{16}"
      case UInt16(kVK_ANSI_W): return "\u{17}"
      case UInt16(kVK_ANSI_X): return "\u{18}"
      case UInt16(kVK_ANSI_Y): return "\u{19}"
      case UInt16(kVK_ANSI_Z): return "\u{1A}"
      case UInt16(kVK_ANSI_LeftBracket): return "\u{1B}"
      case UInt16(kVK_ANSI_Backslash): return "\u{1C}"
      case UInt16(kVK_ANSI_RightBracket): return "\u{1D}"
      case UInt16(kVK_ANSI_6): return "\u{1E}" // ^^
      case UInt16(kVK_ANSI_Minus): return "\u{1F}"
      default: return nil
      }
    }

    // Regular characters
    let upperCase = shift != caps // XOR: shift OR caps toggles case

    switch keyCode {
    // Numbers
    case UInt16(kVK_ANSI_0): return shift ? ")" : "0"
    case UInt16(kVK_ANSI_1): return shift ? "!" : "1"
    case UInt16(kVK_ANSI_2): return shift ? "@" : "2"
    case UInt16(kVK_ANSI_3): return shift ? "#" : "3"
    case UInt16(kVK_ANSI_4): return shift ? "$" : "4"
    case UInt16(kVK_ANSI_5): return shift ? "%" : "5"
    case UInt16(kVK_ANSI_6): return shift ? "^" : "6"
    case UInt16(kVK_ANSI_7): return shift ? "&" : "7"
    case UInt16(kVK_ANSI_8): return shift ? "*" : "8"
    case UInt16(kVK_ANSI_9): return shift ? "(" : "9"

    // Letters
    case UInt16(kVK_ANSI_A): return upperCase ? "A" : "a"
    case UInt16(kVK_ANSI_B): return upperCase ? "B" : "b"
    case UInt16(kVK_ANSI_C): return upperCase ? "C" : "c"
    case UInt16(kVK_ANSI_D): return upperCase ? "D" : "d"
    case UInt16(kVK_ANSI_E): return upperCase ? "E" : "e"
    case UInt16(kVK_ANSI_F): return upperCase ? "F" : "f"
    case UInt16(kVK_ANSI_G): return upperCase ? "G" : "g"
    case UInt16(kVK_ANSI_H): return upperCase ? "H" : "h"
    case UInt16(kVK_ANSI_I): return upperCase ? "I" : "i"
    case UInt16(kVK_ANSI_J): return upperCase ? "J" : "j"
    case UInt16(kVK_ANSI_K): return upperCase ? "K" : "k"
    case UInt16(kVK_ANSI_L): return upperCase ? "L" : "l"
    case UInt16(kVK_ANSI_M): return upperCase ? "M" : "m"
    case UInt16(kVK_ANSI_N): return upperCase ? "N" : "n"
    case UInt16(kVK_ANSI_O): return upperCase ? "O" : "o"
    case UInt16(kVK_ANSI_P): return upperCase ? "P" : "p"
    case UInt16(kVK_ANSI_Q): return upperCase ? "Q" : "q"
    case UInt16(kVK_ANSI_R): return upperCase ? "R" : "r"
    case UInt16(kVK_ANSI_S): return upperCase ? "S" : "s"
    case UInt16(kVK_ANSI_T): return upperCase ? "T" : "t"
    case UInt16(kVK_ANSI_U): return upperCase ? "U" : "u"
    case UInt16(kVK_ANSI_V): return upperCase ? "V" : "v"
    case UInt16(kVK_ANSI_W): return upperCase ? "W" : "w"
    case UInt16(kVK_ANSI_X): return upperCase ? "X" : "x"
    case UInt16(kVK_ANSI_Y): return upperCase ? "Y" : "y"
    case UInt16(kVK_ANSI_Z): return upperCase ? "Z" : "z"

    // Punctuation
    case UInt16(kVK_ANSI_Minus): return shift ? "_" : "-"
    case UInt16(kVK_ANSI_Equal): return shift ? "+" : "="
    case UInt16(kVK_ANSI_LeftBracket): return shift ? "{" : "["
    case UInt16(kVK_ANSI_RightBracket): return shift ? "}" : "]"
    case UInt16(kVK_ANSI_Quote): return shift ? "\"" : "'"
    case UInt16(kVK_ANSI_Semicolon): return shift ? ":" : ";"
    case UInt16(kVK_ANSI_Backslash): return shift ? "|" : "\\"
    case UInt16(kVK_ANSI_Comma): return shift ? "<" : ","
    case UInt16(kVK_ANSI_Period): return shift ? ">" : "."
    case UInt16(kVK_ANSI_Slash): return shift ? "?" : "/"
    case UInt16(kVK_ANSI_Grave): return shift ? "~" : "`"

    default: return nil
    }
  }

  /// Process flags changed (modifier keys)
  private func processFlagsChanged(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, api: RimeApi_stdbool) {
    let changes = lastModifiers.symmetricDifference(modifiers)
    guard !changes.isEmpty else { return }

    let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers)

    var keyCodeToUse = keyCode
    if !SquirrelKeycode.modifierKeycodes.contains(keyCode) {
      guard let inferred = SquirrelKeycode.inferModifierKeycode(from: changes) else {
        lastModifiers = modifiers
        return
      }
      keyCodeToUse = inferred
    }

    let rimeKeycode = SquirrelKeycode.osxKeycodeToRime(keycode: keyCodeToUse, keychar: nil, shift: false, caps: false)

    if changes.contains(.capsLock) {
      let modsWithLockToggle = rimeModifiers ^ kLockMask.rawValue
      _ = api.process_key(sessionId, Int32(rimeKeycode), Int32(modsWithLockToggle))
    }

    for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] where changes.contains(flag) {
      let mod = modifiers.contains(flag) ? rimeModifiers : rimeModifiers | kReleaseMask.rawValue
      _ = api.process_key(sessionId, Int32(rimeKeycode), Int32(mod))
    }

    lastModifiers = modifiers
    updateUI(api: api)
  }

  /// Update UI after key processing
  private func updateUI(api: RimeApi_stdbool) {
    var commitTextStruct = RimeCommit.rimeStructInit()
    if api.get_commit(sessionId, &commitTextStruct) {
      if let text = commitTextStruct.text {
        let str = String(cString: text)
        commitText?(str)
      }
      _ = api.free_commit(&commitTextStruct)
    }

    var ctx = RimeContext_stdbool.rimeStructInit()
    if api.get_context(sessionId, &ctx) {
      let preedit = ctx.composition.preedit.map { String(cString: $0) } ?? ""

      if !preedit.isEmpty {
        let start = preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start))
        let end = preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end))
        let caretPos = preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos))

        let startIdx = String.Index(start, within: preedit) ?? preedit.startIndex
        let endIdx = String.Index(end, within: preedit) ?? preedit.startIndex
        let caretIdx = String.Index(caretPos, within: preedit) ?? preedit.startIndex

        let selRange = NSRange(location: startIdx.utf16Offset(in: preedit),
                               length: preedit.utf16.distance(from: startIdx, to: endIdx))
        let caret = caretIdx.utf16Offset(in: preedit)

        showPreedit?(preedit, selRange, caret)
      } else {
        hidePanel?()
      }

      _ = api.free_context(&ctx)
    } else {
      hidePanel?()
    }

    updateCandidates?()
  }
}
