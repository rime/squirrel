//
//  SquirrelInputController+Grid.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import InputMethodKit

extension SquirrelInputController {
  func selectGridCandidate(globalIndex: Int) -> Bool {
    guard session != 0 else { return false }
    let success = rimeAPI.select_candidate(session, globalIndex)
    if success {
      gridState.reset()
      gridState.compositionKey = ""
      inputPositionTracker.reset()
      rimeUpdate()
    }
    return success
  }

  func toggleGridExpanded() {
    guard let panel = NSApp.squirrelAppDelegate.panel,
          panel.isExpandableGridEnabled,
          !gridState.candidates.isEmpty else { return }
    let currentGlobalIndex = gridState.currentGlobalIndex()
    if gridState.isExpanded {
      gridState.isExpanded = false
      gridState.packedRows = nil
      let collapsedPacked = ensurePackedRows(panel: panel)
      gridState.collapsePreserving(globalIndex: currentGlobalIndex, collapsedRows: collapsedPacked.allRows)
      syncGridHighlightAndRefresh(panel: panel)
    } else {
      gridState.isExpanded = true
      gridState.packedRows = nil
      let maxCols = effectiveGridMaxColumns(panel)
      let targetCount = max(gridState.candidates.count, (panel.gridVisibleRowsConfig + 4) * maxCols)
      fetchGridCandidates(minCount: targetCount)
      let expandedPacked = ensurePackedRows(panel: panel)
      if let target = currentGlobalIndex,
         let pos = gridState.locateCandidate(target, in: expandedPacked.allRows) {
        gridState.activeRow = pos.row
        gridState.activeCellIndex = pos.cell
        let cell = expandedPacked.allRows[pos.row].cells[pos.cell]
        gridState.preferredCenterX = cell.xOffset + cell.width / 2
        gridState.updateViewport(
          totalRows: expandedPacked.allRows.count,
          visibleRows: panel.gridVisibleRowsConfig,
          topMargin: panel.gridTopMarginConfig,
          bottomMargin: panel.gridBottomMarginConfig
        )
      }
      syncGridHighlightAndRefresh(panel: panel)
    }
  }

  func scrollGrid(rows delta: Int) {
    guard let panel = NSApp.squirrelAppDelegate.panel,
          panel.isExpandableGridEnabled,
          !gridState.candidates.isEmpty,
          delta != 0 else { return }
    let maxCols = effectiveGridMaxColumns(panel)
    if !gridState.isExpanded {
      let initialPacked = ensurePackedRows(panel: panel)
      guard delta > 0, (gridState.hasMore || initialPacked.hasHiddenCollapsedCandidates) else { return }
      gridState.isExpanded = true
      gridState.packedRows = nil
      fetchGridCandidates(minCount: max(gridState.candidates.count, (panel.gridVisibleRowsConfig + 4) * maxCols))
    }
    if delta > 0 {
      ensureRowsLoaded(throughRow: gridState.activeRow + panel.gridVisibleRowsConfig + 3, maxCols: maxCols, panel: panel)
    }
    let packed = ensurePackedRows(panel: panel)
    if gridState.applyVerticalMove(
      rowDelta: delta,
      rows: packed.allRows,
      visibleRows: panel.gridVisibleRowsConfig,
      topMargin: panel.gridTopMarginConfig,
      bottomMargin: panel.gridBottomMarginConfig
    ) {
      syncGridHighlightAndRefresh(panel: panel)
    }
  }

  func setGridHover(globalIndex: Int?) {
    guard gridState.hoveredGlobalIndex != globalIndex else { return }
    gridState.hoveredGlobalIndex = globalIndex
    refreshGridPanelOnly()
  }

  // swiftlint:disable:next function_parameter_count
  func syncGridFromRimeContext(
    panel: SquirrelPanel,
    ctx: RimeContext_stdbool,
    preedit: String,
    selRange: NSRange,
    caretPos: Int,
    candidates: [String],
    comments: [String],
    labels: [String]
  ) {
    let rawInput = rimeAPI.get_input(session).map { String(cString: $0) } ?? ""
    let compositionKey = "\(rawInput)\u{0}\(ctx.composition.cursor_pos)\u{0}\(preedit)\u{0}\(schemaId)"
    let pageSize = max(1, Int(ctx.menu.page_size))
    let page = max(0, Int(ctx.menu.page_no))
    let pageStart = page * pageSize
    let pageCandidates = (0..<candidates.count).map { idx in
      SquirrelGridCandidate(globalIndex: pageStart + idx, text: candidates[idx], comment: comments[idx])
    }

    if compositionKey != gridState.compositionKey {
      gridState.reset()
      gridState.compositionKey = compositionKey
    } else if !gridState.candidatesMatchCurrentPage(pageCandidates, pageStart: pageStart) {
      gridState.invalidateCandidates(preservingExpanded: gridState.isExpanded)
    }

    gridState.rimePageSize = pageSize
    gridState.selectLabels = labels
    gridState.panelPreedit = inlinePreedit ? "" : preedit
    gridState.panelSelRange = selRange
    gridState.panelCaretPos = caretPos

    let rimeGlobalHighlight = pageStart + Int(ctx.menu.highlighted_candidate_index)
    let maxCols = effectiveGridMaxColumns(panel)
    let targetCount = gridState.isExpanded
      ? max(gridState.candidates.count, (gridState.viewportTopRow + panel.gridVisibleRowsConfig + 4) * maxCols, rimeGlobalHighlight + 1)
      : max(gridState.candidates.count, maxCols + 2, rimeGlobalHighlight + 1)
    fetchGridCandidates(minCount: targetCount)

    var packed = ensurePackedRows(panel: panel)
    if gridState.currentGlobalIndex() != rimeGlobalHighlight {
      if let pos = gridState.locateCandidate(rimeGlobalHighlight, in: packed.allRows) {
        gridState.activeRow = pos.row
        gridState.activeCellIndex = pos.cell
        let cell = packed.allRows[pos.row].cells[pos.cell]
        gridState.preferredCenterX = cell.xOffset + cell.width / 2
      } else if !gridState.isExpanded, rimeGlobalHighlight < gridState.candidates.count {
        gridState.isExpanded = true
        gridState.packedRows = nil
        packed = ensurePackedRows(panel: panel)
        if let pos = gridState.locateCandidate(rimeGlobalHighlight, in: packed.allRows) {
          gridState.activeRow = pos.row
          gridState.activeCellIndex = pos.cell
          let cell = packed.allRows[pos.row].cells[pos.cell]
          gridState.preferredCenterX = cell.xOffset + cell.width / 2
        }
      }
      if gridState.isExpanded {
        gridState.updateViewport(
          totalRows: packed.allRows.count,
          visibleRows: panel.gridVisibleRowsConfig,
          topMargin: panel.gridTopMarginConfig,
          bottomMargin: panel.gridBottomMarginConfig
        )
      }
    }

    let layout = panel.buildGridLayout(packed: packed, state: gridState, specialCommentIndices: specialCommentIndices)
    presentGridLayout(layout, panel: panel)
  }

  // swiftlint:disable:next cyclomatic_complexity
  func handleGridKey(_ rimeKeycode: UInt32, modifiers _: UInt32, eventModifiers: NSEvent.ModifierFlags) -> Bool {
    guard let panel = NSApp.squirrelAppDelegate.panel,
          panel.isExpandableGridEnabled,
          !gridState.candidates.isEmpty else {
      return false
    }
    let maxCols = effectiveGridMaxColumns(panel)
    _ = ensurePackedRows(panel: panel)
    if gridState.currentLayout == nil, let packed = gridState.packedRows {
      gridState.currentLayout = panel.buildGridLayout(packed: packed, state: gridState, specialCommentIndices: specialCommentIndices)
    }

    let rawLength = rimeAPI.get_input(session).map { strlen($0) } ?? 0
    let caretInPreedit = rimeAPI.get_caret_pos(session) < rawLength
    let isChordTyping = rimeAPI.get_option(session, "_chord_typing")
    let keyEvent = mapGridKeyEvent(rimeKeycode)

    let action = gridState.interpretKey(
      keyEvent,
      eventModifiers: eventModifiers,
      isCaretInsidePreedit: caretInPreedit,
      isChordTyping: isChordTyping,
      maxColumns: maxCols,
      visibleRows: panel.gridVisibleRowsConfig,
      pagingMode: panel.gridPagingModeConfig
    )

    switch action {
    case .passThrough:
      return false
    case .consumedNoChange:
      return true
    case .selectCandidate(let globalIndex):
      return selectGridCandidate(globalIndex: globalIndex)
    case .expandAndMove(let targetRowDelta):
      gridState.isExpanded = true
      gridState.packedRows = nil
      fetchGridCandidates(minCount: max(gridState.candidates.count, (panel.gridVisibleRowsConfig + 4) * maxCols))
      let packed = ensurePackedRows(panel: panel)
      _ = gridState.applyVerticalMove(
        rowDelta: targetRowDelta,
        rows: packed.allRows,
        visibleRows: panel.gridVisibleRowsConfig,
        topMargin: panel.gridTopMarginConfig,
        bottomMargin: panel.gridBottomMarginConfig
      )
      syncGridHighlightAndRefresh(panel: panel)
      return true
    case .moveVertical(let rowDelta):
      if rowDelta > 0 {
        ensureRowsLoaded(throughRow: gridState.activeRow + rowDelta + panel.gridVisibleRowsConfig + 2, maxCols: maxCols, panel: panel)
      }
      let packed = ensurePackedRows(panel: panel)
      if gridState.applyVerticalMove(
        rowDelta: rowDelta,
        rows: packed.allRows,
        visibleRows: panel.gridVisibleRowsConfig,
        topMargin: panel.gridTopMarginConfig,
        bottomMargin: panel.gridBottomMarginConfig
      ) {
        syncGridHighlightAndRefresh(panel: panel)
      }
      return true
    case .moveRight:
      return performGridRightMove(panel: panel, maxCols: maxCols)
    case .moveLeft:
      let packed = ensurePackedRows(panel: panel)
      if gridState.applyLeftMove(
        rows: packed.allRows,
        visibleRows: panel.gridVisibleRowsConfig,
        topMargin: panel.gridTopMarginConfig,
        bottomMargin: panel.gridBottomMarginConfig
      ) {
        syncGridHighlightAndRefresh(panel: panel)
      }
      return true
    case .collapse:
      let currentGlobal = gridState.currentGlobalIndex()
      gridState.isExpanded = false
      gridState.packedRows = nil
      let collapsedPacked = ensurePackedRows(panel: panel)
      gridState.collapsePreserving(globalIndex: currentGlobal, collapsedRows: collapsedPacked.allRows)
      syncGridHighlightAndRefresh(panel: panel)
      return true
    }
  }
}

private extension SquirrelInputController {
  func mapGridKeyEvent(_ rimeKeycode: UInt32) -> SquirrelGridKeyEvent {
    switch Int32(rimeKeycode) {
    case XK_Down: return .down
    case XK_Up: return .up
    case XK_Left: return .left
    case XK_Right: return .right
    case XK_Page_Down: return .pageDown
    case XK_Page_Up: return .pageUp
    case XK_equal: return .equal
    case XK_minus: return .minus
    case XK_space: return .space
    default:
      if rimeKeycode >= 0x20 && rimeKeycode <= 0x7e, let scalar = UnicodeScalar(rimeKeycode) {
        return .printable(String(scalar))
      }
      return .other
    }
  }

  func performGridRightMove(panel: SquirrelPanel, maxCols: Int) -> Bool {
    var packed = ensurePackedRows(panel: panel)
    gridState.clampSelection(to: packed.allRows)
    let curRow = packed.allRows[gridState.activeRow]
    if gridState.activeCellIndex + 1 < curRow.cells.count {
      _ = gridState.applyRightMove(
        rows: packed.allRows,
        visibleRows: panel.gridVisibleRowsConfig,
        topMargin: panel.gridTopMarginConfig,
        bottomMargin: panel.gridBottomMarginConfig
      )
      syncGridHighlightAndRefresh(panel: panel)
      return true
    }
    let nextGlobalIndex = curRow.cells[gridState.activeCellIndex].globalIndex + 1
    if !gridState.isExpanded {
      guard gridState.canExpand() else { return true }
      gridState.isExpanded = true
      gridState.packedRows = nil
    }
    ensureRowsLoaded(throughRow: gridState.activeRow + panel.gridVisibleRowsConfig + 2, maxCols: maxCols, panel: panel)
    packed = ensurePackedRows(panel: panel)
    if let pos = gridState.locateCandidate(nextGlobalIndex, in: packed.allRows) {
      gridState.activeRow = pos.row
      gridState.activeCellIndex = pos.cell
      let nextCell = packed.allRows[pos.row].cells[pos.cell]
      gridState.preferredCenterX = nextCell.xOffset + nextCell.width / 2
      gridState.updateViewport(
        totalRows: packed.allRows.count,
        visibleRows: panel.gridVisibleRowsConfig,
        topMargin: panel.gridTopMarginConfig,
        bottomMargin: panel.gridBottomMarginConfig
      )
      syncGridHighlightAndRefresh(panel: panel)
    } else if gridState.applyRightMove(
      rows: packed.allRows,
      visibleRows: panel.gridVisibleRowsConfig,
      topMargin: panel.gridTopMarginConfig,
      bottomMargin: panel.gridBottomMarginConfig
    ) {
      syncGridHighlightAndRefresh(panel: panel)
    }
    return true
  }

  func effectiveGridMaxColumns(_ panel: SquirrelPanel) -> Int {
    panel.gridMaxColumnsConfig > 0 ? panel.gridMaxColumnsConfig : max(1, gridState.rimePageSize)
  }

  func fetchGridCandidates(minCount: Int) {
    guard session != 0 else { return }
    if gridState.candidates.count >= minCount {
      return
    }
    var iterator = RimeCandidateListIterator()
    guard rimeAPI.candidate_list_from_index(session, &iterator, Int32(gridState.candidates.count)) else {
      gridState.hasMore = false
      return
    }
    defer { rimeAPI.candidate_list_end(&iterator) }

    var more = false
    while rimeAPI.candidate_list_next(&iterator) {
      let text = iterator.candidate.text.map { String(cString: $0) } ?? ""
      let comment = iterator.candidate.comment.map { String(cString: $0) } ?? ""
      gridState.candidates.append(SquirrelGridCandidate(
        globalIndex: Int(iterator.index),
        text: text,
        comment: comment
      ))
      if gridState.candidates.count >= minCount {
        more = rimeAPI.candidate_list_next(&iterator)
        break
      }
    }
    gridState.hasMore = more
    gridState.packedRows = nil
  }

  func ensureRowsLoaded(throughRow targetRow: Int, maxCols: Int, panel: SquirrelPanel) {
    guard gridState.hasMore else { return }
    var safety = 0
    while gridState.hasMore && safety < 8 {
      let packed = ensurePackedRows(panel: panel)
      if packed.allRows.count > targetRow {
        break
      }
      let nextBatch = max(gridState.candidates.count + maxCols * 4, (targetRow + 4) * maxCols)
      fetchGridCandidates(minCount: nextBatch)
      safety += 1
    }
  }

  @discardableResult
  func ensurePackedRows(panel: SquirrelPanel) -> SquirrelGridPackedRows {
    let maxCols = effectiveGridMaxColumns(panel)
    if let cached = gridState.packedRows,
       cached.candidateCount == gridState.candidates.count,
       cached.isExpanded == gridState.isExpanded,
       cached.maxColumns == maxCols,
       cached.expandedColumns == panel.gridExpandedColumnsConfig {
      return cached
    }
    let packed = panel.packGridRows(state: gridState, maxColumns: maxCols, specialCommentIndices: specialCommentIndices)
    gridState.packedRows = packed
    return packed
  }

  func presentGridLayout(_ layout: SquirrelGridLayout, panel: SquirrelPanel) {
    guard let client = client else { return }
    gridState.currentLayout = layout
    let inputPos = currentInputPosition(for: client, hasActiveComposition: true)
    panel.position = inputPos
    panel.inputController = self
    panel.updateGrid(layout, preedit: gridState.panelPreedit, selRange: gridState.panelSelRange, caretPos: gridState.panelCaretPos)
  }

  func refreshGridPanelOnly() {
    guard let panel = NSApp.squirrelAppDelegate.panel, !gridState.candidates.isEmpty else { return }
    let packed = ensurePackedRows(panel: panel)
    let layout = panel.buildGridLayout(packed: packed, state: gridState, specialCommentIndices: specialCommentIndices)
    presentGridLayout(layout, panel: panel)
  }

  func syncGridHighlightAndRefresh(panel: SquirrelPanel) {
    let packed = ensurePackedRows(panel: panel)
    let layout = panel.buildGridLayout(packed: packed, state: gridState, specialCommentIndices: specialCommentIndices)
    guard !layout.allRows.isEmpty else { return }
    let row = layout.allRows[layout.activeRow]
    guard !row.cells.isEmpty else { return }
    let cell = row.cells[layout.activeCellIndexInRow]
    gridState.activeRow = layout.activeRow
    gridState.activeCellIndex = layout.activeCellIndexInRow
    _ = rimeAPI.highlight_candidate(session, cell.globalIndex)
    if inlineCandidate {
      updateInlineCandidatePreview()
    }
    presentGridLayout(layout, panel: panel)
  }

  func updateInlineCandidatePreview() {
    var ctx = RimeContext_stdbool.rimeStructInit()
    guard rimeAPI.get_context(session, &ctx) else { return }
    defer { _ = rimeAPI.free_context(&ctx) }
    let preedit = ctx.composition.preedit.map { String(cString: $0) } ?? ""
    let start = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_start)), within: preedit) ?? preedit.startIndex
    let end = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.sel_end)), within: preedit) ?? preedit.startIndex
    let caretPos = String.Index(preedit.utf8.index(preedit.utf8.startIndex, offsetBy: Int(ctx.composition.cursor_pos)), within: preedit) ?? preedit.startIndex
    var candidatePreview = ctx.commit_text_preview.map { String(cString: $0) } ?? ""
    let endOfCandidatePreview = candidatePreview.endIndex
    if inlinePreedit && caretPos >= end && caretPos < preedit.endIndex {
      candidatePreview += preedit[caretPos...]
    }
    let clampedStart = min(start, candidatePreview.endIndex)
    let clampedCaret = caretPos <= clampedStart ? caretPos : endOfCandidatePreview
    show(
      preedit: candidatePreview,
      selRange: NSRange(
        location: clampedStart.utf16Offset(in: candidatePreview),
        length: candidatePreview.utf16.distance(from: clampedStart, to: candidatePreview.endIndex)
      ),
      caretPos: clampedCaret.utf16Offset(in: candidatePreview)
    )
  }
}
