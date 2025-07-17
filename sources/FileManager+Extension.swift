//
//  FileManager+Extension.swift
//  Squirrel
//
//  Created by mi on 2024/12/1.
//

import Foundation

extension FileManager {
  func createDirIfNotExist(path: URL) {
    if !fileExists(atPath: path.path()) {
      do {
        try createDirectory(at: path, withIntermediateDirectories: true)
      } catch {
        print("Error creating user data directory: \(path.path())")
      }
    }
  }
}
