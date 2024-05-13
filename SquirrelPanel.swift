//
//  SquirrelPanel.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import AppKit

class SquirrelPanel: NSPanel {
  private let view: SquirrelView
  private let back: NSVisualEffectView
  var inputController: SquirrelInputController?
  
  var position: NSRect
  private var screenRect: NSRect = .zero
  private var maxHeight: CGFloat = 0
  
  private var statusMessage: String = ""
  private var statusTimer: Timer?
  
  private var preedit: String = ""
  private var selRange: NSRange = .init(location: NSNotFound, length: 0)
  private var caretPos: Int = 0
  private var candidates: [String] = .init()
  private var comments: [String] = .init()
  private var labels: [String] = .init()
  private var index: Int = 0
  private var cursorIndex: Int = 0
  private var scrollDirection: CGVector = .zero
  private var scrollTime: Date = .distantPast
  
  init(position: NSRect) {
    self.position = position
    self.view = SquirrelView(frame: position)
    self.back = NSVisualEffectView()
    super.init(contentRect: position, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.level = .init(Int(CGShieldingWindowLevel()))
    self.hasShadow = true
    self.isOpaque = false
    self.backgroundColor = .clear
    back.blendingMode = .behindWindow
    back.material = .hudWindow
    back.state = .active
    back.wantsLayer = true
    back.layer?.mask = view.shape
    let contentView = NSView()
    contentView.addSubview(back)
    contentView.addSubview(view)
    contentView.addSubview(view.textView)
    self.contentView = contentView
  }
  
  var linear: Bool {
    view.currentTheme.linear
  }
  var vertical: Bool {
    view.currentTheme.vertical
  }
  var inlinePreedit: Bool {
    view.currentTheme.inlinePreedit
  }
  var inlineCandidate: Bool {
    view.currentTheme.inlineCandidate
  }
  
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown:
      let (index, _) =  view.click(at: mousePosition())
      if let index = index, index >= 0 && index < candidates.count {
        self.index = index
      }
    case .leftMouseUp:
      let (index, preeditIndex) = view.click(at: mousePosition())
      if let preeditIndex = preeditIndex, preeditIndex >= 0 && preeditIndex < preedit.utf16.count {
        if preeditIndex < caretPos {
          let _ = inputController?.moveCaret(forward: true)
        } else if preeditIndex > caretPos {
          let _ = inputController?.moveCaret(forward: false)
        }
      }
      if let index = index, index == self.index && index >= 0 && index < candidates.count {
        let _ = inputController?.selectCandidate(index)
      }
    case .mouseEntered:
      acceptsMouseMovedEvents = true
    case .mouseExited:
      acceptsMouseMovedEvents = false
      if cursorIndex != index {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, update: false)
      }
    case .mouseMoved:
      let (index, _) = view.click(at: mousePosition())
      if let index = index, cursorIndex != index && index >= 0 && index < candidates.count {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, update: false)
      }
    case .scrollWheel:
      if event.phase == .began {
        scrollDirection = .zero
      // Scrollboard span
      } else if event.phase == .ended || (event.phase == .init(rawValue: 0) && event.momentumPhase != .init(rawValue: 0)) {
        if abs(scrollDirection.dx) > abs(scrollDirection.dy) && abs(scrollDirection.dx) > 10 {
          let _ = inputController?.page(up: (scrollDirection.dx < 0) == vertical)
        } else if abs(scrollDirection.dx) < abs(scrollDirection.dy) && abs(scrollDirection.dy) > 10 {
          let _ = inputController?.page(up: scrollDirection.dx > 0)
        }
        scrollDirection = .zero
      // Mouse scroll wheel
      } else if event.phase == .init(rawValue: 0) && event.momentumPhase == .init(rawValue: 0) {
        if scrollTime.timeIntervalSinceNow < -1 {
          scrollDirection = .zero
        }
        scrollTime = .now
        if (scrollDirection.dy >= 0 && event.scrollingDeltaY > 0) || (scrollDirection.dy <= 0 && event.scrollingDeltaY < 0) {
          scrollDirection.dy += event.scrollingDeltaY
        } else {
          scrollDirection = .zero
        }
        if abs(scrollDirection.dy) > 10 {
          let _ = inputController?.page(up: scrollDirection.dy > 0)
          scrollDirection = .zero
        }
      } else {
        scrollDirection.dx += event.scrollingDeltaX
        scrollDirection.dy += event.scrollingDeltaY
      }
    default:
      break
    }
    super.sendEvent(event)
  }
  
  func hide() {
    statusTimer?.invalidate()
    statusTimer = nil
    orderOut(nil)
    maxHeight = 0
  }
  
  // Main function to add attributes to text output from librime
  func update(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted index: Int, update: Bool) {
    if update {
      self.preedit = preedit
      self.selRange = selRange
      self.caretPos = caretPos
      self.candidates = candidates
      self.comments = comments
      self.labels = labels
      self.index = index
    }
    cursorIndex = index
    
    if !candidates.isEmpty || !preedit.isEmpty {
      statusMessage = ""
      statusTimer?.invalidate()
      statusTimer = nil
    } else {
      if !statusMessage.isEmpty {
        show(status: statusMessage)
        statusMessage = ""
      } else if statusTimer == nil {
        hide()
      }
      return
    }
    
    let theme = view.currentTheme
    currentScreen()
    let maxTextWidth = maxTextWidth()
    
    let text = NSMutableAttributedString()
    var preeditRange = NSMakeRange(NSNotFound, 0)
    var highlightedPreeditRange = NSMakeRange(NSNotFound, 0)
    
    // preedit
    if !preedit.isEmpty {
      let line = NSMutableAttributedString()
      let startIndex = String.Index(utf16Offset: selRange.location, in: preedit)
      let endIndex = String.Index(utf16Offset: selRange.upperBound, in: preedit)
      if selRange.location > 0 {
        line.append(NSAttributedString(string: String(preedit[..<startIndex]), attributes: theme.preeditAttrs))
      }
      if selRange.length > 0 {
        let highlightedPreeditStart = line.length
        line.append(NSAttributedString(string: String(preedit[startIndex..<endIndex]), attributes: theme.preeditHighlightedAttrs))
        highlightedPreeditRange = NSMakeRange(highlightedPreeditStart, line.length - highlightedPreeditStart)
      }
      if selRange.upperBound < preedit.utf16.count {
        line.append(NSAttributedString(string: String(preedit[endIndex...]), attributes: theme.preeditAttrs))
      }
      text.append(line)
      
      text.addAttribute(.paragraphStyle, value: theme.preeditParagraphStyle, range: NSMakeRange(0, text.length))
      preeditRange = NSMakeRange(0, text.length)
      if !candidates.isEmpty {
        text.append(NSAttributedString(string: "\n", attributes: theme.preeditAttrs))
      }
    }
    
    // candidates
    var candidateRanges = [NSRange]()
    for i in 0..<candidates.count {
      let line = NSMutableAttributedString()
      
      let attrs = i == index ? theme.highlightedAttrs : theme.attrs
      let labelAttrs = i == index ? theme.labelHighlightedAttrs : theme.labelAttrs
      let commentAttrs = i == index ? theme.commentHighlightedAttrs : theme.commentAttrs
      var labelWidth: CGFloat = 0
      
      if !theme.prefixLabelFormat.isEmpty {
        let label: String
        if labels.count > 1 && i < labels.count {
          label = theme.prefixLabelFormat.replacingOccurrences(of: "%c", with: labels[i])
        } else if labels.count == 1 && i < labels.first!.count {
          // custom: A. B. C...
          let labelCharacter = labels.first![labels.first!.index(labels.first!.startIndex, offsetBy: i)]
          label = theme.prefixLabelFormat.replacingOccurrences(of: "%c", with: String(labelCharacter))
        } else {
          // default: 1. 2. 3...
          label = theme.prefixLabelFormat.replacingOccurrences(of: "%c", with: "\(i+1)")
        }
        line.append(NSAttributedString(string: label.precomposedStringWithCanonicalMapping, attributes: labelAttrs))
        
        // get the label size for indent
        if !linear {
          let str = line.mutableCopy() as! NSMutableAttributedString
          if vertical {
            str.addAttribute(.verticalGlyphForm, value: 1, range: NSMakeRange(0, str.length))
          }
          labelWidth = str.boundingRect(with: .zero, options: .usesLineFragmentOrigin).width
        }
      }
        
      let candidateStart = line.length
      var candidate = NSAttributedString(string: candidates[i].precomposedStringWithCanonicalMapping, attributes: attrs)
      let candidateWidth = candidate.boundingRect(with: .zero, options: .usesLineFragmentOrigin).width
      if candidateWidth <= maxTextWidth * 0.2 {
        // Unicode Word Joiner so that line will not break within
        candidate = insert(separator: "\u{2060}", between: candidate)
      }
      
      line.append(candidate)
      // Use left-to-right marks to prevent right-to-left text from changing the
      // layout of non-candidate text.
      line.addAttribute(.writingDirection, value: [0], range: NSMakeRange(candidateStart, line.length - candidateStart))
      
      if !theme.suffixLabelFormat.isEmpty {
        let label: String
        if labels.count > 1 && i < labels.count {
          label = theme.suffixLabelFormat.replacingOccurrences(of: "%c", with: labels[i])
        } else if labels.count == 1 && i < labels.first!.count {
          // custom: A. B. C...
          let labelCharacter = labels.first![labels.first!.index(labels.first!.startIndex, offsetBy: i)]
          label = theme.suffixLabelFormat.replacingOccurrences(of: "%c", with: String(labelCharacter))
        } else {
          // default: 1. 2. 3...
          label = theme.suffixLabelFormat.replacingOccurrences(of: "%c", with: "\(i+1)")
        }
        line.append(NSAttributedString(string: label.precomposedStringWithCanonicalMapping, attributes: labelAttrs))
      }
      
      if i < comments.count && !comments[i].isEmpty {
        let candidateAndLabelWidth = line.boundingRect(with: .zero, options: .usesLineFragmentOrigin).width
        var comment = NSAttributedString(string: comments[i], attributes: commentAttrs)
        let commentWidth = comment.boundingRect(with: .zero, options: .usesLineFragmentOrigin).width
        if commentWidth <= maxTextWidth * 0.2 {
          // Unicode Word Joiner so that line will not break within
          comment = insert(separator: "\u{2060}", between: comment)
        }
        
        let commentSeparator = if candidateAndLabelWidth + commentWidth <= maxTextWidth * 0.3 {
          // Non-Breaking White Space
          "\u{A0}"
        } else {
          " "
        }
        line.append(NSAttributedString(string: commentSeparator, attributes: commentAttrs))
        line.append(comment)
      }
      
      let lineSeparator = NSAttributedString(string: linear ? "  " : "\n", attributes: attrs)
      if i > 0 {
        text.append(lineSeparator)
      }
      let str = lineSeparator.mutableCopy() as! NSMutableAttributedString
      if vertical {
        str.addAttribute(.verticalGlyphForm, value: 1, range: NSMakeRange(0, str.length))
      }
      view.separatorWidth = str.boundingRect(with: .zero).width
      
      let paragraphStyleCandidate = (i == 0 ? theme.firstParagraphStyle : theme.paragraphStyle).mutableCopy() as! NSMutableParagraphStyle
      if linear {
        paragraphStyleCandidate.lineSpacing = theme.linespace
      }
      paragraphStyleCandidate.headIndent = labelWidth
      line.addAttribute(.paragraphStyle, value: paragraphStyleCandidate, range: NSMakeRange(0, line.length))
      
      candidateRanges.append(NSMakeRange(text.length, line.length))
      text.append(line)
    }

    // text done!
    view.textView.textContentStorage?.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)
    view.drawView(candidateRanges: candidateRanges, hilightedIndex: index, preeditRange: preeditRange, highlightedPreeditRange: highlightedPreeditRange)
    show()
  }
  
  func updateStatus(long longMessage: String, short shortMessage: String) {
    let theme = view.currentTheme
    switch theme.statusMessageType {
    case .mix:
      statusMessage = shortMessage.isEmpty ? longMessage : shortMessage
    case .long:
      statusMessage = longMessage
    case .short:
      if !shortMessage.isEmpty {
        statusMessage = shortMessage
      } else if let initial = longMessage.first {
        statusMessage = String(initial)
      } else {
        statusMessage = ""
      }
    }
  }
  
  func load(config: SquirrelConfig, forDarkMode isDark: Bool) {
    let theme = isDark ? view.darkTheme : view.lightTheme
    theme.load(config: config, dark: isDark)
  }
}

private extension SquirrelPanel {
  func insert(separator: String, between text: NSAttributedString) -> NSAttributedString {
    var range = (text.string as NSString).rangeOfComposedCharacterSequence(at: 0)
    let attributedSeparator = NSAttributedString(string: separator, attributes: text.attributes(at: 0, effectiveRange: nil))
    let workingString = text.attributedSubstring(from: range).mutableCopy() as! NSMutableAttributedString
    while range.upperBound < text.length{
      range = (text.string as NSString).rangeOfComposedCharacterSequence(at: range.upperBound)
      workingString.append(attributedSeparator)
      workingString.append(text.attributedSubstring(from: range))
    }
    return workingString
  }
  
  func mousePosition() -> NSPoint {
    var point = NSEvent.mouseLocation
    point = self.convertPoint(fromScreen: point)
    return view.convert(point, from: nil)
  }
  
  func currentScreen() {
    if let screen = NSScreen.main {
      screenRect = screen.frame
    }
    for screen in NSScreen.screens {
      if NSPointInRect(position.origin, screen.frame) {
        screenRect = screen.frame
        break
      }
    }
  }
  
  func maxTextWidth() -> CGFloat {
    let theme = view.currentTheme
    let font: NSFont = theme.font
    let fontScale = font.pointSize / 12
    let textWidthRatio = min(1, 1 / (vertical ? 4 : 3) + fontScale / 12)
    let maxWidth = if vertical {
      screenRect.height * textWidthRatio - theme.edgeInset.height * 2
    } else {
      screenRect.width * textWidthRatio - theme.edgeInset.width * 2
    }
    return maxWidth
  }
  
  // Get the window size, the windows will be the dirtyRect in
  // SquirrelView.drawRect
  func show() {
    currentScreen()
    let theme = view.currentTheme
    let requestedAppearance: NSAppearance? = theme.native ? nil : NSAppearance(named: .aqua)
    if self.appearance != requestedAppearance {
      self.appearance = requestedAppearance
    }
    
    // Break line if the text is too long, based on screen size.
    let textWidth = maxTextWidth()
    let maxTextHeight = vertical ? screenRect.width - theme.edgeInset.width * 2 : screenRect.height - theme.edgeInset.height * 2
    view.textContainer.size = NSMakeSize(textWidth, maxTextHeight)
    
    var panelRect = NSZeroRect
    // in vertical mode, the width and height are interchanged
    var contentRect = view.contentRect
    if theme.memorizeSize && (vertical && position.midY / screenRect.height < 0.5) ||
        (vertical && position.minX + max(contentRect.width, maxHeight) + theme.edgeInset.width * 2 > screenRect.maxX) {
      if contentRect.width >= maxHeight {
        maxHeight = contentRect.width
      } else {
        contentRect.size.width = maxHeight
        view.textContainer.size = NSMakeSize(maxHeight, maxTextHeight)
      }
    }

    if vertical {
      panelRect.size = NSMakeSize(contentRect.height + theme.edgeInset.height * 2, contentRect.width + theme.edgeInset.width * 2)
      // To avoid jumping up and down while typing, use the lower screen when
      // typing on upper, and vice versa
      if position.midY / screenRect.height >= 0.5 {
        panelRect.origin.y = position.minY - SquirrelTheme.offsetHeight - panelRect.height
      } else {
        panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
      }
      // Make the first candidate fixed at the left of cursor
      panelRect.origin.x = position.minX - panelRect.width - SquirrelTheme.offsetHeight
      if view.preeditRange.length > 0 {
        let preeditRect = view.contentRect(range: view.convert(range: view.preeditRange))
        panelRect.origin.x += preeditRect.height + theme.edgeInset.width
      }
    } else {
      panelRect.size = NSMakeSize(contentRect.width + theme.edgeInset.width * 2, contentRect.height + theme.edgeInset.height * 2)
      panelRect.origin = NSMakePoint(position.minX, position.minY - SquirrelTheme.offsetHeight - panelRect.height)
    }
    
    if panelRect.maxX > screenRect.maxX {
      panelRect.origin.x = screenRect.maxX - panelRect.width
    }
    if panelRect.minX < screenRect.minX {
      panelRect.origin.x = screenRect.minX
    }
    if panelRect.minY < screenRect.minY {
      if vertical {
        panelRect.origin.y = screenRect.minY
      } else {
        panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
      }
    }
    if panelRect.maxY > screenRect.maxY {
      panelRect.origin.y = screenRect.maxY - panelRect.height
    }
    if panelRect.minY < screenRect.minY {
      panelRect.origin.y = screenRect.minY
    }
    self.setFrame(panelRect, display: true)
    
    // rotate the view, the core in vertical mode!
    if vertical {
      contentView!.boundsRotation = -90
      contentView!.setBoundsOrigin(NSMakePoint(0, panelRect.width))
    } else {
      contentView!.boundsRotation = 0
      contentView!.setBoundsOrigin(.zero)
    }
    view.textView.boundsRotation = 0
    view.textView.setBoundsOrigin(.zero)
    
    view.frame = contentView!.bounds
    view.textView.frame = contentView!.bounds
    view.textView.textContainerInset = theme.edgeInset
    
    if theme.translucency {
      back.frame = contentView!.bounds
      back.appearance = NSApp.effectiveAppearance
      back.isHidden = false
    } else {
      back.isHidden = true
    }
    alphaValue = theme.alpha
    invalidateShadow()
    orderFront(nil)
    // voila!
  }
  
  func show(status message: String) {
    let theme = view.currentTheme
    let text = NSMutableAttributedString(string: message, attributes: theme.attrs)
    text.addAttribute(.paragraphStyle, value: theme.paragraphStyle, range: NSMakeRange(0, text.length))
    view.textContentStorage.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)
    view.drawView(candidateRanges: [NSMakeRange(0, text.length)], hilightedIndex: -1, preeditRange: NSMakeRange(NSNotFound, 0), highlightedPreeditRange: NSMakeRange(NSNotFound, 0))
    show()
    
    statusTimer?.invalidate()
    statusTimer = Timer.scheduledTimer(withTimeInterval: SquirrelTheme.showStatusDuration, repeats: false) { _ in
      self.hide()
    }
  }
}
