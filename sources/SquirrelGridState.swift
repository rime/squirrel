//
//  SquirrelGridState.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

enum SquirrelGridKeyEvent: Equatable {
  case down
  case up
  case left
  case right
  case pageDown
  case pageUp
  case equal
  case minus
  case space
  case printable(String)
  case other
}

enum SquirrelGridKeyResult: Equatable {
  case passThrough
  case consumedNoChange
  case selectCandidate(globalIndex: Int)
  case expandAndMove(targetRowDelta: Int)
  case moveVertical(rowDelta: Int)
  case moveRight
  case moveLeft
  case collapse
}

struct SquirrelGridState {
  var isExpanded = false
  var activeRow = 0
  var activeCellIndex = 0
  var preferredCenterX: CGFloat?
  var viewportTopRow = 0
  var hoveredGlobalIndex: Int?
  var compositionKey = ""
  var compositionID = 0
  var candidates: [SquirrelGridCandidate] = []
  var hasMore = false
  var selectLabels: [String] = []
  var rimePageSize = 5
  var packedRows: SquirrelGridPackedRows?
  var currentLayout: SquirrelGridLayout?
  var panelPreedit = ""
  var panelSelRange: NSRange = .empty
  var panelCaretPos = 0

  mutating func reset() {
    isExpanded = false
    activeRow = 0
    activeCellIndex = 0
    preferredCenterX = nil
    viewportTopRow = 0
    hoveredGlobalIndex = nil
    candidates = []
    hasMore = false
    packedRows = nil
    currentLayout = nil
    panelPreedit = ""
    panelSelRange = .empty
    panelCaretPos = 0
    compositionID &+= 1
  }

  mutating func invalidateCandidates(preservingExpanded: Bool) {
    isExpanded = preservingExpanded
    candidates = []
    hasMore = false
    packedRows = nil
    currentLayout = nil
    hoveredGlobalIndex = nil
    if !preservingExpanded {
      activeRow = 0
      activeCellIndex = 0
      viewportTopRow = 0
      preferredCenterX = nil
    }
  }

  func candidatesMatchCurrentPage(_ pageCandidates: [SquirrelGridCandidate], pageStart: Int) -> Bool {
    guard pageStart >= 0, pageStart + pageCandidates.count <= candidates.count else {
      return false
    }
    for (offset, cand) in pageCandidates.enumerated() where candidates[pageStart + offset] != cand {
      return false
    }
    return true
  }

  mutating func clampSelection(to rows: [SquirrelGridRow]) {
    guard !rows.isEmpty else {
      activeRow = 0
      activeCellIndex = 0
      return
    }
    activeRow = max(0, min(activeRow, rows.count - 1))
    let cellCount = rows[activeRow].cells.count
    activeCellIndex = cellCount > 0 ? max(0, min(activeCellIndex, cellCount - 1)) : 0
  }

  func currentGlobalIndex() -> Int? {
    let rows = currentLayout?.allRows ?? packedRows?.allRows ?? []
    guard !rows.isEmpty else { return nil }
    let rowIdx = max(0, min(activeRow, rows.count - 1))
    let cells = rows[rowIdx].cells
    guard !cells.isEmpty else { return nil }
    let cellIdx = max(0, min(activeCellIndex, cells.count - 1))
    return cells[cellIdx].globalIndex
  }

  func locateCandidate(_ globalIndex: Int, in rows: [SquirrelGridRow]) -> (row: Int, cell: Int)? {
    for row in rows {
      if let cellIdx = row.cells.firstIndex(where: { $0.globalIndex == globalIndex }) {
        return (row.rowIndex, cellIdx)
      }
    }
    return nil
  }

  mutating func collapsePreserving(globalIndex: Int?, collapsedRows: [SquirrelGridRow]) {
    isExpanded = false
    activeRow = 0
    viewportTopRow = 0
    preferredCenterX = nil
    if let globalIndex,
       let pos = locateCandidate(globalIndex, in: collapsedRows),
       pos.row == 0 {
      activeCellIndex = pos.cell
    } else {
      activeCellIndex = 0
    }
  }

  func cellIndexInRow(_ row: SquirrelGridRow, matchingCenterX targetX: CGFloat?) -> Int {
    guard let targetX, !row.cells.isEmpty else { return 0 }
    var bestIdx = 0
    var bestDist = CGFloat.greatestFiniteMagnitude
    for (idx, cell) in row.cells.enumerated() {
      let centerX = cell.xOffset + cell.width / 2
      let dist = abs(centerX - targetX)
      if dist < bestDist {
        bestDist = dist
        bestIdx = idx
      }
    }
    return bestIdx
  }

  mutating func updateViewport(totalRows: Int, visibleRows: Int, topMargin: Int, bottomMargin: Int) {
    let clampedVisible = max(1, visibleRows)
    let clampedBottom = min(max(0, bottomMargin), max(0, clampedVisible - 1))
    let maxVisualRow = max(0, clampedVisible - 1 - clampedBottom)
    let clampedTop = min(max(0, topMargin), maxVisualRow)
    if activeRow - viewportTopRow > maxVisualRow {
      viewportTopRow = activeRow - maxVisualRow
    }
    if activeRow - viewportTopRow < clampedTop {
      viewportTopRow = activeRow - clampedTop
    }
    let maxTopRow = max(0, totalRows - clampedVisible)
    viewportTopRow = max(0, min(viewportTopRow, maxTopRow))
  }

  func canExpand() -> Bool {
    hasMore
      || (packedRows?.hasHiddenCollapsedCandidates ?? false)
      || (packedRows?.allRows.count ?? 0) > 1
  }

  mutating func applyVerticalMove(
    rowDelta: Int,
    rows: [SquirrelGridRow],
    visibleRows: Int,
    topMargin: Int,
    bottomMargin: Int
  ) -> Bool {
    guard !rows.isEmpty, rowDelta != 0 else { return false }
    clampSelection(to: rows)
    if preferredCenterX == nil {
      let curCell = rows[activeRow].cells[activeCellIndex]
      preferredCenterX = curCell.xOffset + curCell.width / 2
    }
    let newRow = max(0, min(rows.count - 1, activeRow + rowDelta))
    guard newRow != activeRow else { return false }
    activeRow = newRow
    activeCellIndex = cellIndexInRow(rows[newRow], matchingCenterX: preferredCenterX)
    updateViewport(totalRows: rows.count, visibleRows: visibleRows, topMargin: topMargin, bottomMargin: bottomMargin)
    return true
  }

  mutating func applyRightMove(rows: [SquirrelGridRow], visibleRows: Int, topMargin: Int, bottomMargin: Int) -> Bool {
    guard !rows.isEmpty else { return false }
    clampSelection(to: rows)
    let curRow = rows[activeRow]
    if activeCellIndex + 1 < curRow.cells.count {
      activeCellIndex += 1
      let nextCell = curRow.cells[activeCellIndex]
      preferredCenterX = nextCell.xOffset + nextCell.width / 2
      return true
    } else if activeRow + 1 < rows.count {
      activeRow += 1
      activeCellIndex = 0
      let nextCell = rows[activeRow].cells[0]
      preferredCenterX = nextCell.xOffset + nextCell.width / 2
      updateViewport(totalRows: rows.count, visibleRows: visibleRows, topMargin: topMargin, bottomMargin: bottomMargin)
      return true
    }
    return false
  }

  mutating func applyLeftMove(rows: [SquirrelGridRow], visibleRows: Int, topMargin: Int, bottomMargin: Int) -> Bool {
    guard !rows.isEmpty else { return false }
    clampSelection(to: rows)
    if activeCellIndex > 0 {
      activeCellIndex -= 1
      let prevCell = rows[activeRow].cells[activeCellIndex]
      preferredCenterX = prevCell.xOffset + prevCell.width / 2
      return true
    } else if activeRow > 0 {
      activeRow -= 1
      let prevRow = rows[activeRow]
      activeCellIndex = max(0, prevRow.cells.count - 1)
      let prevCell = prevRow.cells[activeCellIndex]
      preferredCenterX = prevCell.xOffset + prevCell.width / 2
      updateViewport(totalRows: rows.count, visibleRows: visibleRows, topMargin: topMargin, bottomMargin: bottomMargin)
      return true
    }
    return false
  }

  // swiftlint:disable:next function_parameter_count cyclomatic_complexity
  func interpretKey(
    _ key: SquirrelGridKeyEvent,
    eventModifiers: NSEvent.ModifierFlags,
    isCaretInsidePreedit: Bool,
    isChordTyping: Bool,
    maxColumns: Int,
    visibleRows: Int,
    pagingMode: SquirrelTheme.GridPagingMode = .row
  ) -> SquirrelGridKeyResult {
    guard !candidates.isEmpty else { return .passThrough }
    guard eventModifiers.intersection([.command, .option, .control, .shift]).isEmpty else {
      return .passThrough
    }
    let rows = currentLayout?.allRows ?? packedRows?.allRows ?? []
    guard !rows.isEmpty else { return .passThrough }
    let clampedRow = max(0, min(activeRow, rows.count - 1))
    let activeCells = rows[clampedRow].cells
    let clampedCell = activeCells.isEmpty ? 0 : max(0, min(activeCellIndex, activeCells.count - 1))

    switch key {
    case .down:
      if !isExpanded {
        return canExpand() ? .expandAndMove(targetRowDelta: 1) : .consumedNoChange
      }
      return .moveVertical(rowDelta: 1)

    case .pageDown:
      if !isExpanded {
        return canExpand() ? .expandAndMove(targetRowDelta: 1) : .consumedNoChange
      }
      return .moveVertical(rowDelta: max(1, visibleRows))

    case .equal:
      if !isExpanded {
        return canExpand() ? .expandAndMove(targetRowDelta: 1) : .consumedNoChange
      }
      let step = pagingMode == .page ? max(1, visibleRows) : 1
      return .moveVertical(rowDelta: step)

    case .up:
      guard isExpanded else { return .consumedNoChange }
      return clampedRow == 0 ? .collapse : .moveVertical(rowDelta: -1)

    case .pageUp:
      guard isExpanded else { return .consumedNoChange }
      return clampedRow == 0 ? .collapse : .moveVertical(rowDelta: -max(1, visibleRows))

    case .minus:
      guard isExpanded else { return .consumedNoChange }
      let step = pagingMode == .page ? max(1, visibleRows) : 1
      return clampedRow == 0 ? .collapse : .moveVertical(rowDelta: -step)

    case .right:
      if !isExpanded && clampedCell == 0 && isCaretInsidePreedit {
        return .passThrough
      }
      return .moveRight

    case .left:
      if !isExpanded && clampedCell == 0 {
        return .passThrough
      }
      if isExpanded && clampedRow == 0 && clampedCell == 0 {
        return .collapse
      }
      return .moveLeft

    case .space:
      if isChordTyping {
        return .passThrough
      }
      if !activeCells.isEmpty {
        return .selectCandidate(globalIndex: activeCells[clampedCell].globalIndex)
      }
      return .passThrough

    case .printable(let keyChar):
      if let slot = SquirrelGridLayoutEngine.slotIndex(for: keyChar, selectLabels: selectLabels, maxSlots: maxColumns) {
        if slot < activeCells.count {
          return .selectCandidate(globalIndex: activeCells[slot].globalIndex)
        }
        if slot < maxColumns {
          return .consumedNoChange
        }
      }
      return .passThrough

    case .other:
      return .passThrough
    }
  }
}
