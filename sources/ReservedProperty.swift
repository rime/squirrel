//
//  ReservedProperty.swift
//  Squirrel
//
//  Reserved librime properties for plugin -> frontend coordination.
//  See rime/squirrel#1124.
//
//  Values use URL-style query strings. Bare values are stored under
//  "value" for compatibility with historical comma-list payloads.

import Foundation

/// Reserved property keys recognised by Squirrel.
enum ReservedPropertyKey: String {
  /// Candidate comment indices using `accent_text_color`.
  case commentHighlight = "_comment_highlight"

  /// Candidate comment indices using `warning_text_color`.
  case commentWarning = "_comment_warning"

  /// Requests a candidate panel refresh.
  case refreshUI = "_refresh_ui"
}

/// Parsed reserved-property fields.
struct ReservedPropertyValue {
  let fields: [String: String]

  /// Field used for bare values and index lists.
  static let defaultField = "value"

  static let empty = ReservedPropertyValue(fields: [:])

  /// Parses query strings or bare values written by plugins.
  static func parse(_ raw: String) throws(ReservedPropertyError) -> ReservedPropertyValue {
    guard !raw.isEmpty else { throw .emptyInput }
    if !raw.contains("=") {
      return ReservedPropertyValue(fields: [defaultField: raw])
    }
    // URLComponents needs a scheme-less URL with a leading "?".
    if let queryItems = URLComponents(string: "?\(raw)")?.queryItems {
      let pairs = queryItems.map { ($0.name, $0.value ?? "") }
      let dict = Dictionary(pairs, uniquingKeysWith: { _, new in new })
      return ReservedPropertyValue(fields: dict)
    }
    throw .unknownInput(raw)
  }

  /// Extracts non-negative indices from the `value` field.
  func indices() throws(ReservedPropertyError) -> Set<Int> {
    guard let raw = fields[Self.defaultField] else { throw .missingDefaultFields }
    var out = Set<Int>()
    for part in raw.split(separator: ",") {
      let trimmed = part.trimmingCharacters(in: .whitespaces)
      if let index = Int(trimmed), index >= 0 {
        out.insert(index)
      } else {
        throw .invalidIndex(trimmed)
      }
    }
    return out
  }
}

enum ReservedPropertyError: Error {
  case emptyInput
  case unknownInput(String)
  case missingDefaultFields
  case invalidIndex(String)
}
