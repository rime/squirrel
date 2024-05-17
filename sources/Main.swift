//
//  Main.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

@main
struct SquirrelApp {
  static let userDir = if let pw = getpwuid(getuid()) {
    URL(fileURLWithFileSystemRepresentation: pw.pointee.pw_dir, isDirectory: true, relativeTo: nil).appending(components: "Library", "Rime")
  } else {
    try! FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Rime", isDirectory: true)
  }
  static let appDir = "/Library/Input Library/Squirrel.app".withCString { dir in
    URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
  }
  
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
        SquirrelApplicationDelegate.showMessage(msgText: NSLocalizedString("deploy_update", comment: ""), msgId: "deploy")
        // Build all schemas in current directory
        var builderTraits = RimeTraits.rimeStructInit()
        builderTraits.setCString("rime.squirrel-builder", to: \.app_name)
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
    
    autoreleasepool {
      // find the bundle identifier and then initialize the input method server
      let main = Bundle.main
      let connectionName = main.object(forInfoDictionaryKey: "InputMethodConnectionName") as! String
      _ = IMKServer(name: connectionName, bundleIdentifier: main.bundleIdentifier!)
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
        task.executableURL = "/usr/bin/say".withCString { dir in
          URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
        }
        task.arguments = args
        try? task.run()
      } else {
        NSApp.squirrelAppDelegate.setupRime()
        NSApp.squirrelAppDelegate.startRime(fullCheck: true)
        NSApp.squirrelAppDelegate.loadSettings()
        print("Squirrel reporting!")
      }
      
      // finally run everything
      app.run()
      print("Squirrel is quitting...")
      cleanupOldFiles(olderThan: 5)
      rimeAPI.finalize()
    }
    return
  }
  
  static func cleanupOldFiles(olderThan days: Int) {
    let fileManager = FileManager.default
    let currentDate = Date()
    let calendar = Calendar.current
    
    do {
      let fileURLs = try fileManager.contentsOfDirectory(at: fileManager.temporaryDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
      for fileURL in fileURLs {
        if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
          if let daysDifference = calendar.dateComponents([.day], from: creationDate, to: currentDate).day, daysDifference > days {
            try fileManager.removeItem(at: fileURL)
            // print("Deleted: \(fileURL.path)")
          }
        }
      }
    } catch {
      print("Error: \(error.localizedDescription)")
    }
  }
}
