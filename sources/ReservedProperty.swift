//
//  ReservedProperty.swift
//  Squirrel
//

import Foundation

// Reserved librime properties for plugin-to-frontend coordination. Values use
// URL-style query strings; bare values are stored under "value" for compatibility
// with historical comma-list payloads. See rime/squirrel#1124.
enum ReservedPropertyKey: String {
  case commentHighlight = "_comment_highlight"
  case commentWarning = "_comment_warning"
  case refreshUI = "_refresh_ui"
}

struct ReservedPropertyValue {
  let fields: [String: String]

  static let defaultField = "value"

  static let empty = ReservedPropertyValue(fields: [:])

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
