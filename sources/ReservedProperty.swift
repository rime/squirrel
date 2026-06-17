//
//  ReservedProperty.swift
//  Squirrel
//
//  Cross-frontend protocol for plugin -> frontend coordination over
//  librime's notification_handler. See rime/squirrel#1124.
//
//  ┌──────────────────────────── flow ────────────────────────────┐
//  │ Plugin   ctx->set_property("_<key>", "<value>")              │
//  │ librime  notification_handler(type:"property",               │
//  │                                value:"_<key>=<value>")       │
//  │ Squirrel ApplicationDelegate parses prefix → dispatches to   │
//  │          the active InputController via handleReservedProperty│
//  └──────────────────────────────────────────────────────────────┘
//
//  The leading-underscore namespace marks the key as part of this
//  reserved protocol. Plugin-private keys SHOULD use a "<plugin>/key"
//  namespace instead so they will never collide with reserved keys.
//
//  Value encoding: URL-style query string (RFC 3986 application/x-www-
//  form-urlencoded). Picked over JSON / YAML because:
//    - Builtin parser is available on every target frontend
//      (Swift URLComponents / Win HTTP / Lua / C++ Boost)
//    - weasel previously used JSON for IPC and dropped it on
//      performance grounds (rime/squirrel#1124, fxliang 2026-05-27)
//    - Forward-compatible: unknown fields are preserved and ignored
//
//  Backward-compatible shorthand:
//    A bare value without "=" is treated as { "indices": "<value>" },
//    so the historical "_comment_highlight=0,2" form still works.

import Foundation

/// Reserved property keys recognised by Squirrel. Plugins targeting any
/// Rime frontend should only use keys listed here; unrecognised "_*"
/// keys are silently ignored so the table can grow without breaking
/// older Squirrel builds.
enum ReservedPropertyKey: String {
  /// State - candidates at these indices should render their comment
  /// with `accent_text_color` from the active color scheme.
  /// Fields: `indices` (comma-separated non-negative integers)
  case commentHighlight = "_comment_highlight"

  /// State - candidates at these indices should render their comment
  /// with `warning_text_color` from the active color scheme.
  /// Fields: `indices` (comma-separated non-negative integers)
  case commentWarning = "_comment_warning"

  /// Action - the candidate panel should be refreshed because an async
  /// task (network / inference / ...) has produced new candidates.
  /// Optional fields: `source` (plugin codename), `kind` (full|partial)
  case refreshUI = "_refresh_ui"

  /// `true` when the key represents a one-shot action that should be
  /// applied and forgotten. `false` when it represents a piece of
  /// composition-scoped state that sticks until the next overwrite.
  var isAction: Bool {
    switch self {
    case .refreshUI:
      return true
    case .commentHighlight, .commentWarning:
      return false
    }
  }
}

/// Parsed representation of a reserved-property value.
///
/// Use `fields[name]` for a single scalar (e.g. `source`, `kind`) and
/// `indices()` for the conventional comma-separated non-negative integer
/// list that several keys carry.
struct ReservedPropertyValue {
  let fields: [String: String]

  static let empty = ReservedPropertyValue(fields: [:])

  /// Parses raw value strings written by plugins.
  ///
  /// Accepts two shapes:
  ///   1. URL-style query string: `indices=0,2&source=ai_predict`
  ///   2. Bare comma list: `0,2` (normalised to `indices=0,2`)
  ///
  /// Both shapes round-trip through the same `fields[name]` API so
  /// callers never need to know which one the plugin used.
  static func parse(_ raw: String) -> ReservedPropertyValue {
    guard !raw.isEmpty else { return .empty }
    if !raw.contains("=") {
      return ReservedPropertyValue(fields: ["indices": raw])
    }
    // URLComponents needs a scheme-less URL with a leading "?".
    guard let queryItems = URLComponents(string: "?\(raw)")?.queryItems else {
      return .empty
    }
    let pairs = queryItems.map { ($0.name, $0.value ?? "") }
    let dict = Dictionary(pairs, uniquingKeysWith: { _, new in new })
    return ReservedPropertyValue(fields: dict)
  }

  /// Extracts a non-negative integer index list from the conventional
  /// `indices` field. Whitespace and malformed entries are skipped so
  /// stray spaces in hand-written plugin code don't break rendering.
  func indices() -> Set<Int> {
    guard let raw = fields["indices"] else { return [] }
    var out = Set<Int>()
    for part in raw.split(separator: ",") {
      let trimmed = part.trimmingCharacters(in: .whitespaces)
      if let n = Int(trimmed), n >= 0 {
        out.insert(n)
      }
    }
    return out
  }
}
