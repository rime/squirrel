//
//  BridgingFunctions.swift
//  Squirrel
//
//  Created by Leo Liu on 5/11/24.
//

import Foundation

protocol DataSizeable {
    var data_size: Int32 { get set }
}

extension RimeContext: DataSizeable {}
extension RimeTraits: DataSizeable {}
extension RimeCommit: DataSizeable {}
extension RimeStatus: DataSizeable {}
extension RimeModule: DataSizeable {}

extension DataSizeable {
  static func rimeStructInit() -> Self {
    let valuePointer = UnsafeMutablePointer<Self>.allocate(capacity: 1)
    // Initialize the memory to zero
    memset(valuePointer, 0, MemoryLayout<Self>.size)
    // Convert the pointer to a managed Swift variable
    var value = valuePointer.move()
    valuePointer.deallocate()
    // Initialize data_size property
    let offset = MemoryLayout.size(ofValue: \Self.data_size)
    value.data_size = Int32(MemoryLayout<Self>.size - offset)
    return value
  }
}
