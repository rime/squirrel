import XCTest
import AppKit

private final class MockSquirrelConfig: SquirrelConfigReading {
  var bools: [String: Bool] = [:]
  var ints: [String: Int] = [:]
  var doubles: [String: CGFloat] = [:]
  var strings: [String: String] = [:]
  var colors: [String: String] = [:]

  func getBool(_ option: String) -> Bool? { bools[option] }
  func getInt(_ option: String) -> Int? { ints[option] }
  func getDouble(_ option: String) -> CGFloat? { doubles[option] }
  func getString(_ option: String) -> String? { strings[option] }
  func getColor(_ option: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    guard let raw = colors[option] else { return nil }
    return SquirrelColorParser.color(from: raw, inSpace: colorSpace)
  }
}

final class SquirrelConfigAndThemeTests: XCTestCase {
  func testColorParserSupportsHexFormats() {
    let rgb = SquirrelColorParser.color(from: "0xFF8800", inSpace: .sRGB)?.usingColorSpace(.sRGB)
    XCTAssertNotNil(rgb)
    XCTAssertEqual(rgb?.redComponent ?? -1, 0.0, accuracy: 0.01)
    XCTAssertEqual(rgb?.greenComponent ?? -1, 0x88 / 255.0, accuracy: 0.01)
    XCTAssertEqual(rgb?.blueComponent ?? -1, 1.0, accuracy: 0.01)
    XCTAssertEqual(rgb?.alphaComponent ?? -1, 1.0, accuracy: 0.01)

    let argbP3 = SquirrelColorParser.color(from: "0x80112233", inSpace: .displayP3)?.usingColorSpace(.displayP3)
    XCTAssertNotNil(argbP3)
    XCTAssertEqual(argbP3?.alphaComponent ?? -1, 0x80 / 255.0, accuracy: 0.01)
    XCTAssertEqual(argbP3?.redComponent ?? -1, 0x33 / 255.0, accuracy: 0.01)

    XCTAssertNil(SquirrelColorParser.color(from: "not_a_color", inSpace: .sRGB))
  }

  func testThemeLoadAppliesGridOverridesAndClamping() {
    let mock = MockSquirrelConfig()
    mock.strings["style/color_scheme"] = "custom"
    mock.bools["style/expandable_grid"] = true
    mock.ints["style/grid_visible_rows"] = 0 // should clamp to >= 1
    mock.ints["style/grid_max_columns"] = -3 // should clamp to >= 0
    mock.strings["preset_color_schemes/custom/grid_row_style"] = "border"
    mock.strings["preset_color_schemes/custom/grid_background_style"] = "solid"
    mock.ints["preset_color_schemes/custom/grid_visible_rows"] = 7
    mock.doubles["preset_color_schemes/custom/corner_radius"] = 8
    mock.colors["preset_color_schemes/custom/hilited_candidate_back_color"] = "0xFF007AFF"

    let theme = SquirrelTheme()
    theme.load(config: mock, dark: false)

    XCTAssertFalse(theme.native)
    XCTAssertTrue(theme.expandableGrid)
    XCTAssertEqual(theme.gridVisibleRows, 7)
    XCTAssertEqual(theme.gridMaxColumns, 0)
    XCTAssertEqual(theme.gridRowStyle, .border)
    XCTAssertEqual(theme.resolvedGridBackgroundStyle, .solid)
    XCTAssertEqual(theme.resolvedGridCornerRadius, 8)

    // Dynamic blended label color resolves cleanly under both Aqua and DarkAqua without crashing.
    let labelColor = theme.labelHighlightedAttrs[.foregroundColor] as? NSColor
    XCTAssertNotNil(labelColor)
    NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
      XCTAssertNotNil(labelColor?.usingColorSpace(.sRGB))
    }
    NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
      XCTAssertNotNil(labelColor?.usingColorSpace(.sRGB))
    }
  }

  func testThemeLoadSupportsGridPagingModeOverride() {
    let defaultTheme = SquirrelTheme()
    XCTAssertFalse(defaultTheme.expandableGrid)
    XCTAssertEqual(defaultTheme.gridPagingMode, .row)

    let globalPageMock = MockSquirrelConfig()
    globalPageMock.strings["style/color_scheme"] = "custom"
    globalPageMock.strings["style/grid_paging_mode"] = "page"
    let globalPageTheme = SquirrelTheme()
    globalPageTheme.load(config: globalPageMock, dark: false)
    XCTAssertEqual(globalPageTheme.gridPagingMode, .page)

    let schemeOverrideMock = MockSquirrelConfig()
    schemeOverrideMock.strings["style/color_scheme"] = "custom"
    schemeOverrideMock.strings["style/grid_paging_mode"] = "page"
    schemeOverrideMock.strings["preset_color_schemes/custom/grid_paging_mode"] = "row"
    let schemeOverrideTheme = SquirrelTheme()
    schemeOverrideTheme.load(config: schemeOverrideMock, dark: false)
    XCTAssertEqual(schemeOverrideTheme.gridPagingMode, .row)
  }

  func testInputPositionTrackerCompensatesStaleAttr0AcrossWindowDrags() {
    var tracker = SquirrelInputPositionTracker()

    // 1. Replay exact dual-monitor TextEdit drag telemetry from macOS 27.2.
    let initialTextEditAttr0 = NSRect(x: -1477, y: 1318, width: 1, height: 14)
    var currentWinTopLeft = CGPoint(x: -1482, y: -315)
    let firstPos = tracker.resolve(
      rawAttr0: initialTextEditAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { (windowID: 17926, quartzTopLeft: currentWinTopLeft) },
      lookupWindowTopLeft: { _ in currentWinTopLeft }
    )
    XCTAssertEqual(firstPos, initialTextEditAttr0)

    currentWinTopLeft = CGPoint(x: -1119, y: 189)
    let drag1Pos = tracker.resolve(
      rawAttr0: initialTextEditAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { nil },
      lookupWindowTopLeft: { _ in currentWinTopLeft }
    )
    XCTAssertEqual(drag1Pos, NSRect(x: -1114, y: 814, width: 1, height: 14))

    currentWinTopLeft = CGPoint(x: -2226, y: 263)
    let drag2Pos = tracker.resolve(
      rawAttr0: initialTextEditAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { nil },
      lookupWindowTopLeft: { _ in currentWinTopLeft }
    )
    XCTAssertEqual(drag2Pos, NSRect(x: -2221, y: 740, width: 1, height: 14))

    currentWinTopLeft = CGPoint(x: -2296, y: -438)
    let drag3Pos = tracker.resolve(
      rawAttr0: initialTextEditAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { nil },
      lookupWindowTopLeft: { _ in currentWinTopLeft }
    )
    XCTAssertEqual(drag3Pos, NSRect(x: -2291, y: 1441, width: 1, height: 14))

    // 2. Replay exact Antigravity (Electron) drag telemetry.
    tracker.reset()
    let initialElectronAttr0 = NSRect(x: -1868, y: 626, width: 1, height: 18)
    var electronWinTopLeft = CGPoint(x: -2450, y: -448)
    _ = tracker.resolve(
      rawAttr0: initialElectronAttr0,
      bundleID: "com.google.antigravity",
      hasActiveComposition: true,
      findWindowAtAttr0: { (windowID: 7075, quartzTopLeft: electronWinTopLeft) },
      lookupWindowTopLeft: { _ in electronWinTopLeft }
    )
    electronWinTopLeft = CGPoint(x: -2147, y: -265)
    let electronDragged = tracker.resolve(
      rawAttr0: initialElectronAttr0,
      bundleID: "com.google.antigravity",
      hasActiveComposition: true,
      findWindowAtAttr0: { nil },
      lookupWindowTopLeft: { _ in electronWinTopLeft }
    )
    XCTAssertEqual(electronDragged, NSRect(x: -1565, y: 443, width: 1, height: 18))

    // 3. When rawAttr0 itself updates, re-anchor without double-applying offset.
    let updatedAttr0 = NSRect(x: -1565, y: 444, width: 1, height: 17)
    let reanchored = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.google.antigravity",
      hasActiveComposition: true,
      findWindowAtAttr0: { (windowID: 7075, quartzTopLeft: electronWinTopLeft) },
      lookupWindowTopLeft: { _ in electronWinTopLeft }
    )
    XCTAssertEqual(reanchored, updatedAttr0)

    // 4. Inactive composition resets anchor and returns rawAttr0.
    let inactive = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.google.antigravity",
      hasActiveComposition: false,
      findWindowAtAttr0: { (windowID: 7075, quartzTopLeft: electronWinTopLeft) },
      lookupWindowTopLeft: { _ in electronWinTopLeft }
    )
    XCTAssertEqual(inactive, updatedAttr0)
    XCTAssertNil(tracker.anchor)

    // 5. Missing host window leaves anchor nil and caches negative lookup for identical (attr0, bundleID).
    var lookupCount = 0
    let noHost = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.unknown.app",
      hasActiveComposition: true,
      findWindowAtAttr0: {
        lookupCount += 1
        return nil
      },
      lookupWindowTopLeft: { _ in nil }
    )
    XCTAssertEqual(noHost, updatedAttr0)
    XCTAssertNil(tracker.anchor)
    XCTAssertEqual(lookupCount, 1)

    _ = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.unknown.app",
      hasActiveComposition: true,
      findWindowAtAttr0: {
        lookupCount += 1
        return nil
      },
      lookupWindowTopLeft: { _ in nil }
    )
    XCTAssertEqual(lookupCount, 1)

    // Changing rawAttr0 invalidates negative lookup cache.
    let shiftedAttr0 = NSRect(x: -1560, y: 444, width: 1, height: 17)
    _ = tracker.resolve(
      rawAttr0: shiftedAttr0,
      bundleID: "com.unknown.app",
      hasActiveComposition: true,
      findWindowAtAttr0: {
        lookupCount += 1
        return nil
      },
      lookupWindowTopLeft: { _ in nil }
    )
    XCTAssertEqual(lookupCount, 2)

    // 6. Closed host window (lookupWindowTopLeft returns nil) clears anchor.
    tracker.reset()
    var windowOpen = true
    _ = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { (windowID: 42, quartzTopLeft: CGPoint(x: 100, y: 100)) },
      lookupWindowTopLeft: { _ in windowOpen ? CGPoint(x: 100, y: 100) : nil }
    )
    XCTAssertNotNil(tracker.anchor)
    windowOpen = false
    let afterClose = tracker.resolve(
      rawAttr0: updatedAttr0,
      bundleID: "com.apple.TextEdit",
      hasActiveComposition: true,
      findWindowAtAttr0: { nil },
      lookupWindowTopLeft: { _ in nil }
    )
    XCTAssertEqual(afterClose, updatedAttr0)
    XCTAssertNil(tracker.anchor)
  }

  func testSelectHostWindowFiltersTransparentAndPrefersFrontmostFloatingOverBackground() {
    let caret = CGPoint(x: 200, y: 200)
    let entries = [
      // Transparent overlay window (must be skipped)
      SquirrelInputPositionTracker.WindowEntry(windowID: 1, ownerPID: 100, bounds: CGRect(x: 0, y: 0, width: 800, height: 800), layer: 0, alpha: 0.0),
      // Desktop-level window (must be skipped)
      SquirrelInputPositionTracker.WindowEntry(windowID: 2, ownerPID: 100, bounds: CGRect(x: 0, y: 0, width: 800, height: 800), layer: -1, alpha: 1.0),
      // Frontmost floating input panel (layer 3)
      SquirrelInputPositionTracker.WindowEntry(windowID: 3, ownerPID: 100, bounds: CGRect(x: 150, y: 150, width: 300, height: 120), layer: 3, alpha: 1.0),
      // Background normal window (layer 0) behind the floating panel
      SquirrelInputPositionTracker.WindowEntry(windowID: 4, ownerPID: 100, bounds: CGRect(x: 50, y: 50, width: 800, height: 600), layer: 0, alpha: 1.0)
    ]

    let selected = SquirrelInputPositionTracker.selectHostWindow(
      from: entries,
      targetPIDs: [100],
      caretQuartzPoint: caret
    )
    XCTAssertEqual(selected?.windowID, 3)
    XCTAssertEqual(selected?.quartzTopLeft, CGPoint(x: 150, y: 150))
  }
}
