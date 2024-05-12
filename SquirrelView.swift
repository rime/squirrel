//
//  SquirrelView.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

class SquirrelView: NSView {
  let textView: NSTextView
  
  var candidateRanges: [NSRange] = []
  var hilightedIndex = 0
  var preeditRange = NSMakeRange(NSNotFound, 0)
  var highlightedPreeditRange = NSMakeRange(NSNotFound, 0)
  var separatorWidth: CGFloat = 0
  var shape = CAShapeLayer()
  
  var lightTheme = SquirrelTheme()
  var darkTheme = SquirrelTheme()
  var currentTheme: SquirrelTheme {
    isDark ? darkTheme : lightTheme
  }
  var textLayoutManager: NSTextLayoutManager {
    textView.textLayoutManager!
  }
  var textContentStorage: NSTextContentStorage {
    textView.textContentStorage!
  }
  var textContainer: NSTextContainer {
    textLayoutManager.textContainer!
  }
  
  override init(frame frameRect: NSRect) {
    textView = NSTextView(frame: frameRect)
    textView.drawsBackground = false
    textView.isEditable = false
    textView.isSelectable = false
    super.init(frame: frameRect)
    textContainer.lineFragmentPadding = 0
    self.wantsLayer = true
    self.layer?.masksToBounds = true
  }
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var isFlipped: Bool {
    true
  }
  var isDark: Bool {
    NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
  }
  
  func convert(range: NSRange) -> NSTextRange {
    let nullRange = NSTextRange(location: textLayoutManager.documentRange.location)
    guard range.location != NSNotFound else { return nullRange }
    guard let startLocation = textLayoutManager.location(textLayoutManager.documentRange.location, offsetBy: range.location) else { return nullRange }
    guard let endLocation = textLayoutManager.location(startLocation, offsetBy: range.length) else { return nullRange }
    return NSTextRange(location: startLocation, end: endLocation) ?? textLayoutManager.documentRange
  }
  
  // Get the rectangle containing entire contents, expensive to calculate
  var contentRect: NSRect {
    var ranges = candidateRanges
    if preeditRange.length > 0 {
      ranges.append(preeditRange)
    }
    var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
    for range in ranges {
      let rect = self.contentRect(range: convert(range: range))
      x0 = min(NSMinX(rect), x0)
      x1 = max(NSMaxX(rect), x1)
      y0 = min(NSMinY(rect), y0)
      y1 = max(NSMaxY(rect), y1)
    }
    return NSMakeRect(x0, y0, x1-x0, y1-y0)
  }
  // Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
  func contentRect(range: NSTextRange) -> NSRect {
    var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
    textLayoutManager.enumerateTextSegments(in: range, type: .standard, options: .rangeNotRequired) { _, rect, _, _ in
      x0 = min(NSMinX(rect), x0)
      x1 = max(NSMaxX(rect), x1)
      y0 = min(NSMinY(rect), y0)
      y1 = max(NSMaxY(rect), y1)
      return true
    }
    return NSMakeRect(x0, y0, x1-x0, y1-y0)
  }
  
  // Will triger - (void)drawRect:(NSRect)dirtyRect
  func drawView(candidateRanges: Array<NSRange>, hilightedIndex: Int, preeditRange: NSRange, highlightedPreeditRange: NSRange) {
    self.candidateRanges = candidateRanges
    self.hilightedIndex = hilightedIndex
    self.preeditRange = preeditRange
    self.highlightedPreeditRange = highlightedPreeditRange
    self.needsDisplay = true
  }
  
  // All draws happen here
  override func draw(_ dirtyRect: NSRect) {
    var backgroundPath: CGPath?
    var preeditPath: CGPath?
    var candidatePaths: CGMutablePath?
    var highlightedPath: CGMutablePath?
    var highlightedPreeditPath: CGMutablePath?
    let theme = currentTheme
    
    let backgroundRect = dirtyRect
    var containingRect = dirtyRect
    
    // Draw preedit Rect
    var preeditRect = NSZeroRect
    if (preeditRange.length > 0) {
      preeditRect = contentRect(range: convert(range: preeditRange))
      preeditRect.size.width = backgroundRect.size.width
      preeditRect.size.height += theme.edgeInset.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2
      preeditRect.origin = backgroundRect.origin
      if candidateRanges.count == 0 {
        preeditRect.size.height += theme.edgeInset.height - theme.preeditLinespace / 2 - theme.hilitedCornerRadius / 2
      }
      containingRect.size.height -= preeditRect.size.height
      containingRect.origin.y += preeditRect.size.height
      if theme.preeditBackgroundColor != nil {
        preeditPath = drawSmoothLines(rectVertex(of: preeditRect), straightCorner: Set(), alpha: 0, beta: 0)
      }
    }
    
    containingRect = carveInset(rect: containingRect)
    // Draw candidate Rects
    for i in 0..<candidateRanges.count {
      let candidate = candidateRanges[i]
      if i == hilightedIndex {
        // Draw highlighted Rect
        if (candidate.length > 0 && theme.highlightedBackColor != nil) {
          highlightedPath = drawPath(highlightedRange: candidate, backgroundRect: backgroundRect, preeditRect: preeditRect, containingRect: containingRect, extraExpansion: 0)?.mutableCopy()
        }
      } else {
        // Draw other highlighted Rect
        if (candidate.length > 0 && theme.candidateBackColor != nil) {
          let candidatePath = drawPath(highlightedRange: candidate, backgroundRect: backgroundRect, preeditRect: preeditRect, containingRect: containingRect, extraExpansion: theme.surroundingExtraExpansion)
          if candidatePaths == nil {
            candidatePaths = CGMutablePath()
          }
          if let candidatePath = candidatePath {
            candidatePaths?.addPath(candidatePath)
          }
        }
      }
    }
    
    // Draw highlighted part of preedit text
    if (highlightedPreeditRange.length > 0) && (theme.highlightedPreeditColor != nil) {
      var innerBox = preeditRect
      innerBox.size.width -= (theme.edgeInset.width + 1) * 2
      innerBox.origin.x += theme.edgeInset.width + 1
      innerBox.origin.y += theme.edgeInset.height + 1
      if candidateRanges.count == 0 {
        innerBox.size.height -= (theme.edgeInset.height + 1) * 2
      } else {
        innerBox.size.height -= theme.edgeInset.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 2
      }
      var outerBox = preeditRect
      outerBox.size.height -= max(0, theme.hilitedCornerRadius + theme.borderLineWidth)
      outerBox.size.width -= max(0, theme.hilitedCornerRadius + theme.borderLineWidth)
      outerBox.origin.x += max(0, theme.hilitedCornerRadius + theme.borderLineWidth) / 2
      outerBox.origin.y += max(0, theme.hilitedCornerRadius + theme.borderLineWidth) / 2
      
      let (leadingRect, bodyRect, trailingRect) = multilineRects(forRange: convert(range: highlightedPreeditRange), extraSurounding: 0, bounds: outerBox)
      var (highlightedPoints, highlightedPoints2, rightCorners, rightCorners2) = linearMultilineFor(body: bodyRect, leading: leadingRect, trailing: trailingRect)
      
      containingRect = carveInset(rect: preeditRect)
      highlightedPoints = expand(vertex: highlightedPoints, innerBorder: innerBox, outerBorder: outerBox)
      rightCorners = removeCorner(highlightedPoints: highlightedPoints, rightCorners: rightCorners, containingRect: containingRect)
      highlightedPreeditPath = drawSmoothLines(highlightedPoints, straightCorner: rightCorners, alpha: 0.3 * theme.hilitedCornerRadius, beta: 1.4 * theme.hilitedCornerRadius)?.mutableCopy()
      if (highlightedPoints2.count > 0) {
        highlightedPoints2 = expand(vertex: highlightedPoints2, innerBorder: innerBox, outerBorder: outerBox)
        rightCorners2 = removeCorner(highlightedPoints: highlightedPoints2, rightCorners: rightCorners2, containingRect: containingRect)
        let highlightedPreeditPath2 = drawSmoothLines(highlightedPoints2, straightCorner: rightCorners2, alpha: 0.3 * theme.hilitedCornerRadius, beta: 1.4 * theme.hilitedCornerRadius)
        if let highlightedPreeditPath2 = highlightedPreeditPath2 {
          highlightedPreeditPath?.addPath(highlightedPreeditPath2)
        }
      }
    }
    
    NSBezierPath.defaultLineWidth = 0
    backgroundPath = drawSmoothLines(rectVertex(of: backgroundRect), straightCorner: Set(), alpha: 0.3 * theme.cornerRadius, beta: 1.4 * theme.cornerRadius)
    shape.path = backgroundPath
    
    self.layer?.sublayers = nil
    let backPath = backgroundPath?.mutableCopy()
    if let path = preeditPath {
      backPath?.addPath(path)
    }
    if theme.mutualExclusive {
      if let path = highlightedPath {
        backPath?.addPath(path)
      }
      if let path = candidatePaths {
        backPath?.addPath(path)
      }
    }
    let panelLayer = shapeFromPath(path: backPath)
    panelLayer.fillColor = theme.backgroundColor.cgColor
    let panelLayerMask = shapeFromPath(path: backgroundPath)
    panelLayer.mask = panelLayerMask
    self.layer?.addSublayer(panelLayer)
    
    // Fill in colors
    if let color = theme.preeditBackgroundColor, let path = preeditPath {
      let layer = shapeFromPath(path: path)
      layer.fillColor = color.cgColor
      let maskPath = backgroundPath?.mutableCopy()
      if theme.mutualExclusive, let hilitedPath = highlightedPreeditPath {
        maskPath?.addPath(hilitedPath)
      }
      let mask = shapeFromPath(path: maskPath)
      layer.mask = mask
      panelLayer.addSublayer(layer)
    }
    if theme.borderLineWidth > 0, let color = theme.borderColor {
      let borderLayer = shapeFromPath(path: backgroundPath)
      borderLayer.lineWidth = theme.borderLineWidth * 2
      borderLayer.strokeColor = color.cgColor
      borderLayer.fillColor = nil
      panelLayer.addSublayer(borderLayer)
    }
    if let color = theme.highlightedPreeditColor, let path = highlightedPreeditPath {
      let layer = shapeFromPath(path: path)
      layer.fillColor = color.cgColor
      panelLayer.addSublayer(layer)
    }
    if let color = theme.candidateBackColor, let path = candidatePaths {
      let layer = shapeFromPath(path: path)
      layer.fillColor = color.cgColor
      panelLayer.addSublayer(layer)
    }
    if let color = theme.highlightedBackColor, let path = highlightedPath {
      let layer = shapeFromPath(path: path)
      layer.fillColor = color.cgColor
      if theme.shadowSize > 0 {
        let shadowLayer = CAShapeLayer()
        shadowLayer.shadowColor = NSColor.black.cgColor
        shadowLayer.shadowOffset = NSMakeSize(theme.shadowSize/2, (theme.vertical ? -1 : 1) * theme.shadowSize/2)
        shadowLayer.shadowPath = highlightedPath
        shadowLayer.shadowRadius = theme.shadowSize
        shadowLayer.shadowOpacity = 0.2
        let outerPath = backgroundPath?.mutableCopy()
        outerPath?.addPath(path)
        let shadowLayerMask = shapeFromPath(path: outerPath)
        shadowLayer.mask = shadowLayerMask
        layer.strokeColor = NSColor.black.withAlphaComponent(0.15).cgColor
        layer.lineWidth = 0.5
        layer.addSublayer(shadowLayer)
      }
      panelLayer.addSublayer(layer)
    }
  }
  
  func click(at clickPoint: NSPoint) -> (Int?, Int?) {
    var index = 0
    var candidateIndex: Int? = nil
    var preeditIndex: Int? = nil
    if let path = shape.path, path.contains(clickPoint) {
      var point = NSMakePoint(clickPoint.x - textView.textContainerInset.width,
                              clickPoint.y - textView.textContainerInset.height)
      let fragment = textLayoutManager.textLayoutFragment(for: point)
      if let fragment = fragment {
        point = NSMakePoint(point.x - NSMinX(fragment.layoutFragmentFrame),
                            point.y - NSMinY(fragment.layoutFragmentFrame))
        index = textLayoutManager.offset(from: textLayoutManager.documentRange.location, to: fragment.rangeInElement.location)
        for lineFragment in fragment.textLineFragments {
          if lineFragment.typographicBounds.contains(point) {
            point = NSMakePoint(point.x - NSMinX(lineFragment.typographicBounds),
                                point.y - NSMinY(lineFragment.typographicBounds))
            index += lineFragment.characterIndex(for: point)
            if index >= (preeditRange.location == NSNotFound ? 0 : preeditRange.upperBound) && index < preeditRange.upperBound {
              preeditIndex = index
            } else {
              for i in 0..<candidateRanges.count {
                let range = candidateRanges[i]
                if index >= range.location && index < range.upperBound {
                  candidateIndex = i
                  break
                }
              }
            }
            break
          }
        }
      }
    }
    return (candidateIndex, preeditIndex)
  }
}

private extension SquirrelView {
  // A tweaked sign function, to winddown corner radius when the size is small
  func sign(_ number: CGFloat) -> CGFloat {
    if number >= 2 {
      return 1
    } else if number <= -2 {
      return -1
    }else {
      return number / 2
    }
  }
  
  // Bezier cubic curve, which has continuous roundness
  func drawSmoothLines(_ vertex: Array<NSPoint>, straightCorner: Set<Int>, alpha: CGFloat, beta rawBeta: CGFloat) -> CGPath? {
    guard vertex.count >= 4 else {
      return nil
    }
    let beta = max(0.00001, rawBeta)
    let path = CGMutablePath()
    var previousPoint = vertex[vertex.count-1]
    var point = vertex[0]
    var nextPoint: NSPoint
    var control1: NSPoint
    var control2: NSPoint
    var target = previousPoint
    var diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y)
    if straightCorner.isEmpty || !straightCorner.contains(vertex.count-1) {
      target.x += sign(diff.x/beta)*beta
      target.y += sign(diff.y/beta)*beta
    }
    path.move(to: target)
    for i in 0..<vertex.count {
      previousPoint = vertex[(vertex.count+i-1)%vertex.count]
      point = vertex[i]
      nextPoint = vertex[(i+1)%vertex.count]
      target = point
      if straightCorner.contains(i) {
        path.addLine(to: target)
      } else {
        control1 = point
        diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y)
        
        target.x -= sign(diff.x/beta)*beta
        control1.x -= sign(diff.x/beta)*alpha
        target.y -= sign(diff.y/beta)*beta
        control1.y -= sign(diff.y/beta)*alpha
        
        path.addLine(to: target)
        target = point
        control2 = point
        diff = NSMakePoint(nextPoint.x - point.x, nextPoint.y - point.y)
        
        control2.x += sign(diff.x/beta)*alpha
        target.x += sign(diff.x/beta)*beta
        control2.y += sign(diff.y/beta)*alpha
        target.y += sign(diff.y/beta)*beta
        
        path.addCurve(to: target, control1: control1, control2: control2)
      }
    }
    path.closeSubpath()
    return path
  }
  
  func rectVertex(of rect: NSRect) -> Array<NSPoint> {
    [rect.origin,
     NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height),
     NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height),
     NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y)]
  }
  
  func nearEmpty(_ rect: NSRect) -> Bool {
    return rect.size.height * rect.size.width < 1
  }
  
  // Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
  // bodyRect is complete lines in the middle
  func multilineRects(forRange range: NSTextRange, extraSurounding: Double, bounds: NSRect) -> (NSRect, NSRect, NSRect) {
    let edgeInset = currentTheme.edgeInset
    var lineRects = [NSRect]()
    textLayoutManager.enumerateTextSegments(in: range, type: .standard, options: [.rangeNotRequired]) { _, rect, _, _ in
      var newRect = rect
      newRect.origin.x += edgeInset.width
      newRect.origin.y += edgeInset.height
      newRect.size.height += currentTheme.linespace
      newRect.origin.y -= currentTheme.linespace / 2
      lineRects.append(newRect)
      return true
    }
    
    var leadingRect = NSZeroRect
    var bodyRect = NSZeroRect
    var trailingRect = NSZeroRect
    if lineRects.count == 1 {
      bodyRect = lineRects[0]
    } else if lineRects.count == 2 {
      leadingRect = lineRects[0]
      trailingRect = lineRects[1]
    } else if lineRects.count > 2 {
      leadingRect = lineRects[0]
      trailingRect = lineRects[lineRects.count-1]
      var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
      for i in 1..<(lineRects.count-1) {
        let rect = lineRects[i]
        x0 = min(NSMinX(rect), x0)
        x1 = max(NSMaxX(rect), x1)
        y0 = min(NSMinY(rect), y0)
        y1 = max(NSMaxY(rect), y1)
      }
      y0 = min(NSMaxY(leadingRect), y0)
      y1 = max(NSMinY(trailingRect), y1)
      bodyRect = NSMakeRect(x0, y0, x1-x0, y1-y0)
    }
    
    if (extraSurounding > 0) {
      if nearEmpty(leadingRect) && nearEmpty(trailingRect) {
        bodyRect = expandHighlightWidth(rect: bodyRect, extraSurrounding: extraSurounding)
      } else {
        if !(nearEmpty(leadingRect)) {
          leadingRect = expandHighlightWidth(rect: leadingRect, extraSurrounding: extraSurounding)
        }
        if !(nearEmpty(trailingRect)) {
          trailingRect = expandHighlightWidth(rect: trailingRect, extraSurrounding: extraSurounding)
        }
      }
    }
    
    if !nearEmpty(leadingRect) && !nearEmpty(trailingRect) {
      leadingRect.size.width = NSMaxX(bounds) - leadingRect.origin.x
      trailingRect.size.width = NSMaxX(trailingRect) - NSMinX(bounds)
      trailingRect.origin.x = NSMinX(bounds)
      if !nearEmpty(bodyRect) {
        bodyRect.size.width = bounds.size.width
        bodyRect.origin.x = bounds.origin.x
      } else {
        let diff = NSMinY(trailingRect) - NSMaxY(leadingRect)
        leadingRect.size.height += diff / 2
        trailingRect.size.height += diff / 2
        trailingRect.origin.y -= diff / 2
      }
    }
    
    return (leadingRect, bodyRect, trailingRect)
  }
  
  // Based on the 3 boxes from multilineRectForRange, calculate the vertex of the polygon containing the text in range
  func multilineVertex(leadingRect: NSRect, bodyRect: NSRect, trailingRect: NSRect) -> Array<NSPoint> {
    if nearEmpty(bodyRect) && !nearEmpty(leadingRect) && nearEmpty(trailingRect) {
      return rectVertex(of: leadingRect)
    } else if nearEmpty(bodyRect) && nearEmpty(leadingRect) && !nearEmpty(trailingRect) {
      return rectVertex(of: trailingRect)
    } else if nearEmpty(leadingRect) && nearEmpty(trailingRect) && !nearEmpty(bodyRect) {
      return rectVertex(of: bodyRect)
    } else if nearEmpty(trailingRect) && !nearEmpty(bodyRect) {
      let leadingVertex = rectVertex(of: leadingRect)
      let bodyVertex = rectVertex(of: bodyRect)
      return [bodyVertex[0], bodyVertex[1], bodyVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1]]
    } else if nearEmpty(leadingRect) && !nearEmpty(bodyRect) {
      let trailingVertex = rectVertex(of: trailingRect)
      let bodyVertex = rectVertex(of: bodyRect)
      return [trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], bodyVertex[3], bodyVertex[0]]
    } else if !nearEmpty(leadingRect) && !nearEmpty(trailingRect) && nearEmpty(bodyRect) && (NSMaxX(leadingRect)>NSMinX(trailingRect)) {
      let leadingVertex = rectVertex(of: leadingRect)
      let trailingVertex = rectVertex(of: trailingRect)
      return [trailingVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1]]
    } else if !nearEmpty(leadingRect) && !nearEmpty(trailingRect) && !nearEmpty(bodyRect) {
      let leadingVertex = rectVertex(of: leadingRect)
      let bodyVertex = rectVertex(of: bodyRect)
      let trailingVertex = rectVertex(of: trailingRect)
      return [trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1], bodyVertex[0]]
    } else {
      return Array<NSPoint>()
    }
  }
  
  // If the point is outside the innerBox, will extend to reach the outerBox
  func expand(vertex: Array<NSPoint>, innerBorder: NSRect, outerBorder: NSRect) -> Array<NSPoint> {
    var newVertex = Array<NSPoint>()
    for i in 0..<vertex.count {
      var point = vertex[i]
      if point.x < innerBorder.origin.x {
        point.x = outerBorder.origin.x
      } else if point.x > innerBorder.origin.x+innerBorder.size.width {
        point.x = outerBorder.origin.x+outerBorder.size.width
      }
      if point.y < innerBorder.origin.y {
        point.y = outerBorder.origin.y
      } else if point.y > innerBorder.origin.y+innerBorder.size.height {
        point.y = outerBorder.origin.y+outerBorder.size.height
      }
      newVertex.append(point)
    }
    return newVertex
  }
  
  func direction(diff: CGPoint) -> CGPoint {
    if diff.y == 0 && diff.x > 0 {
      return NSMakePoint(0, 1)
    } else if diff.y == 0 && diff.x < 0 {
      return NSMakePoint(0, -1)
    } else if diff.x == 0 && diff.y > 0 {
      return NSMakePoint(-1, 0)
    } else if diff.x == 0 && diff.y < 0 {
      return NSMakePoint(1, 0)
    } else {
      return NSMakePoint(0, 0)
    }
  }
  
  func shapeFromPath(path: CGPath?) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.path = path
    layer.fillRule = .evenOdd
    return layer
  }
  
  // Assumes clockwise iteration
  func enlarge(vertex: Array<NSPoint>, by: Double) -> Array<NSPoint> {
    if by != 0 {
      var previousPoint: NSPoint
      var point: NSPoint
      var nextPoint: NSPoint
      var results = vertex
      var newPoint: NSPoint
      var displacement: NSPoint
      for i in 0..<vertex.count {
        previousPoint = vertex[(vertex.count+i-1) % vertex.count]
        point = vertex[i]
        nextPoint = vertex[(i+1) % vertex.count]
        newPoint = point
        displacement = direction(diff: NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y))
        newPoint.x += by * displacement.x
        newPoint.y += by * displacement.y
        displacement = direction(diff: NSMakePoint(nextPoint.x - point.x, nextPoint.y - point.y))
        newPoint.x += by * displacement.x
        newPoint.y += by * displacement.y
        results[i] = newPoint
      }
      return results
    } else {
      return vertex
    }
  }
  
  // Add gap between horizontal candidates
  func expandHighlightWidth(rect: NSRect, extraSurrounding: CGFloat) -> NSRect {
    var newRect = rect
    if !nearEmpty(newRect) {
      newRect.size.width += extraSurrounding
      newRect.origin.x -= extraSurrounding / 2
    }
    return newRect
  }
  
  func removeCorner(highlightedPoints: Array<CGPoint>, rightCorners: Set<Int>, containingRect: NSRect) -> Set<Int> {
    if !highlightedPoints.isEmpty && !rightCorners.isEmpty {
      var result = rightCorners
      for cornerIndex in rightCorners {
        let corner = highlightedPoints[cornerIndex]
        let dist = min(NSMaxY(containingRect) - corner.y, corner.y - NSMinY(containingRect))
        if dist < 1e-2 {
          result.remove(cornerIndex)
        }
      }
      return result
    } else {
      return rightCorners
    }
  }
  
  func linearMultilineFor(body: NSRect, leading: NSRect, trailing: NSRect) -> (Array<NSPoint>, Array<NSPoint>, Set<Int>, Set<Int>) {
    let highlightedPoints, highlightedPoints2: Array<NSPoint>
    let rightCorners, rightCorners2: Set<Int>
    // Handles the special case where containing boxes are separated
    if (nearEmpty(body) && !nearEmpty(leading) && !nearEmpty(trailing) && NSMaxX(trailing) < NSMinX(leading)) {
      highlightedPoints = rectVertex(of: leading)
      highlightedPoints2 = rectVertex(of: trailing)
      rightCorners = [2, 3]
      rightCorners2 = [0, 1]
    } else {
      highlightedPoints = multilineVertex(leadingRect: leading, bodyRect: body, trailingRect: trailing)
      highlightedPoints2 = []
      rightCorners = []
      rightCorners2 = []
    }
    return (highlightedPoints, highlightedPoints2, rightCorners, rightCorners2)
  }
  
  func drawPath(highlightedRange: NSRange, backgroundRect: NSRect, preeditRect: NSRect, containingRect: NSRect, extraExpansion: Double) -> CGPath? {
    let theme = currentTheme
    let resultingPath: CGMutablePath?
    
    var currentContainingRect = containingRect
    currentContainingRect.size.width += extraExpansion * 2
    currentContainingRect.size.height += extraExpansion * 2
    currentContainingRect.origin.x -= extraExpansion
    currentContainingRect.origin.y -= extraExpansion
    
    let halfLinespace = theme.linespace / 2
    var innerBox = backgroundRect
    innerBox.size.width -= (theme.edgeInset.width + 1) * 2 - 2 * extraExpansion
    innerBox.origin.x += theme.edgeInset.width + 1 - extraExpansion
    innerBox.size.height += 2 * extraExpansion
    innerBox.origin.y -= extraExpansion
    if preeditRange.length == 0 {
      innerBox.origin.y += theme.edgeInset.height + 1
      innerBox.size.height -= (theme.edgeInset.height + 1) * 2
    } else {
      innerBox.origin.y += preeditRect.size.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 1
      innerBox.size.height -= theme.edgeInset.height + preeditRect.size.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 2
    }
    innerBox.size.height -= theme.linespace
    innerBox.origin.y += halfLinespace
    
    var outerBox = backgroundRect
    outerBox.size.height -= preeditRect.size.height + max(0, theme.hilitedCornerRadius + theme.borderLineWidth) - 2 * extraExpansion
    outerBox.size.width -= max(0, theme.hilitedCornerRadius + theme.borderLineWidth)  - 2 * extraExpansion
    outerBox.origin.x += max(0.0, theme.hilitedCornerRadius + theme.borderLineWidth) / 2.0 - extraExpansion
    outerBox.origin.y += preeditRect.size.height + max(0, theme.hilitedCornerRadius + theme.borderLineWidth) / 2 - extraExpansion
    
    let effectiveRadius = max(0, theme.hilitedCornerRadius + 2 * extraExpansion / theme.hilitedCornerRadius * max(0, theme.cornerRadius - theme.hilitedCornerRadius))
    
    if theme.linear {
      let (leadingRect, bodyRect, trailingRect) = multilineRects(forRange: convert(range: highlightedRange), extraSurounding: separatorWidth, bounds: outerBox)
      
      var (highlightedPoints, highlightedPoints2, rightCorners, rightCorners2) = linearMultilineFor(body: bodyRect, leading: leadingRect, trailing: trailingRect)
      
      // Expand the boxes to reach proper border
      highlightedPoints = enlarge(vertex: highlightedPoints, by: extraExpansion)
      highlightedPoints = expand(vertex: highlightedPoints, innerBorder: innerBox, outerBorder: outerBox)
      rightCorners = removeCorner(highlightedPoints: highlightedPoints, rightCorners: rightCorners, containingRect: currentContainingRect)
      resultingPath = drawSmoothLines(highlightedPoints, straightCorner: rightCorners, alpha: 0.3*effectiveRadius, beta: 1.4*effectiveRadius)?.mutableCopy()
      
      if (highlightedPoints2.count > 0) {
        highlightedPoints2 = enlarge(vertex: highlightedPoints2, by: extraExpansion)
        highlightedPoints2 = expand(vertex: highlightedPoints2, innerBorder: innerBox, outerBorder: outerBox)
        rightCorners2 = removeCorner(highlightedPoints: highlightedPoints2, rightCorners: rightCorners2, containingRect: currentContainingRect)
        let highlightedPath2 = drawSmoothLines(highlightedPoints2, straightCorner: rightCorners2, alpha: 0.3*effectiveRadius, beta: 1.4*effectiveRadius)
        if let highlightedPath2 = highlightedPath2 {
          resultingPath?.addPath(highlightedPath2)
        }
      }
    } else {
      var highlightedRect = self.contentRect(range: convert(range: highlightedRange))
      if !nearEmpty(highlightedRect) {
        highlightedRect.size.width = backgroundRect.size.width
        highlightedRect.size.height += theme.linespace
        highlightedRect.origin = NSMakePoint(backgroundRect.origin.x, highlightedRect.origin.y + theme.edgeInset.height - halfLinespace)
        if highlightedRange.upperBound == (textView.string as NSString).length {
          highlightedRect.size.height += theme.edgeInset.height - halfLinespace
        }
        if highlightedRange.location - ((preeditRange.location == NSNotFound ? 0 : preeditRange.location) + preeditRange.length) <= 1 {
          if preeditRange.length == 0 {
            highlightedRect.size.height += theme.edgeInset.height - halfLinespace
            highlightedRect.origin.y -= theme.edgeInset.height - halfLinespace
          } else {
            highlightedRect.size.height += theme.hilitedCornerRadius / 2
            highlightedRect.origin.y -= theme.hilitedCornerRadius / 2
          }
        }
        
        var highlightedPoints = rectVertex(of: highlightedRect)
        highlightedPoints = enlarge(vertex: highlightedPoints, by: extraExpansion)
        highlightedPoints = expand(vertex: highlightedPoints, innerBorder: innerBox, outerBorder: outerBox)
        resultingPath = drawSmoothLines(highlightedPoints, straightCorner: Set(), alpha: effectiveRadius*0.3, beta: effectiveRadius*1.4)?.mutableCopy()
      } else {
        resultingPath = nil
      }
    }
    return resultingPath
  }
  
  func carveInset(rect: NSRect) -> NSRect {
    var newRect = rect
    newRect.size.height -= (currentTheme.hilitedCornerRadius + currentTheme.borderWidth) * 2
    newRect.size.width -= (currentTheme.hilitedCornerRadius + currentTheme.borderWidth) * 2
    newRect.origin.x += currentTheme.hilitedCornerRadius + currentTheme.borderWidth
    newRect.origin.y += currentTheme.hilitedCornerRadius + currentTheme.borderWidth
    return newRect
  }
}
