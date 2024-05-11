//
//  InputSource.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

class SquirrelInstaller {
  static let installLocation = try! FileManager.default.url(for: .libraryDirectory, in: .systemDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Input Methods").appendingPathComponent("Squirrel.app")

  enum InputMode: String, CaseIterable {
    static let primary = Self.hant
    case hans = "im.rime.inputmethod.Squirrel.Hans"
    case hant = "im.rime.inputmethod.Squirrel.Hant"
  }
  
  func enabledModes() -> [InputMode] {
    var enabledModes = Set<InputMode>()
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as NSArray
    for i in 0..<sourceList.count {
      let inputSource = sourceList[i] as! TISInputSource
      let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID).load(as: CFString.self) as String
      // NSLog(@"Examining input source: %@", sourceID);
      for supportedMode in InputMode.allCases {
        if sourceID == supportedMode.rawValue {
          let enabled = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled).load(as: CFBoolean.self))
          if enabled {
            enabledModes.insert(supportedMode)
          }
          break
        }
      }
      if enabledModes.count == InputMode.allCases.count {
        break
      }
    }
    return Array(enabledModes)
  }
  
  func register() {
    let enabledInputModes = enabledModes()
    if enabledInputModes.count > 0 {
      // Already registered.
      return
    }
    TISRegisterInputSource(SquirrelInstaller.installLocation as CFURL)
    print("Registered input source from \(SquirrelInstaller.installLocation)")
  }
  
  func enable(modes: [InputMode] = [.primary]) {
    let enabledInputModes = enabledModes()
    if enabledInputModes.count > 0 {
      // keep user's manually enabled input modes.
      return
    }
    // neither is enabled, enable the default input mode.
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as NSArray
    for i in 0..<sourceList.count {
      let inputSource = sourceList[i] as! TISInputSource
      let sourceID = TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID).load(as: CFString.self) as String
      // NSLog(@"Examining input source: %@", sourceID);
      for mode in modes {
        if sourceID == mode.rawValue {
          let enabled = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled).load(as: CFBoolean.self))
          if !enabled {
            TISEnableInputSource(inputSource)
            print("Enabled input source: \(sourceID)");
          }
          break
        }
      }
    }
  }
  
  func select(mode: InputMode = .primary) {
    let enabledInputModes = enabledModes()
    if !enabledInputModes.contains(mode) {
      print("Target input source not enabled: \(mode.rawValue)")
      return
    }
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as NSArray
    for i in 0..<sourceList.count {
      let inputSource = sourceList[i] as! TISInputSource
      let sourceID = TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID).load(as: CFString.self) as String
      // NSLog(@"Examining input source: %@", sourceID);
      if sourceID == mode.rawValue {
        let enabled = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled).load(as: CFBoolean.self))
        if enabled {
          let selectable = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable).load(as: CFBoolean.self))
          let selected = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelected).load(as: CFBoolean.self))
          if selectable && !selected {
            TISSelectInputSource(inputSource)
            print("Selected input source: \(mode.rawValue)")
          }
          return
        }
      }
    }
  }
  
  func disable(modes: [InputMode] = InputMode.allCases) {
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as NSArray
    for i in 0..<sourceList.count {
      let inputSource = sourceList[i] as! TISInputSource
      let sourceID = TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID).load(as: CFString.self) as String
      // NSLog(@"Examining input source: %@", sourceID);
      for mode in modes {
        if sourceID == mode.rawValue {
          let enabled = CFBooleanGetValue(TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled).load(as: CFBoolean.self))
          if enabled {
            TISDisableInputSource(inputSource)
            print("Disabled input source: \(sourceID)")
          }
          break
        }
      }
    }
  }
}
