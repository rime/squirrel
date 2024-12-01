//
//  GlobalContext.swift
//  Squirrel
//
//  Created by mi on 2024/12/1.
//

import Foundation
import UserNotifications

final class GlobalContext {
  static let shared = GlobalContext()

  let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  var config: SquirrelConfig?
  var panel: SquirrelPanel?
  var enableNotifications = false

  static let notificationIdentifier = "SquirrelNotification"

  enum Path {
    static let userDir = if let pwuid = getpwuid(getuid()) {
      URL(fileURLWithFileSystemRepresentation: pwuid.pointee.pw_dir, isDirectory: true, relativeTo: nil).appending(components: "Library", "Rime")
    } else {
      try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Rime", isDirectory: true)
    }
    static let appDir = "/Library/Input Library/Squirrel.app".withCString { dir in
      URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
    }
    static let logDir = FileManager.default.temporaryDirectory.appending(component: "rime.squirrel", directoryHint: .isDirectory)
  }

  func setupRime() {
    FileManager.default.createDirIfNotExist(path: Path.userDir)
    FileManager.default.createDirIfNotExist(path: Path.logDir)
    // swiftlint:disable identifier_name
    let notification_handler: @convention(c) (UnsafeMutableRawPointer?, RimeSessionId, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void = notificationHandler
    let context_object = Unmanaged.passUnretained(self).toOpaque()
    // swiftlint:enable identifier_name
    rimeAPI.set_notification_handler(notification_handler, context_object)

    var squirrelTraits = RimeTraits.rimeStructInit()
    squirrelTraits.setCString(Bundle.main.sharedSupportPath!, to: \.shared_data_dir)
    squirrelTraits.setCString(Path.userDir.path(), to: \.user_data_dir)
    squirrelTraits.setCString(Path.logDir.path(), to: \.log_dir)
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

  func deploy() {
    print("Start maintenance...")
    self.shutdownRime()
    self.startRime(fullCheck: true)
    self.loadSettings()
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

  func showStatusMessage(msgTextLong: String?, msgTextShort: String?) {
    if !(msgTextLong ?? "").isEmpty || !(msgTextShort ?? "").isEmpty {
      panel?.updateStatus(long: msgTextLong ?? "", short: msgTextShort ?? "")
    }
  }

  func shutdownRime() {
    config?.close()
    rimeAPI.finalize()
  }
}


func showMessage(msgText: String?) {
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
      let request = UNNotificationRequest(identifier: GlobalContext.notificationIdentifier, content: content, trigger: nil)
      center.add(request) { error in
        if let error = error {
          print("User notification request error: \(error.localizedDescription)")
        }
      }
    }
  }
}

private func notificationHandler(contextObject: UnsafeMutableRawPointer?, sessionId: RimeSessionId, messageTypeC: UnsafePointer<CChar>?, messageValueC: UnsafePointer<CChar>?) {
  let context: GlobalContext = Unmanaged<GlobalContext>.fromOpaque(contextObject!).takeUnretainedValue()

  let messageType = messageTypeC.map { String(cString: $0) }
  let messageValue = messageValueC.map { String(cString: $0) }
  if messageType == "deploy" {
    switch messageValue {
    case "start":
      showMessage(msgText: NSLocalizedString("deploy_start", comment: ""))
    case "success":
      showMessage(msgText: NSLocalizedString("deploy_success", comment: ""))
    case "failure":
      showMessage(msgText: NSLocalizedString("deploy_failure", comment: ""))
    default:
      break
    }
    return
  }
  // off
  if !context.enableNotifications {
    return
  }

  if messageType == "schema", let messageValue = messageValue, let schemaName = try? /^[^\/]*\/(.*)$/.firstMatch(in: messageValue)?.output.1 {
    context.showStatusMessage(msgTextLong: String(schemaName), msgTextShort: String(schemaName))
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
        let stateLabelLong = context.rimeAPI.get_state_label_abbreviated(sessionId, name, state, false)
        let stateLabelShort = context.rimeAPI.get_state_label_abbreviated(sessionId, name, state, true)
        let longLabel = stateLabelLong.str.map { String(cString: $0) }
        let shortLabel = stateLabelShort.str.map { String(cString: $0) }
        context.showStatusMessage(msgTextLong: longLabel, msgTextShort: shortLabel)
      }
    }
  }
}
