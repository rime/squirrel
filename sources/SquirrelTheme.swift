//
//  SquirrelView.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

final class SquirrelTheme {
  static let offsetHeight: CGFloat = 5
  static let defaultFontSize: CGFloat = 24
  static let showStatusDuration: Double = 1.2
  static let defaultFont = NSFont.userFont(ofSize: defaultFontSize)!
  
  enum StatusMessageType: String {
    case long, short, mix
  }
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
  
  var native = true
  var memorizeSize = true
  private var colorSpace: RimeColorSpace = .sRGB
  
  var backgroundColor: NSColor = .windowBackgroundColor
  var highlightedPreeditColor: NSColor?
  var highlightedBackColor: NSColor? = .selectedTextBackgroundColor
  var preeditBackgroundColor: NSColor?
  var candidateBackColor: NSColor?
  var borderColor: NSColor?
  
  private var textColor: NSColor = .disabledControlTextColor
  private var highlightedTextColor: NSColor = .controlTextColor
  private var candidateTextColor: NSColor = .secondaryLabelColor
  private var highlightedCandidateTextColor: NSColor = .labelColor
  private var candidateLabelColor: NSColor?
  private var highlightedCandidateLabelColor: NSColor?
  private var commentTextColor: NSColor? = .disabledControlTextColor
  private var highlightedCommentTextColor: NSColor?
  
  var cornerRadius: CGFloat = 0
  var hilitedCornerRadius: CGFloat = 0
  var surroundingExtraExpansion: CGFloat = 0
  var shadowSize: CGFloat = 0
  var borderWidth: CGFloat = 0
  var borderHeight: CGFloat = 0
  var linespace: CGFloat = 0
  var preeditLinespace: CGFloat = 0
  var baseOffset: CGFloat = 0
  var alpha: CGFloat = 1
  
  var translucency = false
  var mutualExclusive = false
  var linear = false
  var vertical = false
  var inlinePreedit = false
  var inlineCandidate = false
  
  private var fonts = Array<NSFont>()
  private var labelFonts = Array<NSFont>()
  private var commentFonts = Array<NSFont>()
  
  private var candidateTemplate = "[label]. [candidate] [comment]"
  var statusMessageType: StatusMessageType = .mix
  
  var font: NSFont {
    return combineFonts(fonts) ?? Self.defaultFont
  }
  var labelFont: NSFont? {
    return combineFonts(labelFonts)
  }
  var commentFont: NSFont? {
    return combineFonts(commentFonts)
  }
  var attrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: candidateTextColor,
     .font: font,
     .baselineOffset: baseOffset]
  }
  var highlightedAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: highlightedCandidateTextColor,
     .font: font,
     .baselineOffset: baseOffset]
  }
  var labelAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: candidateLabelColor ?? blendColor(foregroundColor: self.candidateTextColor, backgroundColor: self.backgroundColor),
            .font: labelFont ?? font,
            .baselineOffset: baseOffset]
  }
  var labelHighlightedAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: highlightedCandidateLabelColor ?? blendColor(foregroundColor: highlightedCandidateTextColor, backgroundColor: highlightedBackColor),
            .font: labelFont ?? font,
            .baselineOffset: baseOffset]
  }
  var commentAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: commentTextColor ?? candidateTextColor,
            .font: commentFont ?? font,
            .baselineOffset: baseOffset]
  }
  var commentHighlightedAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: highlightedCommentTextColor ?? highlightedCandidateTextColor,
            .font: commentFont ?? font,
            .baselineOffset: baseOffset]
  }
  var preeditAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: textColor,
     .font: font,
     .baselineOffset: baseOffset]
  }
  var preeditHighlightedAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: highlightedTextColor,
     .font: font,
     .baselineOffset: baseOffset]
  }
  
  var firstParagraphStyle: NSParagraphStyle {
    let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = linespace / 2
    style.paragraphSpacingBefore = preeditLinespace / 2 + hilitedCornerRadius / 2
    return style as NSParagraphStyle
  }
  var paragraphStyle: NSParagraphStyle {
    let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = linespace / 2
    style.paragraphSpacingBefore = linespace / 2
    return style as NSParagraphStyle
  }
  var preeditParagraphStyle: NSParagraphStyle {
    let style = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = preeditLinespace / 2 + hilitedCornerRadius / 2
    style.lineSpacing = linespace
    return style as NSParagraphStyle
  }
  var edgeInset: NSSize {
    if (self.vertical) {
      return NSMakeSize(borderHeight + cornerRadius, borderWidth + cornerRadius)
    } else {
      return NSMakeSize(borderWidth + cornerRadius, borderHeight + cornerRadius)
    }
  }
  var borderLineWidth: CGFloat {
    return min(borderHeight, borderWidth)
  }
  var candidateFormat: String {
    get {
      candidateTemplate
    } set {
      var newTemplate = newValue
      if newTemplate.contains(/%@/) {
        newTemplate.replace(/%@/, with: "[candidate] [comment]")
      }
      if newTemplate.contains(/%c/) {
        newTemplate.replace(/%c/, with: "[label]")
      }
      candidateTemplate = newTemplate
    }
  }
  
  func load(config: SquirrelConfig, dark: Bool) {
    linear = config.updateCandidateListLayout(prefix: "style")
    vertical = config.updateTextOrientation(prefix: "style")
    inlinePreedit = config.getBool("style/inline_preedit") ?? inlinePreedit
    inlineCandidate = config.getBool("style/inline_candidate") ?? inlineCandidate
    translucency = config.getBool("style/translucency") ?? translucency
    mutualExclusive = config.getBool("style/mutual_exclusive") ?? mutualExclusive
    memorizeSize = config.getBool("style/memorize_size") ?? memorizeSize
    
    statusMessageType = .init(rawValue: config.getString("style/status_message_type") ?? "") ?? statusMessageType
    candidateFormat = config.getString("style/candidate_format") ?? candidateFormat
    
    alpha = max(0, min(1, config.getDouble("style/alpha") ?? alpha))
    cornerRadius = config.getDouble("style/corner_radius") ?? cornerRadius
    hilitedCornerRadius = config.getDouble("style/hilited_corner_radius") ?? hilitedCornerRadius
    surroundingExtraExpansion = config.getDouble("style/surrounding_extra_expansion") ?? surroundingExtraExpansion
    borderHeight = config.getDouble("style/border_height") ?? borderHeight
    borderWidth = config.getDouble("style/border_width") ?? borderWidth
    linespace = config.getDouble("style/line_spacing") ?? linespace
    preeditLinespace = config.getDouble("style/spacing") ?? preeditLinespace
    baseOffset = config.getDouble("style/base_offset") ?? baseOffset
    shadowSize = max(0, config.getDouble("style/shadow_size") ?? shadowSize)
    
    var fontName = config.getString("style/font_face")
    var fontSize = config.getDouble("style/font_point")
    var labelFontName = config.getString("style/label_font_face")
    var labelFontSize = config.getDouble("style/label_font_point")
    var commentFontName = config.getString("style/comment_font_face")
    var commentFontSize = config.getDouble("style/comment_font_point")
    
    let colorSchemeOption = dark ? "style/color_scheme_dark" : "style/color_scheme"
    if let colorScheme = config.getString(colorSchemeOption), colorScheme != "native" {
      native = false
      let prefix = "preset_color_schemes/\(colorScheme)"
      colorSpace = .from(name: config.getString("\(prefix)/color_space") ?? "")
      backgroundColor = config.getColor("\(prefix)/back_color", inSpace: colorSpace) ?? backgroundColor
      highlightedPreeditColor = config.getColor("\(prefix)/hilited_back_color", inSpace: colorSpace)
      highlightedBackColor = config.getColor("\(prefix)/hilited_candidate_back_color", inSpace: colorSpace) ?? highlightedPreeditColor
      preeditBackgroundColor = config.getColor("\(prefix)/preedit_back_color", inSpace: colorSpace)
      candidateBackColor = config.getColor("\(prefix)/candidate_back_color", inSpace: colorSpace)
      borderColor = config.getColor("\(prefix)/border_color", inSpace: colorSpace)
      
      textColor = config.getColor("\(prefix)/text_color", inSpace: colorSpace) ?? textColor
      highlightedTextColor = config.getColor("\(prefix)/hilited_text_color", inSpace: colorSpace) ?? textColor
      candidateTextColor = config.getColor("\(prefix)/candidate_text_color", inSpace: colorSpace) ?? textColor
      highlightedCandidateTextColor = config.getColor("\(prefix)/hilited_candidate_text_color", inSpace: colorSpace) ?? highlightedTextColor
      candidateLabelColor = config.getColor("\(prefix)/label_color", inSpace: colorSpace)
      highlightedCandidateLabelColor = config.getColor("\(prefix)/label_hilited_color", inSpace: colorSpace) ?? config.getColor("\(prefix)/hilited_candidate_label_color", inSpace: colorSpace)
      commentTextColor = config.getColor("\(prefix)/comment_text_color", inSpace: colorSpace)
      highlightedCommentTextColor = config.getColor("\(prefix)/hilited_comment_text_color", inSpace: colorSpace)
      
      // the following per-color-scheme configurations, if exist, will
      // override configurations with the same name under the global 'style'
      // section
      inlinePreedit = config.getBool("\(prefix)/inline_preedit") ?? inlinePreedit
      inlineCandidate = config.getBool("\(prefix)/inline_candidate") ?? inlineCandidate
      translucency = config.getBool("\(prefix)/translucency") ?? translucency
      mutualExclusive = config.getBool("\(prefix)/mutual_exclusive") ?? mutualExclusive
      candidateFormat = config.getString("\(prefix)/candidate_format") ?? candidateFormat
      fontName = config.getString("\(prefix)/font_face") ?? fontName
      fontSize = config.getDouble("\(prefix)/font_point") ?? fontSize
      labelFontName = config.getString("\(prefix)/label_font_face") ?? labelFontName
      labelFontSize = config.getDouble("\(prefix)/label_font_point") ?? labelFontSize
      commentFontName = config.getString("\(prefix)/comment_font_face") ?? commentFontName
      commentFontSize = config.getDouble("\(prefix)/comment_font_point") ?? commentFontSize
      
      alpha = max(0, min(1, config.getDouble("\(prefix)/alpha") ?? alpha))
      cornerRadius = config.getDouble("\(prefix)/corner_radius") ?? cornerRadius
      hilitedCornerRadius = config.getDouble("\(prefix)/hilited_corner_radius") ?? hilitedCornerRadius
      surroundingExtraExpansion = config.getDouble("\(prefix)/surrounding_extra_expansion") ?? surroundingExtraExpansion
      borderHeight = config.getDouble("\(prefix)/border_height") ?? borderHeight
      borderWidth = config.getDouble("\(prefix)/border_width") ?? borderWidth
      linespace = config.getDouble("\(prefix)/line_spacing") ?? linespace
      preeditLinespace = config.getDouble("\(prefix)/spacing") ?? preeditLinespace
      baseOffset = config.getDouble("\(prefix)/base_offset") ?? baseOffset
      shadowSize = config.getDouble("\(prefix)/shadow_size") ?? shadowSize
    } else {
      native = true
    }
    if let name = fontName {
      fonts = decodeFonts(from: name, size: fontSize)
    }
    if let name = labelFontName ?? fontName {
      labelFonts = decodeFonts(from: name, size: labelFontSize ?? fontSize)
    }
    if let name = commentFontName ?? fontName {
      commentFonts = decodeFonts(from: name, size: commentFontSize ?? fontSize)
    }
  }
}
  
private extension SquirrelTheme {
  func combineFonts(_ fonts: Array<NSFont>) -> NSFont? {
    if fonts.count == 0 { return nil }
    if fonts.count == 1 { return fonts[0] }
    let attribute = [NSFontDescriptor.AttributeName.cascadeList: fonts[1...].map { $0.fontDescriptor } ]
    let fontDescriptor = fonts[0].fontDescriptor.addingAttributes(attribute)
    return NSFont.init(descriptor: fontDescriptor, size: fonts[0].pointSize)
  }
  
  func decodeFonts(from fontString: String, size: CGFloat?) -> Array<NSFont> {
    var seenFontFamilies = Set<String>()
    let fontStrings = fontString.split(separator: ",")
    var fonts = Array<NSFont>()
    for string in fontStrings {
      let trimedString = string.trimmingCharacters(in: .whitespaces)
      if let fontFamilyName = trimedString.split(separator: "-").first.map({String($0)}) {
        if seenFontFamilies.contains(fontFamilyName) {
          continue
        } else {
          seenFontFamilies.insert(fontFamilyName)
        }
      } else {
        if seenFontFamilies.contains(trimedString) {
          continue
        } else {
          seenFontFamilies.insert(trimedString)
        }
      }
      if let validFont = NSFont(name: String(trimedString), size: size ?? Self.defaultFontSize) {
        fonts.append(validFont)
      }
    }
    return fonts
  }
  
  func blendColor(foregroundColor: NSColor, backgroundColor: NSColor?) -> NSColor {
    let foregroundColor = foregroundColor.usingColorSpace(NSColorSpace.deviceRGB)!
    let backgroundColor = (backgroundColor ?? NSColor.gray).usingColorSpace(NSColorSpace.deviceRGB)!
    func blend(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
      return (a * 2 + b) / 3
    }
    return NSColor(deviceRed: blend(foregroundColor.redComponent, backgroundColor.redComponent),
                   green: blend(foregroundColor.greenComponent, backgroundColor.greenComponent),
                   blue: blend(foregroundColor.blueComponent, backgroundColor.blueComponent),
                   alpha: blend(foregroundColor.alphaComponent, backgroundColor.alphaComponent))
  }
}

