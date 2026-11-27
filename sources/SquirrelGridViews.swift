//
//  SquirrelGridViews.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

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
  override var isFlipped: Bool { true }

  var drawsHighlightedText: Bool = false
  var gridLayout: SquirrelGridLayout?
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
        let isDark = self.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
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

extension SquirrelView {
  var isEffectiveAppearanceDark: Bool {
    self.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
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

  func drawGrid(_ layout: SquirrelGridLayout, resizeAnchor: SquirrelGridResizeAnchor = .top, animateResize: Bool = true) {
    self.gridLayout = layout
    self.gridOverlayView.gridLayout = layout
    self.gridHighlightOverlayView.gridLayout = layout
    self.textView.isHidden = true
    self.gridOverlayView.isHidden = false
    self.gridOverlayView.clearCellTransitions(redrawImmediately: false)
    self.gridHighlightOverlayView.clearCellTransitions(redrawImmediately: false)
    updateGridLayers(layout, resizeAnchor: resizeAnchor, animateResize: animateResize)
    self.gridOverlayView.needsDisplay = true
    self.gridOverlayView.displayIfNeeded()
    if !self.gridHighlightOverlayView.isHidden {
      self.gridHighlightOverlayView.needsDisplay = true
      self.gridHighlightOverlayView.displayIfNeeded()
    }
  }

  func gridHitTest(at point: NSPoint) -> SquirrelGridHitResult {
    guard let layout = gridLayout else { return .none }
    return SquirrelGridLayoutEngine.hitTest(point: point, contentOrigin: gridContentOrigin, layout: layout)
  }
}

private extension SquirrelView {
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

  // swiftlint:disable:next function_parameter_count
  func applyBoxRect(
    _ targetRect: NSRect,
    from fromRect: NSRect?,
    to layer: CALayer,
    cornerRadius: CGFloat,
    animated: Bool,
    useEaseOut: Bool = false
  ) {
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

  func updateGridLayers(_ layout: SquirrelGridLayout, resizeAnchor: SquirrelGridResizeAnchor, animateResize: Bool) {
    let theme = currentTheme
    let targetCardRect = NSRect(origin: gridContentOrigin, size: layout.panelSize)
    let shouldAnimate = theme.gridAnimation && (lastGridCompositionID == layout.compositionID)
    let expandChanged = layout.isExpanded != lastGridExpanded
    let sizeChanged = lastGridCardSize != .zero && lastGridCardSize != layout.panelSize
    let shouldAnimateResize = shouldAnimate && sizeChanged && animateResize

    var fromCardRect: NSRect?
    if shouldAnimateResize {
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
      updateGridBackgroundAndMaskLayers(
        layout: layout,
        fromCardRect: fromCardRect,
        targetCardRect: targetCardRect,
        shouldAnimateResize: shouldAnimateResize
      )
      updateGridPreeditAndHighlightLayers(layout: layout, shouldAnimate: shouldAnimate, expandChanged: expandChanged)
      updateGridChromeLayers(layout: layout, shouldAnimate: shouldAnimate, expandChanged: expandChanged)

      CATransaction.commit()
    }

    if shouldAnimate && expandChanged && lastGridViewportTopRow == 0 && layout.viewportTopRow == 0 {
      runGridReflowTransitions(layout: layout)
    }

    lastGridCompositionID = layout.compositionID
    lastGridExpanded = layout.isExpanded
    lastGridViewportTopRow = layout.viewportTopRow
    lastGridCardSize = layout.panelSize
    lastGridRow0Cells = layout.viewportTopRow == 0 ? (layout.visibleRows.first?.cells ?? []) : []
  }

  // swiftlint:disable:next cyclomatic_complexity
  func updateGridBackgroundAndMaskLayers(
    layout: SquirrelGridLayout,
    fromCardRect: NSRect?,
    targetCardRect: NSRect,
    shouldAnimateResize: Bool
  ) {
    let theme = currentTheme
    let darkAppearance = isEffectiveAppearanceDark
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
      applyBoxRect(targetCardRect, from: fromCardRect, to: gridShadowLayer, cornerRadius: cardCornerRadius, animated: shouldAnimateResize, useEaseOut: useSmoothEase)
      let bgAlpha = theme.backgroundColor.usingColorSpace(.sRGB)?.alphaComponent ?? 1.0
      let tint = bgAlpha < 0.99
        ? theme.backgroundColor
        : theme.backgroundColor.withAlphaComponent(darkAppearance ? 0.16 : 0.20)
      gridCardClipLayer.backgroundColor = tint.cgColor
      gridCardClipLayer.borderWidth = 0.5
      gridCardClipLayer.borderColor = NSColor.labelColor.withAlphaComponent(darkAppearance ? 0.20 : 0.12).cgColor
    case .solid:
      gridShadowLayer.isHidden = false
      gridShadowLayer.backgroundColor = theme.backgroundColor.cgColor
      gridShadowLayer.shadowOpacity = darkAppearance ? 0.42 : 0.18
      applyBoxRect(targetCardRect, from: fromCardRect, to: gridShadowLayer, cornerRadius: cardCornerRadius, animated: shouldAnimateResize, useEaseOut: false)
      gridCardClipLayer.backgroundColor = nil
      if theme.borderLineWidth > 0, let color = theme.borderColor {
        gridCardClipLayer.borderWidth = theme.borderLineWidth
        gridCardClipLayer.borderColor = color.cgColor
      } else {
        gridCardClipLayer.borderWidth = 0.5
        gridCardClipLayer.borderColor = NSColor.labelColor.withAlphaComponent(darkAppearance ? 0.15 : 0.10).cgColor
      }
    }
    applyBoxRect(targetCardRect, from: fromCardRect, to: gridCardClipLayer, cornerRadius: cardCornerRadius, animated: shouldAnimateResize, useEaseOut: useSmoothEase)

    if let overlayLayer = gridOverlayView.layer {
      overlayLayer.removeAnimation(forKey: "gridTextFade")
      overlayLayer.opacity = 1.0
      if shouldAnimateResize {
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
  }

  // swiftlint:disable:next cyclomatic_complexity
  func updateGridPreeditAndHighlightLayers(
    layout: SquirrelGridLayout,
    shouldAnimate: Bool,
    expandChanged: Bool
  ) {
    let theme = currentTheme
    let darkAppearance = isEffectiveAppearanceDark
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

    if let hoverRect = layout.hoveredCellRect, hoverRect != layout.activeCellRect {
      gridHoverLayer.isHidden = false
      gridHoverLayer.backgroundColor = theme.resolvedGridHoverBackColor.cgColor
      applyAnimatedRect(hoverRect, to: gridHoverLayer, cornerRadius: cellRadius, animated: shouldAnimate)
    } else {
      gridHoverLayer.isHidden = true
    }

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
        applyPillShadow(to: gridActiveCellLayer, shadowSize: theme.shadowSize)
        applyAnimatedRect(layout.activeCellRect, to: gridActiveCellLayer, cornerRadius: cellRadius, animated: shouldAnimate)
        if let hiLayer = gridHighlightOverlayView.layer {
          if hiLayer.mask !== gridHighlightOverlayView.gridActiveTextMaskLayer {
            hiLayer.mask = gridHighlightOverlayView.gridActiveTextMaskLayer
          }
          applyAnimatedRect(layout.activeCellRect, to: gridHighlightOverlayView.gridActiveTextMaskLayer, cornerRadius: cellRadius, animated: shouldAnimate)
        }
      } else {
        gridActivePillView.isHidden = true
        gridHighlightOverlayView.isHidden = true
        gridActiveCellLayer.isHidden = true
        gridFallbackActiveCellLayer.isHidden = false
        gridFallbackActiveCellLayer.backgroundColor = color.cgColor
        applyPillShadow(to: gridFallbackActiveCellLayer, shadowSize: theme.shadowSize)
        applyAnimatedRect(layout.activeCellRect, to: gridFallbackActiveCellLayer, cornerRadius: cellRadius, animated: shouldAnimate)
      }
    } else {
      gridActivePillView.isHidden = true
      gridHighlightOverlayView.isHidden = true
      gridActiveCellLayer.isHidden = true
      gridFallbackActiveCellLayer.isHidden = true
    }

    // Active row highlight/border: keep border above pill when usePillTextMask is active.
    switch theme.gridRowStyle {
    case .border:
      if layout.usePillTextMask, let pillLayer = gridActivePillView.layer {
        if gridActiveRowBorderLayer.superlayer !== pillLayer {
          pillLayer.addSublayer(gridActiveRowBorderLayer)
        }
      } else if gridActiveRowBorderLayer.superlayer !== gridCardClipLayer {
        gridCardClipLayer.addSublayer(gridActiveRowBorderLayer)
      }
      gridActiveRowBorderLayer.zPosition = 10
      gridActiveRowBorderLayer.backgroundColor = nil
      gridActiveRowBorderLayer.borderWidth = 1.5
      gridActiveRowBorderLayer.borderColor = theme.resolvedGridRowBorderColor.cgColor
    case .native:
      if gridActiveRowBorderLayer.superlayer !== gridCardClipLayer {
        gridCardClipLayer.insertSublayer(gridActiveRowBorderLayer, at: 0)
      }
      gridActiveRowBorderLayer.zPosition = 0
      gridActiveRowBorderLayer.borderWidth = 0
      gridActiveRowBorderLayer.backgroundColor = NSColor.labelColor.withAlphaComponent(darkAppearance ? 0.07 : 0.045).cgColor
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
  }

  func applyPillShadow(to layer: CALayer, shadowSize: CGFloat) {
    if shadowSize > 0 {
      layer.shadowColor = NSColor.black.cgColor
      layer.shadowOffset = NSSize(width: shadowSize / 2, height: shadowSize / 2)
      layer.shadowRadius = shadowSize
      layer.shadowOpacity = 0.2
    } else {
      layer.shadowOpacity = 0
    }
  }

  func updateGridChromeLayers(
    layout: SquirrelGridLayout,
    shouldAnimate: Bool,
    expandChanged: Bool
  ) {
    let theme = currentTheme
    if let divRect = layout.chevronDividerRect {
      gridDividerLayer.isHidden = false
      gridDividerLayer.frame = divRect
      gridDividerLayer.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
    } else {
      gridDividerLayer.isHidden = true
    }

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
  }

  func runGridReflowTransitions(layout: SquirrelGridLayout) {
    let prevRow0ByIndex = Dictionary(uniqueKeysWithValues: lastGridRow0Cells.map { ($0.globalIndex, $0.frame.minX) })
    var specs = [SquirrelGridCellTransitionSpec]()

    if layout.isExpanded {
      let newRow0Cells = layout.visibleRows.first?.cells ?? []
      let row0PushedDown = lastGridRow0Cells.count > newRow0Cells.count

      for cell in newRow0Cells {
        if let prevX = prevRow0ByIndex[cell.globalIndex] {
          let deltaX = prevX - cell.frame.minX
          if abs(deltaX) > 1.0 {
            specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: deltaX, fadeIn: false))
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
          let deltaX = prevX - cell.frame.minX
          if abs(deltaX) > 1.0 {
            specs.append(SquirrelGridCellTransitionSpec(cell: cell, fromDeltaX: deltaX, fadeIn: false))
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
}
