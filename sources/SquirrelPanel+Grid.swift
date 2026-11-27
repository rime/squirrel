//
//  SquirrelPanel+Grid.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

extension SquirrelPanel {
  struct GridMetrics {
    let maxRowWidth: CGFloat
    let outerPadX: CGFloat
    let outerPadY: CGFloat
    let cellPadX: CGFloat
    let cellPadY: CGFloat
    let colGap: CGFloat
    let rowGap: CGFloat
    let rowBorderInsetX: CGFloat
    let rowBorderInsetY: CGFloat
    let chevronSlotWidth: CGFloat
    let unitRefWidth: CGFloat
    let targetGridWidth: CGFloat
  }

  func gridMetrics(isExpanded: Bool, selectLabels: [String], specialCommentIndices: [ReservedPropertyKey: Set<Int>]) -> GridMetrics {
    currentScreen()
    let theme = view.currentTheme
    let outerPadX: CGFloat = max(3, theme.borderWidth > 0 ? min(theme.borderWidth + 2, 5) : 4)
    let outerPadY: CGFloat = max(3, theme.borderHeight > 0 ? min(theme.borderHeight + 2, 5) : 4)
    let cellPadX: CGFloat = 5
    let cellPadY: CGFloat = 2.5
    let colGap: CGFloat = 2
    let rowGap: CGFloat = isExpanded ? max(theme.linespace, 5) : max(theme.linespace, 3)
    let rowBorderInsetX: CGFloat = theme.gridRowStyle == .border ? 1.5 : 0
    let rowBorderInsetY: CGFloat = (isExpanded && theme.gridRowStyle == .border) ? 1.5 : 0
    let chevronSlotWidth: CGFloat = 20
    let maxRowWidth = max(240, screenRect.width * 0.85 - outerPadX * 2 - chevronSlotWidth - rowBorderInsetX * 2)

    let formatContext = SquirrelGridLayoutEngine.CellFormatContext(
      selectLabels: selectLabels,
      theme: theme,
      specialCommentIndices: specialCommentIndices
    )
    let singleCharSample = SquirrelGridLayoutEngine.formatCell(
      candidate: SquirrelGridCandidate(globalIndex: -1, text: "啊", comment: ""),
      slot: 7,
      showLabel: true,
      isHighlighted: false,
      context: formatContext
    )
    let singleCharRefW = ceil(singleCharSample.size().width) + cellPadX * 2
    let twoCharSample = SquirrelGridLayoutEngine.formatCell(
      candidate: SquirrelGridCandidate(globalIndex: -1, text: "设定", comment: ""),
      slot: 7,
      showLabel: true,
      isHighlighted: false,
      context: formatContext
    )
    let unitRefWidth = ceil(twoCharSample.size().width) + cellPadX * 2

    let defaultTargetWidth = singleCharRefW * 9 + colGap * 8
    let targetGridWidth: CGFloat
    if theme.gridWidth > 0 {
      let requestedContentWidth = theme.gridWidth - outerPadX * 2 - chevronSlotWidth - rowBorderInsetX * 2
      targetGridWidth = min(maxRowWidth, max(unitRefWidth * 2 + colGap, requestedContentWidth))
    } else {
      targetGridWidth = min(maxRowWidth, defaultTargetWidth)
    }

    return GridMetrics(
      maxRowWidth: maxRowWidth,
      outerPadX: outerPadX,
      outerPadY: outerPadY,
      cellPadX: cellPadX,
      cellPadY: cellPadY,
      colGap: colGap,
      rowGap: rowGap,
      rowBorderInsetX: rowBorderInsetX,
      rowBorderInsetY: rowBorderInsetY,
      chevronSlotWidth: chevronSlotWidth,
      unitRefWidth: unitRefWidth,
      targetGridWidth: targetGridWidth
    )
  }

  func packGridRows(
    state: SquirrelGridState,
    maxColumns: Int,
    specialCommentIndices: [ReservedPropertyKey: Set<Int>]
  ) -> SquirrelGridPackedRows {
    let theme = view.currentTheme
    let metrics = gridMetrics(
      isExpanded: state.isExpanded,
      selectLabels: state.selectLabels,
      specialCommentIndices: specialCommentIndices
    )
    let formatContext = SquirrelGridLayoutEngine.CellFormatContext(
      selectLabels: state.selectLabels,
      theme: theme,
      specialCommentIndices: specialCommentIndices
    )
    let packConfig = SquirrelGridPackConfig(
      maxColumns: maxColumns,
      expandedColumns: theme.gridExpandedColumns,
      isExpanded: state.isExpanded,
      targetGridWidth: metrics.targetGridWidth,
      maxRowWidth: metrics.maxRowWidth,
      unitRefWidth: metrics.unitRefWidth,
      colGap: metrics.colGap
    )
    return SquirrelGridLayoutEngine.packRows(candidates: state.candidates, config: packConfig) { cand, slot in
      let sampleAttr = SquirrelGridLayoutEngine.formatCell(
        candidate: cand,
        slot: slot,
        showLabel: true,
        isHighlighted: false,
        context: formatContext
      )
      let wideAttr = SquirrelGridLayoutEngine.formatCell(
        candidate: cand,
        slot: 7,
        showLabel: true,
        isHighlighted: false,
        context: formatContext
      )
      return ceil(max(sampleAttr.size().width, wideAttr.size().width)) + metrics.cellPadX * 2
    }
  }

  func buildGridLayout(
    packed: SquirrelGridPackedRows,
    state: SquirrelGridState,
    specialCommentIndices: [ReservedPropertyKey: Set<Int>]
  ) -> SquirrelGridLayout {
    let theme = view.currentTheme
    let metrics = gridMetrics(
      isExpanded: state.isExpanded,
      selectLabels: state.selectLabels,
      specialCommentIndices: specialCommentIndices
    )
    let input = SquirrelGridLayoutBuildInput(
      compositionID: state.compositionID,
      preedit: state.panelPreedit,
      selRange: state.panelSelRange,
      selectLabels: state.selectLabels,
      activeRow: state.activeRow,
      activeCellIndexInRow: state.activeCellIndex,
      viewportTopRow: state.viewportTopRow,
      hoveredGlobalIndex: state.hoveredGlobalIndex,
      hasMore: state.hasMore,
      specialCommentIndices: specialCommentIndices,
      theme: theme,
      maxRowWidth: metrics.maxRowWidth,
      outerPadX: metrics.outerPadX,
      outerPadY: metrics.outerPadY,
      cellPadX: metrics.cellPadX,
      cellPadY: metrics.cellPadY,
      rowGap: metrics.rowGap,
      rowBorderInsetX: metrics.rowBorderInsetX,
      rowBorderInsetY: metrics.rowBorderInsetY,
      chevronSlotWidth: metrics.chevronSlotWidth
    )
    return SquirrelGridLayoutEngine.buildLayout(packed: packed, input: input)
  }

  func updateGrid(_ layout: SquirrelGridLayout, preedit: String, selRange: NSRange, caretPos: Int) {
    self.preedit = preedit
    self.selRange = selRange
    self.caretPos = caretPos
    statusMessage = ""
    statusTimer?.invalidate()
    statusTimer = nil
    showGrid(layout)
  }

  // swiftlint:disable:next cyclomatic_complexity
  func showGrid(_ layout: SquirrelGridLayout) {
    currentScreen()
    let theme = view.currentTheme
    let targetAppearance: NSAppearance? = (theme.native || view.darkTheme.available)
      ? NSApp.effectiveAppearance
      : NSAppearance(named: .aqua)
    if self.appearance?.name != targetAppearance?.name {
      self.appearance = targetAppearance
    }

    let boundsRect = visibleScreenRect.isEmpty ? screenRect : visibleScreenRect
    var cardScreenRect = NSRect(origin: .zero, size: layout.panelSize)
    cardScreenRect.origin = NSPoint(x: position.minX, y: position.minY - SquirrelTheme.offsetHeight - cardScreenRect.height)

    var isAboveCursor = false
    if cardScreenRect.maxX > boundsRect.maxX { cardScreenRect.origin.x = boundsRect.maxX - cardScreenRect.width }
    if cardScreenRect.minX < boundsRect.minX { cardScreenRect.origin.x = boundsRect.minX }
    if cardScreenRect.minY < boundsRect.minY {
      cardScreenRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
      isAboveCursor = true
    }
    if cardScreenRect.maxY > boundsRect.maxY { cardScreenRect.origin.y = boundsRect.maxY - cardScreenRect.height }
    if cardScreenRect.minY < boundsRect.minY { cardScreenRect.origin.y = boundsRect.minY }

    let sameComp = (lastGridCompositionID == layout.compositionID) && (lastGridCardScreenRect != .zero)
    let animate = theme.gridAnimation && sameComp
    let flippedSide = sameComp && (isAboveCursor != lastGridWasAboveCursor)
    let pad = SquirrelView.gridShadowPadding
    let targetWindowFrame = cardScreenRect.insetBy(dx: -pad, dy: -pad)
    let resizeAnchor: SquirrelGridResizeAnchor = isAboveCursor ? .bottom : .top

    let keepingInFlightShrink = gridCollapseResizeWorkItem != nil
      && sameComp
      && !flippedSide
      && (gridActiveShrinkTargetSize == layout.panelSize)
      && (lastGridCardScreenRect.origin == cardScreenRect.origin)
    if !keepingInFlightShrink {
      gridCollapseResizeWorkItem?.cancel()
      gridCollapseResizeWorkItem = nil
      gridActiveShrinkTargetSize = nil
    }

    let isShrinking = !keepingInFlightShrink
      && animate
      && !flippedSide
      && (layout.panelSize.height < lastGridCardScreenRect.height)

    if self.hasShadow {
      self.hasShadow = false
    }
    if !back.isHidden {
      back.isHidden = true
    }

    let activeBack = configureGridBackdrop(theme: theme, targetAppearance: targetAppearance)
    let sizeChanged = sameComp && (lastGridCardScreenRect.size != layout.panelSize)
    var pendingBackEndFrame: NSRect?

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let targetBackFrame: NSRect
    let activeBoundsHeight: CGFloat
    if keepingInFlightShrink {
      let curBounds = NSRect(origin: .zero, size: self.frame.size)
      let overlayY = isAboveCursor ? pad : (curBounds.height - pad - layout.panelSize.height)
      view.gridContentOrigin = NSPoint(x: pad, y: overlayY)
      applyGridContainerGeometry(windowBounds: curBounds, overlayOrigin: NSPoint(x: pad, y: overlayY), overlaySize: layout.panelSize)
      activeBoundsHeight = curBounds.height
      targetBackFrame = NSRect(x: pad, y: overlayY, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: resizeAnchor, animateResize: false)
    } else if isShrinking {
      let tempHeight = max(targetWindowFrame.height, self.frame.height)
      let tempWidth = max(targetWindowFrame.width, self.frame.width)
      let tempY = isAboveCursor ? targetWindowFrame.minY : (targetWindowFrame.maxY - tempHeight)
      let tempWindowFrame = NSRect(x: targetWindowFrame.minX, y: tempY, width: tempWidth, height: tempHeight)
      if self.frame != tempWindowFrame {
        self.setFrame(tempWindowFrame, display: false)
      }
      let tempBounds = NSRect(origin: .zero, size: tempWindowFrame.size)
      let overlayY = isAboveCursor ? pad : (tempBounds.height - pad - layout.panelSize.height)
      view.gridContentOrigin = NSPoint(x: pad, y: overlayY)
      applyGridContainerGeometry(windowBounds: tempBounds, overlayOrigin: NSPoint(x: pad, y: overlayY), overlaySize: layout.panelSize)
      activeBoundsHeight = tempBounds.height
      targetBackFrame = NSRect(x: pad, y: overlayY, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: resizeAnchor, animateResize: true)

      gridActiveShrinkTargetSize = layout.panelSize
      let workItem = DispatchWorkItem { [weak self] in
        guard let self, self.view.gridLayout?.compositionID == layout.compositionID else { return }
        self.finalizeShrinkWindowFrame(targetWindowFrame: targetWindowFrame, layout: layout, activeBack: activeBack, pad: pad)
      }
      gridCollapseResizeWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    } else {
      view.gridContentOrigin = NSPoint(x: pad, y: pad)
      if self.frame != targetWindowFrame {
        self.setFrame(targetWindowFrame, display: false)
      }
      let targetBounds = NSRect(origin: .zero, size: targetWindowFrame.size)
      applyGridContainerGeometry(windowBounds: targetBounds, overlayOrigin: NSPoint(x: pad, y: pad), overlaySize: layout.panelSize)
      activeBoundsHeight = targetBounds.height
      targetBackFrame = NSRect(x: pad, y: pad, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: resizeAnchor, animateResize: !flippedSide)
    }

    if let activeBack, !keepingInFlightShrink {
      if animate && sizeChanged && !flippedSide {
        let fromY = resizeAnchor == .top
          ? (activeBoundsHeight - pad - lastGridCardScreenRect.height)
          : pad
        let fromBackFrame = NSRect(x: pad, y: fromY, width: lastGridCardScreenRect.width, height: lastGridCardScreenRect.height)
        activeBack.frame = fromBackFrame
        pendingBackEndFrame = targetBackFrame
      } else if activeBack.frame != targetBackFrame {
        activeBack.frame = targetBackFrame
      }
    }

    CATransaction.commit()

    if let activeBack, let endFrame = pendingBackEndFrame {
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.22
        ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        activeBack.animator().frame = endFrame
      }
    }

    if animate && flippedSide {
      self.alphaValue = 0
      if !self.isVisible {
        orderFront(nil)
      }
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.14
        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.animator().alphaValue = theme.alpha
      }
    } else {
      if self.alphaValue != theme.alpha {
        alphaValue = theme.alpha
      }
      if !self.isVisible {
        orderFront(nil)
      }
    }

    lastGridCardScreenRect = cardScreenRect
    lastGridWasAboveCursor = isAboveCursor
    lastGridCompositionID = layout.compositionID
  }

  // swiftlint:disable:next cyclomatic_complexity
  func handleGridEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown:
      gridPressedHit = view.gridHitTest(at: mousePosition())
    case .leftMouseUp:
      let hit = view.gridHitTest(at: mousePosition())
      if hit == gridPressedHit {
        switch hit {
        case .toggleExpand:
          inputController?.toggleGridExpanded()
        case .candidate(let globalIndex, _, _):
          _ = inputController?.selectGridCandidate(globalIndex: globalIndex)
        case .preedit(let charIdx):
          if charIdx < caretPos {
            _ = inputController?.moveCaret(forward: true)
          } else if charIdx > caretPos {
            _ = inputController?.moveCaret(forward: false)
          }
        case .none:
          break
        }
      }
      gridPressedHit = .none
    case .mouseEntered:
      acceptsMouseMovedEvents = true
    case .mouseExited:
      acceptsMouseMovedEvents = false
      inputController?.setGridHover(globalIndex: nil)
      gridPressedHit = .none
    case .mouseMoved:
      let hit = view.gridHitTest(at: mousePosition())
      if case .candidate(let globalIndex, _, _) = hit {
        inputController?.setGridHover(globalIndex: globalIndex)
      } else {
        inputController?.setGridHover(globalIndex: nil)
      }
    case .scrollWheel:
      handleGridScrollEvent(event)
    default:
      break
    }
  }
}

private extension SquirrelPanel {
  func applyGridContainerGeometry(windowBounds: NSRect, overlayOrigin: NSPoint, overlaySize: NSSize) {
    if let content = contentView {
      if content.frame != windowBounds { content.frame = windowBounds }
      if content.bounds != windowBounds { content.bounds = windowBounds }
      if content.boundsRotation != 0 { content.boundsRotation = 0 }
      if content.bounds.origin != .zero { content.setBoundsOrigin(.zero) }
    }
    if view.frame != windowBounds {
      view.frame = windowBounds
    }
    let overlayFrame = NSRect(origin: overlayOrigin, size: overlaySize)
    if view.gridOverlayView.frame != overlayFrame {
      view.gridOverlayView.frame = overlayFrame
    }
    if view.gridActivePillView.frame != overlayFrame {
      view.gridActivePillView.frame = overlayFrame
    }
    if view.gridHighlightOverlayView.frame != overlayFrame {
      view.gridHighlightOverlayView.frame = overlayFrame
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  func configureGridBackdrop(theme: SquirrelTheme, targetAppearance: NSAppearance?) -> NSView? {
    let bgStyle = theme.resolvedGridBackgroundStyle
    let cardCornerRadius = theme.resolvedGridCornerRadius
    switch bgStyle {
    case .glass, .auto:
      if !gridBlurBack.isHidden { gridBlurBack.isHidden = true }
      if #available(macOS 26.0, *), let glass = gridGlassBack as? NSGlassEffectView {
        if glass.cornerRadius != cardCornerRadius { glass.cornerRadius = cardCornerRadius }
        if glass.appearance?.name != targetAppearance?.name { glass.appearance = targetAppearance }
        if glass.isHidden { glass.isHidden = false }
        return glass
      }
      return nil
    case .blur:
      if let gridGlassBack, !gridGlassBack.isHidden { gridGlassBack.isHidden = true }
      if gridBlurBack.layer?.cornerRadius != cardCornerRadius {
        gridBlurBack.layer?.cornerRadius = cardCornerRadius
      }
      if gridBlurBack.appearance?.name != targetAppearance?.name {
        gridBlurBack.appearance = targetAppearance
      }
      if gridBlurBack.isHidden { gridBlurBack.isHidden = false }
      return gridBlurBack
    case .solid:
      if let gridGlassBack, !gridGlassBack.isHidden { gridGlassBack.isHidden = true }
      if !gridBlurBack.isHidden { gridBlurBack.isHidden = true }
      return nil
    }
  }

  func finalizeShrinkWindowFrame(
    targetWindowFrame: NSRect,
    layout: SquirrelGridLayout,
    activeBack: NSView?,
    pad: CGFloat
  ) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    gridActiveShrinkTargetSize = nil
    gridCollapseResizeWorkItem = nil
    view.gridContentOrigin = NSPoint(x: pad, y: pad)
    if self.frame != targetWindowFrame {
      self.setFrame(targetWindowFrame, display: false)
    }
    let finalBounds = NSRect(origin: .zero, size: targetWindowFrame.size)
    applyGridContainerGeometry(windowBounds: finalBounds, overlayOrigin: NSPoint(x: pad, y: pad), overlaySize: layout.panelSize)
    let finalOverlayFrame = NSRect(origin: NSPoint(x: pad, y: pad), size: layout.panelSize)
    if let activeBack, !activeBack.isHidden, activeBack.frame != finalOverlayFrame {
      activeBack.frame = finalOverlayFrame
    }
    self.view.gridOverlayView.layer?.mask = nil
    CATransaction.commit()
  }

  // swiftlint:disable:next cyclomatic_complexity
  func handleGridScrollEvent(_ event: NSEvent) {
    let stepThreshold: CGFloat = 24
    if event.phase == .began {
      scrollDirection = .zero
    } else if event.phase == .changed {
      scrollDirection.dy += event.scrollingDeltaY
      var steps = 0
      while abs(scrollDirection.dy) >= stepThreshold {
        if scrollDirection.dy > 0 {
          steps -= 1
          scrollDirection.dy -= stepThreshold
        } else {
          steps += 1
          scrollDirection.dy += stepThreshold
        }
      }
      if steps != 0 {
        inputController?.scrollGrid(rows: steps)
      }
    } else if event.phase == .ended || (event.phase == .init(rawValue: 0) && event.momentumPhase != .init(rawValue: 0)) {
      if abs(scrollDirection.dy) > 10 {
        inputController?.scrollGrid(rows: scrollDirection.dy > 0 ? -1 : 1)
      }
      scrollDirection = .zero
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
        inputController?.scrollGrid(rows: scrollDirection.dy > 0 ? -1 : 1)
        scrollDirection = .zero
      }
    } else {
      scrollDirection.dx += event.scrollingDeltaX
      scrollDirection.dy += event.scrollingDeltaY
    }
  }
}
