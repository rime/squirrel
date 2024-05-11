//
//  SquirrelConfig.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

class SquirrelConfig {
  enum RimeColorSpace {
    case displayP3, sRGB
    static func from(name: String) -> Self {
      if name == "display_p3" {
        return .displayP3
      } else {
        return .sRGB
      }
    }
  }
  
  private let rimeAPI = rime_get_api().pointee
  private(set) var isOpen = false
  var colorSpace: RimeColorSpace = .sRGB
  var schemaID: String = ""
  
  private var cache: Dictionary<String, Any> = [:]
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
      self.schemaID = schemaID
      self.baseConfig = baseConfig
    }
    return isOpen
  }
  
  func close() {
    if isOpen {
      let _ = rimeAPI.config_close(&config)
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
  
  func getInt(_ option: String) -> Int? {
    if let cachedValue = cachedValue(of: Int.self, forKey: option) {
      return cachedValue
    }
    var value: Int32 = 0
    if isOpen && rimeAPI.config_get_int(&config, option, &value) {
      cache[option] = value
      return Int(value)
    }
    return baseConfig?.getInt(option)
  }
  
  func getDouble(_ option: String) -> Double? {
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
  
  func getColor(_ option: String) -> NSColor? {
    if let cachedValue = cachedValue(of: NSColor.self, forKey: option) {
      return cachedValue
    }
    if let colorStr = getString(option), let color = color(from: colorStr) {
      cache[option] = color
      return color
    }
    return baseConfig?.getColor(option)
  }
  
  func getAppOptions(_ appName: String) -> Dictionary<String, Bool> {
    let rootKey = "app_options/\(appName)"
    var appOptions = [String : Bool]()
    var iterator = RimeConfigIterator()
    let _ = rimeAPI.config_begin_map(&iterator, &config, rootKey)
    while rimeAPI.config_next(&iterator) {
      // print("[DEBUG] option[\(iterator.index)]: \(String(cString: iterator.key)), path: (\(String(cString: iterator.path))")
      if let path = iterator.path, let value = getBool(String(cString: path)) {
        appOptions[String(cString: iterator.key)] = value
      }
    }
    rimeAPI.config_end(&iterator)
    return appOptions
  }
  
  func load(theme: SquirrelTheme, dark: Bool) {
    theme.linear = updateCandidateListLayout(prefix: "style")
    theme.vertical = updateTextOrientation(prefix: "style")
    theme.inlinePreedit = getBool("style/inline_preedit") ?? theme.inlinePreedit
    theme.inlineCandidate = getBool("style/inline_candidate") ?? theme.inlineCandidate
    theme.translucency = getBool("style/translucency") ?? theme.translucency
    theme.mutualExclusive = getBool("style/mutual_exclusive") ?? theme.mutualExclusive
    theme.memorizeSize = getBool("style/memorize_size") ?? theme.memorizeSize
    
    theme.statusMessageType = .init(rawValue: getString("style/status_message_type") ?? "") ?? theme.statusMessageType
    theme.candidateFormat = getString("style/candidate_format") ?? theme.candidateFormat
    
    theme.alpha = max(0, min(1, getDouble("style/alpha") ?? theme.alpha))
    theme.cornerRadius = getDouble("style/corner_radius") ?? theme.cornerRadius
    theme.hilitedCornerRadius = getDouble("style/hilited_corner_radius") ?? theme.hilitedCornerRadius
    theme.surroundingExtraExpansion = getDouble("style/surrounding_extra_expansion") ?? theme.surroundingExtraExpansion
    theme.borderHeight = getDouble("style/border_height") ?? theme.borderHeight
    theme.borderWidth = getDouble("style/border_width") ?? theme.borderWidth
    theme.linespace = getDouble("style/line_spacing") ?? theme.linespace
    theme.preeditLinespace = getDouble("style/spacing") ?? theme.preeditLinespace
    theme.baseOffset = getDouble("style/base_offset") ?? theme.baseOffset
    theme.shadowSize = max(0, getDouble("style/shadow_size") ?? theme.shadowSize)
    
    var fontName = getString("style/font_face")
    var fontSize = getDouble("style/font_point")
    var labelFontName = getString("style/label_font_face")
    var labelFontSize = getDouble("style/label_font_point")
    var commentFontName = getString("style/comment_font_face")
    var commentFontSize = getDouble("style/comment_font_point")
    
    let colorSchemeOption = dark ? "style/color_scheme_dark" : "style/color_scheme"
    if let colorScheme = getString(colorSchemeOption), colorScheme != "native" {
      theme.native = false
      let prefix = "preset_color_schemes/\(colorScheme)"
      colorSpace = .from(name: getString("\(prefix)/color_space") ?? "")
      theme.backgroundColor = getColor("\(prefix)/back_color") ?? theme.backgroundColor
      theme.highlightedPreeditColor = getColor("\(prefix)/hilited_back_color")
      theme.highlightedBackColor = getColor("\(prefix)/hilited_candidate_back_color") ?? theme.highlightedPreeditColor
      theme.preeditBackgroundColor = getColor("\(prefix)/preedit_back_color")
      theme.candidateBackColor = getColor("\(prefix)/candidate_back_color")
      theme.borderColor = getColor("\(prefix)/border_color")
      
      theme.textColor = getColor("\(prefix)/text_color") ?? theme.textColor
      theme.highlightedTextColor = getColor("\(prefix)/hilited_text_color") ?? theme.textColor
      theme.candidateTextColor = getColor("\(prefix)/candidate_text_color") ?? theme.textColor
      theme.highlightedCandidateTextColor = getColor("\(prefix)/hilited_candidate_text_color") ?? theme.highlightedTextColor
      theme.candidateLabelColor = getColor("\(prefix)/label_color")
      theme.highlightedCandidateLabelColor = getColor("\(prefix)/label_hilited_color") ?? getColor("\(prefix)/hilited_candidate_label_color")
      theme.commentTextColor = getColor("\(prefix)/comment_text_color")
      theme.highlightedCommentTextColor = getColor("\(prefix)/hilited_comment_text_color")
      
      // the following per-color-scheme configurations, if exist, will
      // override configurations with the same name under the global 'style'
      // section
      theme.inlinePreedit = getBool("\(prefix)/inline_preedit") ?? theme.inlinePreedit
      theme.inlineCandidate = getBool("\(prefix)/inline_candidate") ?? theme.inlineCandidate
      theme.translucency = getBool("\(prefix)/translucency") ?? theme.translucency
      theme.mutualExclusive = getBool("\(prefix)/mutual_exclusive") ?? theme.mutualExclusive
      theme.candidateFormat = getString("\(prefix)/candidate_format") ?? theme.candidateFormat
      fontName = getString("\(prefix)/font_face") ?? fontName
      fontSize = getDouble("\(prefix)/font_point") ?? fontSize
      labelFontName = getString("\(prefix)/label_font_face") ?? labelFontName
      labelFontSize = getDouble("\(prefix)/label_font_point") ?? labelFontSize
      commentFontName = getString("\(prefix)/comment_font_face") ?? commentFontName
      commentFontSize = getDouble("\(prefix)/comment_font_point") ?? commentFontSize
      theme.alpha = max(0, min(1, getDouble("\(prefix)/alpha") ?? theme.alpha))
      theme.cornerRadius = getDouble("\(prefix)/corner_radius") ?? theme.cornerRadius
      theme.hilitedCornerRadius = getDouble("\(prefix)/hilited_corner_radius") ?? theme.hilitedCornerRadius
      theme.surroundingExtraExpansion = getDouble("\(prefix)/surrounding_extra_expansion") ?? theme.surroundingExtraExpansion
      theme.borderHeight = getDouble("\(prefix)/border_height") ?? theme.borderHeight
      theme.borderWidth = getDouble("\(prefix)/border_width") ?? theme.borderWidth
      theme.linespace = getDouble("\(prefix)/line_spacing") ?? theme.linespace
      theme.preeditLinespace = getDouble("\(prefix)/spacing") ?? theme.preeditLinespace
      theme.baseOffset = getDouble("\(prefix)/base_offset") ?? theme.baseOffset
      theme.shadowSize = getDouble("\(prefix)/shadow_size") ?? theme.shadowSize
    } else {
      theme.native = true
    }
    if let name = fontName, let size = fontSize {
      theme.fonts = theme.decodeFonts(from: name, size: size > 0 ? size : SquirrelTheme.defaultFontSize)
    }
    if let name = labelFontName, let size = labelFontSize {
      theme.labelFonts = theme.decodeFonts(from: name, size: size > 0 ? size : SquirrelTheme.defaultFontSize)
    }
    if let name = commentFontName, let size = commentFontSize {
      theme.commentFonts = theme.decodeFonts(from: name, size: size > 0 ? size : SquirrelTheme.defaultFontSize)
    }
  }
}

private extension SquirrelConfig {
  func cachedValue<T>(of: T.Type, forKey key: String) -> T? {
    return cache[key] as? T
  }
  
  func color(from colorStr: String) -> NSColor? {
    if let matched = try? /0x(\x{2})(\x{2})(\x{2})(\x{2})/.wholeMatch(in: colorStr) {
      let (_, a, b, g, r) = matched.output
      return color(alpha: Int(a, radix: 16)!, red: Int(r, radix: 16)!, green: Int(g, radix: 16)!, blue: Int(b, radix: 16)!, colorspace: colorSpace)
    } else if let matched = try? /0x(\x{2})(\x{2})(\x{2})/.wholeMatch(in: colorStr) {
      let (_, b, g, r) = matched.output
      return color(alpha: 255, red: Int(r, radix: 16)!, green: Int(g, radix: 16)!, blue: Int(b, radix: 16)!, colorspace: colorSpace)
    } else {
      return nil
    }
  }
  
  func color(alpha: Int, red: Int, green: Int, blue: Int, colorspace: RimeColorSpace) -> NSColor {
    switch colorspace {
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
  
  // isLinear
  func updateCandidateListLayout(prefix: String) -> Bool {
    let candidateListLayout = getString("\(prefix)/candidate_list_layout")
    if candidateListLayout == "stacked" {
      return false
    } else if candidateListLayout == "linear" {
      return true
    } else {
      // Deprecated. Not to be confused with text_orientation: horizontal
      return getBool("\(prefix)/horizontal") ?? false
    }
  }
  
  // isVertical
  func updateTextOrientation(prefix: String) -> Bool {
  let textOrientation = getString("\(prefix)/text_orientation")
    if textOrientation == "horizontal" {
      return false
    } else if textOrientation == "vertical" {
      return true
    } else {
      // Deprecated.
      return getBool("\(prefix)/vertical") ?? true
    }
  }
}
