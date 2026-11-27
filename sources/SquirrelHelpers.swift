//
//  SquirrelHelpers.swift
//  Squirrel
//
//  Created by Leo Liu on 5/11/24.
//

import Foundation
import CoreGraphics

infix operator ?= : AssignmentPrecedence
// swiftlint:disable:next operator_whitespace
func ?=<T>(left: inout T, right: T?) {
  if let right = right {
    left = right
  }
}
// swiftlint:disable:next operator_whitespace
func ?=<T>(left: inout T?, right: T?) {
  if let right = right {
    left = right
  }
}

extension NSRange {
  static let empty = NSRange(location: NSNotFound, length: 0)
}

extension NSPoint {
  static func += (lhs: inout Self, rhs: Self) {
    lhs.x += rhs.x
    lhs.y += rhs.y
  }
  static func - (lhs: Self, rhs: Self) -> Self {
    Self.init(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
  static func -= (lhs: inout Self, rhs: Self) {
    lhs.x -= rhs.x
    lhs.y -= rhs.y
  }
  static func * (lhs: Self, rhs: CGFloat) -> Self {
    Self.init(x: lhs.x * rhs, y: lhs.y * rhs)
  }
  static func / (lhs: Self, rhs: CGFloat) -> Self {
    Self.init(x: lhs.x / rhs, y: lhs.y / rhs)
  }
  var length: CGFloat {
    sqrt(pow(self.x, 2) + pow(self.y, 2))
  }
}

struct SquirrelInputPositionTracker {
  struct Anchor: Equatable {
    let attr0: NSRect
    let windowID: CGWindowID
    let quartzTopLeft: CGPoint
    let bundleID: String
  }

  struct WindowEntry {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let bounds: CGRect
    let layer: Int
    let alpha: Double
  }

  private(set) var anchor: Anchor?
  private var failedLookup: (attr0: NSRect, bundleID: String)?

  mutating func reset() {
    anchor = nil
    failedLookup = nil
  }

  static func selectHostWindow(
    from entries: [WindowEntry],
    targetPIDs: Set<pid_t>,
    caretQuartzPoint: CGPoint
  ) -> (windowID: CGWindowID, quartzTopLeft: CGPoint)? {
    var fallbackMatch: (windowID: CGWindowID, quartzTopLeft: CGPoint)?
    for entry in entries {
      guard targetPIDs.contains(entry.ownerPID),
            entry.alpha > 0.01,
            entry.layer >= 0,
            entry.bounds.width > 50,
            entry.bounds.height > 50,
            entry.bounds.insetBy(dx: -12, dy: -12).contains(caretQuartzPoint) else {
        continue
      }
      let candidate = (windowID: entry.windowID, quartzTopLeft: entry.bounds.origin)
      if entry.layer <= 25 {
        return candidate
      }
      if fallbackMatch == nil {
        fallbackMatch = candidate
      }
    }
    return fallbackMatch
  }

  mutating func resolve(
    rawAttr0: NSRect,
    bundleID: String,
    hasActiveComposition: Bool,
    findWindowAtAttr0: () -> (windowID: CGWindowID, quartzTopLeft: CGPoint)?,
    lookupWindowTopLeft: (CGWindowID) -> CGPoint?
  ) -> NSRect {
    guard hasActiveComposition,
          !rawAttr0.isNull, !rawAttr0.isInfinite,
          rawAttr0.origin.x.isFinite, rawAttr0.origin.y.isFinite,
          rawAttr0 != .zero else {
      anchor = nil
      failedLookup = nil
      return rawAttr0
    }

    if let existing = anchor, existing.bundleID == bundleID, existing.attr0 == rawAttr0 {
      if let currentTopLeft = lookupWindowTopLeft(existing.windowID) {
        let deltaX = currentTopLeft.x - existing.quartzTopLeft.x
        let deltaY = -(currentTopLeft.y - existing.quartzTopLeft.y)
        if deltaX.isFinite, deltaY.isFinite, abs(deltaX) > 0.5 || abs(deltaY) > 0.5 {
          return rawAttr0.offsetBy(dx: deltaX, dy: deltaY)
        }
        return rawAttr0
      } else {
        anchor = nil
        failedLookup = (rawAttr0, bundleID)
        return rawAttr0
      }
    }

    if let failed = failedLookup, failed.bundleID == bundleID, failed.attr0 == rawAttr0 {
      return rawAttr0
    }

    if let hostWin = findWindowAtAttr0() {
      anchor = Anchor(
        attr0: rawAttr0,
        windowID: hostWin.windowID,
        quartzTopLeft: hostWin.quartzTopLeft,
        bundleID: bundleID
      )
      failedLookup = nil
    } else {
      anchor = nil
      failedLookup = (rawAttr0, bundleID)
    }
    return rawAttr0
  }
}
