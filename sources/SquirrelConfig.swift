//
//  SquirrelConfig.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

final class SquirrelConfig {
  private let rimeAPI: RimeApi_stdbool = rime_get_api_stdbool().pointee
  private(set) var isOpen = false

  private var cache: [String: Any] = [:]
  private var config: RimeConfig = .init()
  private var baseConfig: SquirrelConfig?

  func openBaseConfig() -> Bool {
    close()
    isOpen = rimeAPI.config_open("squirrel", &config)
    return isOpen
  }

  func open(schemaID: String, baseConfig: SquirrelConfig?) -> Bool {
    close()
    isOpen = rimeAPI.schema_open(schemaID, &config)
    if isOpen {
      self.baseConfig = baseConfig
    }
    return isOpen
  }

  func close() {
    if isOpen {
      _ = rimeAPI.config_close(&config)
      baseConfig = nil
      isOpen = false
    }
  }

  deinit {
    close()
  }

  func has(section: String) -> Bool {
    if isOpen {
      var iterator: RimeConfigIterator = .init()
      if rimeAPI.config_begin_map(&iterator, &config, section) {
        rimeAPI.config_end(&iterator)
        return true
      }
    }
    return false
  }

  func getBool(_ option: String) -> Bool? {
    if let cachedValue = cachedValue(of: Bool.self, forKey: option) {
      return cachedValue
    }
    var value = false
    if isOpen && rimeAPI.config_get_bool(&config, option, &value) {
      cache[option] = value
      return value
    }
    return baseConfig?.getBool(option)
  }

  func getDouble(_ option: String) -> CGFloat? {
    if let cachedValue = cachedValue(of: Double.self, forKey: option) {
      return cachedValue
    }
    var value: Double = 0
    if isOpen && rimeAPI.config_get_double(&config, option, &value) {
      cache[option] = value
      return value
    }
    return baseConfig?.getDouble(option)
  }

  func getString(_ option: String) -> String? {
    if let cachedValue = cachedValue(of: String.self, forKey: option) {
      return cachedValue
    }
    if isOpen, let value = rimeAPI.config_get_cstring(&config, option) {
      cache[option] = String(cString: value)
      return String(cString: value)
    }
    return baseConfig?.getString(option)
  }

  func getColor(_ option: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    if let cachedValue = cachedValue(of: NSColor.self, forKey: option) {
      return cachedValue
    }
    if let colorStr = getString(option), let color = color(from: colorStr, inSpace: colorSpace) {
      cache[option] = color
      return color
    }
    return baseConfig?.getColor(option, inSpace: colorSpace)
  }

  func getAppOptions(_ appName: String) -> [String: Bool] {
    let rootKey = "app_options/\(appName)"
    var appOptions = [String: Bool]()
    var iterator = RimeConfigIterator()
    _ = rimeAPI.config_begin_map(&iterator, &config, rootKey)
    while rimeAPI.config_next(&iterator) {
      // print("[DEBUG] option[\(iterator.index)]: \(String(cString: iterator.key)), path: (\(String(cString: iterator.path))")
      if let key = iterator.key, let path = iterator.path, let value = getBool(String(cString: path)) {
        appOptions[String(cString: key)] = value
      }
    }
    rimeAPI.config_end(&iterator)
    return appOptions
  }
}

private extension SquirrelConfig {
  func cachedValue<T>(of: T.Type, forKey key: String) -> T? {
    return cache[key] as? T
  }

  func color(from colorStr: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: colorStr) {
      let (_, alpha, blue, green, red) = matched.output
      return color(alpha: Int(alpha, radix: 16)!, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!, blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    } else if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: colorStr) {
      let (_, blue, green, red) = matched.output
      return color(alpha: 255, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!, blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    } else {
      return nil
    }
  }

  func color(alpha: Int, red: Int, green: Int, blue: Int, colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor {
    switch colorSpace {
    case .displayP3:
      return NSColor(displayP3Red: CGFloat(red) / 255,
                     green: CGFloat(green) / 255,
                     blue: CGFloat(blue) / 255,
                     alpha: CGFloat(alpha) / 255)
    case .sRGB:
      return NSColor(srgbRed: CGFloat(red) / 255,
                     green: CGFloat(green) / 255,
                     blue: CGFloat(blue) / 255,
                     alpha: CGFloat(alpha) / 255)
    }
  }
}
