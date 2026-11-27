import XCTest
import AppKit

final class SquirrelGridLayoutEngineTests: XCTestCase {
  private func makeCandidates(_ count: Int, textPrefix: String = "词") -> [SquirrelGridCandidate] {
    (0..<count).map { idx in
      SquirrelGridCandidate(globalIndex: idx, text: "\(textPrefix)\(idx)", comment: "")
    }
  }

  private func makeConfig(
    maxColumns: Int = 9,
    expandedColumns: Int = 0,
    isExpanded: Bool = false,
    targetGridWidth: CGFloat = 320,
    maxRowWidth: CGFloat = 600,
    unitRefWidth: CGFloat = 56,
    colGap: CGFloat = 2
  ) -> SquirrelGridPackConfig {
    SquirrelGridPackConfig(
      maxColumns: maxColumns,
      expandedColumns: expandedColumns,
      isExpanded: isExpanded,
      targetGridWidth: targetGridWidth,
      maxRowWidth: maxRowWidth,
      unitRefWidth: unitRefWidth,
      colGap: colGap
    )
  }

  func testPackRowsHandlesEmptyAndSingleCandidate() {
    let emptyPacked = SquirrelGridLayoutEngine.packRows(candidates: [], config: makeConfig()) { _, _ in 40 }
    XCTAssertTrue(emptyPacked.allRows.isEmpty)
    XCTAssertFalse(emptyPacked.hasHiddenCollapsedCandidates)

    let single = makeCandidates(1)
    let singlePacked = SquirrelGridLayoutEngine.packRows(candidates: single, config: makeConfig()) { _, _ in 40 }
    XCTAssertEqual(singlePacked.allRows.count, 1)
    XCTAssertEqual(singlePacked.allRows[0].cells.count, 1)
    XCTAssertFalse(singlePacked.hasHiddenCollapsedCandidates)
  }

  func testCollapsedPackingClampsUltraLongFirstCandidateAndTracksHidden() {
    let candidates = makeCandidates(5)
    let packed = SquirrelGridLayoutEngine.packRows(
      candidates: candidates,
      config: makeConfig(targetGridWidth: 200, maxRowWidth: 260)
    ) { cand, _ in
      cand.globalIndex == 0 ? 500 : 40
    }
    XCTAssertEqual(packed.allRows.count, 1)
    XCTAssertEqual(packed.allRows[0].cells.count, 1)
    XCTAssertEqual(packed.allRows[0].cells[0].width, 260)
    XCTAssertTrue(packed.hasHiddenCollapsedCandidates)
  }

  func testExpandedPackingUniformSlotsAndEvenColumnAlignment() {
    let candidates = [
      SquirrelGridCandidate(globalIndex: 0, text: "a", comment: ""),
      SquirrelGridCandidate(globalIndex: 1, text: "wide", comment: ""),
      SquirrelGridCandidate(globalIndex: 2, text: "b", comment: ""),
      SquirrelGridCandidate(globalIndex: 3, text: "c", comment: "")
    ]
    // 4 equal columns: totalGridWidth = 238, colGap = 2 -> slotWidth = 58
    let config = makeConfig(maxColumns: 6, expandedColumns: 4, isExpanded: true, targetGridWidth: 238, unitRefWidth: 58, colGap: 2)
    let packed = SquirrelGridLayoutEngine.packRows(candidates: candidates, config: config) { cand, _ in
      cand.text == "wide" ? 80 : 30
    }
    // Cell 0 ("a", span 1, nextCol=1). Cell 1 ("wide", span 2) at odd nextCol=1 triggers even-column alignment:
    // Cell 0 stretches to span 2, Cell 1 takes cols 2..3 (span 2). Row 0 is full!
    XCTAssertEqual(packed.allRows.count, 2)
    XCTAssertEqual(packed.allRows[0].cells.count, 2)
    XCTAssertEqual(packed.allRows[0].cells[0].colSpan, 2)
    XCTAssertEqual(packed.allRows[0].cells[1].colSpan, 2)
    XCTAssertEqual(packed.allRows[1].cells.count, 2)
  }

  func testLabelStringAndSlotIndexParity() {
    // Default digits 1..9, 0
    XCTAssertEqual(SquirrelGridLayoutEngine.labelString(for: 0, selectLabels: []), "1")
    XCTAssertEqual(SquirrelGridLayoutEngine.labelString(for: 9, selectLabels: []), "0")
    XCTAssertEqual(SquirrelGridLayoutEngine.slotIndex(for: "1", selectLabels: [], maxSlots: 10), 0)
    XCTAssertEqual(SquirrelGridLayoutEngine.slotIndex(for: "0", selectLabels: [], maxSlots: 10), 9)

    // 5 custom labels with 9 columns: slot 5 displays "6" and "6" selects slot 5
    let fiveLabels = ["1", "2", "3", "4", "5"]
    XCTAssertEqual(SquirrelGridLayoutEngine.labelString(for: 5, selectLabels: fiveLabels), "6")
    XCTAssertEqual(SquirrelGridLayoutEngine.slotIndex(for: "6", selectLabels: fiveLabels, maxSlots: 9), 5)

    // Custom ASCII letters
    let letterLabels = ["a", "s", "d", "f", "g"]
    XCTAssertEqual(SquirrelGridLayoutEngine.slotIndex(for: "d", selectLabels: letterLabels, maxSlots: 5), 2)

    // Non-ASCII alternative_select_labels fall back to numeric keys 1..5
    let circleLabels = ["①", "②", "③", "④", "⑤"]
    XCTAssertEqual(SquirrelGridLayoutEngine.labelString(for: 0, selectLabels: circleLabels), "①")
    XCTAssertEqual(SquirrelGridLayoutEngine.slotIndex(for: "2", selectLabels: circleLabels, maxSlots: 5), 1)
  }

  func testPreeditClampingAndHitTest() {
    let theme = SquirrelTheme()
    let candidates = makeCandidates(3)
    let packed = SquirrelGridLayoutEngine.packRows(
      candidates: candidates,
      config: makeConfig(targetGridWidth: 260, maxRowWidth: 300)
    ) { _, _ in 50 }

    let longPreedit = String(repeating: "pinyin", count: 30)
    let input = SquirrelGridLayoutBuildInput(
      compositionID: 1,
      preedit: longPreedit,
      selRange: NSRange(location: 0, length: 6),
      selectLabels: [],
      activeRow: 0,
      activeCellIndexInRow: 0,
      viewportTopRow: 0,
      hoveredGlobalIndex: nil,
      hasMore: true,
      specialCommentIndices: [:],
      theme: theme,
      maxRowWidth: 300,
      outerPadX: 4,
      outerPadY: 4,
      cellPadX: 5,
      cellPadY: 2.5,
      rowGap: 3,
      rowBorderInsetX: 0,
      rowBorderInsetY: 0,
      chevronSlotWidth: 20
    )
    let layout = SquirrelGridLayoutEngine.buildLayout(packed: packed, input: input)
    XCTAssertLessThanOrEqual(layout.preeditTextWidth, 300)

    // Short preedit: clicking right-hand empty space outside preeditTextWidth must return .none
    let shortInput = SquirrelGridLayoutBuildInput(
      compositionID: 1,
      preedit: "ni",
      selRange: NSRange(location: 0, length: 2),
      selectLabels: [],
      activeRow: 0,
      activeCellIndexInRow: 0,
      viewportTopRow: 0,
      hoveredGlobalIndex: nil,
      hasMore: true,
      specialCommentIndices: [:],
      theme: theme,
      maxRowWidth: 300,
      outerPadX: 4,
      outerPadY: 4,
      cellPadX: 5,
      cellPadY: 2.5,
      rowGap: 3,
      rowBorderInsetX: 0,
      rowBorderInsetY: 0,
      chevronSlotWidth: 20
    )
    let shortLayout = SquirrelGridLayoutEngine.buildLayout(packed: packed, input: shortInput)
    let origin = NSPoint(x: 16, y: 16)

    // Hit inside preedit text
    let insidePreedit = NSPoint(x: origin.x + shortLayout.preeditRect.minX + 2, y: origin.y + shortLayout.preeditRect.midY)
    if case .preedit = SquirrelGridLayoutEngine.hitTest(point: insidePreedit, contentOrigin: origin, layout: shortLayout) {
      // ok
    } else {
      XCTFail("Expected preedit hit inside text bounds")
    }

    // Hit empty space to the right of short preedit
    let emptyRight = NSPoint(x: origin.x + shortLayout.preeditRect.minX + shortLayout.preeditTextWidth + 30, y: origin.y + shortLayout.preeditRect.midY)
    XCTAssertEqual(SquirrelGridLayoutEngine.hitTest(point: emptyRight, contentOrigin: origin, layout: shortLayout), .none)

    // Hit expand button
    if let btn = shortLayout.expandButtonRect {
      let btnPoint = NSPoint(x: origin.x + btn.midX, y: origin.y + btn.midY)
      XCTAssertEqual(SquirrelGridLayoutEngine.hitTest(point: btnPoint, contentOrigin: origin, layout: shortLayout), .toggleExpand)
    } else {
      XCTFail("Expected expandButtonRect")
    }
  }
}
