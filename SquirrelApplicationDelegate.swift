//
//  SquirrelApplicationDelegate.swift
//  Squirrel
//
//  Created by Leo Liu on 5/6/24.
//

import UserNotifications
import Sparkle
import AppKit

class SquirrelApplicationDelegate: NSObject, NSApplicationDelegate {
  static let rimeWikiURL = URL(string: "https://github.com/rime/home/wiki")!
  
  let rimeAPI: RimeApi = rime_get_api().pointee
  var config: SquirrelConfig?
  var panel: SquirrelPanel?
  var enableNotifications = false
  let updateController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  
  func applicationWillFinishLaunching(_ notification: Notification) {
    addObservers()
  }
  
  func applicationWillTerminate(_ notification: Notification) {
    NotificationCenter.default.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
    panel?.hide()
  }
  
  @objc func deploy() {
    print("Start maintenance...")
    self.shutdownRime()
    self.startRime(fullCheck: true)
    self.loadSettings()
  }
  
  @objc func syncUserData() {
    print("Sync user data")
    let _ = rimeAPI.sync_user_data()
  }
  
  @objc func configure() {
    let configURL = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Rime", isDirectory: true)
    NSWorkspace.shared.open(configURL)
  }
  
  @objc func checkForUpdates() {
    if updateController.updater.canCheckForUpdates {
      print("Checking for updates")
      updateController.updater.checkForUpdates()
    } else {
      print("Cannot check for updates")
    }
  }
  
  @objc func openWiki() {
    NSWorkspace.shared.open(Self.rimeWikiURL)
  }
  
  static func showMessage(msgText: String?, msgId: String?) {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .provisional]) { granted, error in
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
        let request = UNNotificationRequest(identifier: "SquirrelNotification", content: content, trigger: nil)
        center.add(request) { error in
          if let error = error {
            print("User notification request error: \(error.localizedDescription)")
          }
        }
      }
    }
  }
  
  func setupRime() {
    let userDataDir = try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Rime", isDirectory: true)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: userDataDir.path()) {
      do {
        try fileManager.createDirectory(at: userDataDir, withIntermediateDirectories: true)
      } catch {
        print("Error creating user data directory: \(userDataDir.path())")
      }
    }
    let notification_handler: @convention(c) (UnsafeMutableRawPointer?, RimeSessionId, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = notificationHandler
    let context_object = Unmanaged.passUnretained(self).toOpaque()
    rimeAPI.set_notification_handler(notification_handler, context_object)
    
    var squirrelTraits = RimeTraits.rimeStructInit()
    Bundle.main.sharedSupportPath!.withCString { cString in
      squirrelTraits.shared_data_dir = cString
    }
    userDataDir.path().withCString { cString in
      squirrelTraits.user_data_dir = cString
    }
    "Squirrel".withCString { cString in
      squirrelTraits.distribution_code_name = cString
    }
    "鼠鬚管".withCString { cString in
      squirrelTraits.distribution_name = cString
    }
    (Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String).withCString { cString in
      squirrelTraits.distribution_version = cString
    }
    "rime.squirrel".withCString { cString in
      squirrelTraits.app_name = cString
    }
    rimeAPI.setup(&squirrelTraits)
  }
  
  func startRime(fullCheck: Bool) {
    print("Initializing la rime...")
    rimeAPI.initialize(nil)
    // check for configuration updates
    if rimeAPI.start_maintenance(fullCheck) {
      // update squirrel config
      // print("[DEBUG] maintenance suceeds")
      let _ = rimeAPI.deploy_config_file("squirrel.yaml", "config_version")
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
    //print("[DEBUG] archive: \(logFile)")
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
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_start", comment: ""), msgId: messageType)
    case "success":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_success", comment: ""), msgId: messageType)
    case "failure":
      SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_failure", comment: ""), msgId: messageType)
    default:
      break
    }
    return
  }
  // off
  if !delegate.enableNotifications {
    return
  }
  // schema change
  if messageType == "schema", let messageValue = messageValue, let schemaName = try? /^[^\/]*\/(.*)$/.firstMatch(in: messageValue)?.output.1 {
    delegate.showStatusMessage(msgTextLong: String(schemaName), msgTextShort: String(schemaName))
    return
  }
  // option change
  if messageType == "option" {
    let state = messageValue?.first != "!"
    let optionName = if state {
      messageValue
    } else {
      String(messageValue![messageValue!.index(after: messageValue!.startIndex)...])
    }
    let stateLabelLong = delegate.rimeAPI.get_state_label_abbreviated(sessionId, optionName?.cString(using: .utf8), state, false)
    let stateLabelShort = delegate.rimeAPI.get_state_label_abbreviated(sessionId, optionName?.cString(using: .utf8), state, true)
    let longLabel = stateLabelLong.str.map { String(cString: $0) }
    let shortLabel = stateLabelShort.str.map { String(cString: $0) }
    delegate.showStatusMessage(msgTextLong: longLabel, msgTextShort: shortLabel)
  }
}

private extension SquirrelApplicationDelegate {
  func showStatusMessage(msgTextLong: String?, msgTextShort: String?) {
    panel?.updateStatus(long: msgTextLong ?? "", short: msgTextShort ?? "")
  }
  
  func shutdownRime() {
    config?.close()
    rimeAPI.finalize()
  }
  
  func workspaceWillPowerOff(notification: Notification) {
    print("Finalizing before logging out.")
    self.shutdownRime()
  }
  
  func rimeNeedsReload(notification: Notification) {
    print("Reloading rime on demand.")
    self.deploy()
  }
  
  func rimeNeedsSync(notification: Notification) {
    print("Sync rime on demand.")
    self.syncUserData()
  }
}

extension NSApplication {
  var squirrelAppDelegate: SquirrelApplicationDelegate {
    self.delegate as! SquirrelApplicationDelegate
  }
}
