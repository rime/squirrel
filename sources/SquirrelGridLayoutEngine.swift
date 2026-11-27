//
//  SquirrelGridLayoutEngine.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

enum SquirrelGridLayoutEngine {
  struct CellFormatContext {
    let selectLabels: [String]
    let theme: SquirrelTheme
    let specialCommentIndices: [ReservedPropertyKey: Set<Int>]
  }

  static func explicitLabels(from selectLabels: [String]) -> [String] {
    if selectLabels.count > 1 {
      return selectLabels
    } else if selectLabels.count == 1, let first = selectLabels.first {
      return first.map { String($0) }
    }
    return []
  }

  static func labelString(for slot: Int, selectLabels: [String]) -> String {
    let labels = explicitLabels(from: selectLabels)
    if slot >= 0 && slot < labels.count {
      return labels[slot]
    } else if slot == 9 {
      return "0"
    } else {
      return "\(slot + 1)"
    }
  }

  static func slotIndex(for keyChar: String, selectLabels: [String], maxSlots: Int) -> Int? {
    guard maxSlots > 0, keyChar.count == 1 else { return nil }
    let labels = explicitLabels(from: selectLabels)
    for slot in 0..<maxSlots {
      let keyForSlot: String?
      if slot < labels.count {
        let lbl = labels[slot]
        if lbl.count == 1, let scalar = lbl.unicodeScalars.first, scalar.isASCII {
          keyForSlot = lbl
        } else {
          keyForSlot = slot == 9 ? "0" : (slot < 9 ? "\(slot + 1)" : nil)
        }
      } else {
        keyForSlot = slot == 9 ? "0" : (slot < 9 ? "\(slot + 1)" : nil)
      }
      if keyForSlot == keyChar {
        return slot
      }
    }
    return nil
  }

  static func replace(placeholder: String, in text: NSMutableAttributedString, with replacement: NSAttributedString) {
    let string = text.string
    for range in string.ranges(of: placeholder).reversed() {
      let startPos = range.lowerBound.utf16Offset(in: string)
      let endPos = range.upperBound.utf16Offset(in: string)
      text.replaceCharacters(in: NSRange(location: startPos, length: endPos - startPos), with: replacement)
    }
  }

  static func formatCell(
    candidate: SquirrelGridCandidate,
    slot: Int,
    showLabel: Bool,
    isHighlighted: Bool,
    context: CellFormatContext
  ) -> NSAttributedString {
    let theme = context.theme
    let attrs = isHighlighted ? theme.highlightedAttrs : theme.attrs
    let labelAttrs = isHighlighted ? theme.labelHighlightedAttrs : theme.labelAttrs
    var commentAttrs = isHighlighted ? theme.commentHighlightedAttrs : theme.commentAttrs
    if !isHighlighted, !context.specialCommentIndices.isEmpty {
      if let accent = context.specialCommentIndices[.commentHighlight], accent.contains(candidate.globalIndex) {
        commentAttrs[.foregroundColor] = theme.accentCommentTextColor
      } else if let warning = context.specialCommentIndices[.commentWarning], warning.contains(candidate.globalIndex) {
        commentAttrs[.foregroundColor] = theme.warningCommentTextColor
      }
    }

    let label = theme.candidateFormat.contains(/\[label\]/) ? labelString(for: slot, selectLabels: context.selectLabels) : ""
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

    let singleLineStyle = NSMutableParagraphStyle()
    singleLineStyle.lineBreakMode = .byTruncatingTail
    line.addAttribute(.paragraphStyle, value: singleLineStyle, range: NSRange(location: 0, length: line.length))
    return line
  }
}

extension SquirrelGridLayoutEngine {
  // swiftlint:disable:next cyclomatic_complexity
  static func packRows(
    candidates: [SquirrelGridCandidate],
    config: SquirrelGridPackConfig,
    measureWidth: (SquirrelGridCandidate, Int) -> CGFloat
  ) -> SquirrelGridPackedRows {
    let effectiveMaxCols = max(1, config.maxColumns)
    guard !candidates.isEmpty else {
      return SquirrelGridPackedRows(
        allRows: [],
        hasHiddenCollapsedCandidates: false,
        totalGridWidth: min(config.maxRowWidth, config.targetGridWidth),
        isExpanded: config.isExpanded,
        maxColumns: effectiveMaxCols,
        expandedColumns: config.expandedColumns,
        candidateCount: 0
      )
    }

    // 1. Pack collapsed Row 0 strictly on a single line within targetGridWidth.
    var collapsedRow0Cells = [SquirrelGridCell]()
    var accWidth: CGFloat = 0
    let row0Limit = min(effectiveMaxCols, candidates.count)
    for idx in 0..<row0Limit {
      let cand = candidates[idx]
      var cellW = measureWidth(cand, idx)
      if idx == 0 {
        cellW = min(cellW, config.maxRowWidth)
      }
      let cellX = idx == 0 ? 0 : (accWidth + config.colGap)
      let nextAcc = cellX + cellW
      if idx > 0 && nextAcc > config.targetGridWidth + 0.5 {
        break
      }
      accWidth = nextAcc
      collapsedRow0Cells.append(SquirrelGridCell(
        globalIndex: cand.globalIndex,
        cellIndexInRow: idx,
        colSpan: 1,
        text: cand.text,
        comment: cand.comment,
        xOffset: cellX,
        width: cellW
      ))
    }

    let collapsedGridWidth = max(1, accWidth)
    let fixedGridWidth = min(config.maxRowWidth, max(config.targetGridWidth, collapsedGridWidth))
    let hasHiddenCollapsed = candidates.count > collapsedRow0Cells.count

    if !config.isExpanded {
      return SquirrelGridPackedRows(
        allRows: [SquirrelGridRow(rowIndex: 0, cells: collapsedRow0Cells)],
        hasHiddenCollapsedCandidates: hasHiddenCollapsed,
        totalGridWidth: fixedGridWidth,
        isExpanded: false,
        maxColumns: effectiveMaxCols,
        expandedColumns: config.expandedColumns,
        candidateCount: candidates.count
      )
    }

    // 2. Expanded Apple-native uniform equal-slot grid using the same fixedGridWidth.
    let expandedGridWidth = fixedGridWidth
    let baseCols: Int
    if config.expandedColumns > 0 {
      baseCols = min(effectiveMaxCols, config.expandedColumns)
    } else {
      let fitCols = max(1, Int(floor((expandedGridWidth + config.colGap) / (config.unitRefWidth + config.colGap))))
      baseCols = min(effectiveMaxCols, fitCols)
    }
    let slotWidth = (expandedGridWidth - config.colGap * CGFloat(max(0, baseCols - 1))) / CGFloat(max(1, baseCols))
    let colOriginsX = (0..<baseCols).map { CGFloat($0) * (slotWidth + config.colGap) }

    func slotSpanWidth(_ span: Int) -> CGFloat {
      CGFloat(span) * slotWidth + CGFloat(max(0, span - 1)) * config.colGap
    }

    var allRows = [SquirrelGridRow]()
    var currentRowCells = [SquirrelGridCell]()
    var currentRowIdx = 0
    var nextCol = 0

    for cand in candidates {
      let naturalW = measureWidth(cand, currentRowCells.count)
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
          cellIndexInRow: currentRowCells[lastIdx].cellIndexInRow,
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

        let flushedW = measureWidth(cand, 0)
        chosenSpan = baseCols
        for span in 1...baseCols where slotSpanWidth(span) >= flushedW + 1.0 {
          chosenSpan = span
          break
        }
      }

      let finalSpan = min(chosenSpan, baseCols - nextCol)
      let cell = SquirrelGridCell(
        globalIndex: cand.globalIndex,
        cellIndexInRow: currentRowCells.count,
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

    return SquirrelGridPackedRows(
      allRows: allRows,
      hasHiddenCollapsedCandidates: hasHiddenCollapsed,
      totalGridWidth: expandedGridWidth,
      isExpanded: true,
      maxColumns: effectiveMaxCols,
      expandedColumns: config.expandedColumns,
      candidateCount: candidates.count
    )
  }

  // swiftlint:disable:next cyclomatic_complexity
  static func buildLayout(
    packed: SquirrelGridPackedRows,
    input: SquirrelGridLayoutBuildInput
  ) -> SquirrelGridLayout {
    let theme = input.theme
    let isExpanded = packed.isExpanded
    let allRows = packed.allRows
    let totalGridWidth = packed.totalGridWidth
    let showChevron = isExpanded || input.hasMore || packed.hasHiddenCollapsedCandidates

    let clampedActiveRow = allRows.isEmpty ? 0 : max(0, min(input.activeRow, allRows.count - 1))
    let clampedActiveCell = (allRows.isEmpty || allRows[clampedActiveRow].cells.isEmpty)
      ? 0
      : max(0, min(input.activeCellIndexInRow, allRows[clampedActiveRow].cells.count - 1))
    let maxVisibleRows = isExpanded ? max(1, theme.gridVisibleRows) : 1
    let clampedTopRow = isExpanded ? max(0, min(input.viewportTopRow, max(0, allRows.count - maxVisibleRows))) : 0
    let visibleEndRow = isExpanded ? min(allRows.count, clampedTopRow + maxVisibleRows) : min(1, allRows.count)

    // Preedit geometry (clamped to maxRowWidth so long preedit never overflows screen).
    var preeditAttr: NSMutableAttributedString?
    var preeditRect = NSRect.zero
    var preeditTextWidth: CGFloat = 0
    var preeditHighlightedRect = NSRect.zero
    var contentY = input.outerPadY

    if !input.preedit.isEmpty {
      let fullRange = NSRange(location: 0, length: input.preedit.utf16.count)
      let attr = NSMutableAttributedString(string: input.preedit, attributes: theme.preeditAttrs)
      let safeSel = NSIntersectionRange(input.selRange, fullRange)
      if safeSel.length > 0 {
        attr.addAttributes(theme.preeditHighlightedAttrs, range: safeSel)
      }
      let preeditStyle = NSMutableParagraphStyle()
      preeditStyle.lineBreakMode = .byTruncatingHead
      attr.addAttribute(.paragraphStyle, value: preeditStyle, range: fullRange)
      preeditAttr = attr

      let pSize = attr.size()
      preeditTextWidth = min(ceil(pSize.width), input.maxRowWidth)
      let pHeight = ceil(pSize.height)
      preeditRect = NSRect(x: input.outerPadX, y: contentY, width: max(preeditTextWidth, totalGridWidth), height: pHeight)
      if safeSel.length > 0 {
        let prefixSize = attr.attributedSubstring(from: NSRange(location: 0, length: safeSel.location)).size()
        let selSize = attr.attributedSubstring(from: safeSel).size()
        let clampedX = min(preeditRect.minX + floor(prefixSize.width), preeditRect.minX + preeditTextWidth)
        let clampedW = min(ceil(selSize.width), max(0, preeditRect.minX + preeditTextWidth - clampedX))
        preeditHighlightedRect = NSRect(x: clampedX, y: preeditRect.minY, width: clampedW, height: pHeight)
      }
      contentY = preeditRect.maxY + max(theme.preeditLinespace, 4)
    }

    // Uniform row height and visible row formatting.
    let sampleTextHeight = ceil(("中A" as NSString).size(withAttributes: theme.attrs).height)
    let rowHeight = max(sampleTextHeight, ceil(theme.font.ascender - theme.font.descender)) + input.cellPadY * 2
    let gridStartX = input.outerPadX + input.rowBorderInsetX
    let gridStartY = contentY + input.rowBorderInsetY

    let pillAlpha = theme.highlightedBackColor?.usingColorSpace(.sRGB)?.alphaComponent ?? 0
    let usePillTextMask = (theme.highlightedBackColor != nil) && (pillAlpha >= 0.98)
    let formatContext = CellFormatContext(
      selectLabels: input.selectLabels,
      theme: theme,
      specialCommentIndices: input.specialCommentIndices
    )

    var visibleRows = [SquirrelGridRow]()
    var activeRowRect = NSRect.zero
    var activeCellRect = NSRect.zero
    var hoveredCellRect: NSRect?

    if clampedTopRow < visibleEndRow {
      for rIdx in clampedTopRow..<visibleEndRow {
        var row = allRows[rIdx]
        let visualRowIndex = rIdx - clampedTopRow
        let rowY = gridStartY + CGFloat(visualRowIndex) * (rowHeight + input.rowGap)
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
            isHighlighted: usePillTextMask ? false : isCellActive,
            context: formatContext
          )
          if usePillTextMask {
            cell.highlightedAttributedString = formatCell(
              candidate: cand,
              slot: cIdx,
              showLabel: !isExpanded || isRowActive,
              isHighlighted: true,
              context: formatContext
            )
          } else {
            cell.highlightedAttributedString = NSAttributedString()
          }
          row.cells[cIdx] = cell
          if isCellActive {
            activeCellRect = cell.frame
          }
          if let hovered = input.hoveredGlobalIndex, hovered == cell.globalIndex {
            hoveredCellRect = cell.frame
          }
        }

        if isRowActive {
          activeRowRect = row.frame.insetBy(dx: -input.rowBorderInsetX, dy: -1.0)
        }
        visibleRows.append(row)
      }
    }

    let visibleCount = max(1, visibleRows.count)
    var rowDividerRects = [NSRect]()
    if isExpanded && theme.gridRowStyle == .native && visibleRows.count > 1 {
      for vIdx in 0..<(visibleRows.count - 1) {
        let divY = floor(visibleRows[vIdx].frame.maxY + input.rowGap / 2)
        rowDividerRects.append(NSRect(x: gridStartX, y: divY, width: totalGridWidth, height: 0.5))
      }
    }
    let gridTotalHeight = CGFloat(visibleCount) * rowHeight + CGFloat(visibleCount - 1) * input.rowGap
    let gridContentRect = NSRect(x: gridStartX, y: gridStartY, width: totalGridWidth, height: gridTotalHeight)

    let chevronDividerRect: NSRect? = showChevron ? NSRect(
      x: gridContentRect.maxX + input.rowBorderInsetX + 2,
      y: gridStartY + 4,
      width: 1,
      height: max(8, rowHeight - 8)
    ) : nil

    let expandButtonRect: NSRect? = showChevron ? NSRect(
      x: gridContentRect.maxX + input.rowBorderInsetX + 3,
      y: gridStartY,
      width: input.chevronSlotWidth - 3,
      height: rowHeight
    ) : nil

    let isScrollable = isExpanded && (allRows.count > maxVisibleRows || input.hasMore)
    var scrollbarTrackRect: NSRect?
    var scrollbarThumbRect: NSRect?
    if isScrollable {
      let trackX = (expandButtonRect?.midX ?? (gridContentRect.maxX + input.rowBorderInsetX + 6)) - 2
      let trackY = gridContentRect.minY + (showChevron ? rowHeight + input.rowGap : 0)
      let trackH = max(20, gridContentRect.maxY - trackY)
      let trackRect = NSRect(x: trackX, y: trackY, width: 4, height: trackH)
      let effectiveTotalRows = max(allRows.count + (input.hasMore ? 1 : 0), visibleCount)
      let thumbH = max(18, trackH * CGFloat(visibleCount) / CGFloat(effectiveTotalRows))
      let maxOffsetRows = max(1, allRows.count - visibleCount)
      let progress = min(1, max(0, CGFloat(clampedTopRow) / CGFloat(maxOffsetRows)))
      let thumbY = trackRect.minY + (trackH - thumbH) * progress
      scrollbarTrackRect = trackRect
      scrollbarThumbRect = NSRect(x: trackRect.minX, y: thumbY, width: 4, height: thumbH)
    }

    let rightEdge = max(
      preeditRect.maxX,
      gridContentRect.maxX + input.rowBorderInsetX + input.chevronSlotWidth
    )
    let panelSize = NSSize(
      width: rightEdge + input.outerPadX,
      height: gridContentRect.maxY + input.rowBorderInsetY + input.outerPadY
    )

    return SquirrelGridLayout(
      compositionID: input.compositionID,
      isExpanded: isExpanded,
      usePillTextMask: usePillTextMask,
      allRows: allRows,
      visibleRows: visibleRows,
      viewportTopRow: clampedTopRow,
      activeRow: clampedActiveRow,
      activeCellIndexInRow: clampedActiveCell,
      panelSize: panelSize,
      preeditAttributedString: preeditAttr,
      preeditRect: preeditRect,
      preeditTextWidth: preeditTextWidth,
      preeditHighlightedRect: preeditHighlightedRect,
      gridContentRect: gridContentRect,
      rowDividerRects: rowDividerRects,
      activeRowRect: activeRowRect,
      activeCellRect: activeCellRect,
      hoveredCellRect: hoveredCellRect,
      chevronDividerRect: chevronDividerRect,
      expandButtonRect: expandButtonRect,
      scrollbarTrackRect: scrollbarTrackRect,
      scrollbarThumbRect: scrollbarThumbRect,
      cellPaddingX: input.cellPadX
    )
  }

  static func hitTest(point: NSPoint, contentOrigin: NSPoint, layout: SquirrelGridLayout) -> SquirrelGridHitResult {
    let localPoint = NSPoint(x: point.x - contentOrigin.x, y: point.y - contentOrigin.y)
    if let buttonRect = layout.expandButtonRect, buttonRect.contains(localPoint) {
      return .toggleExpand
    }
    for row in layout.visibleRows {
      for cell in row.cells where cell.frame.contains(localPoint) {
        return .candidate(globalIndex: cell.globalIndex, row: row.rowIndex, cellIndexInRow: cell.cellIndexInRow)
      }
    }
    if let preeditAttr = layout.preeditAttributedString,
       !layout.preeditRect.isEmpty,
       layout.preeditTextWidth > 0 {
      let textHitRect = NSRect(
        x: layout.preeditRect.minX,
        y: layout.preeditRect.minY,
        width: layout.preeditTextWidth,
        height: layout.preeditRect.height
      )
      if textHitRect.contains(localPoint) {
        let ratio = max(0, min(1, (localPoint.x - textHitRect.minX) / max(1, textHitRect.width)))
        let charIdx = Int(round(ratio * CGFloat(preeditAttr.length)))
        return .preedit(characterIndex: charIdx)
      }
    }
    return .none
  }
}
