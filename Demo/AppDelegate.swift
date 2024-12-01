//
//  AppDelegate.swift
//  Demo
//
//  Created by mi on 2024/12/1.
//

import Cocoa
import InputController

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application

    if GlobalContext.shared.problematicLaunchDetected() {
      print("Problematic launch detected!")
      let args = ["Problematic launch detected! Squirrel may be suffering a crash due to improper configuration. Revert previous modifications to see if the problem recurs."]
      let task = Process()
      task.executableURL = "/usr/bin/say".withCString { dir in
        URL(fileURLWithFileSystemRepresentation: dir, isDirectory: false, relativeTo: nil)
      }
      task.arguments = args
      try? task.run()
    } else {
      GlobalContext.shared.setupRime()
      GlobalContext.shared.startRime(fullCheck: false)
      GlobalContext.shared.loadSettings()
      print("Squirrel reporting!")
    }
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}


}

