// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - Root Extensions

// Extend the RangeReplaceableCollection to allow it clean duplicated characters.
// Ref: https://stackoverflow.com/questions/25738817/
public extension RangeReplaceableCollection where Element: Hashable {
  var deduplicated: Self {
    var set = Set<Element>()
    return filter { set.insert($0).inserted }
  }
}

// MARK: - String charComponents Extension

public extension String {
  var charComponents: [String] { map { String($0) } }
}

public extension Array where Element == String.Element {
  var charComponents: [String] { map { String($0) } }
}

// MARK: - String Tildes Expansion Extension

public extension String {
  var expandingTildeInPath: String {
    (self as NSString).expandingTildeInPath
  }
}

// MARK: - String Localized Error Extension

extension String: LocalizedError {
  public var errorDescription: String? {
    self
  }
}

// MARK: - Ensuring trailing slash of a string

public extension String {
  mutating func ensureTrailingSlash() {
    if !hasSuffix("/") {
      self += "/"
    }
  }
}

// MARK: - CharCode printability check

// Ref: https://forums.swift.org/t/57085/5
public extension UniChar {
  var isPrintable: Bool {
    guard Unicode.Scalar(UInt32(self)) != nil else {
      struct NotAWholeScalar: Error {}
      return false
    }
    return true
  }

  var isPrintableASCII: Bool {
    (32 ... 126).contains(self)
  }
}

// MARK: - Stable Sort Extension

// Ref: https://stackoverflow.com/a/50545761/4162914
public extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  func stableSort(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}

// MARK: - Return toggled value.

public extension Bool {
  mutating func toggled() -> Bool {
    toggle()
    return self
  }
}

// MARK: - Property wrapper

// Ref: https://www.avanderlee.com/swift/property-wrappers/

@propertyWrapper
public struct AppProperty<Value> {
  public let key: String
  public let defaultValue: Value
  public var container: UserDefaults = .standard
  public init(key: String, defaultValue: Value) {
    self.key = key
    self.defaultValue = defaultValue
    if container.object(forKey: key) == nil {
      container.set(defaultValue, forKey: key)
    }
  }

  public var wrappedValue: Value {
    get {
      container.object(forKey: key) as? Value ?? defaultValue
    }
    set {
      container.set(newValue, forKey: key)
    }
  }
}
