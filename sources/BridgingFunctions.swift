//
//  BridgingFunctions.swift
//  Squirrel
//
//  Created by Leo Liu on 5/11/24.
//

import Foundation

protocol DataSizeable {
  // swiftlint:disable:next identifier_name
  var data_size: Int32 { get set }
}

extension RimeContext_stdbool: DataSizeable {}
extension RimeTraits: DataSizeable {}
extension RimeCommit: DataSizeable {}
extension RimeStatus_stdbool: DataSizeable {}
extension RimeModule: DataSizeable {}

extension DataSizeable {
  static func rimeStructInit() -> Self {
    let valuePointer = UnsafeMutablePointer<Self>.allocate(capacity: 1)
    memset(valuePointer, 0, MemoryLayout<Self>.size)
    var value = valuePointer.move()
    valuePointer.deallocate()
    let offset = MemoryLayout.size(ofValue: \Self.data_size)
    value.data_size = Int32(MemoryLayout<Self>.size - offset)
    return value
  }

  mutating func setCString(_ swiftString: String, to keypath: WritableKeyPath<Self, UnsafePointer<CChar>?>) {
    swiftString.withCString { cStr in
      // Rime traits keep C string pointers after this closure returns.
      let mutableCStr = strdup(cStr)
      if let existing = self[keyPath: keypath] {
        free(UnsafeMutableRawPointer(mutating: existing))
      }
      self[keyPath: keypath] = UnsafePointer(mutableCStr)
    }
  }
}

