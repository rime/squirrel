//
//  SquirrelPanel.swift
//  Squirrel
//
//  Created by Leo Liu on 5/10/24.
//

import AppKit

final class SquirrelPanel: NSPanel {
  private let view: SquirrelView
  private let back: NSView
  private let gridGlassBack: NSView?
  private let gridBlurBack: NSVisualEffectView
  var inputController: SquirrelInputController?

  var position: NSRect
  private var screenRect: NSRect = .zero
  private var visibleScreenRect: NSRect = .zero
  private var maxHeight: CGFloat = 0

  private var statusMessage: String = ""
  private var statusTimer: Timer?

  private var preedit: String = ""
  private var selRange: NSRange = .empty
  private var caretPos: Int = 0
  private var candidates: [String] = .init()
  private var comments: [String] = .init()
  private var labels: [String] = .init()
  private var index: Int = 0
  private var cursorIndex: Int = 0
  private var scrollDirection: CGVector = .zero
  private var scrollTime: Date = .distantPast
  private var page: Int = 0
  private var lastPage: Bool = true
  private var pagingUp: Bool?
  private var gridPressedHit: SquirrelGridHitResult = .none
  private var lastGridCardScreenRect: NSRect = .zero
  private var lastGridWasAboveCursor = false
  private var lastGridCompositionID: Int?
  private var gridCollapseResizeWorkItem: DispatchWorkItem?

  init(position: NSRect) {
    self.position = position
    self.view = SquirrelView(frame: position)
    self.back = Self.makeBackgroundView()
    if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView()
      glass.style = .regular
      glass.tintColor = nil
      glass.wantsLayer = true
      glass.isHidden = true
      self.gridGlassBack = glass
    } else {
      self.gridGlassBack = nil
    }
    let blur = NSVisualEffectView()
    blur.blendingMode = .behindWindow
    blur.material = .hudWindow
    blur.state = .active
    blur.wantsLayer = true
    blur.layer?.cornerCurve = .continuous
    blur.layer?.masksToBounds = true
    blur.isHidden = true
    self.gridBlurBack = blur
    super.init(contentRect: position, styleMask: .nonactivatingPanel, backing: .buffered, defer: true)
    self.level = .init(Int(CGShieldingWindowLevel()))
    self.hasShadow = true
    self.isOpaque = false
    self.backgroundColor = .clear
    back.wantsLayer = true
    back.layer?.mask = view.shape
    let contentView = NSView()
    contentView.addSubview(back)
    if let gridGlassBack {
      contentView.addSubview(gridGlassBack)
    }
    contentView.addSubview(gridBlurBack)
    contentView.addSubview(view)
    contentView.addSubview(view.textView)
    contentView.addSubview(view.gridOverlayView)
    contentView.addSubview(view.gridActivePillView)
    contentView.addSubview(view.gridHighlightOverlayView)
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
  var isExpandableGridEnabled: Bool {
    view.currentTheme.expandableGrid && view.currentTheme.linear && !view.currentTheme.vertical
  }
  var gridMaxColumnsConfig: Int {
    view.currentTheme.gridMaxColumns
  }
  var gridVisibleRowsConfig: Int {
    view.currentTheme.gridVisibleRows
  }
  var gridTopMarginConfig: Int {
    view.currentTheme.gridTopMarginRows
  }
  var gridBottomMarginConfig: Int {
    view.currentTheme.gridBottomMarginRows
  }

  // swiftlint:disable:next cyclomatic_complexity
  override func sendEvent(_ event: NSEvent) {
    if view.gridLayout != nil {
      handleGridEvent(event)
      super.sendEvent(event)
      return
    }
    switch event.type {
    case .leftMouseDown:
      let (index, _, pagingUp) =  view.click(at: mousePosition())
      if let pagingUp {
        self.pagingUp = pagingUp
      } else {
        self.pagingUp = nil
      }
      if let index, index >= 0 && index < candidates.count {
        self.index = index
      }
    case .leftMouseUp:
      let (index, preeditIndex, pagingUp) = view.click(at: mousePosition())

      if let pagingUp, pagingUp == self.pagingUp {
        _ = inputController?.page(up: pagingUp)
      } else {
        self.pagingUp = nil
      }
      if let preeditIndex, preeditIndex >= 0 && preeditIndex < preedit.utf16.count {
        if preeditIndex < caretPos {
          _ = inputController?.moveCaret(forward: true)
        } else if preeditIndex > caretPos {
          _ = inputController?.moveCaret(forward: false)
        }
      }
      if let index, index == self.index && index >= 0 && index < candidates.count {
        _ = inputController?.selectCandidate(index)
      }
    case .mouseEntered:
      acceptsMouseMovedEvents = true
    case .mouseExited:
      acceptsMouseMovedEvents = false
      if cursorIndex != index {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, page: page, lastPage: lastPage, update: false)
      }
      pagingUp = nil
    case .mouseMoved:
      let (index, _, _) = view.click(at: mousePosition())
      if let index = index, cursorIndex != index && index >= 0 && index < candidates.count {
        update(preedit: preedit, selRange: selRange, caretPos: caretPos, candidates: candidates, comments: comments, labels: labels, highlighted: index, page: page, lastPage: lastPage, update: false)
      }
    case .scrollWheel:
      if event.phase == .began {
        scrollDirection = .zero
      } else if event.phase == .ended || (event.phase == .init(rawValue: 0) && event.momentumPhase != .init(rawValue: 0)) {
        if abs(scrollDirection.dx) > abs(scrollDirection.dy) && abs(scrollDirection.dx) > 10 {
          _ = inputController?.page(up: (scrollDirection.dx < 0) == vertical)
        } else if abs(scrollDirection.dx) < abs(scrollDirection.dy) && abs(scrollDirection.dy) > 10 {
          _ = inputController?.page(up: scrollDirection.dy > 0)
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
          _ = inputController?.page(up: scrollDirection.dy > 0)
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
    gridCollapseResizeWorkItem?.cancel()
    gridCollapseResizeWorkItem = nil
    lastGridCardScreenRect = .zero
    lastGridWasAboveCursor = false
    lastGridCompositionID = nil
    view.resetGridAnimationState()
    orderOut(nil)
    maxHeight = 0
  }

  // swiftlint:disable:next cyclomatic_complexity function_parameter_count
  func update(preedit: String, selRange: NSRange, caretPos: Int, candidates: [String], comments: [String], labels: [String], highlighted index: Int, page: Int, lastPage: Bool, update: Bool) {
    if update {
      self.preedit = preedit
      self.selRange = selRange
      self.caretPos = caretPos
      self.candidates = candidates
      self.comments = comments
      self.labels = labels
      self.index = index
      self.page = page
      self.lastPage = lastPage
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

    let text = NSMutableAttributedString()
    let preeditRange: NSRange
    let highlightedPreeditRange: NSRange

    if !preedit.isEmpty {
      preeditRange = NSRange(location: 0, length: preedit.utf16.count)
      highlightedPreeditRange = selRange

      let line = NSMutableAttributedString(string: preedit)
      line.addAttributes(theme.preeditAttrs, range: preeditRange)
      line.addAttributes(theme.preeditHighlightedAttrs, range: selRange)
      text.append(line)

      text.addAttribute(.paragraphStyle, value: theme.preeditParagraphStyle, range: NSRange(location: 0, length: text.length))
      if !candidates.isEmpty {
        text.append(NSAttributedString(string: "\n", attributes: theme.preeditAttrs))
      }
    } else {
      preeditRange = .empty
      highlightedPreeditRange = .empty
    }

    var candidateRanges = [NSRange]()
    for i in 0..<candidates.count {
      let attrs = i == index ? theme.highlightedAttrs : theme.attrs
      let labelAttrs = i == index ? theme.labelHighlightedAttrs : theme.labelAttrs
      var commentAttrs = i == index ? theme.commentHighlightedAttrs : theme.commentAttrs

      let label = if theme.candidateFormat.contains(/\[label\]/) {
        if labels.count > 1 && i < labels.count {
          labels[i]
        } else if labels.count == 1 && i < labels.first!.count {
          String(labels.first![labels.first!.index(labels.first!.startIndex, offsetBy: i)])
        } else {
          "\(i+1)"
        }
      } else {
        ""
      }

      let candidate = candidates[i].precomposedStringWithCanonicalMapping
      let comment = comments[i].precomposedStringWithCanonicalMapping

      let line = NSMutableAttributedString(string: theme.candidateFormat, attributes: labelAttrs)
      let candidateText = NSMutableAttributedString(string: candidate, attributes: attrs)
      if candidate.count <= 5 {
        preventLineBreaks(in: candidateText)
      }
      // Apply semantic accent/warning colors only for non-highlighted rows
      if let inputController, !inputController.specialCommentIndices.isEmpty && i != index {
        if let accent = inputController.specialCommentIndices[.commentHighlight], accent.contains(i) {
          commentAttrs[.foregroundColor] = theme.accentCommentTextColor
        } else if let warning = inputController.specialCommentIndices[.commentWarning], warning.contains(i) {
          commentAttrs[.foregroundColor] = theme.warningCommentTextColor
        }
      }
      let labelText = NSAttributedString(string: label, attributes: labelAttrs)
      let commentText = NSAttributedString(string: comment, attributes: commentAttrs)
      replace(placeholder: "[label]", in: line, with: labelText)
      let labeledLine = line.copy() as! NSAttributedString
      replace(placeholder: "[candidate]", in: line, with: candidateText)
      replace(placeholder: "[comment]", in: line, with: commentText)

      if line.length <= 10 {
        preventLineBreaks(in: line)
      }

      let lineSeparator = NSAttributedString(string: linear ? "  " : "\n", attributes: attrs)
      if i > 0 {
        text.append(lineSeparator)
      }
      let str = lineSeparator.mutableCopy() as! NSMutableAttributedString
      if vertical {
        str.addAttribute(.verticalGlyphForm, value: 1, range: NSRange(location: 0, length: str.length))
      }
      view.separatorWidth = str.boundingRect(with: .zero).width

      let paragraphStyleCandidate = (i == 0 ? theme.firstParagraphStyle : theme.paragraphStyle).mutableCopy() as! NSMutableParagraphStyle
      if linear {
        paragraphStyleCandidate.paragraphSpacingBefore -= theme.linespace
        paragraphStyleCandidate.lineSpacing = theme.linespace
      }
      if !linear, let labelEnd = labeledLine.string.firstMatch(of: /\[(candidate|comment)\]/)?.range.lowerBound {
        let labelString = labeledLine.attributedSubstring(from: NSRange(location: 0, length: labelEnd.utf16Offset(in: labeledLine.string)))
        let labelWidth = labelString.boundingRect(with: .zero, options: [.usesLineFragmentOrigin]).width
        paragraphStyleCandidate.headIndent = labelWidth
      }
      line.addAttribute(.paragraphStyle, value: paragraphStyleCandidate, range: NSRange(location: 0, length: line.length))

      candidateRanges.append(NSRange(location: text.length, length: line.length))
      text.append(line)
    }

    view.textView.textContentStorage?.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)

    // Force TextKit 2 layout before measuring wrapped text and highlight bounds.
    let textWidth = maxTextWidth()
    let maxTextHeight = vertical ? screenRect.width - theme.edgeInset.width * 2 : screenRect.height - theme.edgeInset.height * 2
    view.textContainer.size = NSSize(width: textWidth, height: maxTextHeight)
    view.textLayoutManager.ensureLayout(for: view.textLayoutManager.documentRange)

    // Keep very tall wrapped text from auto-scrolling past the first line.
    view.textView.scrollToBeginningOfDocument(nil)

    view.drawView(candidateRanges: candidateRanges, hilightedIndex: index, preeditRange: preeditRange, highlightedPreeditRange: highlightedPreeditRange, canPageUp: page > 0, canPageDown: !lastPage)
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
    if isDark {
      view.darkTheme = SquirrelTheme()
      view.darkTheme.load(config: config, dark: true)
    } else {
      view.lightTheme = SquirrelTheme()
      view.lightTheme.load(config: config, dark: isDark)
    }
  }

  // swiftlint:disable:next function_parameter_count
  func buildGridLayout(
    compositionID: Int,
    preedit: String,
    selRange: NSRange,
    candidates: [SquirrelGridCandidate],
    selectLabels: [String],
    maxColumns: Int,
    isExpanded: Bool,
    activeRow: Int,
    activeCellIndexInRow: Int,
    viewportTopRow: Int,
    hoveredGlobalIndex: Int?,
    hasMore: Bool,
    specialCommentIndices: [ReservedPropertyKey: Set<Int>]
  ) -> SquirrelGridLayout {
    currentScreen()
    let theme = view.currentTheme
    let effectiveMaxCols = max(1, maxColumns)
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

    let singleLineStyle = NSMutableParagraphStyle()
    singleLineStyle.lineBreakMode = .byTruncatingTail

    func labelString(for slot: Int) -> String {
      if selectLabels.count > 1 && slot < selectLabels.count {
        return selectLabels[slot]
      } else if selectLabels.count == 1, let first = selectLabels.first, slot < first.count {
        return String(first[first.index(first.startIndex, offsetBy: slot)])
      } else if slot == 9 {
        return "0"
      } else {
        return "\(slot + 1)"
      }
    }

    func formatCell(
      candidate: SquirrelGridCandidate,
      slot: Int,
      showLabel: Bool,
      isHighlighted: Bool
    ) -> NSAttributedString {
      let attrs = isHighlighted ? theme.highlightedAttrs : theme.attrs
      let labelAttrs = isHighlighted ? theme.labelHighlightedAttrs : theme.labelAttrs
      var commentAttrs = isHighlighted ? theme.commentHighlightedAttrs : theme.commentAttrs
      if !isHighlighted, !specialCommentIndices.isEmpty {
        if let accent = specialCommentIndices[.commentHighlight], accent.contains(candidate.globalIndex) {
          commentAttrs[.foregroundColor] = theme.accentCommentTextColor
        } else if let warning = specialCommentIndices[.commentWarning], warning.contains(candidate.globalIndex) {
          commentAttrs[.foregroundColor] = theme.warningCommentTextColor
        }
      }

      let label = theme.candidateFormat.contains(/\[label\]/) ? labelString(for: slot) : ""
      let candText = candidate.text.precomposedStringWithCanonicalMapping
      let commentText = candidate.comment.precomposedStringWithCanonicalMapping

      let line = NSMutableAttributedString(string: theme.candidateFormat, attributes: labelAttrs)
      replace(placeholder: "[label]", in: line, with: NSAttributedString(string: label, attributes: labelAttrs))

      // Hide label on inactive rows while preserving exact horizontal alignment.
      if !showLabel, let candPlaceholderRange = line.string.range(of: "[candidate]") {
        let prefixLen = candPlaceholderRange.lowerBound.utf16Offset(in: line.string)
        if prefixLen > 0 {
          line.addAttribute(.foregroundColor, value: NSColor.clear, range: NSRange(location: 0, length: prefixLen))
        }
      }

      replace(placeholder: "[candidate]", in: line, with: NSAttributedString(string: candText, attributes: attrs))
      if commentText.isEmpty {
        replace(placeholder: " [comment]", in: line, with: NSAttributedString(string: "", attributes: commentAttrs))
      }
      replace(placeholder: "[comment]", in: line, with: NSAttributedString(string: commentText, attributes: commentAttrs))
      line.addAttribute(.paragraphStyle, value: singleLineStyle, range: NSRange(location: 0, length: line.length))
      return line
    }

    // Compute reference widths and fixed panel width (default: 9 single-char CJK candidates).
    let singleCharSample = formatCell(
      candidate: SquirrelGridCandidate(globalIndex: -1, text: "啊", comment: ""),
      slot: 7,
      showLabel: true,
      isHighlighted: false
    )
    let singleCharRefW = ceil(singleCharSample.size().width) + cellPadX * 2
    let twoCharSample = formatCell(
      candidate: SquirrelGridCandidate(globalIndex: -1, text: "设定", comment: ""),
      slot: 7,
      showLabel: true,
      isHighlighted: false
    )
    let unitRefW = ceil(twoCharSample.size().width) + cellPadX * 2

    let defaultTargetWidth = singleCharRefW * 9 + colGap * 8
    let targetGridWidth: CGFloat
    if theme.gridWidth > 0 {
      let requestedContentWidth = theme.gridWidth - outerPadX * 2 - chevronSlotWidth - rowBorderInsetX * 2
      targetGridWidth = min(maxRowWidth, max(unitRefW * 2 + colGap, requestedContentWidth))
    } else {
      targetGridWidth = min(maxRowWidth, defaultTargetWidth)
    }

    // 1. Pack collapsed Row 0 strictly on a single line within targetGridWidth (at least 1 candidate, at most effectiveMaxCols).
    var collapsedRow0Cells = [SquirrelGridCell]()
    var collapsedColWidths = [CGFloat]()
    var collapsedColOriginsX = [CGFloat]()
    var accWidth: CGFloat = 0
    let row0Limit = min(effectiveMaxCols, candidates.count)
    for idx in 0..<row0Limit {
      let cand = candidates[idx]
      let sampleAttr = formatCell(candidate: cand, slot: idx, showLabel: true, isHighlighted: false)
      let wideLabelAttr = formatCell(candidate: cand, slot: 7, showLabel: true, isHighlighted: false)
      var cellW = ceil(max(sampleAttr.size().width, wideLabelAttr.size().width)) + cellPadX * 2
      if idx == 0 {
        cellW = min(cellW, maxRowWidth)
      }
      let cellX = idx == 0 ? 0 : (accWidth + colGap)
      let nextAcc = cellX + cellW
      if idx > 0 && nextAcc > targetGridWidth + 0.5 {
        break
      }
      accWidth = nextAcc
      collapsedColWidths.append(cellW)
      collapsedColOriginsX.append(cellX)
      collapsedRow0Cells.append(SquirrelGridCell(
        globalIndex: cand.globalIndex,
        row: 0,
        cellIndexInRow: idx,
        startCol: idx,
        colSpan: 1,
        text: cand.text,
        comment: cand.comment,
        xOffset: cellX,
        width: cellW
      ))
    }

    let collapsedGridWidth = max(1, accWidth)
    let fixedGridWidth = min(maxRowWidth, max(targetGridWidth, collapsedGridWidth))
    let showChevron = isExpanded || hasMore || candidates.count > collapsedRow0Cells.count
    var colWidths = collapsedColWidths
    var colOriginsX = collapsedColOriginsX
    var allRows = [SquirrelGridRow]()
    let totalGridWidth: CGFloat

    if !isExpanded {
      allRows.append(SquirrelGridRow(rowIndex: 0, cells: collapsedRow0Cells))
      if candidates.count > collapsedRow0Cells.count {
        let extra = candidates[collapsedRow0Cells.count]
        allRows.append(SquirrelGridRow(rowIndex: 1, cells: [
          SquirrelGridCell(
            globalIndex: extra.globalIndex,
            row: 1,
            cellIndexInRow: 0,
            startCol: 0,
            colSpan: 1,
            text: extra.text,
            comment: extra.comment,
            xOffset: 0,
            width: fixedGridWidth
          )
        ]))
      }
      totalGridWidth = fixedGridWidth
    } else {
      // 2. Expanded Apple-native uniform equal-slot grid using the same fixedGridWidth.
      let expandedGridWidth = fixedGridWidth
      let baseCols: Int
      if theme.gridExpandedColumns > 0 {
        baseCols = min(effectiveMaxCols, theme.gridExpandedColumns)
      } else {
        let fitCols = max(1, Int(floor((expandedGridWidth + colGap) / (unitRefW + colGap))))
        baseCols = min(effectiveMaxCols, fitCols)
      }
      let slotWidth = (expandedGridWidth - colGap * CGFloat(max(0, baseCols - 1))) / CGFloat(max(1, baseCols))
      colWidths = Array(repeating: slotWidth, count: baseCols)
      colOriginsX = (0..<baseCols).map { CGFloat($0) * (slotWidth + colGap) }

      func slotSpanWidth(_ span: Int) -> CGFloat {
        CGFloat(span) * slotWidth + CGFloat(max(0, span - 1)) * colGap
      }

      var currentRowCells = [SquirrelGridCell]()
      var currentRowIdx = 0
      var nextCol = 0

      for cand in candidates {
        let sampleAttr = formatCell(candidate: cand, slot: currentRowCells.count, showLabel: true, isHighlighted: false)
        let wideLabelAttr = formatCell(candidate: cand, slot: 7, showLabel: true, isHighlighted: false)
        let naturalW = ceil(max(sampleAttr.size().width, wideLabelAttr.size().width)) + cellPadX * 2

        var chosenSpan = baseCols
        for span in 1...baseCols where slotSpanWidth(span) >= naturalW + 1.0 {
          chosenSpan = span
          break
        }

        if baseCols % 2 == 0 && chosenSpan == 2 && nextCol % 2 == 1,
           nextCol + 1 + chosenSpan <= baseCols,
           !currentRowCells.isEmpty {
          let lastIdx = currentRowCells.count - 1
          let newSpan = currentRowCells[lastIdx].colSpan + 1
          currentRowCells[lastIdx] = SquirrelGridCell(
            globalIndex: currentRowCells[lastIdx].globalIndex,
            row: currentRowCells[lastIdx].row,
            cellIndexInRow: currentRowCells[lastIdx].cellIndexInRow,
            startCol: currentRowCells[lastIdx].startCol,
            colSpan: newSpan,
            text: currentRowCells[lastIdx].text,
            comment: currentRowCells[lastIdx].comment,
            xOffset: currentRowCells[lastIdx].xOffset,
            width: slotSpanWidth(newSpan)
          )
          nextCol += 1
        }

        if nextCol > 0 && (nextCol + chosenSpan > baseCols || currentRowCells.count >= effectiveMaxCols) {
          allRows.append(SquirrelGridRow(rowIndex: currentRowIdx, cells: currentRowCells))
          currentRowCells = []
          currentRowIdx += 1
          nextCol = 0

          let flushedSample = formatCell(candidate: cand, slot: 0, showLabel: true, isHighlighted: false)
          let flushedW = ceil(max(flushedSample.size().width, wideLabelAttr.size().width)) + cellPadX * 2
          chosenSpan = baseCols
          for span in 1...baseCols where slotSpanWidth(span) >= flushedW + 1.0 {
            chosenSpan = span
            break
          }
        }

        let finalSpan = min(chosenSpan, baseCols - nextCol)
        let cell = SquirrelGridCell(
          globalIndex: cand.globalIndex,
          row: currentRowIdx,
          cellIndexInRow: currentRowCells.count,
          startCol: nextCol,
          colSpan: finalSpan,
          text: cand.text,
          comment: cand.comment,
          xOffset: colOriginsX[nextCol],
          width: slotSpanWidth(finalSpan)
        )
        currentRowCells.append(cell)
        nextCol += finalSpan
        if nextCol >= baseCols {
          allRows.append(SquirrelGridRow(rowIndex: currentRowIdx, cells: currentRowCells))
          currentRowCells = []
          currentRowIdx += 1
          nextCol = 0
        }
      }
      if !currentRowCells.isEmpty {
        allRows.append(SquirrelGridRow(rowIndex: currentRowIdx, cells: currentRowCells))
      }
      totalGridWidth = expandedGridWidth
    }

    // 3. Clamp active indices and visible slice.
    let clampedActiveRow = max(0, min(activeRow, allRows.count - 1))
    let clampedActiveCell = max(0, min(activeCellIndexInRow, allRows[clampedActiveRow].cells.count - 1))
    let maxVisibleRows = isExpanded ? max(1, theme.gridVisibleRows) : 1
    let clampedTopRow = isExpanded ? max(0, min(viewportTopRow, max(0, allRows.count - maxVisibleRows))) : 0
    let visibleEndRow = isExpanded ? min(allRows.count, clampedTopRow + maxVisibleRows) : 1

    // 4. Compute preedit geometry.
    var preeditAttr: NSMutableAttributedString?
    var preeditRect = NSRect.zero
    var preeditHighlightedRect = NSRect.zero
    var contentY = outerPadY

    if !preedit.isEmpty {
      let fullRange = NSRange(location: 0, length: preedit.utf16.count)
      let attr = NSMutableAttributedString(string: preedit, attributes: theme.preeditAttrs)
      let safeSel = NSIntersectionRange(selRange, fullRange)
      if safeSel.length > 0 {
        attr.addAttributes(theme.preeditHighlightedAttrs, range: safeSel)
      }
      preeditAttr = attr
      let pSize = attr.size()
      let pWidth = ceil(pSize.width)
      let pHeight = ceil(pSize.height)
      preeditRect = NSRect(x: outerPadX, y: contentY, width: max(pWidth, totalGridWidth), height: pHeight)
      if safeSel.length > 0 {
        let prefixSize = attr.attributedSubstring(from: NSRange(location: 0, length: safeSel.location)).size()
        let selSize = attr.attributedSubstring(from: safeSel).size()
        preeditHighlightedRect = NSRect(
          x: preeditRect.minX + floor(prefixSize.width),
          y: preeditRect.minY,
          width: ceil(selSize.width),
          height: pHeight
        )
      }
      contentY = preeditRect.maxY + max(theme.preeditLinespace, 4)
    }

    // 5. Compute uniform row height and populate visible rows.
    let sampleTextHeight = ceil(("中A" as NSString).size(withAttributes: theme.attrs).height)
    let rowHeight = max(sampleTextHeight, ceil(theme.font.ascender - theme.font.descender)) + cellPadY * 2

    let gridStartX = outerPadX + rowBorderInsetX
    let gridStartY = contentY + rowBorderInsetY
    let pillAlpha = theme.highlightedBackColor?.usingColorSpace(.sRGB)?.alphaComponent ?? 0
    let usePillTextMask = (theme.highlightedBackColor != nil) && (pillAlpha >= 0.98)
    var visibleRows = [SquirrelGridRow]()
    var activeRowRect = NSRect.zero
    var activeCellRect = NSRect.zero
    var hoveredCellRect: NSRect?

    for rIdx in clampedTopRow..<visibleEndRow {
      var row = allRows[rIdx]
      let visualRowIndex = rIdx - clampedTopRow
      let rowY = gridStartY + CGFloat(visualRowIndex) * (rowHeight + rowGap)
      row.frame = NSRect(x: gridStartX, y: rowY, width: totalGridWidth, height: rowHeight)
      let isRowActive = (rIdx == clampedActiveRow)

      for cIdx in 0..<row.cells.count {
        var cell = row.cells[cIdx]
        cell.frame = NSRect(x: gridStartX + cell.xOffset, y: rowY, width: cell.width, height: rowHeight)
        let isCellActive = isRowActive && (cIdx == clampedActiveCell)
        let cand = SquirrelGridCandidate(globalIndex: cell.globalIndex, text: cell.text, comment: cell.comment)
        cell.attributedString = formatCell(
          candidate: cand,
          slot: cIdx,
          showLabel: !isExpanded || isRowActive,
          isHighlighted: usePillTextMask ? false : isCellActive
        )
        cell.highlightedAttributedString = formatCell(
          candidate: cand,
          slot: cIdx,
          showLabel: !isExpanded || isRowActive,
          isHighlighted: true
        )
        row.cells[cIdx] = cell
        if isCellActive {
          activeCellRect = cell.frame
        }
        if let hoveredGlobalIndex, hoveredGlobalIndex == cell.globalIndex {
          hoveredCellRect = cell.frame
        }
      }

      if isRowActive {
        activeRowRect = row.frame.insetBy(dx: -rowBorderInsetX, dy: -1.0)
      }
      visibleRows.append(row)
    }

    let visibleCount = max(1, visibleRows.count)
    var rowDividerRects = [NSRect]()
    if isExpanded && theme.gridRowStyle == .native && visibleRows.count > 1 {
      for vIdx in 0..<(visibleRows.count - 1) {
        let divY = floor(visibleRows[vIdx].frame.maxY + rowGap / 2)
        rowDividerRects.append(NSRect(x: gridStartX, y: divY, width: totalGridWidth, height: 0.5))
      }
    }
    let gridTotalHeight = CGFloat(visibleCount) * rowHeight + CGFloat(visibleCount - 1) * rowGap
    let gridContentRect = NSRect(x: gridStartX, y: gridStartY, width: totalGridWidth, height: gridTotalHeight)
    let activeColumnRect = NSRect(
      x: activeCellRect.minX,
      y: gridContentRect.minY,
      width: activeCellRect.width,
      height: gridContentRect.height
    )

    let chevronDividerRect: NSRect? = showChevron ? NSRect(
      x: gridContentRect.maxX + rowBorderInsetX + 2,
      y: gridStartY + 4,
      width: 1,
      height: max(8, rowHeight - 8)
    ) : nil

    let expandButtonRect: NSRect? = showChevron ? NSRect(
      x: gridContentRect.maxX + rowBorderInsetX + 3,
      y: gridStartY,
      width: chevronSlotWidth - 3,
      height: rowHeight
    ) : nil

    let isScrollable = isExpanded && (allRows.count > maxVisibleRows || hasMore)
    var scrollbarTrackRect: NSRect?
    var scrollbarThumbRect: NSRect?
    if isScrollable {
      let trackX = (expandButtonRect?.midX ?? (gridContentRect.maxX + rowBorderInsetX + 6)) - 2
      let trackY = gridContentRect.minY + (showChevron ? rowHeight + rowGap : 0)
      let trackH = max(20, gridContentRect.maxY - trackY)
      let trackRect = NSRect(x: trackX, y: trackY, width: 4, height: trackH)
      let effectiveTotalRows = max(allRows.count + (hasMore ? 1 : 0), visibleCount)
      let thumbH = max(18, trackH * CGFloat(visibleCount) / CGFloat(effectiveTotalRows))
      let maxOffsetRows = max(1, allRows.count - visibleCount)
      let progress = min(1, max(0, CGFloat(clampedTopRow) / CGFloat(maxOffsetRows)))
      let thumbY = trackRect.minY + (trackH - thumbH) * progress
      scrollbarTrackRect = trackRect
      scrollbarThumbRect = NSRect(x: trackRect.minX, y: thumbY, width: 4, height: thumbH)
    }

    let rightEdge = max(
      preeditRect.maxX,
      gridContentRect.maxX + rowBorderInsetX + chevronSlotWidth
    )
    let panelSize = NSSize(
      width: rightEdge + outerPadX,
      height: gridContentRect.maxY + rowBorderInsetY + outerPadY
    )

    return SquirrelGridLayout(
      compositionID: compositionID,
      isExpanded: isExpanded,
      showColumnHighlight: false,
      usePillTextMask: usePillTextMask,
      colWidths: colWidths,
      colOriginsX: colOriginsX,
      allRows: allRows,
      visibleRows: visibleRows,
      viewportTopRow: clampedTopRow,
      activeRow: clampedActiveRow,
      activeCellIndexInRow: clampedActiveCell,
      hoveredGlobalIndex: hoveredGlobalIndex,
      hasMore: hasMore,
      totalLoadedRows: allRows.count,
      maxVisibleRows: maxVisibleRows,
      panelSize: panelSize,
      preeditAttributedString: preeditAttr,
      preeditRect: preeditRect,
      preeditHighlightedRect: preeditHighlightedRect,
      gridContentRect: gridContentRect,
      rowDividerRects: rowDividerRects,
      activeRowRect: activeRowRect,
      activeColumnRect: activeColumnRect,
      activeCellRect: activeCellRect,
      hoveredCellRect: hoveredCellRect,
      chevronDividerRect: chevronDividerRect,
      expandButtonRect: expandButtonRect,
      scrollbarTrackRect: scrollbarTrackRect,
      scrollbarThumbRect: scrollbarThumbRect,
      cellPaddingX: cellPadX
    )
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
}

private extension SquirrelPanel {
  func mousePosition() -> NSPoint {
    var point = NSEvent.mouseLocation
    point = self.convertPoint(fromScreen: point)
    return view.convert(point, from: nil)
  }

  func currentScreen() {
    if let screen = NSScreen.main {
      screenRect = screen.frame
      visibleScreenRect = screen.visibleFrame
    }
    for screen in NSScreen.screens where screen.frame.contains(position.origin) {
      screenRect = screen.frame
      visibleScreenRect = screen.visibleFrame
      break
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

  // swiftlint:disable:next cyclomatic_complexity
  func show() {
    gridCollapseResizeWorkItem?.cancel()
    gridCollapseResizeWorkItem = nil
    gridGlassBack?.isHidden = true
    gridBlurBack.isHidden = true
    view.gridActivePillView.isHidden = true
    view.gridHighlightOverlayView.isHidden = true
    self.hasShadow = true
    back.layer?.mask = view.shape
    currentScreen()
    let theme = view.currentTheme
    if theme.native || view.darkTheme.available {
      self.appearance = NSApp.effectiveAppearance
    } else {
      // user configured only a light theme, set window appearance to light.
      self.appearance = NSAppearance(named: .aqua)
    }

    view.textView.textContainerInset = theme.edgeInset

    var textWidth = maxTextWidth()
    // Measure natural text height before constraining the panel.
    view.textContainer.size = NSSize(width: textWidth, height: .greatestFiniteMagnitude)

    // Do not let NSTextView shrink the container to the current view width; it can loop or hide text.
    view.textContainer.widthTracksTextView = false
    view.textContainer.heightTracksTextView = false

    view.textLayoutManager.ensureLayout(for: view.textLayoutManager.documentRange)
    view.textView.bounds.origin = .zero

    var contentRect = view.contentRect

    // Compute the largest size possible for a giant panel
    var naturalPanelSize = NSSize.zero
    if vertical {
      naturalPanelSize.width = contentRect.height + theme.edgeInset.height * 2
      naturalPanelSize.height = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
    } else {
      naturalPanelSize.width = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
      naturalPanelSize.height = contentRect.height + theme.edgeInset.height * 2
    }

    let maxAllowedWidth = screenRect.width * 0.95
    let maxAllowedHeight = screenRect.height * 0.95

    let requiresFullScreen = naturalPanelSize.width > maxAllowedWidth || naturalPanelSize.height > maxAllowedHeight

    if requiresFullScreen {
      // Expand line length before fullscreen scaling to avoid wasting screen space on narrow text.
      let area = contentRect.width * contentRect.height
      let screenRatio = maxAllowedWidth / maxAllowedHeight

      let optimalTextWidth: CGFloat
      if vertical {
        // Width = screen height in vertical mode
        optimalTextWidth = sqrt(area / screenRatio)
      } else {
        optimalTextWidth = sqrt(area * screenRatio)
      }

      // If there's extra room for text, tighten the layout
      if optimalTextWidth > textWidth {
        textWidth = optimalTextWidth
        view.textContainer.size = NSSize(width: textWidth, height: .greatestFiniteMagnitude)
        view.textLayoutManager.ensureLayout(for: view.textLayoutManager.documentRange)

        contentRect = view.contentRect

        if vertical {
          naturalPanelSize.width = contentRect.height + theme.edgeInset.height * 2
          naturalPanelSize.height = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
        } else {
          naturalPanelSize.width = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
          naturalPanelSize.height = contentRect.height + theme.edgeInset.height * 2
        }
      }
    }

    var panelRect = NSRect.zero

    if requiresFullScreen {
      let scaleX = maxAllowedWidth / naturalPanelSize.width
      let scaleY = maxAllowedHeight / naturalPanelSize.height
      let scale = min(scaleX, scaleY)

      panelRect.size = NSSize(width: naturalPanelSize.width * scale, height: naturalPanelSize.height * scale)

      panelRect.origin = NSPoint(
        x: screenRect.minX + (screenRect.width - panelRect.width) / 2,
        y: screenRect.minY + (screenRect.height - panelRect.height) / 2
      )

      maxHeight = 0
    } else {
      if theme.memorizeSize && (vertical && position.midY / screenRect.height < 0.5) ||
          (vertical && position.minX + max(contentRect.width, maxHeight) + theme.edgeInset.width * 2 > screenRect.maxX) {
        if contentRect.width >= maxHeight {
          maxHeight = contentRect.width
        } else {
          contentRect.size.width = maxHeight
          if vertical {
            naturalPanelSize.height = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
          } else {
            naturalPanelSize.width = contentRect.width + theme.edgeInset.width * 2 + theme.pagingOffset
          }
        }
      }

      panelRect.size = naturalPanelSize

      if vertical {
        // Anchor vertical panels on one side of the cursor to avoid jumping while typing.
        if position.midY / screenRect.height >= 0.5 {
          panelRect.origin.y = position.minY - SquirrelTheme.offsetHeight - panelRect.height + theme.pagingOffset
        } else {
          panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight
        }
        panelRect.origin.x = position.minX - panelRect.width - SquirrelTheme.offsetHeight
        if view.preeditRange.length > 0, let preeditTextRange = view.convert(range: view.preeditRange) {
          let preeditRect = view.contentRect(range: preeditTextRange)
          panelRect.origin.x += preeditRect.height + theme.edgeInset.width
        }
      } else {
        panelRect.origin = NSPoint(x: position.minX - theme.pagingOffset, y: position.minY - SquirrelTheme.offsetHeight - panelRect.height)
      }

      if panelRect.maxX > screenRect.maxX { panelRect.origin.x = screenRect.maxX - panelRect.width }
      if panelRect.minX < screenRect.minX { panelRect.origin.x = screenRect.minX }
      if panelRect.minY < screenRect.minY {
        if vertical { panelRect.origin.y = screenRect.minY } else { panelRect.origin.y = position.maxY + SquirrelTheme.offsetHeight }
      }
      if panelRect.maxY > screenRect.maxY { panelRect.origin.y = screenRect.maxY - panelRect.height }
      if panelRect.minY < screenRect.minY { panelRect.origin.y = screenRect.minY }
    }

    self.setFrame(panelRect, display: true)

    // Keep the window frame at the scaled physical size while drawing in natural coordinates through bounds.
    contentView!.frame = NSRect(origin: .zero, size: panelRect.size)
    contentView!.bounds = NSRect(origin: .zero, size: naturalPanelSize)

    if vertical {
      contentView!.boundsRotation = -90
      contentView!.setBoundsOrigin(NSPoint(x: 0, y: naturalPanelSize.width))
    } else {
      contentView!.boundsRotation = 0
      contentView!.setBoundsOrigin(.zero)
    }

    view.textView.boundsRotation = 0
    view.textView.setBoundsOrigin(.zero)

    // Subviews must read the post-rotation bounds; Cocoa adjusts the origin and swaps dimensions in vertical mode.
    let subviewFrame = contentView!.bounds
    view.frame = subviewFrame

    var textFrame = subviewFrame
    textFrame.size.width -= theme.pagingOffset
    textFrame.origin.x += theme.pagingOffset
    view.textView.frame = textFrame

    if theme.translucency {
      var backFrame = subviewFrame
      backFrame.size.width += theme.pagingOffset
      back.frame = backFrame
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
    text.addAttribute(.paragraphStyle, value: theme.paragraphStyle, range: NSRange(location: 0, length: text.length))
    view.textContentStorage.attributedString = text
    view.textView.setLayoutOrientation(vertical ? .vertical : .horizontal)
    view.drawView(candidateRanges: [NSRange(location: 0, length: text.length)], hilightedIndex: -1,
                  preeditRange: .empty, highlightedPreeditRange: .empty, canPageUp: false, canPageDown: false)
    show()

    statusTimer?.invalidate()
    statusTimer = Timer.scheduledTimer(withTimeInterval: SquirrelTheme.showStatusDuration, repeats: false) { _ in
      self.hide()
    }
  }

  func replace(placeholder: String, in text: NSMutableAttributedString, with replacement: NSAttributedString) {
    let string = text.string
    for range in string.ranges(of: placeholder).reversed() {
      text.replaceCharacters(in: convert(range: range, in: string), with: replacement)
    }
  }

  func preventLineBreaks(in text: NSMutableAttributedString) {
    let string = text.string
    let range = convert(range: string.dropFirst().startIndex..<string.endIndex, in: string)
    text.addAttribute(.noBreak, value: true, range: range)
  }

  func convert(range: Range<String.Index>, in string: String) -> NSRange {
    let startPos = range.lowerBound.utf16Offset(in: string)
    let endPos = range.upperBound.utf16Offset(in: string)
    return NSRange(location: startPos, length: endPos - startPos)
  }

  func showGrid(_ layout: SquirrelGridLayout) {
    gridCollapseResizeWorkItem?.cancel()
    gridCollapseResizeWorkItem = nil
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
    let isShrinkingBelowCursor = animate && !isAboveCursor && !flippedSide && (layout.panelSize.height < lastGridCardScreenRect.height)
    let pad = SquirrelView.gridShadowPadding
    let targetWindowFrame = cardScreenRect.insetBy(dx: -pad, dy: -pad)
    let resizeAnchor: SquirrelGridResizeAnchor = isAboveCursor ? .bottom : .top

    if self.hasShadow {
      self.hasShadow = false
    }
    view.gridContentOrigin = NSPoint(x: pad, y: pad)

    func applyContainerGeometry(windowBounds: NSRect, overlayOrigin: NSPoint, overlaySize: NSSize) {
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

    if !back.isHidden {
      back.isHidden = true
    }

    let bgStyle = theme.resolvedGridBackgroundStyle
    let cardCornerRadius = theme.resolvedGridCornerRadius
    let activeBack: NSView?
    switch bgStyle {
    case .glass, .auto:
      if !gridBlurBack.isHidden { gridBlurBack.isHidden = true }
      if #available(macOS 26.0, *), let glass = gridGlassBack as? NSGlassEffectView {
        if glass.cornerRadius != cardCornerRadius { glass.cornerRadius = cardCornerRadius }
        if glass.appearance?.name != targetAppearance?.name { glass.appearance = targetAppearance }
        if glass.isHidden { glass.isHidden = false }
        activeBack = glass
      } else {
        activeBack = nil
      }
    case .blur:
      if let gridGlassBack, !gridGlassBack.isHidden { gridGlassBack.isHidden = true }
      if gridBlurBack.layer?.cornerRadius != cardCornerRadius {
        gridBlurBack.layer?.cornerRadius = cardCornerRadius
      }
      if gridBlurBack.appearance?.name != targetAppearance?.name {
        gridBlurBack.appearance = targetAppearance
      }
      if gridBlurBack.isHidden { gridBlurBack.isHidden = false }
      activeBack = gridBlurBack
    case .solid:
      if let gridGlassBack, !gridGlassBack.isHidden { gridGlassBack.isHidden = true }
      if !gridBlurBack.isHidden { gridBlurBack.isHidden = true }
      activeBack = nil
    }

    let sizeChanged = sameComp && (lastGridCardScreenRect.size != layout.panelSize)
    var pendingBackEndFrame: NSRect?

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let targetBackFrame: NSRect
    let activeBoundsHeight: CGFloat
    if isShrinkingBelowCursor {
      let tempHeight = max(targetWindowFrame.height, self.frame.height)
      let tempWidth = max(targetWindowFrame.width, self.frame.width)
      let tempWindowFrame = NSRect(
        x: targetWindowFrame.minX,
        y: targetWindowFrame.maxY - tempHeight,
        width: tempWidth,
        height: tempHeight
      )
      if self.frame != tempWindowFrame {
        self.setFrame(tempWindowFrame, display: false)
      }
      let tempBounds = NSRect(origin: .zero, size: tempWindowFrame.size)
      let overlayY = tempBounds.height - pad - layout.panelSize.height
      applyContainerGeometry(windowBounds: tempBounds, overlayOrigin: NSPoint(x: pad, y: overlayY), overlaySize: layout.panelSize)
      activeBoundsHeight = tempBounds.height
      targetBackFrame = NSRect(x: pad, y: overlayY, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: .top)

      let workItem = DispatchWorkItem { [weak self] in
        guard let self, self.view.gridLayout?.compositionID == layout.compositionID else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if self.frame != targetWindowFrame {
          self.setFrame(targetWindowFrame, display: false)
        }
        let finalBounds = NSRect(origin: .zero, size: targetWindowFrame.size)
        if let content = self.contentView {
          if content.frame != finalBounds { content.frame = finalBounds }
          if content.bounds != finalBounds { content.bounds = finalBounds }
        }
        if self.view.frame != finalBounds {
          self.view.frame = finalBounds
        }
        let finalOverlayFrame = NSRect(origin: NSPoint(x: pad, y: pad), size: layout.panelSize)
        if self.view.gridOverlayView.frame != finalOverlayFrame {
          self.view.gridOverlayView.frame = finalOverlayFrame
        }
        if self.view.gridActivePillView.frame != finalOverlayFrame {
          self.view.gridActivePillView.frame = finalOverlayFrame
        }
        if self.view.gridHighlightOverlayView.frame != finalOverlayFrame {
          self.view.gridHighlightOverlayView.frame = finalOverlayFrame
        }
        if let activeBack, !activeBack.isHidden, activeBack.frame != finalOverlayFrame {
          activeBack.frame = finalOverlayFrame
        }
        self.view.gridOverlayView.layer?.mask = nil
        CATransaction.commit()
      }
      gridCollapseResizeWorkItem = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    } else if animate && flippedSide {
      let targetBounds = NSRect(origin: .zero, size: targetWindowFrame.size)
      applyContainerGeometry(windowBounds: targetBounds, overlayOrigin: NSPoint(x: pad, y: pad), overlaySize: layout.panelSize)
      activeBoundsHeight = targetBounds.height
      targetBackFrame = NSRect(x: pad, y: pad, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: resizeAnchor)
    } else {
      if self.frame != targetWindowFrame {
        self.setFrame(targetWindowFrame, display: false)
      }
      let targetBounds = NSRect(origin: .zero, size: targetWindowFrame.size)
      applyContainerGeometry(windowBounds: targetBounds, overlayOrigin: NSPoint(x: pad, y: pad), overlaySize: layout.panelSize)
      activeBoundsHeight = targetBounds.height
      targetBackFrame = NSRect(x: pad, y: pad, width: layout.panelSize.width, height: layout.panelSize.height)
      view.drawGrid(layout, resizeAnchor: resizeAnchor)
    }

    if let activeBack {
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
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.16
        ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        self.animator().setFrame(targetWindowFrame, display: false)
      }
    }

    lastGridCardScreenRect = cardScreenRect
    lastGridWasAboveCursor = isAboveCursor
    lastGridCompositionID = layout.compositionID

    if self.alphaValue != theme.alpha {
      alphaValue = theme.alpha
    }
    if !self.isVisible {
      orderFront(nil)
    }
  }

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
      if event.phase == .began {
        scrollDirection = .zero
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
    default:
      break
    }
  }

  static func makeBackgroundView() -> NSView {
    if #available(macOS 26.0, *) {
      let glassView = NSGlassEffectView()
      glassView.style = .clear
      return glassView
    } else {
      let visualEffectView = NSVisualEffectView()
      visualEffectView.blendingMode = .behindWindow
      visualEffectView.material = .hudWindow
      visualEffectView.state = .active
      return visualEffectView
    }
  }
}
