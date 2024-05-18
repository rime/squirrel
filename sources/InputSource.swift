//
//  InputSource.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import Foundation
import InputMethodKit

final class SquirrelInstaller {
  enum InputMode: String, CaseIterable {
    static let primary = Self.hant
    case hans = "im.rime.inputmethod.Squirrel.Hans"
    case hant = "im.rime.inputmethod.Squirrel.Hant"
  }
  private lazy var inputSources: [String: TISInputSource] = {
    var inputSources = [String: TISInputSource]()
    var matchingSources = [InputMode: TISInputSource]()
    let sourceList = TISCreateInputSourceList(nil, true).takeUnretainedValue() as! [TISInputSource]
    for inputSource in sourceList {
      let sourceIDRef = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID)
      guard let sourceID = unsafeBitCast(sourceIDRef, to: CFString?.self) as String? else { continue }
      // print("[DEBUG] Examining input source: \(sourceID)")
      inputSources[sourceID] = inputSource
    }
    return inputSources
  }()
  
  func enabledModes() -> [InputMode] {
    var enabledModes = Set<InputMode>()
    for (mode, inputSource) in getInputSource(modes: InputMode.allCases) {
      if let enabled = getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled), enabled {
        enabledModes.insert(mode)
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
    TISRegisterInputSource(SquirrelApp.appDir as CFURL)
    print("Registered input source from \(SquirrelApp.appDir)")
  }
  
  func enable(modes: [InputMode] = [.primary]) {
    let enabledInputModes = enabledModes()
    if Set(modes).isSubset(of: enabledInputModes) {
      print("User already enabled Squirrel method(s): \(enabledInputModes)")
      // keep user's manually enabled input modes.
      return
    }
    for (mode, inputSource) in getInputSource(modes: modes) {
      if let enabled = getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled), enabled {
        let error = TISEnableInputSource(inputSource)
        print("Enable \(error == noErr ? "succeeds" : "fails") for input source: \(mode.rawValue)");
      }
    }
  }
  
  func select(mode: InputMode = .primary) {
    let enabledInputModes = enabledModes()
    if !enabledInputModes.contains(mode) {
      enable(modes: [mode])
    }
    for (mode, inputSource) in getInputSource(modes: [mode]) {
      if let enabled = getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled),
          let selectable = getBool(for: inputSource, key: kTISPropertyInputSourceIsSelectCapable),
          let selected = getBool(for: inputSource, key: kTISPropertyInputSourceIsSelected),
         enabled && selectable && !selected {
        let error = TISSelectInputSource(inputSource)
        print("Selection \(error == noErr ? "succeeds" : "fails") for input source: \(mode.rawValue)")
      } else {
        print("Failed to select \(mode.rawValue)")
      }
    }
  }
  
  func disable(modes: [InputMode] = InputMode.allCases) {
    for (mode, inputSource) in getInputSource(modes: modes) {
      if let enabled = getBool(for: inputSource, key: kTISPropertyInputSourceIsEnabled), enabled {
        TISDisableInputSource(inputSource)
        print("Disabled input source: \(mode.rawValue)")
      }
    }
  }
  
  private func getInputSource(modes: [InputMode]) -> [InputMode: TISInputSource] {
    var matchingSources = [InputMode: TISInputSource]()
    for mode in modes {
      if let inputSource = inputSources[mode.rawValue] {
        matchingSources[mode] = inputSource
      }
    }
    return matchingSources
  }
  
  private func getBool(for inputSource: TISInputSource, key: CFString!) -> Bool? {
    let enabledRef = TISGetInputSourceProperty(inputSource, key)
    guard let enabled = unsafeBitCast(enabledRef, to: CFBoolean?.self) else { return nil }
    return CFBooleanGetValue(enabled)
  }
}
