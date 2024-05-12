//
//  SquirrelInputController.swift
//  Squirrel
//
//  Created by Leo Liu on 5/7/24.
//

import InputMethodKit

class SquirrelInputController: IMKInputController {
  private static let keyRollOver = 50
  
  private let rimeAPI: RimeApi = rime_get_api().pointee
  private var preedit: String = ""
  private var selRange: NSRange = NSMakeRange(NSNotFound, 0)
  private var caretPos: Int = 0
  private var lastModifier: NSEvent.ModifierFlags = .init()
  private var lastEventType: NSEvent.EventType = .keyDown
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
  
  override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
    let modifiers = event.modifierFlags
    
    // Return YES to indicate the the key input was received and dealt with.
    // Key processing will not continue in that case.  In other words the
    // system will not deliver a key down event to the application.
    // Returning NO means the original key down will be passed on to the client.
    let handled  = autoreleasepool {
      var handled = false
      
      if session == 0 || !rimeAPI.find_session(session) {
        createSession()
        if session == 0 {
          return false
        }
      }
      
      let app = (sender as? IMKTextInput)?.bundleIdentifier()
      if let app = app, currentApp != app {
        currentApp = app
        updateAppOptions()
      }
      
      switch event.type {
      case .flagsChanged:
        if lastModifier == modifiers {
          handled = true
          break
        }
        // print("[DEBUG] FLAGSCHANGED client: \(sender ?? "nil"), modifiers: \(modifiers)")
        var rimeModifiers: UInt32 = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers.rawValue)
        // For flags-changed event, keyCode is available since macOS 10.15
        // (#715)
        let rimeKeycode: UInt32 = SquirrelKeycode.osxKeycodeToRime(keycode: event.keyCode, keychar: Character(""), shift: false, caps: false)
        var releaseMask: UInt32 = 0
        let changes: UInt = UInt(lastModifier.rawValue ^ modifiers.rawValue)
        if changes & NSEvent.ModifierFlags.capsLock.rawValue != 0 {
          // NOTE: rime assumes XK_Caps_Lock to be sent before modifier changes,
          // while NSFlagsChanged event has the flag changed already.
          // so it is necessary to revert kLockMask.
          rimeModifiers ^= UInt32(kLockMask.rawValue);
          handled = processKey(rimeKeycode, modifiers: rimeModifiers)
        }
        if changes & NSEvent.ModifierFlags.shift.rawValue != 0 {
          releaseMask = modifiers.rawValue & NSEvent.ModifierFlags.shift.rawValue != 0 ? 0 : kReleaseMask.rawValue
          handled = processKey(rimeKeycode, modifiers: rimeModifiers | releaseMask)
        }
        if changes & NSEvent.ModifierFlags.control.rawValue != 0 {
          releaseMask = modifiers.rawValue & NSEvent.ModifierFlags.control.rawValue != 0 ? 0 : kReleaseMask.rawValue
          handled = processKey(rimeKeycode, modifiers: rimeModifiers | releaseMask)
        }
        if changes & NSEvent.ModifierFlags.option.rawValue != 0 {
          releaseMask = modifiers.rawValue & NSEvent.ModifierFlags.option.rawValue != 0 ? 0 : kReleaseMask.rawValue
          handled = processKey(rimeKeycode, modifiers: rimeModifiers | releaseMask)
        }
        if changes & NSEvent.ModifierFlags.command.rawValue != 0 {
          releaseMask = modifiers.rawValue & NSEvent.ModifierFlags.command.rawValue != 0 ? 0 : kReleaseMask.rawValue
          handled = processKey(rimeKeycode, modifiers: rimeModifiers | releaseMask)
        }
        rimeUpdate()
        
      case .keyDown:
        // ignore Command+X hotkeys.
        if modifiers.rawValue & NSEvent.ModifierFlags.command.rawValue != 0 {
          break
        }
        
        let keyCode = event.keyCode
        var keyChars = event.charactersIgnoringModifiers
        if let code = keyChars?.unicodeScalars.first, !code.isASCII {
          keyChars = event.characters
        }
        // print("[DEBUG] KEYDOWN client: \(sender ?? "nil"), modifiers: \(modifiers), keyCode: \(keyCode), keyChars: [\(keyChars ?? "empty")]")
        
        // translate osx keyevents to rime keyevents
        if let char = keyChars?.first {
          let rimeKeycode = SquirrelKeycode.osxKeycodeToRime(keycode: keyCode, keychar: char,
                                             shift: modifiers.rawValue & NSEvent.ModifierFlags.shift.rawValue != 0,
                                             caps: modifiers.rawValue & NSEvent.ModifierFlags.capsLock.rawValue != 0)
          if rimeKeycode != 0 {
            let rimeModifiers = SquirrelKeycode.osxModifiersToRime(modifiers: modifiers.rawValue)
            handled = processKey(rimeKeycode, modifiers: rimeModifiers)
            rimeUpdate()
          }
        }
        
      default:
        break
      }
      return handled
    }
    
    if event.type == .flagsChanged {
      lastModifier = modifiers
    }
    lastEventType = event.type
    
    return handled
  }
  
  func selectCandidate(_ index: Int) -> Bool {
    let success = rimeAPI.select_candidate_on_current_page(session, index)
    if success {
      rimeUpdate()
    }
    return success
  }
  
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
  
  func recognizedEvents(_ sender: Any!) -> NSEvent.EventTypeMask {
    // print("[DEBUG] recognizedEvents:")
    return [.keyDown, .flagsChanged]
  }
  
  override func activateServer(_ sender: Any!) {
    // print("[DEBUG] activateServer:")
    var keyboardLayout = NSApp.squirrelAppDelegate.config?.getString("keyboard_layout") ?? ""
    if keyboardLayout == "last" || keyboardLayout == "" {
      keyboardLayout = ""
    } else if keyboardLayout == "default" {
      keyboardLayout = "com.apple.keylayout.ABC"
    } else if !keyboardLayout.hasPrefix("com.apple.keylayout.") {
      keyboardLayout = "com.apple.keylayout.\(keyboardLayout)"
    }
    if keyboardLayout != "" {
      (sender as? IMKTextInput)?.overrideKeyboard(withKeyboardNamed: keyboardLayout)
    }
    preedit = ""
  }
  
  override init!(server: IMKServer!, delegate: Any!, client: Any!) {
    // print("[DEBUG] initWithServer: \(server ?? .init()) delegate: \(delegate ?? "nil") client:\(client ?? "nil")")
    super.init(server: server, delegate: delegate, client: client)
    createSession()
  }
  
  override func deactivateServer(_ sender: Any!) {
    // print("[DEBUG] deactivateServer: \(sender ?? "nil")")
    hidePalettes()
    commitComposition(sender)
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
    deploy.keyEquivalentModifierMask = [NSEvent.ModifierFlags.control, NSEvent.ModifierFlags.option]
    let sync = NSMenuItem(title: NSLocalizedString("Sync user data", comment: "Menu item"), action: #selector(syncUserData), keyEquivalent: "")
    sync.target = self
    let setting = NSMenuItem(title: NSLocalizedString("Settings...", comment: "Menu item"), action: #selector(configure), keyEquivalent: "")
    setting.target = self
    let wiki = NSMenuItem(title: NSLocalizedString("Rime Wiki...", comment: "Menu item"), action: #selector(openWiki), keyEquivalent: "")
    wiki.target = self
    let update = NSMenuItem(title: NSLocalizedString("Check for updates...", comment: "Menu item"), action: #selector(checkForUpdates), keyEquivalent: "")
    update.target = self
    
    let menu = NSMenu()
    menu.addItem(deploy)
    menu.addItem(sync)
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
  
  @objc func configure() {
    NSApp.squirrelAppDelegate.configure()
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
  
  func onChordTimer(_ timer: Timer) {
    // chord release triggered by timer
    var processedKeys = false
    if chordKeyCount > 0 && session != 0 {
      // simulate key-ups
      for i in 0..<chordKeyCount {
        if rimeAPI.process_key(session, Int32(chordKeyCodes[i]), Int32(chordModifiers[i] | kReleaseMask.rawValue)) {
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
    for i in 0..<chordKeyCount {
      if chordKeyCodes[i] == keycode {
        return
      }
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
    guard let app = client().bundleIdentifier() else { return }
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
      let _ = rimeAPI.destroy_session(session)
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
      let isChordingKey =
      (rimeKeycode >= XK_space && rimeKeycode <= XK_asciitilde) ||
      rimeKeycode == XK_Control_L || rimeKeycode == XK_Control_R ||
      rimeKeycode == XK_Alt_L || rimeKeycode == XK_Alt_R ||
      rimeKeycode == XK_Shift_L || rimeKeycode == XK_Shift_R
      if isChordingKey &&
          rimeAPI.get_option(session, "_chord_typing") {
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
        let _ = rimeAPI.free_commit(&commitText)
      }
    }
  }
  
  func rimeUpdate() {
    // print("[DEBUG] rimeUpdate")
    rimeConsumeCommittedText()
    
    var status = RimeStatus.rimeStructInit()
    if rimeAPI.get_status(session, &status) {
      // enable schema specific ui style
      if let schema_id = status.schema_id, schemaId == "" || schemaId != String(cString: schema_id) {
        schemaId = String(cString: schema_id)
        NSApp.squirrelAppDelegate.loadSettings(for: schemaId)
        // inline preedit
        if let panel = NSApp.squirrelAppDelegate.panel {
          inlinePreedit = panel.inlinePreedit && (!rimeAPI.get_option(session, "no_inline") || rimeAPI.get_option(session, "inline"))
          inlineCandidate = panel.inlineCandidate && (!rimeAPI.get_option(session, "no_inline") || rimeAPI.get_option(session, "inline"))
          // if not inline, embed soft cursor in preedit string
          rimeAPI.set_option(session, "soft_cursor", !inlinePreedit)
        }
      }
      let _ = rimeAPI.free_status(&status)
    }
    
    var ctx = RimeContext.rimeStructInit()
    if rimeAPI.get_context(session, &ctx) {
      // update preedit text
      let preedit = ctx.composition.preedit.map({ String(cString: $0) }) ?? ""
        
      let start = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start)), within: preedit) ?? preedit.startIndex
      let end = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end)), within: preedit) ?? preedit.startIndex
      let caretPos = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos)), within: preedit) ?? preedit.endIndex
      
      if inlineCandidate {
        var candidatePreview = ctx.commit_text_preview.map { String(cString: $0) } ?? ""
        if inlinePreedit {
          if caretPos >= end && caretPos < preedit.endIndex {
            candidatePreview += preedit[caretPos...]
          }
          show(preedit: candidatePreview,
               selRange: NSRange(location: start.utf16Offset(in: candidatePreview), length: candidatePreview.utf16.distance(from: start, to: candidatePreview.endIndex)),
               caretPos: candidatePreview.utf16.count - preedit.utf16.distance(from: caretPos, to: preedit.endIndex))
        } else {
          if end < caretPos && start < caretPos {
            candidatePreview = String(candidatePreview[..<candidatePreview.index(candidatePreview.endIndex, offsetBy: -preedit.distance(from: end, to: caretPos))])
          } else if end < preedit.endIndex && caretPos <= start {
            candidatePreview = String(candidatePreview[..<candidatePreview.index(candidatePreview.endIndex, offsetBy: -preedit.distance(from: end, to: preedit.endIndex))])
          }
          show(preedit: candidatePreview,
               selRange: NSRange(location: start.utf16Offset(in: candidatePreview), length: candidatePreview.utf16.distance(from: start, to: candidatePreview.endIndex)),
               caretPos: candidatePreview.utf16.count)
        }
      } else {
        if inlinePreedit {
          show(preedit: preedit, selRange: NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end)), caretPos: caretPos.utf16Offset(in: preedit))
        } else {
          // TRICKY: display a non-empty string to prevent iTerm2 from echoing
          // each character in preedit. note this is a full-shape space U+3000;
          // using half shape characters like "..." will result in an unstable
          // baseline when composing Chinese characters.
          show(preedit: preedit.isEmpty ? "" : "　", selRange: NSMakeRange(0, 0), caretPos: 0)
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
      if let select_keys = ctx.menu.select_keys {
        labels = Array(arrayLiteral: String(cString: select_keys))
      } else if let select_labels = ctx.select_labels {
        let pageSize = Int(ctx.menu.page_size)
        for i in 0..<pageSize {
          labels.append(select_labels[i].map { String(cString: $0) } ?? "")
        }
      }
      showPanel(preedit: inlinePreedit ? "" : preedit, selRange: NSRange(location: start.utf16Offset(in: preedit), length: preedit.utf16.distance(from: start, to: end)), caretPos: caretPos.utf16Offset(in: preedit), candidates: candidates, comments: comments, labels: labels, highlighted: Int(ctx.menu.highlighted_candidate_index))
      let _ = rimeAPI.free_context(&ctx)
    } else {
      hidePalettes()
    }
  }
  
  func commit(string: String) {
    // print("[DEBUG] commitString: \(string)")
    client().insertText(string, replacementRange: NSMakeRange(NSNotFound, 0))
    preedit = ""
    hidePalettes()
  }
  
  func show(preedit: String, selRange: NSRange, caretPos: Int) {
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
      let attrs = mark(forStyle: kTSMHiliteConvertedText, at: NSMakeRange(0, start))! as! [NSAttributedString.Key : Any]
      attrString.setAttributes(attrs, range: NSMakeRange(0, start))
    }
    let remainingRange = NSMakeRange(start, preedit.utf16.count - start)
    let attrs = mark(forStyle: kTSMHiliteSelectedRawText, at: remainingRange)! as! [NSAttributedString.Key : Any]
    attrString.setAttributes(attrs, range: remainingRange)
    client().setMarkedText(attrString, selectionRange: NSMakeRange(caretPos, 0), replacementRange: NSMakeRange(NSNotFound, NSNotFound))
  }
  
  func showPanel(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted: Int) {
    // print("[DEBUG] showPanelWithPreedit:...:")
    var inputPos = NSRect()
    client().attributes(forCharacterIndex: 0, lineHeightRectangle: &inputPos)
    if let panel = NSApp.squirrelAppDelegate.panel {
      panel.position = inputPos
      panel.inputController = self
      panel.update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: highlighted, update: true)
    }
  }
}
