//
//  SquirrelColorParser.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import AppKit

protocol SquirrelConfigReading {
  func getBool(_ option: String) -> Bool?
  func getInt(_ option: String) -> Int?
  func getDouble(_ option: String) -> CGFloat?
  func getString(_ option: String) -> String?
  func getColor(_ option: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor?
}

enum SquirrelColorParser {
  static func color(from colorStr: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    let trimmed = colorStr.trimmingCharacters(in: .whitespacesAndNewlines)
    if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      let (_, alpha, blue, green, red) = matched.output
      return makeColor(alpha: Int(alpha, radix: 16)!, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!, blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    } else if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      let (_, blue, green, red) = matched.output
      return makeColor(alpha: 255, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!, blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    } else {
      return nil
    }
  }

  private static func makeColor(alpha: Int, red: Int, green: Int, blue: Int, colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor {
    switch colorSpace {
    case .displayP3:
      return NSColor(displayP3Red: CGFloat(red) / 255,
                     green: CGFloat(green) / 255,
                     blue: CGFloat(blue) / 255,
                     alpha: CGFloat(alpha) / 255)
    case .sRGB:
      return NSColor(srgbRed: CGFloat(red) / 255,
                     green: CGFloat(green) / 255,
                     blue: CGFloat(blue) / 255,
                     alpha: CGFloat(alpha) / 255)
    }
  }
}
