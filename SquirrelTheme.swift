//
//  SquirrelView.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

class SquirrelTheme {
  static let offsetHeight: CGFloat = 5
  static let defaultFontSize: CGFloat = 24
  static let showStatusDuration: Double = 1.2
  
  enum StatusMessageType: String {
    case long, short, mix
  }
  
  var native = true
  var memorizeSize = true
  
  var backgroundColor: NSColor = .windowBackgroundColor
  var highlightedPreeditColor: NSColor?
  var highlightedBackColor: NSColor? = .selectedTextBackgroundColor
  var preeditBackgroundColor: NSColor?
  var candidateBackColor: NSColor?
  var borderColor: NSColor?
  
  var textColor: NSColor = .disabledControlTextColor
  var highlightedTextColor: NSColor = .controlTextColor
  var candidateTextColor: NSColor = .controlTextColor
  var highlightedCandidateTextColor: NSColor = .selectedControlTextColor
  var candidateLabelColor: NSColor?
  var highlightedCandidateLabelColor: NSColor?
  var commentTextColor: NSColor? = .disabledControlTextColor
  var highlightedCommentTextColor: NSColor?
  
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
  var inlineCandidate = true
  
  var fonts: Array<NSFont> = [NSFont.userFont(ofSize: SquirrelTheme.defaultFontSize)!]
  var labelFonts = Array<NSFont>()
  var commentFonts = Array<NSFont>()
  
  var prefixLabelFormat = "%c.\u{00A0}"
  var suffixLabelFormat = ""
  var statusMessageType: StatusMessageType = .mix
  
  var font: NSFont! {
    return combineFonts(fonts)
  }
  var labelFont: NSFont? {
    return combineFonts(labelFonts)
  }
  var commentFont: NSFont? {
    return combineFonts(commentFonts)
  }
  var attrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: candidateTextColor,
     .font: font!,
     .baselineOffset: baseOffset]
  }
  var highlightedAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: highlightedCandidateTextColor,
     .font: font!,
     .baselineOffset: baseOffset]
  }
  var labelAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: candidateLabelColor ?? blendColor(foregroundColor: self.candidateTextColor, backgroundColor: self.backgroundColor),
            .font: labelFont ?? font!,
            .baselineOffset: baseOffset]
  }
  var labelHighlightedAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: highlightedCandidateLabelColor ?? blendColor(foregroundColor: highlightedCandidateTextColor, backgroundColor: highlightedBackColor),
            .font: labelFont ?? font!,
            .baselineOffset: baseOffset]
  }
  var commentAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: commentTextColor ?? candidateTextColor,
            .font: commentFont ?? font!,
            .baselineOffset: baseOffset]
  }
  var commentHighlightedAttrs: [NSAttributedString.Key : Any] {
    return [.foregroundColor: highlightedCommentTextColor ?? highlightedCandidateTextColor,
            .font: commentFont ?? font!,
            .baselineOffset: baseOffset]
  }
  var preeditAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: textColor,
     .font: font!,
     .baselineOffset: baseOffset]
  }
  var preeditHighlightedAttrs: [NSAttributedString.Key : Any] {
    [.foregroundColor: highlightedTextColor,
     .font: font!,
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
      "\(prefixLabelFormat)%@\(suffixLabelFormat)"
    } set {
      if let (_, pre, post) = try? /(.*)%@(.*)/.wholeMatch(in: newValue)?.output {
        prefixLabelFormat = String(pre)
        suffixLabelFormat = String(post)
      } else {
        prefixLabelFormat = newValue
      }
    }
  }
  
  func combineFonts(_ fonts: Array<NSFont>) -> NSFont? {
    if fonts.count == 0 { return nil }
    if fonts.count == 1 { return fonts[0] }
    let attribute = [NSFontDescriptor.AttributeName.cascadeList: fonts[1...].map { $0.fontDescriptor } ]
    let fontDescriptor = fonts[0].fontDescriptor.addingAttributes(attribute)
    return NSFont.init(descriptor: fontDescriptor, size: fonts[0].pointSize)
  }
  
  func decodeFonts(from fontString: String, size: CGFloat) -> Array<NSFont> {
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
      if let validFont = NSFont(name: String(trimedString), size: size) {
        fonts.append(validFont)
      }
    }
    return fonts
  }
  
  func blendColor(foregroundColor: NSColor, backgroundColor: NSColor?) -> NSColor {
    let foregroundColor = foregroundColor.usingColorSpace(NSColorSpace.deviceRGB)!
    let backgroundColor = (backgroundColor ?? NSColor.darkGray).usingColorSpace(NSColorSpace.deviceRGB)!
    func blend(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
      return (a * 2 + b) / 3
    }
    return NSColor(deviceRed: blend(foregroundColor.redComponent, backgroundColor.redComponent),
                   green: blend(foregroundColor.greenComponent, backgroundColor.greenComponent),
                   blue: blend(foregroundColor.blueComponent, backgroundColor.blueComponent),
                   alpha: blend(foregroundColor.alphaComponent, backgroundColor.alphaComponent))
  }
}

