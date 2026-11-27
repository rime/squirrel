import XCTest
import AppKit

final class SquirrelGridStateTests: XCTestCase {
  private func makeRows(_ counts: [Int], width: CGFloat = 50) -> [SquirrelGridRow] {
    var rows = [SquirrelGridRow]()
    var global = 0
    for (rIdx, count) in counts.enumerated() {
      var cells = [SquirrelGridCell]()
      for cIdx in 0..<count {
        cells.append(SquirrelGridCell(
          globalIndex: global,
          cellIndexInRow: cIdx,
          colSpan: 1,
          text: "词\(global)",
          comment: "",
          xOffset: CGFloat(cIdx) * (width + 2),
          width: width
        ))
        global += 1
      }
      rows.append(SquirrelGridRow(rowIndex: rIdx, cells: cells))
    }
    return rows
  }

  private func makePacked(_ rows: [SquirrelGridRow], isExpanded: Bool, hasHiddenCollapsed: Bool = true) -> SquirrelGridPackedRows {
    SquirrelGridPackedRows(
      allRows: rows,
      hasHiddenCollapsedCandidates: hasHiddenCollapsed,
      totalGridWidth: 300,
      isExpanded: isExpanded,
      maxColumns: 5,
      expandedColumns: 5,
      candidateCount: rows.reduce(0) { $0 + $1.cells.count }
    )
  }

  func testCandidatesMatchCurrentPageDetectsDeleteAndOptionChanges() {
    var state = SquirrelGridState()
    state.candidates = [
      SquirrelGridCandidate(globalIndex: 0, text: "国", comment: ""),
      SquirrelGridCandidate(globalIndex: 1, text: "过", comment: ""),
      SquirrelGridCandidate(globalIndex: 2, text: "果", comment: "")
    ]

    XCTAssertTrue(state.candidatesMatchCurrentPage([
      SquirrelGridCandidate(globalIndex: 0, text: "国", comment: ""),
      SquirrelGridCandidate(globalIndex: 1, text: "过", comment: "")
    ], pageStart: 0))

    // Deleted candidate 0 -> shifted
    XCTAssertFalse(state.candidatesMatchCurrentPage([
      SquirrelGridCandidate(globalIndex: 0, text: "过", comment: ""),
      SquirrelGridCandidate(globalIndex: 1, text: "果", comment: "")
    ], pageStart: 0))

    // Simplified -> Traditional change
    XCTAssertFalse(state.candidatesMatchCurrentPage([
      SquirrelGridCandidate(globalIndex: 0, text: "國", comment: ""),
      SquirrelGridCandidate(globalIndex: 1, text: "過", comment: "")
    ], pageStart: 0))
  }

  func testInterpretKeyRightPassThroughOnlyWhenCaretInsidePreedit() {
    var state = SquirrelGridState()
    let rows = makeRows([3])
    state.candidates = rows[0].cells.map { SquirrelGridCandidate(globalIndex: $0.globalIndex, text: $0.text, comment: "") }
    state.packedRows = makePacked(rows, isExpanded: false, hasHiddenCollapsed: true)
    state.activeRow = 0
    state.activeCellIndex = 0

    let inside = state.interpretKey(.right, eventModifiers: [], isCaretInsidePreedit: true, isChordTyping: false, maxColumns: 5, visibleRows: 5)
    XCTAssertEqual(inside, .passThrough)

    let atEnd = state.interpretKey(.right, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 5, visibleRows: 5)
    XCTAssertEqual(atEnd, .moveRight)
  }

  func testInterpretKeySpacePassesThroughDuringChordTyping() {
    var state = SquirrelGridState()
    let rows = makeRows([3])
    state.candidates = rows[0].cells.map { SquirrelGridCandidate(globalIndex: $0.globalIndex, text: $0.text, comment: "") }
    state.packedRows = makePacked(rows, isExpanded: false)

    XCTAssertEqual(
      state.interpretKey(.space, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: true, maxColumns: 5, visibleRows: 5),
      .passThrough
    )
    XCTAssertEqual(
      state.interpretKey(.space, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 5, visibleRows: 5),
      .selectCandidate(globalIndex: 0)
    )
  }

  func testPageDownMovesByFullVisibleRowsAndViewportScrollsWithMargins() {
    var state = SquirrelGridState()
    let rows = makeRows(Array(repeating: 4, count: 10))
    state.candidates = rows.flatMap(\.cells).map { SquirrelGridCandidate(globalIndex: $0.globalIndex, text: $0.text, comment: "") }
    state.packedRows = makePacked(rows, isExpanded: true)
    state.isExpanded = true

    let action = state.interpretKey(.pageDown, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5)
    XCTAssertEqual(action, .moveVertical(rowDelta: 5))

    let moved = state.applyVerticalMove(rowDelta: 5, rows: rows, visibleRows: 5, topMargin: 1, bottomMargin: 1)
    XCTAssertTrue(moved)
    XCTAssertEqual(state.activeRow, 5)
    // visibleRows=5, bottomMargin=1 -> maxVisualRow=3 -> viewportTopRow = 5 - 3 = 2
    XCTAssertEqual(state.viewportTopRow, 2)
  }

  func testVerticalMovePreservesPreferredCenterXAcrossUnequalRows() {
    var state = SquirrelGridState()
    let row0 = SquirrelGridRow(rowIndex: 0, cells: [
      SquirrelGridCell(globalIndex: 0, cellIndexInRow: 0, colSpan: 1, text: "a", comment: "", xOffset: 0, width: 50),
      SquirrelGridCell(globalIndex: 1, cellIndexInRow: 1, colSpan: 1, text: "b", comment: "", xOffset: 52, width: 50),
      SquirrelGridCell(globalIndex: 2, cellIndexInRow: 2, colSpan: 1, text: "c", comment: "", xOffset: 104, width: 50)
    ])
    let row1 = SquirrelGridRow(rowIndex: 1, cells: [
      SquirrelGridCell(globalIndex: 3, cellIndexInRow: 0, colSpan: 3, text: "wide", comment: "", xOffset: 0, width: 154)
    ])
    let row2 = SquirrelGridRow(rowIndex: 2, cells: [
      SquirrelGridCell(globalIndex: 4, cellIndexInRow: 0, colSpan: 1, text: "d", comment: "", xOffset: 0, width: 50),
      SquirrelGridCell(globalIndex: 5, cellIndexInRow: 1, colSpan: 1, text: "e", comment: "", xOffset: 52, width: 50),
      SquirrelGridCell(globalIndex: 6, cellIndexInRow: 2, colSpan: 1, text: "f", comment: "", xOffset: 104, width: 50)
    ])
    let rows = [row0, row1, row2]
    state.isExpanded = true
    state.activeRow = 0
    state.activeCellIndex = 2 // centerX = 129

    XCTAssertTrue(state.applyVerticalMove(rowDelta: 1, rows: rows, visibleRows: 5, topMargin: 1, bottomMargin: 1))
    XCTAssertEqual(state.activeRow, 1)
    XCTAssertEqual(state.activeCellIndex, 0)

    XCTAssertTrue(state.applyVerticalMove(rowDelta: 1, rows: rows, visibleRows: 5, topMargin: 1, bottomMargin: 1))
    XCTAssertEqual(state.activeRow, 2)
    XCTAssertEqual(state.activeCellIndex, 2) // Restores column 2!
  }

  func testCollapsePreservingMapsIndexAndClampsOutOfBounds() {
    var state = SquirrelGridState()
    state.isExpanded = true
    state.activeRow = 99
    state.activeCellIndex = 99
    state.preferredCenterX = 120

    let collapsed = makeRows([3])
    state.clampSelection(to: collapsed)
    XCTAssertEqual(state.activeRow, 0)
    XCTAssertEqual(state.activeCellIndex, 2)

    state.collapsePreserving(globalIndex: 1, collapsedRows: collapsed)
    XCTAssertFalse(state.isExpanded)
    XCTAssertEqual(state.activeRow, 0)
    XCTAssertEqual(state.activeCellIndex, 1)
    XCTAssertNil(state.preferredCenterX)

    // Global index not in collapsed row 0 falls back to 0
    state.collapsePreserving(globalIndex: 10, collapsedRows: collapsed)
    XCTAssertEqual(state.activeCellIndex, 0)
  }

  func testMinusAndEqualPagingRespectGridPagingMode() {
    var state = SquirrelGridState()
    let rows = makeRows(Array(repeating: 4, count: 10))
    state.candidates = rows.flatMap(\.cells).map { SquirrelGridCandidate(globalIndex: $0.globalIndex, text: $0.text, comment: "") }
    state.packedRows = makePacked(rows, isExpanded: false)
    state.isExpanded = false

    // Default (.row): '=' when collapsed expands and moves +1 row
    XCTAssertEqual(
      state.interpretKey(.equal, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .expandAndMove(targetRowDelta: 1)
    )

    state.packedRows = makePacked(rows, isExpanded: true)
    state.isExpanded = true
    state.activeRow = 2

    // Default (.row): '=' and '-' step by 1 row, while PageDown/PageUp still page by visibleRows
    XCTAssertEqual(
      state.interpretKey(.equal, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .moveVertical(rowDelta: 1)
    )
    XCTAssertEqual(
      state.interpretKey(.minus, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .moveVertical(rowDelta: -1)
    )
    XCTAssertEqual(
      state.interpretKey(.pageDown, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .moveVertical(rowDelta: 5)
    )
    XCTAssertEqual(
      state.interpretKey(.pageUp, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .moveVertical(rowDelta: -5)
    )

    state.activeRow = 0
    XCTAssertEqual(
      state.interpretKey(.minus, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5),
      .collapse
    )

    // .page mode: '=' when collapsed expands +1, when expanded moves +visibleRows / -visibleRows
    state.isExpanded = false
    state.packedRows = makePacked(rows, isExpanded: false)
    XCTAssertEqual(
      state.interpretKey(.equal, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5, pagingMode: .page),
      .expandAndMove(targetRowDelta: 1)
    )

    state.isExpanded = true
    state.packedRows = makePacked(rows, isExpanded: true)
    state.activeRow = 6
    XCTAssertEqual(
      state.interpretKey(.equal, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5, pagingMode: .page),
      .moveVertical(rowDelta: 5)
    )
    XCTAssertEqual(
      state.interpretKey(.minus, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5, pagingMode: .page),
      .moveVertical(rowDelta: -5)
    )

    state.activeRow = 0
    XCTAssertEqual(
      state.interpretKey(.minus, eventModifiers: [], isCaretInsidePreedit: false, isChordTyping: false, maxColumns: 4, visibleRows: 5, pagingMode: .page),
      .collapse
    )
  }
}
