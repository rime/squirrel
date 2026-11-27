//
//  SquirrelGridModels.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

struct SquirrelGridCandidate: Equatable {
  let globalIndex: Int
  let text: String
  let comment: String
}

struct SquirrelGridCell {
  let globalIndex: Int
  let cellIndexInRow: Int
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

struct SquirrelGridPackedRows {
  let allRows: [SquirrelGridRow]
  let hasHiddenCollapsedCandidates: Bool
  let totalGridWidth: CGFloat
  let isExpanded: Bool
  let maxColumns: Int
  let expandedColumns: Int
  let candidateCount: Int
}

struct SquirrelGridPackConfig {
  let maxColumns: Int
  let expandedColumns: Int
  let isExpanded: Bool
  let targetGridWidth: CGFloat
  let maxRowWidth: CGFloat
  let unitRefWidth: CGFloat
  let colGap: CGFloat
}

struct SquirrelGridLayoutBuildInput {
  let compositionID: Int
  let preedit: String
  let selRange: NSRange
  let selectLabels: [String]
  let activeRow: Int
  let activeCellIndexInRow: Int
  let viewportTopRow: Int
  let hoveredGlobalIndex: Int?
  let hasMore: Bool
  let specialCommentIndices: [ReservedPropertyKey: Set<Int>]
  let theme: SquirrelTheme
  let maxRowWidth: CGFloat
  let outerPadX: CGFloat
  let outerPadY: CGFloat
  let cellPadX: CGFloat
  let cellPadY: CGFloat
  let rowGap: CGFloat
  let rowBorderInsetX: CGFloat
  let rowBorderInsetY: CGFloat
  let chevronSlotWidth: CGFloat
}

struct SquirrelGridLayout {
  let compositionID: Int
  let isExpanded: Bool
  let usePillTextMask: Bool
  let allRows: [SquirrelGridRow]
  let visibleRows: [SquirrelGridRow]
  let viewportTopRow: Int
  let activeRow: Int
  let activeCellIndexInRow: Int
  let panelSize: NSSize
  let preeditAttributedString: NSAttributedString?
  let preeditRect: NSRect
  let preeditTextWidth: CGFloat
  let preeditHighlightedRect: NSRect
  let gridContentRect: NSRect
  let rowDividerRects: [NSRect]
  let activeRowRect: NSRect
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
