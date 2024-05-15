//
//  InputSource.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

struct SquirrelInstaller {
  static let installLocation = try! FileManager.default.url(for: .libraryDirectory, in: .localDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Input Methods").appendingPathComponent("Squirrel.app")

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
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { return [] }
      // print("[DEBUG] Examining input source: \(sourceID)")
      for supportedMode in InputMode.allCases {
        if sourceID == supportedMode.rawValue {
          let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
          guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return [] }
          if CFBooleanGetValue(enabled) {
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
      print("User already registered Squirrel method(s): \(enabledInputModes)")
      // Already registered.
      return
    }
    TISRegisterInputSource(SquirrelInstaller.installLocation as CFURL)
    print("Registered input source from \(SquirrelInstaller.installLocation)")
  }
  
  func enable(modes: [InputMode] = [.primary]) {
    let enabledInputModes = enabledModes()
    if enabledInputModes.count > 0 {
      print("User already enabled Squirrel method(s): \(enabledInputModes)")
      // keep user's manually enabled input modes.
      return
    }
    // neither is enabled, enable the default input mode.
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as NSArray
    for i in 0..<sourceList.count {
      let inputSource = sourceList[i] as! TISInputSource
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { return }
      // print("Examining input source: \(sourceID)")
      for mode in modes {
        if sourceID == mode.rawValue {
          let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
          guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return }
          if !CFBooleanGetValue(enabled) {
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
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { return }
      // print("[DEBUG] Examining input source: \(sourceID)")
      if sourceID == mode.rawValue {
        let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
        guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return }
        if CFBooleanGetValue(enabled) {
          let selectableRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable)
          guard let selectable = unsafeBitCast(selectableRef, to: CFBoolean?.self) else { return }
          let selectedRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelected)
          guard let selected = unsafeBitCast(selectedRef, to: CFBoolean?.self) else { return }
          if CFBooleanGetValue(selectable) && !CFBooleanGetValue(selected) {
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
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { return }
      // print("[DEBUG] Examining input source: \(sourceID)")
      for mode in modes {
        if sourceID == mode.rawValue {
          let enabledRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled)
          guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return }
          if CFBooleanGetValue(enabled) {
            TISDisableInputSource(inputSource)
            print("Disabled input source: \(sourceID)")
          }
          break
        }
      }
    }
  }
}
