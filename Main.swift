//
//  CommandLine.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

@main
struct SquirrelApp {
  static let connectionName = "Squirrel_1_Connection"
  
  static func main() {
    let installer = SquirrelInstaller()
    let rimeAPI = rime_get_api().pointee
    let args = CommandLine.arguments
    if args.count > 1 {
      switch args[1] {
      case "--quit":
        let bundleId = Bundle.main.bundleIdentifier!
        let runningSquirrels = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        runningSquirrels.forEach { $0.terminate() }
        return
      case "--reload":
        DistributedNotificationCenter.default().postNotificationName(.init("SquirrelReloadNotification"), object: nil)
        return
      case "--register-input-source", "--install":
        installer.register()
        return
      case "--enable-input-source":
        installer.enable()
        return
      case "--disable-input-source":
        installer.disable()
        return
      case "--select-input-source":
        installer.select()
        return
      case "--build":
        // Notification
        SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_update", comment: ""))
        // Build all schemas in current directory
        var builderTraits = RimeTraits()
        "rime.squirrel-builder".withCString { appName in
          builderTraits.app_name = appName
        }
        rimeAPI.setup(&builderTraits)
        rimeAPI.deployer_initialize(nil)
        _ = rimeAPI.deploy()
        return
      case "--sync":
        DistributedNotificationCenter.default().postNotificationName(.init("SquirrelSyncNotification"), object: nil)
        return
      default:
        break
      }
    }
    
    // find the bundle identifier and then initialize the input method server
    let main = Bundle.main
    let _ = IMKServer(name: Self.connectionName, bundleIdentifier: main.bundleIdentifier!)
    // load the bundle explicitly because in this case the input method is a
    // background only application
    let app = NSApplication.shared
    let delegate = SquirrelApplicationDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    
    // opencc will be configured with relative dictionary paths
    FileManager.default.changeCurrentDirectoryPath(main.sharedSupportPath!)
    
    if NSApp.squirrelAppDelegate.problematicLaunchDetected() {
      print("Problematic launch detected!")
      let args = ["Problematic launch detected! Squirrel may be suffering a crash due to improper configuration. Revert previous modifications to see if the problem recurs."]
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
      task.arguments = args
      try? task.run()
    } else {
      NSApp.squirrelAppDelegate.setupRime()
      NSApp.squirrelAppDelegate.startRime(fullCheck: false)
      NSApp.squirrelAppDelegate.loadSettings()
      print("Squirrel reporting!")
    }
    
    // finally run everything
    app.run()
    print("Squirrel is quitting...")
    rimeAPI.finalize()
  }
}
