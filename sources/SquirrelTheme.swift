//
//  SquirrelTheme.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

final class SquirrelTheme {
  static let offsetHeight: CGFloat = 5
  static let defaultFontSize: CGFloat = NSFont.systemFontSize
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

  private(set) var available = true
  private(set) var native = true
  private(set) var memorizeSize = true
  private var colorSpace: RimeColorSpace = .sRGB

  var backgroundColor: NSColor = .windowBackgroundColor
  var highlightedPreeditColor: NSColor?
  var highlightedBackColor: NSColor? = .selectedTextBackgroundColor
  var preeditBackgroundColor: NSColor?
  var candidateBackColor: NSColor?
  var borderColor: NSColor?

  private var textColor: NSColor = .tertiaryLabelColor
  private var highlightedTextColor: NSColor = .labelColor
  private var candidateTextColor: NSColor = .secondaryLabelColor
  private var highlightedCandidateTextColor: NSColor = .labelColor
  private var candidateLabelColor: NSColor?
  private var highlightedCandidateLabelColor: NSColor?
  private var commentTextColor: NSColor? = .tertiaryLabelColor
  private var highlightedCommentTextColor: NSColor?

  private(set) var cornerRadius: CGFloat = 0
  private(set) var hilitedCornerRadius: CGFloat = 0
  private(set) var surroundingExtraExpansion: CGFloat = 0
  private(set) var shadowSize: CGFloat = 0
  private(set) var borderWidth: CGFloat = 0
  private(set) var borderHeight: CGFloat = 0
  private(set) var linespace: CGFloat = 0
  private(set) var preeditLinespace: CGFloat = 0
  private(set) var baseOffset: CGFloat = 0
  private(set) var alpha: CGFloat = 1

  private(set) var translucency = false
  private(set) var mutualExclusive = false
  private(set) var linear = false
  private(set) var vertical = false
  private(set) var inlinePreedit = false
  private(set) var inlineCandidate = false
  private(set) var showPaging = false

  private var fonts = [NSFont]()
  private var labelFonts = [NSFont]()
  private var commentFonts = [NSFont]()
  private var fontSize: CGFloat?
  private var labelFontSize: CGFloat?
  private var commentFontSize: CGFloat?

  private var _candidateFormat = "[label]. [candidate] [comment]"
  private(set) var statusMessageType: StatusMessageType = .mix

  private var defaultFont: NSFont {
    if let size = fontSize {
      Self.defaultFont.withSize(size)
    } else {
      Self.defaultFont
    }
  }

  private(set) lazy var font: NSFont = combineFonts(fonts, size: fontSize) ?? defaultFont
  private(set) lazy var labelFont: NSFont = {
    if let font = combineFonts(labelFonts, size: labelFontSize ?? fontSize) {
      return font
    } else if let size = labelFontSize {
      return self.font.withSize(size)
    } else {
      return self.font
    }
  }()
  private(set) lazy var commentFont: NSFont = {
    if let font = combineFonts(commentFonts, size: commentFontSize ?? fontSize) {
      return font
    } else if let size = commentFontSize {
      return self.font.withSize(size)
    } else {
      return self.font
    }
  }()
  private(set) lazy var attrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: candidateTextColor,
    .font: font,
    .baselineOffset: baseOffset
  ]
  private(set) lazy var highlightedAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: highlightedCandidateTextColor,
    .font: font,
    .baselineOffset: baseOffset
  ]
  private(set) lazy var labelAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: candidateLabelColor ?? blendColor(foregroundColor: self.candidateTextColor, backgroundColor: self.backgroundColor),
    .font: labelFont,
    .baselineOffset: baseOffset + (!vertical ? (font.pointSize - labelFont.pointSize) / 2.5 : 0)
  ]
  private(set) lazy var labelHighlightedAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: highlightedCandidateLabelColor ?? blendColor(foregroundColor: highlightedCandidateTextColor, backgroundColor: highlightedBackColor),
    .font: labelFont,
    .baselineOffset: baseOffset + (!vertical ? (font.pointSize - labelFont.pointSize) / 2.5 : 0)
  ]
  private(set) lazy var commentAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: commentTextColor ?? candidateTextColor,
    .font: commentFont,
    .baselineOffset: baseOffset + (!vertical ? (font.pointSize - commentFont.pointSize) / 2.5 : 0)
  ]
  private(set) lazy var commentHighlightedAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: highlightedCommentTextColor ?? highlightedCandidateTextColor,
    .font: commentFont,
    .baselineOffset: baseOffset + (!vertical ? (font.pointSize - commentFont.pointSize) / 2.5 : 0)
  ]
  private(set) lazy var preeditAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: textColor,
    .font: font,
    .baselineOffset: baseOffset
  ]
  private(set) lazy var preeditHighlightedAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: highlightedTextColor,
    .font: font,
    .baselineOffset: baseOffset
  ]

  private(set) lazy var firstParagraphStyle: NSParagraphStyle = {
    let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = linespace / 2
    style.paragraphSpacingBefore = preeditLinespace / 2 + hilitedCornerRadius / 2
    return style as NSParagraphStyle
  }()
  private(set) lazy var paragraphStyle: NSParagraphStyle = {
    let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = linespace / 2
    style.paragraphSpacingBefore = linespace / 2
    return style as NSParagraphStyle
  }()
  private(set) lazy var preeditParagraphStyle: NSParagraphStyle = {
    let style = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
    style.paragraphSpacing = preeditLinespace / 2 + hilitedCornerRadius / 2
    style.lineSpacing = linespace
    return style as NSParagraphStyle
  }()
  private(set) lazy var edgeInset: NSSize = if self.vertical {
    NSSize(width: borderHeight + cornerRadius, height: borderWidth + cornerRadius)
  } else {
    NSSize(width: borderWidth + cornerRadius, height: borderHeight + cornerRadius)
  }
  private(set) lazy var borderLineWidth: CGFloat = min(borderHeight, borderWidth)
  private(set) var candidateFormat: String {
    get {
      _candidateFormat
    } set {
      var newTemplate = newValue
      if newTemplate.contains(/%@/) {
        newTemplate.replace(/%@/, with: "[candidate] [comment]")
      }
      if newTemplate.contains(/%c/) {
        newTemplate.replace(/%c/, with: "[label]")
      }
      _candidateFormat = newTemplate
    }
  }
  var pagingOffset: CGFloat {
    if showPaging {
      (labelFontSize ?? fontSize ?? Self.defaultFontSize) * 1.5
    } else {
      0
    }
  }

  func load(config: SquirrelConfig, dark: Bool) {
    linear ?= config.getString("style/candidate_list_layout").map { $0 == "linear" }
    vertical ?= config.getString("style/text_orientation").map { $0 == "vertical" }
    inlinePreedit ?= config.getBool("style/inline_preedit")
    inlineCandidate ?= config.getBool("style/inline_candidate")
    translucency ?= config.getBool("style/translucency")
    mutualExclusive ?= config.getBool("style/mutual_exclusive")
    memorizeSize ?= config.getBool("style/memorize_size")
    showPaging ?= config.getBool("style/show_paging")

    statusMessageType ?= .init(rawValue: config.getString("style/status_message_type") ?? "")
    candidateFormat ?= config.getString("style/candidate_format")

    alpha ?= config.getDouble("style/alpha").map { min(1, max(0, $0)) }
    cornerRadius ?= config.getDouble("style/corner_radius")
    hilitedCornerRadius ?= config.getDouble("style/hilited_corner_radius")
    surroundingExtraExpansion ?= config.getDouble("style/surrounding_extra_expansion")
    borderHeight ?= config.getDouble("style/border_height")
    borderWidth ?= config.getDouble("style/border_width")
    linespace ?= config.getDouble("style/line_spacing")
    preeditLinespace ?= config.getDouble("style/spacing")
    baseOffset ?= config.getDouble("style/base_offset")
    shadowSize ?= config.getDouble("style/shadow_size").map { max(0, $0) }

    var fontName = config.getString("style/font_face")
    var fontSize = config.getDouble("style/font_point")
    var labelFontName = config.getString("style/label_font_face")
    var labelFontSize = config.getDouble("style/label_font_point")
    var commentFontName = config.getString("style/comment_font_face")
    var commentFontSize = config.getDouble("style/comment_font_point")

    let colorSchemeOption = dark ? "style/color_scheme_dark" : "style/color_scheme"
    if let colorScheme = config.getString(colorSchemeOption) {
      if colorScheme != "native" {
        native = false
        let prefix = "preset_color_schemes/\(colorScheme)"
        colorSpace = .from(name: config.getString("\(prefix)/color_space") ?? "")
        backgroundColor ?= config.getColor("\(prefix)/back_color", inSpace: colorSpace)
        highlightedPreeditColor = config.getColor("\(prefix)/hilited_back_color", inSpace: colorSpace)
        highlightedBackColor = config.getColor("\(prefix)/hilited_candidate_back_color", inSpace: colorSpace) ?? highlightedPreeditColor
        preeditBackgroundColor = config.getColor("\(prefix)/preedit_back_color", inSpace: colorSpace)
        candidateBackColor = config.getColor("\(prefix)/candidate_back_color", inSpace: colorSpace)
        borderColor = config.getColor("\(prefix)/border_color", inSpace: colorSpace)

        textColor ?= config.getColor("\(prefix)/text_color", inSpace: colorSpace)
        highlightedTextColor = config.getColor("\(prefix)/hilited_text_color", inSpace: colorSpace) ?? textColor
        candidateTextColor = config.getColor("\(prefix)/candidate_text_color", inSpace: colorSpace) ?? textColor
        highlightedCandidateTextColor = config.getColor("\(prefix)/hilited_candidate_text_color", inSpace: colorSpace) ?? highlightedTextColor
        candidateLabelColor = config.getColor("\(prefix)/label_color", inSpace: colorSpace)
        highlightedCandidateLabelColor = config.getColor("\(prefix)/hilited_candidate_label_color", inSpace: colorSpace)
        commentTextColor = config.getColor("\(prefix)/comment_text_color", inSpace: colorSpace)
        highlightedCommentTextColor = config.getColor("\(prefix)/hilited_comment_text_color", inSpace: colorSpace)

        // the following per-color-scheme configurations, if exist, will
        // override configurations with the same name under the global 'style'
        // section
        linear ?= config.getString("\(prefix)/candidate_list_layout").map { $0 == "linear" }
        vertical ?= config.getString("\(prefix)/text_orientation").map { $0 == "vertical" }
        inlinePreedit ?= config.getBool("\(prefix)/inline_preedit")
        inlineCandidate ?= config.getBool("\(prefix)/inline_candidate")
        translucency ?= config.getBool("\(prefix)/translucency")
        mutualExclusive ?= config.getBool("\(prefix)/mutual_exclusive")
        showPaging ?= config.getBool("\(prefix)/show_paging")
        candidateFormat ?= config.getString("\(prefix)/candidate_format")
        fontName ?= config.getString("\(prefix)/font_face")
        fontSize ?= config.getDouble("\(prefix)/font_point")
        labelFontName ?= config.getString("\(prefix)/label_font_face")
        labelFontSize ?= config.getDouble("\(prefix)/label_font_point")
        commentFontName ?= config.getString("\(prefix)/comment_font_face")
        commentFontSize ?= config.getDouble("\(prefix)/comment_font_point")

        alpha ?= config.getDouble("\(prefix)/alpha").map { max(0, min(1, $0)) }
        cornerRadius ?= config.getDouble("\(prefix)/corner_radius")
        hilitedCornerRadius ?= config.getDouble("\(prefix)/hilited_corner_radius")
        surroundingExtraExpansion ?= config.getDouble("\(prefix)/surrounding_extra_expansion")
        borderHeight ?= config.getDouble("\(prefix)/border_height")
        borderWidth ?= config.getDouble("\(prefix)/border_width")
        linespace ?= config.getDouble("\(prefix)/line_spacing")
        preeditLinespace ?= config.getDouble("\(prefix)/spacing")
        baseOffset ?= config.getDouble("\(prefix)/base_offset")
        shadowSize ?= config.getDouble("\(prefix)/shadow_size").map { max(0, $0) }
      }
    } else {
      available = false
    }

    fonts = decodeFonts(from: fontName)
    self.fontSize = fontSize
    labelFonts = decodeFonts(from: labelFontName ?? fontName)
    self.labelFontSize = labelFontSize
    commentFonts = decodeFonts(from: commentFontName ?? fontName)
    self.commentFontSize = commentFontSize
  }
}

private extension SquirrelTheme {
  func combineFonts(_ fonts: [NSFont], size: CGFloat?) -> NSFont? {
    if fonts.count == 0 { return nil }
    if fonts.count == 1 {
      if let size = size {
        return fonts[0].withSize(size)
      } else {
        return fonts[0]
      }
    }
    let attribute = [NSFontDescriptor.AttributeName.cascadeList: fonts[1...].map { $0.fontDescriptor } ]
    let fontDescriptor = fonts[0].fontDescriptor.addingAttributes(attribute)
    return NSFont.init(descriptor: fontDescriptor, size: size ?? fonts[0].pointSize)
  }

  func decodeFonts(from fontString: String?) -> [NSFont] {
    guard let fontString = fontString else { return [] }
    var seenFontFamilies = Set<String>()
    let fontStrings = fontString.split(separator: ",")
    var fonts = [NSFont]()
    for string in fontStrings {
      if let matchedFontName = try? /^\s*(.+)-([^-]+)\s*$/.firstMatch(in: string) {
        let family = String(matchedFontName.output.1)
        let style = String(matchedFontName.output.2)
        if seenFontFamilies.contains(family) { continue }
        let fontDescriptor = NSFontDescriptor(fontAttributes: [.family: family, .face: style])
        if let font = NSFont(descriptor: fontDescriptor, size: Self.defaultFontSize) {
          fonts.append(font)
          seenFontFamilies.insert(family)
          continue
        }
      }
      let fontName = string.trimmingCharacters(in: .whitespaces)
      if seenFontFamilies.contains(fontName) { continue }
      let fontDescriptor = NSFontDescriptor(fontAttributes: [.name: fontName])
      if let font = NSFont(descriptor: fontDescriptor, size: Self.defaultFontSize) {
        fonts.append(font)
        seenFontFamilies.insert(fontName)
        continue
      }
    }
    return fonts
  }

  func blendColor(foregroundColor: NSColor, backgroundColor: NSColor?) -> NSColor {
    let foregroundColor = foregroundColor.usingColorSpace(NSColorSpace.deviceRGB)!
    let backgroundColor = (backgroundColor ?? NSColor.gray).usingColorSpace(NSColorSpace.deviceRGB)!
    func blend(foreground: CGFloat, background: CGFloat) -> CGFloat {
      return (foreground * 2 + background) / 3
    }
    return NSColor(deviceRed: blend(foreground: foregroundColor.redComponent, background: backgroundColor.redComponent),
                   green: blend(foreground: foregroundColor.greenComponent, background: backgroundColor.greenComponent),
                   blue: blend(foreground: foregroundColor.blueComponent, background: backgroundColor.blueComponent),
                   alpha: blend(foreground: foregroundColor.alphaComponent, background: backgroundColor.alphaComponent))
  }
}
