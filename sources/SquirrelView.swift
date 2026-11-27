//
//  SquirrelView.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

private class SquirrelLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
  func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, shouldBreakLineBefore location: any NSTextLocation, hyphenating: Bool) -> Bool {
    let index = textLayoutManager.offset(from: textLayoutManager.documentRange.location, to: location)
    if let attributes = textLayoutManager.textContainer?.textView?.textContentStorage?.attributedString?.attributes(at: index, effectiveRange: nil),
       let noBreak = attributes[.noBreak] as? Bool, noBreak {
      return false
    }
    return true
  }
}

extension NSAttributedString.Key {
  static let noBreak = NSAttributedString.Key("noBreak")
}

struct SquirrelGridCandidate {
  let globalIndex: Int
  let text: String
  let comment: String
}

struct SquirrelGridCell {
  let globalIndex: Int
  let row: Int
  let cellIndexInRow: Int
  let startCol: Int
  let colSpan: Int
  let text: String
  let comment: String
  var xOffset: CGFloat = 0
  var width: CGFloat = 0
  var frame: NSRect = .zero
  var attributedString: NSAttributedString = NSAttributedString()
  var highlightedAttributedString: NSAttributedString = NSAttributedString()
}

struct SquirrelGridRow {
  let rowIndex: Int
  var cells: [SquirrelGridCell]
  var frame: NSRect = .zero
}

struct SquirrelGridLayout {
  let compositionID: Int
  let isExpanded: Bool
  let showColumnHighlight: Bool
  let usePillTextMask: Bool
  let colWidths: [CGFloat]
  let colOriginsX: [CGFloat]
  let allRows: [SquirrelGridRow]
  let visibleRows: [SquirrelGridRow]
  let viewportTopRow: Int
  let activeRow: Int
  let activeCellIndexInRow: Int
  let hoveredGlobalIndex: Int?
  let hasMore: Bool
  let totalLoadedRows: Int
  let maxVisibleRows: Int
  let panelSize: NSSize
  let preeditAttributedString: NSAttributedString?
  let preeditRect: NSRect
  let preeditHighlightedRect: NSRect
  let gridContentRect: NSRect
  let rowDividerRects: [NSRect]
  let activeRowRect: NSRect
  let activeColumnRect: NSRect
  let activeCellRect: NSRect
  let hoveredCellRect: NSRect?
  let chevronDividerRect: NSRect?
  let expandButtonRect: NSRect?
  let scrollbarTrackRect: NSRect?
  let scrollbarThumbRect: NSRect?
  let cellPaddingX: CGFloat
}

enum SquirrelGridHitResult: Equatable {
  case candidate(globalIndex: Int, row: Int, cellIndexInRow: Int)
  case toggleExpand
  case preedit(characterIndex: Int)
  case none
}

enum SquirrelGridResizeAnchor {
  case top
  case bottom
}

struct SquirrelGridCellTransitionSpec {
  let cell: SquirrelGridCell
  let fromDeltaX: CGFloat
  let fadeIn: Bool
}

private final class FlippedClipView: NSView {
  override var isFlipped: Bool { true }
}

private final class SquirrelGridTransitionCellView: NSView {
  override var isFlipped: Bool { true }
  let attributedString: NSAttributedString
  let cellPaddingX: CGFloat

  init(frame: NSRect, attributedString: NSAttributedString, cellPaddingX: CGFloat) {
    self.attributedString = attributedString
    self.cellPaddingX = cellPaddingX
    super.init(frame: frame)
    self.wantsLayer = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_ dirtyRect: NSRect) {
    let textW = max(0, bounds.width - cellPaddingX * 2)
    let strSize = attributedString.size()
    let centeredY = max(0, (bounds.height - strSize.height) / 2)
    let drawRect = NSRect(x: cellPaddingX, y: centeredY, width: textW, height: strSize.height)
    attributedString.draw(with: drawRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
  }
}

final class SquirrelGridPillView: NSView {
  override var isFlipped: Bool { true }
}

final class SquirrelGridOverlayView: NSView {
  override var isFlipped: Bool {
    true
  }

  var drawsHighlightedText: Bool = false
  var gridLayout: SquirrelGridLayout?
  var theme: SquirrelTheme = SquirrelTheme()
  lazy var gridTextMaskLayer: CALayer = {
    let layer = CALayer()
    layer.backgroundColor = NSColor.black.cgColor
    layer.cornerCurve = .continuous
    return layer
  }()
  lazy var gridActiveTextMaskLayer: CALayer = {
    let layer = CALayer()
    layer.backgroundColor = NSColor.black.cgColor
    layer.cornerCurve = .continuous
    return layer
  }()
  private var hiddenTransitionGlobalIndices = Set<Int>()
  private var transitionClipView: FlippedClipView?
  private var transitionCleanupWorkItem: DispatchWorkItem?
  private var transitionGeneration: Int = 0

  func clearCellTransitions(redrawImmediately: Bool = false) {
    transitionGeneration &+= 1
    transitionCleanupWorkItem?.cancel()
    transitionCleanupWorkItem = nil
    let hadHidden = !hiddenTransitionGlobalIndices.isEmpty
    let hadClip = transitionClipView != nil
    guard hadHidden || hadClip else { return }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    hiddenTransitionGlobalIndices.removeAll()
    transitionClipView?.removeFromSuperview()
    transitionClipView = nil
    if hadHidden {
      needsDisplay = true
      if redrawImmediately {
        displayIfNeeded()
      }
    }
    CATransaction.commit()
  }

  func runCellTransitions(_ specs: [SquirrelGridCellTransitionSpec], clipRect: NSRect, cellPaddingX: CGFloat) {
    clearCellTransitions()
    guard !specs.isEmpty, !clipRect.isEmpty else { return }

    let clipView = FlippedClipView(frame: clipRect)
    clipView.wantsLayer = true
    clipView.layer?.masksToBounds = true
    addSubview(clipView)
    transitionClipView = clipView

    var hidden = Set<Int>()
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    for spec in specs {
      hidden.insert(spec.cell.globalIndex)
      let cellFrame = spec.cell.frame.offsetBy(dx: -clipRect.minX, dy: -clipRect.minY)
      let cellView = SquirrelGridTransitionCellView(
        frame: cellFrame,
        attributedString: drawsHighlightedText ? spec.cell.highlightedAttributedString : spec.cell.attributedString,
        cellPaddingX: cellPaddingX
      )
      clipView.addSubview(cellView)
      cellView.displayIfNeeded()

      if let layer = cellView.layer {
        layer.transform = CATransform3DIdentity
        layer.opacity = 1.0

        if abs(spec.fromDeltaX) > 0.5 {
          let slide = CASpringAnimation(keyPath: "transform.translation.x")
          slide.fromValue = spec.fromDeltaX
          slide.toValue = 0
          slide.stiffness = 480
          slide.damping = 36
          slide.mass = 0.85
          slide.duration = slide.settlingDuration
          layer.add(slide, forKey: "reflowSlideX")
        }

        if spec.fadeIn {
          let fade = CABasicAnimation(keyPath: "opacity")
          fade.fromValue = 0.0
          fade.toValue = 1.0
          fade.duration = 0.16
          fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
          layer.add(fade, forKey: "reflowFadeIn")
        }
      }
    }

    CATransaction.commit()

    hiddenTransitionGlobalIndices = hidden
    let gen = transitionGeneration
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.transitionGeneration == gen else { return }
      self.clearCellTransitions(redrawImmediately: true)
    }
    transitionCleanupWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let layout = gridLayout else { return }

    if !drawsHighlightedText {
      if let preeditAttr = layout.preeditAttributedString, !layout.preeditRect.isEmpty {
        preeditAttr.draw(with: layout.preeditRect, options: [.usesLineFragmentOrigin])
      }

      if !layout.rowDividerRects.isEmpty {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let dividerColor = NSColor.separatorColor.withAlphaComponent(isDark ? 0.24 : 0.16)
        dividerColor.setFill()
        for rect in layout.rowDividerRects {
          rect.fill()
        }
      }
    }

    for row in layout.visibleRows {
      for cell in row.cells {
        if hiddenTransitionGlobalIndices.contains(cell.globalIndex) {
          continue
        }
        let attrStr = drawsHighlightedText ? cell.highlightedAttributedString : cell.attributedString
        let textRect = NSRect(
          x: cell.frame.minX + layout.cellPaddingX,
          y: cell.frame.minY,
          width: max(0, cell.frame.width - layout.cellPaddingX * 2),
          height: cell.frame.height
        )
        let strSize = attrStr.size()
        let centeredY = textRect.minY + max(0, (textRect.height - strSize.height) / 2)
        let drawRect = NSRect(x: textRect.minX, y: centeredY, width: textRect.width, height: strSize.height)
        attrStr.draw(with: drawRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
      }
    }

    if !drawsHighlightedText, let trackRect = layout.scrollbarTrackRect, let thumbRect = layout.scrollbarThumbRect {
      let trackColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12)
      trackColor.setFill()
      NSBezierPath(roundedRect: trackRect, xRadius: trackRect.width / 2, yRadius: trackRect.width / 2).fill()

      let thumbColor = NSColor.secondaryLabelColor.withAlphaComponent(0.45)
      thumbColor.setFill()
      NSBezierPath(roundedRect: thumbRect, xRadius: thumbRect.width / 2, yRadius: thumbRect.width / 2).fill()
    }
  }
}

final class SquirrelView: NSView {
  static let gridShadowPadding: CGFloat = 16

  let textView: NSTextView
  let gridOverlayView: SquirrelGridOverlayView
  let gridActivePillView: SquirrelGridPillView
  let gridHighlightOverlayView: SquirrelGridOverlayView
  var gridLayout: SquirrelGridLayout?
  var gridContentOrigin = NSPoint(x: SquirrelView.gridShadowPadding, y: SquirrelView.gridShadowPadding)

  private var gridRootLayer: CALayer?
  private lazy var gridShadowLayer = CALayer()
  private lazy var gridCardClipLayer = CALayer()
  private lazy var gridPreeditBgLayer = CALayer()
  private lazy var gridPreeditHighlightLayer = CALayer()
  private lazy var gridColumnLayer = CALayer()
  private lazy var gridHoverLayer = CALayer()
  private lazy var gridActiveCellLayer = CALayer()
  private lazy var gridFallbackActiveCellLayer = CALayer()
  private lazy var gridActiveRowBorderLayer = CALayer()
  private lazy var gridDividerLayer = CALayer()
  private lazy var gridChevronLayer = CAShapeLayer()
  private var lastGridCompositionID: Int?
  private var lastGridExpanded = false
  private var lastGridViewportTopRow = 0
  private var lastGridCardSize: NSSize = .zero
  private var lastGridRow0Cells: [SquirrelGridCell] = []

  private let squirrelLayoutDelegate: SquirrelLayoutDelegate
  var candidateRanges: [NSRange] = []
  var hilightedIndex = 0
  var preeditRange: NSRange = .empty
  var canPageUp: Bool = false
  var canPageDown: Bool = false
  var highlightedPreeditRange: NSRange = .empty
  var separatorWidth: CGFloat = 0
  var shape = CAShapeLayer()
  private var downPath: CGPath?
  private var upPath: CGPath?

  var lightTheme = SquirrelTheme()
  var darkTheme = SquirrelTheme()
  var currentTheme: SquirrelTheme {
    if isDark && darkTheme.available { darkTheme } else { lightTheme }
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
    squirrelLayoutDelegate = SquirrelLayoutDelegate()
    textView = NSTextView(frame: frameRect)
    textView.drawsBackground = false
    textView.isEditable = false
    textView.isSelectable = false
    textView.textLayoutManager?.delegate = squirrelLayoutDelegate
    gridOverlayView = SquirrelGridOverlayView(frame: frameRect)
    gridOverlayView.wantsLayer = true
    gridOverlayView.layerContentsRedrawPolicy = .onSetNeedsDisplay
    gridOverlayView.isHidden = true
    gridActivePillView = SquirrelGridPillView(frame: frameRect)
    gridActivePillView.wantsLayer = true
    gridActivePillView.isHidden = true
    gridHighlightOverlayView = SquirrelGridOverlayView(frame: frameRect)
    gridHighlightOverlayView.drawsHighlightedText = true
    gridHighlightOverlayView.wantsLayer = true
    gridHighlightOverlayView.layerContentsRedrawPolicy = .onSetNeedsDisplay
    gridHighlightOverlayView.isHidden = true
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

  func convert(range: NSRange) -> NSTextRange? {
    guard range != .empty else { return nil }
    guard let startLocation = textLayoutManager.location(textLayoutManager.documentRange.location, offsetBy: range.location) else { return nil }
    guard let endLocation = textLayoutManager.location(startLocation, offsetBy: range.length) else { return nil }
    return NSTextRange(location: startLocation, end: endLocation)
  }

  var contentRect: NSRect {
    var ranges = candidateRanges
    if preeditRange.length > 0 {
      ranges.append(preeditRange)
    }
    // swiftlint:disable:next identifier_name
    var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
    for range in ranges {
      if let textRange = convert(range: range) {
        let rect = contentRect(range: textRange)
        x0 = min(rect.minX, x0)
        x1 = max(rect.maxX, x1)
        y0 = min(rect.minY, y0)
        y1 = max(rect.maxY, y1)
      }
    }
    if x1 == -CGFloat.infinity { return .zero }
    return NSRect(x: min(0, x0), y: min(0, y0), width: x1 - min(0, x0), height: y1 - min(0, y0))
  }

  func contentRect(range: NSTextRange) -> NSRect {
    // swiftlint:disable:next identifier_name
    var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
    textLayoutManager.enumerateTextSegments(in: range, type: .selection, options: [.rangeNotRequired]) { _, rect, _, _ in
      x0 = min(rect.minX, x0)
      x1 = max(rect.maxX, x1)
      y0 = min(rect.minY, y0)
      y1 = max(rect.maxY, y1)
      return true
    }
    return NSRect(x: x0, y: y0, width: x1-x0, height: y1-y0)
  }

  // swiftlint:disable:next function_parameter_count
  func drawView(candidateRanges: [NSRange], hilightedIndex: Int, preeditRange: NSRange, highlightedPreeditRange: NSRange, canPageUp: Bool, canPageDown: Bool) {
    self.gridLayout = nil
    self.gridOverlayView.gridLayout = nil
    self.gridOverlayView.layer?.mask = nil
    self.gridHighlightOverlayView.gridLayout = nil
    self.gridHighlightOverlayView.layer?.mask = nil
    self.gridRootLayer?.removeFromSuperlayer()
    self.gridRootLayer = nil
    self.lastGridCompositionID = nil
    self.lastGridCardSize = .zero
    self.textView.isHidden = false
    self.gridOverlayView.isHidden = true
    self.gridActivePillView.isHidden = true
    self.gridHighlightOverlayView.isHidden = true
    self.candidateRanges = candidateRanges
    self.hilightedIndex = hilightedIndex
    self.preeditRange = preeditRange
    self.highlightedPreeditRange = highlightedPreeditRange
    self.canPageUp = canPageUp
    self.canPageDown = canPageDown
    self.needsDisplay = true
  }

  func resetGridAnimationState() {
    lastGridCompositionID = nil
    lastGridExpanded = false
    lastGridViewportTopRow = 0
    lastGridCardSize = .zero
    lastGridRow0Cells = []
    gridOverlayView.clearCellTransitions()
    gridHighlightOverlayView.clearCellTransitions()
  }

  func drawGrid(_ layout: SquirrelGridLayout, resizeAnchor: SquirrelGridResizeAnchor = .top) {
    self.gridLayout = layout
    self.gridOverlayView.gridLayout = layout
    self.gridOverlayView.theme = currentTheme
    self.gridHighlightOverlayView.gridLayout = layout
    self.gridHighlightOverlayView.theme = currentTheme
    self.textView.isHidden = true
    self.gridOverlayView.isHidden = false
    self.gridOverlayView.clearCellTransitions(redrawImmediately: false)
    self.gridHighlightOverlayView.clearCellTransitions(redrawImmediately: false)
    updateGridLayers(layout, resizeAnchor: resizeAnchor)
    self.gridOverlayView.needsDisplay = true
    self.gridOverlayView.displayIfNeeded()
    if !self.gridHighlightOverlayView.isHidden {
      self.gridHighlightOverlayView.needsDisplay = true
      self.gridHighlightOverlayView.displayIfNeeded()
    }
  }

  func gridHitTest(at point: NSPoint) -> SquirrelGridHitResult {
    guard let layout = gridLayout else { return .none }
    let localPoint = NSPoint(x: point.x - gridContentOrigin.x, y: point.y - gridContentOrigin.y)
    if let buttonRect = layout.expandButtonRect, buttonRect.contains(localPoint) {
      return .toggleExpand
    }
    for row in layout.visibleRows {
      for cell in row.cells where cell.frame.contains(localPoint) {
        return .candidate(globalIndex: cell.globalIndex, row: row.rowIndex, cellIndexInRow: cell.cellIndexInRow)
      }
    }
    if let preeditAttr = layout.preeditAttributedString, !layout.preeditRect.isEmpty, layout.preeditRect.contains(localPoint) {
      let ratio = max(0, min(1, (localPoint.x - layout.preeditRect.minX) / max(1, layout.preeditRect.width)))
      let charIdx = Int(round(ratio * CGFloat(preeditAttr.length)))
      return .preedit(characterIndex: charIdx)
    }
    return .none
  }

  // swiftlint:disable:next cyclomatic_complexity
  override func draw(_ dirtyRect: NSRect) {
    if gridLayout != nil {
      return
    }
    var backgroundPath: CGPath?
    var preeditPath: CGPath?
    var candidatePaths: CGMutablePath?
    var highlightedPath: CGMutablePath?
    var highlightedPreeditPath: CGMutablePath?
    let theme = currentTheme

    var containingRect = self.bounds
    containingRect.size.width -= theme.pagingOffset
    let backgroundRect = containingRect

    var preeditRect = NSRect.zero
    if preeditRange.length > 0, let preeditTextRange = convert(range: preeditRange) {
      preeditRect = contentRect(range: preeditTextRange)
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
    for i in 0..<candidateRanges.count {
      let candidate = candidateRanges[i]
      if i == hilightedIndex {
        if candidate.length > 0 && theme.highlightedBackColor != nil {
          highlightedPath = drawPath(highlightedRange: candidate, backgroundRect: backgroundRect, preeditRect: preeditRect, containingRect: containingRect, extraExpansion: 0)?.mutableCopy()
        }
      } else {
        if candidate.length > 0 && theme.candidateBackColor != nil {
          let candidatePath = drawPath(highlightedRange: candidate, backgroundRect: backgroundRect, preeditRect: preeditRect,
                                       containingRect: containingRect, extraExpansion: theme.surroundingExtraExpansion)
          if candidatePaths == nil {
            candidatePaths = CGMutablePath()
          }
          if let candidatePath = candidatePath {
            candidatePaths?.addPath(candidatePath)
          }
        }
      }
    }

    if (highlightedPreeditRange.length > 0) && (theme.highlightedPreeditColor != nil), let highlightedPreeditTextRange = convert(range: highlightedPreeditRange) {
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

      let (leadingRect, bodyRect, trailingRect) = multilineRects(forRange: highlightedPreeditTextRange, extraSurounding: 0, bounds: outerBox)
      var (highlightedPoints, highlightedPoints2, rightCorners, rightCorners2) = linearMultilineFor(body: bodyRect, leading: leadingRect, trailing: trailingRect)

      containingRect = carveInset(rect: preeditRect)
      highlightedPoints = expand(vertex: highlightedPoints, innerBorder: innerBox, outerBorder: outerBox)
      rightCorners = removeCorner(highlightedPoints: highlightedPoints, rightCorners: rightCorners, containingRect: containingRect)
      highlightedPreeditPath = drawSmoothLines(highlightedPoints, straightCorner: rightCorners, alpha: 0.3 * theme.hilitedCornerRadius, beta: 1.4 * theme.hilitedCornerRadius)?.mutableCopy()
      if highlightedPoints2.count > 0 {
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
        shadowLayer.shadowOffset = NSSize(width: theme.shadowSize/2, height: (theme.vertical ? -1 : 1) * theme.shadowSize/2)
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
    panelLayer.setAffineTransform(CGAffineTransform(translationX: theme.pagingOffset, y: 0))
    let panelPath = CGMutablePath()
    panelPath.addPath(backgroundPath!, transform: panelLayer.affineTransform().scaledBy(x: 1, y: -1).translatedBy(x: 0, y: -self.bounds.height))

    let (pagingLayer, downPath, upPath) = pagingLayer(theme: theme, preeditRect: preeditRect)
    if let sublayers = pagingLayer.sublayers, !sublayers.isEmpty {
      self.layer?.addSublayer(pagingLayer)
    }
    self.downPath = downPath?.copy()
    self.upPath = upPath?.copy()
    let flipTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.bounds.height)
    if let downPath {
      panelPath.addPath(downPath, transform: flipTransform)
    }
    if let upPath {
      panelPath.addPath(upPath, transform: flipTransform)
    }

    shape.path = panelPath
  }

  func click(at clickPoint: NSPoint) -> (Int?, Int?, Bool?) {
    var index = 0
    var candidateIndex: Int?
    var preeditIndex: Int?
    if let downPath = self.downPath, downPath.contains(clickPoint) {
      return (nil, nil, false)
    }
    if let upPath = self.upPath, upPath.contains(clickPoint) {
      return (nil, nil, true)
    }
    if let path = shape.path, path.contains(clickPoint) {
      var point = NSPoint(x: clickPoint.x - textView.textContainerInset.width - currentTheme.pagingOffset,
                          y: clickPoint.y - textView.textContainerInset.height)
      let fragment = textLayoutManager.textLayoutFragment(for: point)
      if let fragment = fragment {
        point = NSPoint(x: point.x - fragment.layoutFragmentFrame.minX,
                        y: point.y - fragment.layoutFragmentFrame.minY)
        index = textLayoutManager.offset(from: textLayoutManager.documentRange.location, to: fragment.rangeInElement.location)
        for lineFragment in fragment.textLineFragments where lineFragment.typographicBounds.contains(point) {
          point = NSPoint(x: point.x - lineFragment.typographicBounds.minX,
                          y: point.y - lineFragment.typographicBounds.minY)
          index += lineFragment.characterIndex(for: point)
          if index >= preeditRange.location && index < preeditRange.upperBound {
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
    return (candidateIndex, preeditIndex, nil)
  }
}

private extension SquirrelView {
  // Soften corner radius when adjacent points are very close.
  func sign(_ number: NSPoint) -> NSPoint {
    if number.length >= 2 {
      return number / number.length
    } else {
      return number / 2
    }
  }

  // Use cubic Bezier corners for continuous rounded paths.
  func drawSmoothLines(_ vertex: [NSPoint], straightCorner: Set<Int>, alpha: CGFloat, beta rawBeta: CGFloat) -> CGPath? {
    guard vertex.count >= 3 else {
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
    var diff = point - previousPoint
    if straightCorner.isEmpty || !straightCorner.contains(vertex.count-1) {
      target += sign(diff / beta) * beta
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
        diff = point - previousPoint

        target -= sign(diff / beta) * beta
        control1 -= sign(diff / beta) * alpha

        path.addLine(to: target)
        target = point
        control2 = point
        diff = nextPoint - point

        target += sign(diff / beta) * beta
        control2 += sign(diff / beta) * alpha

        path.addCurve(to: target, control1: control1, control2: control2)
      }
    }
    path.closeSubpath()
    return path
  }

  func rectVertex(of rect: NSRect) -> [NSPoint] {
    [rect.origin,
     NSPoint(x: rect.origin.x, y: rect.origin.y+rect.size.height),
     NSPoint(x: rect.origin.x+rect.size.width, y: rect.origin.y+rect.size.height),
     NSPoint(x: rect.origin.x+rect.size.width, y: rect.origin.y)]
  }

  func nearEmpty(_ rect: NSRect) -> Bool {
    return rect.size.height * rect.size.width < 1
  }

  // Split a multiline range into leading, complete-body, and trailing boxes.
  func multilineRects(forRange range: NSTextRange, extraSurounding: Double, bounds: NSRect) -> (NSRect, NSRect, NSRect) {
    let edgeInset = currentTheme.edgeInset
    var lineRects = [NSRect]()
    textLayoutManager.enumerateTextSegments(in: range, type: .selection, options: [.rangeNotRequired]) { _, rect, _, _ in
      var newRect = rect
      newRect.origin.x += edgeInset.width
      newRect.origin.y += edgeInset.height
      newRect.size.height += currentTheme.linespace
      newRect.origin.y -= currentTheme.linespace / 2
      lineRects.append(newRect)
      return true
    }

    var leadingRect = NSRect.zero
    var bodyRect = NSRect.zero
    var trailingRect = NSRect.zero
    if lineRects.count == 1 {
      bodyRect = lineRects[0]
    } else if lineRects.count == 2 {
      leadingRect = lineRects[0]
      trailingRect = lineRects[1]
    } else if lineRects.count > 2 {
      leadingRect = lineRects[0]
      trailingRect = lineRects[lineRects.count-1]
      // swiftlint:disable:next identifier_name
      var x0 = CGFloat.infinity, x1 = -CGFloat.infinity, y0 = CGFloat.infinity, y1 = -CGFloat.infinity
      for i in 1..<(lineRects.count-1) {
        let rect = lineRects[i]
        x0 = min(rect.minX, x0)
        x1 = max(rect.maxX, x1)
        y0 = min(rect.minY, y0)
        y1 = max(rect.maxY, y1)
      }
      y0 = min(leadingRect.maxY, y0)
      y1 = max(trailingRect.minY, y1)
      bodyRect = NSRect(x: x0, y: y0, width: x1-x0, height: y1-y0)
    }

    if extraSurounding > 0 {
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
      leadingRect.size.width = bounds.maxX - leadingRect.origin.x
      trailingRect.size.width = trailingRect.maxX - bounds.minX
      trailingRect.origin.x = bounds.minX
      if !nearEmpty(bodyRect) {
        bodyRect.size.width = bounds.size.width
        bodyRect.origin.x = bounds.origin.x
      } else {
        let diff = trailingRect.minY - leadingRect.maxY
        leadingRect.size.height += diff / 2
        trailingRect.size.height += diff / 2
        trailingRect.origin.y -= diff / 2
      }
    }

    return (leadingRect, bodyRect, trailingRect)
  }

  // Build the highlight polygon from the multiline text boxes.
  func multilineVertex(leadingRect: NSRect, bodyRect: NSRect, trailingRect: NSRect) -> [NSPoint] {
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
    } else if !nearEmpty(leadingRect) && !nearEmpty(trailingRect) && nearEmpty(bodyRect) && (leadingRect.maxX>trailingRect.minX) {
      let leadingVertex = rectVertex(of: leadingRect)
      let trailingVertex = rectVertex(of: trailingRect)
      return [trailingVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1]]
    } else if !nearEmpty(leadingRect) && !nearEmpty(trailingRect) && !nearEmpty(bodyRect) {
      let leadingVertex = rectVertex(of: leadingRect)
      let bodyVertex = rectVertex(of: bodyRect)
      let trailingVertex = rectVertex(of: trailingRect)
      return [trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1], bodyVertex[0]]
    } else {
      return [NSPoint]()
    }
  }

  // Clamp points outside the inner border to the outer border.
  func expand(vertex: [NSPoint], innerBorder: NSRect, outerBorder: NSRect) -> [NSPoint] {
    var newVertex = [NSPoint]()
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
      return NSPoint(x: 0, y: 1)
    } else if diff.y == 0 && diff.x < 0 {
      return NSPoint(x: 0, y: -1)
    } else if diff.x == 0 && diff.y > 0 {
      return NSPoint(x: -1, y: 0)
    } else if diff.x == 0 && diff.y < 0 {
      return NSPoint(x: 1, y: 0)
    } else {
      return NSPoint(x: 0, y: 0)
    }
  }

  func shapeFromPath(path: CGPath?) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.path = path
    layer.fillRule = .evenOdd
    return layer
  }

  // Assumes clockwise iteration
  func enlarge(vertex: [NSPoint], by: Double) -> [NSPoint] {
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
        displacement = direction(diff: point - previousPoint)
        newPoint.x += by * displacement.x
        newPoint.y += by * displacement.y
        displacement = direction(diff: nextPoint - point)
        newPoint.x += by * displacement.x
        newPoint.y += by * displacement.y
        results[i] = newPoint
      }
      return results
    } else {
      return vertex
    }
  }

  func expandHighlightWidth(rect: NSRect, extraSurrounding: CGFloat) -> NSRect {
    var newRect = rect
    if !nearEmpty(newRect) {
      newRect.size.width += extraSurrounding
      newRect.origin.x -= extraSurrounding / 2
    }
    return newRect
  }

  func removeCorner(highlightedPoints: [CGPoint], rightCorners: Set<Int>, containingRect: NSRect) -> Set<Int> {
    if !highlightedPoints.isEmpty && !rightCorners.isEmpty {
      var result = rightCorners
      for cornerIndex in rightCorners {
        let corner = highlightedPoints[cornerIndex]
        let dist = min(containingRect.maxY - corner.y, corner.y - containingRect.minY)
        if dist < 1e-2 {
          result.remove(cornerIndex)
        }
      }
      return result
    } else {
      return rightCorners
    }
  }

  // swiftlint:disable:next large_tuple
  func linearMultilineFor(body: NSRect, leading: NSRect, trailing: NSRect) -> (Array<NSPoint>, Array<NSPoint>, Set<Int>, Set<Int>) {
    let highlightedPoints, highlightedPoints2: [NSPoint]
    let rightCorners, rightCorners2: Set<Int>
    if nearEmpty(body) && !nearEmpty(leading) && !nearEmpty(trailing) && trailing.maxX < leading.minX {
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

    if theme.linear, let highlightedTextRange = convert(range: highlightedRange) {
      let (leadingRect, bodyRect, trailingRect) = multilineRects(forRange: highlightedTextRange, extraSurounding: separatorWidth, bounds: outerBox)
      var (highlightedPoints, highlightedPoints2, rightCorners, rightCorners2) = linearMultilineFor(body: bodyRect, leading: leadingRect, trailing: trailingRect)

      highlightedPoints = enlarge(vertex: highlightedPoints, by: extraExpansion)
      highlightedPoints = expand(vertex: highlightedPoints, innerBorder: innerBox, outerBorder: outerBox)
      rightCorners = removeCorner(highlightedPoints: highlightedPoints, rightCorners: rightCorners, containingRect: currentContainingRect)
      resultingPath = drawSmoothLines(highlightedPoints, straightCorner: rightCorners, alpha: 0.3*effectiveRadius, beta: 1.4*effectiveRadius)?.mutableCopy()

      if highlightedPoints2.count > 0 {
        highlightedPoints2 = enlarge(vertex: highlightedPoints2, by: extraExpansion)
        highlightedPoints2 = expand(vertex: highlightedPoints2, innerBorder: innerBox, outerBorder: outerBox)
        rightCorners2 = removeCorner(highlightedPoints: highlightedPoints2, rightCorners: rightCorners2, containingRect: currentContainingRect)
        let highlightedPath2 = drawSmoothLines(highlightedPoints2, straightCorner: rightCorners2, alpha: 0.3*effectiveRadius, beta: 1.4*effectiveRadius)
        if let highlightedPath2 = highlightedPath2 {
          resultingPath?.addPath(highlightedPath2)
        }
      }
    } else if let highlightedTextRange = convert(range: highlightedRange) {
      var highlightedRect = self.contentRect(range: highlightedTextRange)
      if !nearEmpty(highlightedRect) {
        highlightedRect.size.width = backgroundRect.size.width
        highlightedRect.size.height += theme.linespace
        highlightedRect.origin = NSPoint(x: backgroundRect.origin.x, y: highlightedRect.origin.y + theme.edgeInset.height - halfLinespace)
        if highlightedRange.upperBound == (textView.string as NSString).length {
          highlightedRect.size.height += theme.edgeInset.height - halfLinespace
        }
        if highlightedRange.location - (preeditRange == .empty ? 0 : preeditRange.upperBound) <= 1 {
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
    } else {
      resultingPath = nil
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

  func triangle(center: NSPoint, radius: CGFloat) -> [NSPoint] {
    [NSPoint(x: center.x, y: center.y + radius),
     NSPoint(x: center.x + 0.5 * sqrt(3) * radius, y: center.y - 0.5 * radius),
     NSPoint(x: center.x - 0.5 * sqrt(3) * radius, y: center.y - 0.5 * radius)]
  }

  func pagingLayer(theme: SquirrelTheme, preeditRect: CGRect) -> (CAShapeLayer, CGPath?, CGPath?) {
    let layer = CAShapeLayer()
    guard theme.showPaging && (canPageUp || canPageDown) else { return (layer, nil, nil) }
    guard let firstCandidate = candidateRanges.first, let range = convert(range: firstCandidate) else { return (layer, nil, nil) }
    var height = contentRect(range: range).height
    let preeditHeight = max(0, preeditRect.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 - theme.edgeInset.height) + theme.edgeInset.height - theme.linespace / 2
    height += theme.linespace
    let radius = min(0.5 * theme.pagingOffset, 2 * height / 9)
    let effectiveRadius = min(theme.cornerRadius, 0.6 * radius)
    guard let trianglePath = drawSmoothLines(
      triangle(center: .zero, radius: radius),
      straightCorner: [], alpha: 0.3 * effectiveRadius, beta: 1.4 * effectiveRadius
    ) else {
      return (layer, nil, nil)
    }
    var downPath: CGPath?
    var upPath: CGPath?
    if canPageDown {
      var downTransform = CGAffineTransform(translationX: 0.5 * theme.pagingOffset, y: 2 * height / 3 + preeditHeight)
      let downLayer = shapeFromPath(path: trianglePath.copy(using: &downTransform))
      downLayer.fillColor = theme.backgroundColor.cgColor
      downPath = trianglePath.copy(using: &downTransform)
      layer.addSublayer(downLayer)
    }
    if canPageUp {
      var upTransform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -0.5 * theme.pagingOffset, y: -height / 3 - preeditHeight)
      let upLayer = shapeFromPath(path: trianglePath.copy(using: &upTransform))
      upLayer.fillColor = theme.backgroundColor.cgColor
      upPath = trianglePath.copy(using: &upTransform)
      layer.addSublayer(upLayer)
    }
    return (layer, downPath, upPath)
  }

  func ensureGridRootLayer() -> CALayer {
    if let existing = gridRootLayer {
      return existing
    }
    self.layer?.sublayers = nil
    let root = CALayer()
    gridShadowLayer.cornerCurve = .continuous
    gridShadowLayer.masksToBounds = false
    gridShadowLayer.shadowColor = NSColor.black.cgColor
    gridShadowLayer.shadowRadius = 10
    gridShadowLayer.shadowOffset = CGSize(width: 0, height: 3)

    gridCardClipLayer.cornerCurve = .continuous
    gridCardClipLayer.masksToBounds = true
    gridColumnLayer.cornerCurve = .continuous
    gridHoverLayer.cornerCurve = .continuous
    gridActiveCellLayer.cornerCurve = .continuous
    gridFallbackActiveCellLayer.cornerCurve = .continuous
    gridActiveRowBorderLayer.cornerCurve = .continuous
    gridActiveRowBorderLayer.backgroundColor = nil
    gridActiveRowBorderLayer.borderWidth = 1.5
    gridChevronLayer.fillColor = nil
    gridChevronLayer.lineCap = .round
    gridChevronLayer.lineJoin = .round
    gridChevronLayer.lineWidth = 1.4

    gridCardClipLayer.addSublayer(gridPreeditBgLayer)
    gridCardClipLayer.addSublayer(gridPreeditHighlightLayer)
    gridCardClipLayer.addSublayer(gridColumnLayer)
    gridCardClipLayer.addSublayer(gridActiveRowBorderLayer)
    gridCardClipLayer.addSublayer(gridHoverLayer)
    gridCardClipLayer.addSublayer(gridFallbackActiveCellLayer)
    gridCardClipLayer.addSublayer(gridDividerLayer)
    gridCardClipLayer.addSublayer(gridChevronLayer)
    root.addSublayer(gridShadowLayer)
    root.addSublayer(gridCardClipLayer)
    self.layer?.addSublayer(root)
    gridRootLayer = root
    return root
  }

  func applyBoxRect(_ targetRect: NSRect, from fromRect: NSRect?, to layer: CALayer, cornerRadius: CGFloat, animated: Bool, useEaseOut: Bool = false) {
    let targetBounds = NSRect(origin: .zero, size: targetRect.size)
    let targetPos = NSPoint(x: targetRect.midX, y: targetRect.midY)
    layer.cornerRadius = cornerRadius
    layer.cornerCurve = .continuous
    layer.bounds = targetBounds
    layer.position = targetPos

    if animated, let fromRect, (fromRect.size != targetRect.size || fromRect.origin != targetRect.origin) {
      let fromBounds = NSRect(origin: .zero, size: fromRect.size)
      let fromPos = NSPoint(x: fromRect.midX, y: fromRect.midY)

      if useEaseOut {
        let timing = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        let posAnim = CABasicAnimation(keyPath: "position")
        posAnim.fromValue = NSValue(point: fromPos)
        posAnim.toValue = NSValue(point: targetPos)
        posAnim.duration = 0.22
        posAnim.timingFunction = timing

        let boundsAnim = CABasicAnimation(keyPath: "bounds")
        boundsAnim.fromValue = NSValue(rect: fromBounds)
        boundsAnim.toValue = NSValue(rect: targetBounds)
        boundsAnim.duration = 0.22
        boundsAnim.timingFunction = timing

        layer.add(posAnim, forKey: "position")
        layer.add(boundsAnim, forKey: "bounds")
      } else {
        let springPos = CASpringAnimation(keyPath: "position")
        springPos.fromValue = NSValue(point: fromPos)
        springPos.toValue = NSValue(point: targetPos)
        springPos.stiffness = 420
        springPos.damping = 32
        springPos.mass = 0.85
        springPos.duration = springPos.settlingDuration

        let springBounds = CASpringAnimation(keyPath: "bounds")
        springBounds.fromValue = NSValue(rect: fromBounds)
        springBounds.toValue = NSValue(rect: targetBounds)
        springBounds.stiffness = 420
        springBounds.damping = 32
        springBounds.mass = 0.85
        springBounds.duration = springBounds.settlingDuration

        layer.add(springPos, forKey: "position")
        layer.add(springBounds, forKey: "bounds")
      }
    } else {
      layer.removeAnimation(forKey: "position")
      layer.removeAnimation(forKey: "bounds")
    }
  }

  func applyAnimatedRect(_ rect: NSRect, to layer: CALayer, cornerRadius: CGFloat, animated: Bool) {
    let fromBounds = layer.presentation()?.bounds ?? layer.bounds
    let fromPos = layer.presentation()?.position ?? layer.position
    let targetBounds = NSRect(origin: .zero, size: rect.size)
    let targetPos = NSPoint(x: rect.midX, y: rect.midY)

    layer.cornerRadius = cornerRadius
    layer.bounds = targetBounds
    layer.position = targetPos

    if animated && !fromBounds.isEmpty && (fromBounds.size != targetBounds.size || fromPos != targetPos) {
      let springPos = CASpringAnimation(keyPath: "position")
      springPos.fromValue = NSValue(point: fromPos)
      springPos.toValue = NSValue(point: targetPos)
      springPos.stiffness = 560
      springPos.damping = 38
      springPos.mass = 0.85
      springPos.duration = springPos.settlingDuration

      let springBounds = CASpringAnimation(keyPath: "bounds")
      springBounds.fromValue = NSValue(rect: fromBounds)
      springBounds.toValue = NSValue(rect: targetBounds)
      springBounds.stiffness = 560
      springBounds.damping = 38
      springBounds.mass = 0.85
      springBounds.duration = springBounds.settlingDuration

      layer.add(springPos, forKey: "position")
      layer.add(springBounds, forKey: "bounds")
    } else {
      layer.removeAnimation(forKey: "position")
      layer.removeAnimation(forKey: "bounds")
    }
  }

  func applyOpacity(_ target: Float, to layer: CALayer, animated: Bool, duration: CFTimeInterval = 0.12) {
    let fromOpacity = layer.presentation()?.opacity ?? layer.opacity
    layer.opacity = target
    if animated && abs(fromOpacity - target) > 0.01 {
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = fromOpacity
      fade.toValue = target
      fade.duration = duration
      fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
      layer.add(fade, forKey: "opacity")
    } else {
      layer.removeAnimation(forKey: "opacity")
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func updateGridLayers(_ layout: SquirrelGridLayout, resizeAnchor: SquirrelGridResizeAnchor) {
    let theme = currentTheme
    let targetCardRect = NSRect(origin: gridContentOrigin, size: layout.panelSize)

    let shouldAnimate = theme.gridAnimation && (lastGridCompositionID == layout.compositionID)
    let expandChanged = layout.isExpanded != lastGridExpanded
    let sizeChanged = lastGridCardSize != .zero && lastGridCardSize != layout.panelSize

    var fromCardRect: NSRect?
    if shouldAnimate && sizeChanged {
      switch resizeAnchor {
      case .top:
        fromCardRect = NSRect(
          x: gridContentOrigin.x,
          y: gridContentOrigin.y,
          width: lastGridCardSize.width,
          height: lastGridCardSize.height
        )
      case .bottom:
        fromCardRect = NSRect(
          x: gridContentOrigin.x,
          y: gridContentOrigin.y + (layout.panelSize.height - lastGridCardSize.height),
          width: lastGridCardSize.width,
          height: lastGridCardSize.height
        )
      }
    }

    self.effectiveAppearance.performAsCurrentDrawingAppearance {
      CATransaction.begin()
      CATransaction.setDisableActions(true)

    let root = ensureGridRootLayer()
    root.frame = self.bounds

    let bgStyle = theme.resolvedGridBackgroundStyle
    let cardCornerRadius = theme.resolvedGridCornerRadius
    let useSmoothEase = (bgStyle == .glass || bgStyle == .blur)

    switch bgStyle {
    case .glass, .auto:
      gridShadowLayer.isHidden = true
      gridShadowLayer.removeAnimation(forKey: "position")
      gridShadowLayer.removeAnimation(forKey: "bounds")
      gridCardClipLayer.backgroundColor = nil
      gridCardClipLayer.borderWidth = 0
    case .blur:
      gridShadowLayer.isHidden = false
      gridShadowLayer.backgroundColor = NSColor.clear.cgColor
      gridShadowLayer.shadowOpacity = 0
      applyBoxRect(targetCardRect, from: fromCardRect, to: gridShadowLayer, cornerRadius: cardCornerRadius, animated: shouldAnimate && sizeChanged, useEaseOut: useSmoothEase)
      let bgAlpha = theme.backgroundColor.usingColorSpace(.sRGB)?.alphaComponent ?? 1.0
      let tint = bgAlpha < 0.99
        ? theme.backgroundColor
        : theme.backgroundColor.withAlphaComponent(isDark ? 0.16 : 0.20)
      gridCardClipLayer.backgroundColor = tint.cgColor
      gridCardClipLayer.borderWidth = 0.5
      gridCardClipLayer.borderColor = NSColor.labelColor.withAlphaComponent(isDark ? 0.20 : 0.12).cgColor
    case .solid:
      gridShadowLayer.isHidden = false
      gridShadowLayer.backgroundColor = theme.backgroundColor.cgColor
      gridShadowLayer.shadowOpacity = isDark ? 0.42 : 0.18
      applyBoxRect(targetCardRect, from: fromCardRect, to: gridShadowLayer, cornerRadius: cardCornerRadius, animated: shouldAnimate && sizeChanged, useEaseOut: false)
      gridCardClipLayer.backgroundColor = nil
      if theme.borderLineWidth > 0, let color = theme.borderColor {
        gridCardClipLayer.borderWidth = theme.borderLineWidth
        gridCardClipLayer.borderColor = color.cgColor
      } else {
        gridCardClipLayer.borderWidth = 0.5
        gridCardClipLayer.borderColor = NSColor.labelColor.withAlphaComponent(isDark ? 0.15 : 0.10).cgColor
      }
    }
    applyBoxRect(targetCardRect, from: fromCardRect, to: gridCardClipLayer, cornerRadius: cardCornerRadius, animated: shouldAnimate && sizeChanged, useEaseOut: useSmoothEase)

    if let overlayLayer = gridOverlayView.layer {
      overlayLayer.removeAnimation(forKey: "gridTextFade")
      overlayLayer.opacity = 1.0
      if shouldAnimate && sizeChanged {
        if overlayLayer.mask !== gridOverlayView.gridTextMaskLayer {
          overlayLayer.mask = gridOverlayView.gridTextMaskLayer
        }
        let targetMaskRect = NSRect(origin: .zero, size: layout.panelSize)
        let fromMaskRect = fromCardRect.map {
          NSRect(
            x: $0.minX - gridContentOrigin.x,
            y: $0.minY - gridContentOrigin.y,
            width: $0.width,
            height: $0.height
          )
        }
        applyBoxRect(targetMaskRect, from: fromMaskRect, to: gridOverlayView.gridTextMaskLayer, cornerRadius: cardCornerRadius, animated: true, useEaseOut: useSmoothEase)
      } else {
        gridOverlayView.gridTextMaskLayer.removeAnimation(forKey: "position")
        gridOverlayView.gridTextMaskLayer.removeAnimation(forKey: "bounds")
        if overlayLayer.mask != nil {
          overlayLayer.mask = nil
        }
      }
    }

    if !layout.preeditRect.isEmpty, let color = theme.preeditBackgroundColor {
      gridPreeditBgLayer.isHidden = false
      gridPreeditBgLayer.frame = NSRect(
        x: 0,
        y: 0,
        width: layout.panelSize.width,
        height: layout.preeditRect.maxY + theme.preeditLinespace / 2
      )
      gridPreeditBgLayer.backgroundColor = color.cgColor
    } else {
      gridPreeditBgLayer.isHidden = true
    }

    if !layout.preeditHighlightedRect.isEmpty, let color = theme.highlightedPreeditColor {
      gridPreeditHighlightLayer.isHidden = false
      gridPreeditHighlightLayer.frame = layout.preeditHighlightedRect
      gridPreeditHighlightLayer.cornerRadius = max(theme.hilitedCornerRadius, 3)
      gridPreeditHighlightLayer.backgroundColor = color.cgColor
    } else {
      gridPreeditHighlightLayer.isHidden = true
    }

    let cellRadius = max(theme.hilitedCornerRadius, 4)

    // Vertical column highlight band when expanded.
    gridColumnLayer.backgroundColor = theme.resolvedGridColumnBackColor.cgColor
    if layout.isExpanded && layout.showColumnHighlight && !layout.activeColumnRect.isEmpty {
      gridColumnLayer.isHidden = false
      applyAnimatedRect(layout.activeColumnRect, to: gridColumnLayer, cornerRadius: cellRadius, animated: shouldAnimate && lastGridExpanded)
      applyOpacity(1, to: gridColumnLayer, animated: shouldAnimate && expandChanged)
    } else {
      gridColumnLayer.removeAnimation(forKey: "opacity")
      gridColumnLayer.opacity = 0
      gridColumnLayer.isHidden = true
    }

    // Hover highlight.
    if let hoverRect = layout.hoveredCellRect, hoverRect != layout.activeCellRect {
      gridHoverLayer.isHidden = false
      gridHoverLayer.backgroundColor = theme.resolvedGridColumnBackColor.cgColor
      applyAnimatedRect(hoverRect, to: gridHoverLayer, cornerRadius: cellRadius, animated: shouldAnimate)
    } else {
      gridHoverLayer.isHidden = true
    }

    // Active cell highlight background.
    if let pillLayer = gridActivePillView.layer, gridActiveCellLayer.superlayer !== pillLayer {
      pillLayer.addSublayer(gridActiveCellLayer)
    }
    gridActiveCellLayer.zPosition = 5
    gridFallbackActiveCellLayer.zPosition = 5
    if let color = theme.highlightedBackColor, !layout.activeCellRect.isEmpty {
      if layout.usePillTextMask {
        gridFallbackActiveCellLayer.isHidden = true
        gridActivePillView.isHidden = false
        gridHighlightOverlayView.isHidden = false
        gridActiveCellLayer.isHidden = false
        gridActiveCellLayer.backgroundColor = color.cgColor
        if theme.shadowSize > 0 {
          gridActiveCellLayer.shadowColor = NSColor.black.cgColor
          gridActiveCellLayer.shadowOffset = NSSize(width: theme.shadowSize / 2, height: theme.shadowSize / 2)
          gridActiveCellLayer.shadowRadius = theme.shadowSize
          gridActiveCellLayer.shadowOpacity = 0.2
        } else {
          gridActiveCellLayer.shadowOpacity = 0
        }
        applyAnimatedRect(layout.activeCellRect, to: gridActiveCellLayer, cornerRadius: cellRadius, animated: shouldAnimate)
        if let hiLayer = gridHighlightOverlayView.layer {
          if hiLayer.mask !== gridHighlightOverlayView.gridActiveTextMaskLayer {
            hiLayer.mask = gridHighlightOverlayView.gridActiveTextMaskLayer
          }
          applyAnimatedRect(
            layout.activeCellRect,
            to: gridHighlightOverlayView.gridActiveTextMaskLayer,
            cornerRadius: cellRadius,
            animated: shouldAnimate
          )
        }
      } else {
        gridActivePillView.isHidden = true
        gridHighlightOverlayView.isHidden = true
        gridActiveCellLayer.isHidden = true
        gridFallbackActiveCellLayer.isHidden = false
        gridFallbackActiveCellLayer.backgroundColor = color.cgColor
        if theme.shadowSize > 0 {
          gridFallbackActiveCellLayer.shadowColor = NSColor.black.cgColor
          gridFallbackActiveCellLayer.shadowOffset = NSSize(width: theme.shadowSize / 2, height: theme.shadowSize / 2)
          gridFallbackActiveCellLayer.shadowRadius = theme.shadowSize
          gridFallbackActiveCellLayer.shadowOpacity = 0.2
        } else {
          gridFallbackActiveCellLayer.shadowOpacity = 0
        }
        applyAnimatedRect(layout.activeCellRect, to: gridFallbackActiveCellLayer, cornerRadius: cellRadius, animated: shouldAnimate)
      }
    } else {
      gridActivePillView.isHidden = true
      gridHighlightOverlayView.isHidden = true
      gridActiveCellLayer.isHidden = true
      gridFallbackActiveCellLayer.isHidden = true
    }

    // Horizontal active row highlight when expanded.
    switch theme.gridRowStyle {
    case .border:
      gridActiveRowBorderLayer.zPosition = 10
      gridActiveRowBorderLayer.backgroundColor = nil
      gridActiveRowBorderLayer.borderWidth = 1.5
      gridActiveRowBorderLayer.borderColor = theme.resolvedGridRowBorderColor.cgColor
    case .native:
      gridActiveRowBorderLayer.zPosition = 0
      gridActiveRowBorderLayer.borderWidth = 0
      gridActiveRowBorderLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(isDark ? 0.07 : 0.045).cgColor
    }
    if layout.isExpanded && !layout.activeRowRect.isEmpty {
      gridActiveRowBorderLayer.isHidden = false
      applyAnimatedRect(layout.activeRowRect, to: gridActiveRowBorderLayer, cornerRadius: max(cellRadius, 6), animated: shouldAnimate && lastGridExpanded)
      applyOpacity(1, to: gridActiveRowBorderLayer, animated: shouldAnimate && expandChanged)
    } else {
      applyOpacity(0, to: gridActiveRowBorderLayer, animated: shouldAnimate && expandChanged)
      if !shouldAnimate || !expandChanged {
        gridActiveRowBorderLayer.isHidden = true
      }
    }

    // Hairline divider next to expand chevron.
    if let divRect = layout.chevronDividerRect {
      gridDividerLayer.isHidden = false
      gridDividerLayer.frame = divRect
      gridDividerLayer.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    } else {
      gridDividerLayer.isHidden = true
    }

    // Animated expand/collapse chevron.
    if let buttonRect = layout.expandButtonRect {
      gridChevronLayer.isHidden = false
      let chevronColor = (theme.labelAttrs[.foregroundColor] as? NSColor) ?? NSColor.secondaryLabelColor
      gridChevronLayer.strokeColor = chevronColor.cgColor
      let halfW: CGFloat = 4.0
      let halfH: CGFloat = 2.2
      let chevronPath = CGMutablePath()
      chevronPath.move(to: NSPoint(x: -halfW, y: -halfH))
      chevronPath.addLine(to: NSPoint(x: 0, y: halfH))
      chevronPath.addLine(to: NSPoint(x: halfW, y: -halfH))
      gridChevronLayer.path = chevronPath
      gridChevronLayer.bounds = NSRect(x: -halfW - 2, y: -halfH - 2, width: (halfW + 2) * 2, height: (halfH + 2) * 2)
      gridChevronLayer.position = NSPoint(x: buttonRect.midX, y: buttonRect.midY)

      let targetAngle: CGFloat = layout.isExpanded ? .pi : 0
      let fromAngle = (gridChevronLayer.presentation()?.value(forKeyPath: "transform.rotation.z") as? CGFloat) ?? (lastGridExpanded ? .pi : 0)
      gridChevronLayer.transform = CATransform3DMakeRotation(targetAngle, 0, 0, 1)
      if shouldAnimate && expandChanged {
        let rotAnim = CABasicAnimation(keyPath: "transform.rotation.z")
        rotAnim.fromValue = fromAngle
        rotAnim.toValue = targetAngle
        rotAnim.duration = 0.14
        rotAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        gridChevronLayer.add(rotAnim, forKey: "chevronRotation")
      } else {
        gridChevronLayer.removeAnimation(forKey: "chevronRotation")
      }
    } else {
      gridChevronLayer.isHidden = true
    }

      CATransaction.commit()
    }

    if shouldAnimate && expandChanged && lastGridViewportTopRow == 0 && layout.viewportTopRow == 0 {
      let prevRow0ByIndex = Dictionary(uniqueKeysWithValues: lastGridRow0Cells.map { ($0.globalIndex, $0.frame.minX) })
      var specs = [SquirrelGridCellTransitionSpec]()

      if layout.isExpanded {
        let newRow0Cells = layout.visibleRows.first?.cells ?? []
        let row0PushedDown = lastGridRow0Cells.count > newRow0Cells.count

        for cell in newRow0Cells {
          if let prevX = prevRow0ByIndex[cell.globalIndex] {
            let dx = prevX - cell.frame.minX
            if abs(dx) > 1.0 {
              specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: dx, fadeIn: false))
            }
          }
        }

        if row0PushedDown && layout.visibleRows.count > 1 {
          for cell in layout.visibleRows[1].cells {
            specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: -24.0, fadeIn: true))
          }
        }
      } else {
        let newRow0Cells = layout.visibleRows.first?.cells ?? []
        for cell in newRow0Cells {
          if let prevX = prevRow0ByIndex[cell.globalIndex] {
            let dx = prevX - cell.frame.minX
            if abs(dx) > 1.0 {
              specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: dx, fadeIn: false))
            }
          } else {
            specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: 24.0, fadeIn: true))
          }
        }
      }

      if !specs.isEmpty {
        gridOverlayView.runCellTransitions(specs, clipRect: layout.gridContentRect, cellPaddingX: layout.cellPaddingX)
        if !gridHighlightOverlayView.isHidden {
          gridHighlightOverlayView.runCellTransitions(specs, clipRect: layout.gridContentRect, cellPaddingX: layout.cellPaddingX)
        }
      }
    }

    lastGridCompositionID = layout.compositionID
    lastGridExpanded = layout.isExpanded
    lastGridViewportTopRow = layout.viewportTopRow
    lastGridCardSize = layout.panelSize
    lastGridRow0Cells = layout.viewportTopRow == 0 ? (layout.visibleRows.first?.cells ?? []) : []
  }
}
