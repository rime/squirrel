//
//  SquirrelApplicationDelegate.swift
//  Squirrel
//
//  Created by Leo Liu on 5/6/24.
//

import UserNotifications
import Sparkle
import AppKit

final class SquirrelApplicationDelegate: NSObject, NSApplicationDelegate, SPUStandardUserDriverDelegate, UNUserNotificationCenterDelegate, QuickAddWordPanelDelegate {
  static let rimeWikiURL = URL(string: "https://github.com/rime/home/wiki")!
  static let updateNotificationIdentifier = "SquirrelUpdateNotification"
  static let notificationIdentifier = "SquirrelNotification"
  static let quickAddWordNotification = "SquirrelQuickAddWordNotification"
  static let quickAddWordNotificationObject = "/Library/Input Methods/SquirrelFlypy.app"

  let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  var config: SquirrelConfig?
  var panel: SquirrelPanel?
  var quickAddWordPanel: QuickAddWordPanel?
  private var quickAddWordActivationPolicyBeforePanel: NSApplication.ActivationPolicy?
  var enableNotifications = false
  let updateController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  var supportsGentleScheduledUpdateReminders: Bool {
    true
  }

  func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
    NSApp.setActivationPolicy(.regular)
    if !state.userInitiated {
      NSApp.dockTile.badgeLabel = "1"
      let content = UNMutableNotificationContent()
      content.title = NSLocalizedString("A new update is available", comment: "Update")
      content.body = NSLocalizedString("Version [version] is now available", comment: "Update").replacingOccurrences(of: "[version]", with: update.displayVersionString)
      let request = UNNotificationRequest(identifier: Self.updateNotificationIdentifier, content: content, trigger: nil)
      UNUserNotificationCenter.current().add(request)
    }
  }

  func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
    NSApp.dockTile.badgeLabel = ""
    UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.updateNotificationIdentifier])
  }

  func standardUserDriverWillFinishUpdateSession() {
    NSApp.setActivationPolicy(.accessory)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.notification.request.identifier == Self.updateNotificationIdentifier && response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      updateController.updater.checkForUpdates()
    }

    completionHandler()
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    panel = SquirrelPanel(position: .zero)
    quickAddWordPanel = QuickAddWordPanel()
    quickAddWordPanel?.delegate = self
    addObservers()
  }

  func applicationWillTerminate(_ notification: Notification) {
    // swiftlint:disable:next notification_center_detachment
    NotificationCenter.default.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
    panel?.hide()
  }

  func deploy() {
    print("Start maintenance...")
    self.shutdownRime()
    self.startRime(fullCheck: true)
    self.loadSettings()
  }

  func syncUserData() {
    print("Sync user data")
    _ = rimeAPI.sync_user_data()
  }

  func openLogFolder() {
    NSWorkspace.shared.open(SquirrelApp.logDir)
  }

  func openRimeFolder() {
    NSWorkspace.shared.open(SquirrelApp.userDir)
  }

  func checkForUpdates() {
    if updateController.updater.canCheckForUpdates {
      print("Checking for updates")
      updateController.updater.checkForUpdates()
    } else {
      print("Cannot check for updates")
    }
  }

  func openWiki() {
    NSWorkspace.shared.open(Self.rimeWikiURL)
  }

  /// Opens the quick-add panel and optionally pre-fills fields.
  func showQuickAddWordPanel(prefillWord: String? = nil, prefillCode: String? = nil) {
    DispatchQueue.main.async {
      if self.quickAddWordPanel == nil {
        self.quickAddWordPanel = QuickAddWordPanel()
        self.quickAddWordPanel?.delegate = self
      }
      self.prepareActivationPolicyForQuickAddPanel()
      self.quickAddWordPanel?.show(prefillWord: prefillWord, prefillCode: prefillCode)
    }
  }

  /// Handles panel confirm callbacks by validating and persisting a phrase entry.
  func quickAddWordPanel(_ panel: QuickAddWordPanel, didConfirmWord word: String, code: String) {
    guard !word.isEmpty, !code.isEmpty else {
      Self.showMessage(msgText: "快速加词失败：词条和编码不能为空")
      return
    }
    guard !word.contains("\t"), !code.contains("\t"), validateQuickAddCode(code) else {
      Self.showMessage(msgText: "快速加词失败：编码仅支持字母、数字、空格和撇号")
      return
    }
    do {
      try appendQuickAddWord(word: word, code: code)
      panel.hide()
      self.restoreActivationPolicyAfterQuickAddPanelIfNeeded()
      if quickAddWordPanel === panel {
        quickAddWordPanel = nil
      }
      deploy()
      Self.showMessage(msgText: "快速加词成功")
    } catch {
      Self.showMessage(msgText: "快速加词失败：\(error.localizedDescription)")
    }
  }

  /// Handles panel cancel callbacks.
  func quickAddWordPanelDidCancel(_ panel: QuickAddWordPanel) {
    panel.hide()
    self.restoreActivationPolicyAfterQuickAddPanelIfNeeded()
    if quickAddWordPanel === panel {
      quickAddWordPanel = nil
    }
  }

  static func showMessage(msgText: String?) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .provisional]) { _, error in
      if let error = error {
        print("User notification authorization error: \(error.localizedDescription)")
      }
    }
    center.getNotificationSettings { settings in
      if (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) && settings.alertSetting == .enabled {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Squirrel", comment: "")
        if let msgText = msgText {
          content.subtitle = msgText
        }
        content.interruptionLevel = .active
        let request = UNNotificationRequest(identifier: Self.notificationIdentifier, content: content, trigger: nil)
        center.add(request) { error in
          if let error = error {
            print("User notification request error: \(error.localizedDescription)")
          }
        }
      }
    }
  }

  func setupRime() {
    createDirIfNotExist(path: SquirrelApp.userDir)
    createDirIfNotExist(path: SquirrelApp.logDir)
    // swiftlint:disable identifier_name
    let notification_handler: @convention(c) (UnsafeMutableRawPointer?, RimeSessionId, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = notificationHandler
    let context_object = Unmanaged.passUnretained(self).toOpaque()
    // swiftlint:enable identifier_name
    rimeAPI.set_notification_handler(notification_handler, context_object)

    var squirrelTraits = RimeTraits.rimeStructInit()
    squirrelTraits.setCString(Bundle.main.sharedSupportPath!, to: \.shared_data_dir)
    squirrelTraits.setCString(SquirrelApp.userDir.path(percentEncoded: false), to: \.user_data_dir)
    squirrelTraits.setCString(SquirrelApp.logDir.path(percentEncoded: false), to: \.log_dir)
    squirrelTraits.setCString("Squirrel", to: \.distribution_code_name)
    squirrelTraits.setCString("鼠鬚管", to: \.distribution_name)
    squirrelTraits.setCString(Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String, to: \.distribution_version)
    squirrelTraits.setCString("rime.squirrel", to: \.app_name)
    rimeAPI.setup(&squirrelTraits)
  }

  func startRime(fullCheck: Bool) {
    print("Initializing la rime...")
    rimeAPI.initialize(nil)
    // check for configuration updates
    if rimeAPI.start_maintenance(fullCheck) {
      // update squirrel config
      // print("[DEBUG] maintenance suceeds")
      _ = rimeAPI.deploy_config_file("squirrel.yaml", "config_version")
    } else {
      // print("[DEBUG] maintenance fails")
    }
  }

  func loadSettings() {
    config = SquirrelConfig()
    if !config!.openBaseConfig() {
      return
    }

    enableNotifications = config!.getString("show_notifications_when") != "never"
    if let panel = panel, let config = self.config {
      panel.load(config: config, forDarkMode: false)
      panel.load(config: config, forDarkMode: true)
    }
  }

  func loadSettings(for schemaID: String) {
    if schemaID.count == 0 || schemaID.first == "." {
      return
    }
    let schema = SquirrelConfig()
    if let panel = panel, let config = self.config {
      if schema.open(schemaID: schemaID, baseConfig: config) && schema.has(section: "style") {
        panel.load(config: schema, forDarkMode: false)
        panel.load(config: schema, forDarkMode: true)
      } else {
        panel.load(config: config, forDarkMode: false)
        panel.load(config: config, forDarkMode: true)
      }
    }
    schema.close()
  }

  // prevent freezing the system
  func problematicLaunchDetected() -> Bool {
    var detected = false
    let logFile = FileManager.default.temporaryDirectory.appendingPathComponent("squirrel_launch.json", conformingTo: .json)
    // print("[DEBUG] archive: \(logFile)")
    do {
      let archive = try Data(contentsOf: logFile, options: [.uncached])
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .millisecondsSince1970
      let previousLaunch = try decoder.decode(Date.self, from: archive)
      if previousLaunch.timeIntervalSinceNow >= -2 {
        detected = true
      }
    } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {

    } catch {
      print("Error occurred during processing launch time archive: \(error.localizedDescription)")
      return detected
    }
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .millisecondsSince1970
      let record = try encoder.encode(Date.now)
      try record.write(to: logFile)
    } catch {
      print("Error occurred during saving launch time to archive: \(error.localizedDescription)")
    }
    return detected
  }

  // add an awakeFromNib item so that we can set the action method.  Note that
  // any menuItems without an action will be disabled when displayed in the Text
  // Input Menu.
  func addObservers() {
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: nil, using: workspaceWillPowerOff)

    let notifCenter = DistributedNotificationCenter.default()
    notifCenter.addObserver(forName: .init("SquirrelReloadNotification"), object: nil, queue: nil, using: rimeNeedsReload)
    notifCenter.addObserver(forName: .init("SquirrelSyncNotification"), object: nil, queue: nil, using: rimeNeedsSync)
    notifCenter.addObserver(self,
                            selector: #selector(handleQuickAddWordNotification(_:)),
                            name: .init(Self.quickAddWordNotification),
                            object: Self.quickAddWordNotificationObject,
                            suspensionBehavior: .deliverImmediately)
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    print("Squirrel is quitting.")
    rimeAPI.cleanup_all_sessions()
    return .terminateNow
  }

}

private func notificationHandler(contextObject: UnsafeMutableRawPointer?, sessionId: RimeSessionId, messageTypeC: UnsafePointer<CChar>?, messageValueC: UnsafePointer<CChar>?) {
  let delegate: SquirrelApplicationDelegate = Unmanaged<SquirrelApplicationDelegate>.fromOpaque(contextObject!).takeUnretainedValue()

  let messageType = messageTypeC.map { String(cString: $0) }
  let messageValue = messageValueC.map { String(cString: $0) }
  if messageType == "deploy" {
    switch messageValue {
    case "start":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_start", comment: ""))
    case "success":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_success", comment: ""))
    case "failure":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_failure", comment: ""))
    default:
      break
    }
    return
  }
  // off
  if !delegate.enableNotifications {
    return
  }

  if messageType == "schema", let messageValue = messageValue, let schemaName = try? /^[^\/]*\/(.*)$/.firstMatch(in: messageValue)?.output.1 {
    delegate.showStatusMessage(msgTextLong: String(schemaName), msgTextShort: String(schemaName))
    return
  } else if messageType == "option" {
    let state = messageValue?.first != "!"
    let optionName = if state {
      messageValue
    } else {
      String(messageValue![messageValue!.index(after: messageValue!.startIndex)...])
    }
    if let optionName = optionName {
      optionName.withCString { name in
        let stateLabelLong = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, false)
        let stateLabelShort = delegate.rimeAPI.get_state_label_abbreviated(sessionId, name, state, true)
        let longLabel = stateLabelLong.str.map { String(cString: $0) }
        let shortLabel = stateLabelShort.str.map { String(cString: $0) }
        delegate.showStatusMessage(msgTextLong: longLabel, msgTextShort: shortLabel)
      }
    }
  }
}

private extension SquirrelApplicationDelegate {
  /// Caches the current `NSApp` activation policy and switches to regular when needed so the quick-add window can take focus; skips if a quick-add session already stashed a policy.
  func prepareActivationPolicyForQuickAddPanel() {
    if quickAddWordActivationPolicyBeforePanel != nil { return }
    quickAddWordActivationPolicyBeforePanel = NSApp.activationPolicy()
    if NSApp.activationPolicy() != .regular {
      NSApp.setActivationPolicy(.regular)
    }
  }

  /// Restores the activation policy stashed in `prepareActivationPolicyForQuickAddPanel` after the quick-add UI is dismissed.
  func restoreActivationPolicyAfterQuickAddPanelIfNeeded() {
    guard let previous = quickAddWordActivationPolicyBeforePanel else { return }
    quickAddWordActivationPolicyBeforePanel = nil
    NSApp.setActivationPolicy(previous)
  }

  func showStatusMessage(msgTextLong: String?, msgTextShort: String?) {
    if !(msgTextLong ?? "").isEmpty || !(msgTextShort ?? "").isEmpty {
      panel?.updateStatus(long: msgTextLong ?? "", short: msgTextShort ?? "")
    }
  }

  func shutdownRime() {
    config?.close()
    rimeAPI.finalize()
  }

  func workspaceWillPowerOff(_: Notification) {
    print("Finalizing before logging out.")
    self.shutdownRime()
  }

  func rimeNeedsReload(_: Notification) {
    print("Reloading rime on demand.")
    self.deploy()
  }

  func rimeNeedsSync(_: Notification) {
    print("Sync rime on demand.")
    self.syncUserData()
  }

  /// Responds to distributed quick-add notifications by showing the panel.
  @objc func handleQuickAddWordNotification(_ notification: Notification) {
    rimeNeedsQuickAddWord(notification)
  }

  func rimeNeedsQuickAddWord(_: Notification) {
    print("Open quick add word panel on demand.")
    self.showQuickAddWordPanel()
  }

  /// Ensures the target directory exists.
  func createDirIfNotExist(path: URL) {
    let fileManager = FileManager.default
    let decodedPath = path.path(percentEncoded: false)
    if !fileManager.fileExists(atPath: decodedPath) {
      do {
        try fileManager.createDirectory(at: path, withIntermediateDirectories: true)
      } catch {
        print("Error creating user data directory: \(decodedPath)")
      }
    }
  }

  /// Validates quick-add code characters against allowed ASCII set.
  func validateQuickAddCode(_ code: String) -> Bool {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' ")
    return code.unicodeScalars.allSatisfy { allowed.contains($0) }
  }

  /// Returns the target user dictionary file path used by quick-add.
  func quickAddUserDictURL() -> URL {
    SquirrelApp.userDir.appendingPathComponent("flypy_user.txt", isDirectory: false)
  }

  /// Appends a new quick-add entry to the user dictionary file.
  func appendQuickAddWord(word: String, code: String) throws {
    let fileURL = quickAddUserDictURL()
    let line = "\(word)\t\(code)"
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: fileURL.path(percentEncoded: false)) {
      try "# coding: utf-8\n".write(to: fileURL, atomically: true, encoding: .utf8)
    }
    let oldText = try String(contentsOf: fileURL, encoding: .utf8)
    let needsNewline = oldText.isEmpty || oldText.hasSuffix("\n")
    let merged = oldText + (needsNewline ? "" : "\n") + line + "\n"
    try merged.write(to: fileURL, atomically: true, encoding: .utf8)
  }

}

extension NSApplication {
  var squirrelAppDelegate: SquirrelApplicationDelegate {
    self.delegate as! SquirrelApplicationDelegate
  }
}
