//
//  SquirrelColor.swift
//  Squirrel
//
//  Created by Squirrel contributors.
//

import AppKit

struct ColorStop {
  let color: NSColor
  let location: CGFloat
}

enum GradientKind {
  case linear(angle: CGFloat)
  case radial(center: CGPoint)
  case conic(angle: CGFloat)
}

enum ThemeFill {
  case solid(NSColor)
  case gradient(GradientKind, [ColorStop])
}

private struct RawStop {
  let color: NSColor
  let location: CGFloat?
}

// MARK: - Value helpers

extension ThemeFill {
  var isGradient: Bool {
    if case .gradient = self {
      return true
    }
    return false
  }

  /// A single color for consumers that cannot render a gradient (text blending, paging arrows, fallbacks).
  var representativeColor: NSColor {
    switch self {
    case .solid(let color):
      return color
    case .gradient(_, let stops):
      return Self.sample(stops, at: 0.5)
    }
  }

  static func sample(_ stops: [ColorStop], at position: CGFloat) -> NSColor {
    guard let first = stops.first, let last = stops.last else { return .clear }
    if position <= first.location { return first.color }
    if position >= last.location { return last.color }
    for index in 1..<stops.count where position <= stops[index].location {
      let left = stops[index - 1]
      let right = stops[index]
      let span = right.location - left.location
      let ratio = span > 0 ? (position - left.location) / span : 0
      return blend(left.color, right.color, ratio: ratio)
    }
    return last.color
  }

  private static func blend(_ left: NSColor, _ right: NSColor, ratio: CGFloat) -> NSColor {
    let leftColor = left.usingColorSpace(.sRGB) ?? left
    let rightColor = right.usingColorSpace(.sRGB) ?? right
    return NSColor(srgbRed: leftColor.redComponent + (rightColor.redComponent - leftColor.redComponent) * ratio,
                   green: leftColor.greenComponent + (rightColor.greenComponent - leftColor.greenComponent) * ratio,
                   blue: leftColor.blueComponent + (rightColor.blueComponent - leftColor.blueComponent) * ratio,
                   alpha: leftColor.alphaComponent + (rightColor.alphaComponent - leftColor.alphaComponent) * ratio)
  }
}

// MARK: - Parsing

extension ThemeFill {
  /// Parses either a plain Rime color (`0xAABBGGRR`) or a CSS-like gradient expression.
  static func parse(_ string: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> ThemeFill? {
    if let solid = RimeColorParser.color(from: string, inSpace: colorSpace) {
      return .solid(solid)
    }
    let lowered = string.lowercased()
    guard let matched = try? /^\s*(linear|radial|conic)-gradient\s*\(\s*(.+?)\s*\)\s*$/.wholeMatch(in: lowered) else {
      return nil
    }
    let kindName = String(matched.output.1)
    var segments = String(matched.output.2).split(separator: ",").map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !segments.isEmpty else { return nil }

    var kind = defaultKind(kindName)
    if let first = segments.first, parseStop(first, inSpace: colorSpace) == nil {
      kind = parseDirection(first, kindName: kindName) ?? kind
      segments.removeFirst()
    }

    let rawStops = segments.compactMap { parseStop($0, inSpace: colorSpace) }
    let stops = normalize(rawStops)
    if stops.count == 1, let only = stops.first {
      return .solid(only.color)
    }
    guard stops.count >= 2 else { return nil }
    return .gradient(kind, stops)
  }

  private static func defaultKind(_ name: String) -> GradientKind {
    switch name {
    case "radial":
      return .radial(center: CGPoint(x: 0.5, y: 0.5))
    case "conic":
      return .conic(angle: 0)
    default:
      return .linear(angle: 180)
    }
  }

  private static func parseDirection(_ segment: String, kindName: String) -> GradientKind? {
    switch kindName {
    case "linear":
      if let angle = parseAngle(segment) {
        return .linear(angle: angle)
      }
      if let angle = parseSideKeywords(segment) {
        return .linear(angle: angle)
      }
      return nil
    case "radial":
      return .radial(center: parseCenter(segment))
    case "conic":
      return .conic(angle: parseAngle(segment) ?? 0)
    default:
      return nil
    }
  }

  private static func parseStop(_ segment: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> RawStop? {
    let tokens = segment.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    guard let colorToken = tokens.first, let color = RimeColorParser.color(from: colorToken, inSpace: colorSpace) else {
      return nil
    }
    var location: CGFloat?
    if tokens.count > 1, let percent = parsePercent(tokens[1]) {
      location = percent
    }
    return RawStop(color: color, location: location)
  }

  private static func parseAngle(_ segment: String) -> CGFloat? {
    let trimmed = segment.trimmingCharacters(in: .whitespaces)
    guard let matched = try? /^([+-]?\d+(?:\.\d+)?)\s*(deg|grad|rad|turn)?$/.wholeMatch(in: trimmed) else {
      return nil
    }
    guard let value = Double(matched.output.1) else { return nil }
    switch matched.output.2.map({ String($0) }) ?? "" {
    case "turn":
      return CGFloat(value * 360)
    case "rad":
      return CGFloat(value * 180 / Double.pi)
    case "grad":
      return CGFloat(value * 0.9)
    default:
      return CGFloat(value)
    }
  }

  private static func parseSideKeywords(_ segment: String) -> CGFloat? {
    guard segment.hasPrefix("to ") else { return nil }
    let side = segment.dropFirst(3)
    let hasTop = side.contains("top")
    let hasBottom = side.contains("bottom")
    let hasLeft = side.contains("left")
    let hasRight = side.contains("right")
    if hasTop && hasRight { return 45 }
    if hasBottom && hasRight { return 135 }
    if hasBottom && hasLeft { return 225 }
    if hasTop && hasLeft { return 315 }
    if hasTop { return 0 }
    if hasRight { return 90 }
    if hasBottom { return 180 }
    if hasLeft { return 270 }
    return nil
  }

  private static func parseCenter(_ segment: String) -> CGPoint {
    guard let atRange = segment.range(of: "at ") else { return CGPoint(x: 0.5, y: 0.5) }
    let values = segment[atRange.upperBound...].split(separator: " ").compactMap { parsePercent(String($0)) }
    if values.count >= 2 { return CGPoint(x: values[0], y: values[1]) }
    if values.count == 1 { return CGPoint(x: values[0], y: 0.5) }
    return CGPoint(x: 0.5, y: 0.5)
  }

  private static func parsePercent(_ token: String) -> CGFloat? {
    let trimmed = token.trimmingCharacters(in: .whitespaces)
    guard let matched = try? /^([+-]?\d+(?:\.\d+)?)\s*%?$/.wholeMatch(in: trimmed),
          let value = Double(matched.output.1) else {
      return nil
    }
    return CGFloat(value) / 100
  }

  private static func normalize(_ rawStops: [RawStop]) -> [ColorStop] {
    guard !rawStops.isEmpty else { return [] }
    var locations = rawStops.map { $0.location }
    if locations[0] == nil { locations[0] = 0 }
    if locations[locations.count - 1] == nil { locations[locations.count - 1] = 1 }
    var index = 0
    while index < locations.count {
      guard locations[index] == nil else {
        index += 1
        continue
      }
      var end = index
      while end < locations.count && locations[end] == nil { end += 1 }
      let startLocation = locations[index - 1] ?? 0
      let endLocation = end < locations.count ? (locations[end] ?? 1) : 1
      let segmentCount = CGFloat(end - index + 1)
      for offset in index..<end {
        locations[offset] = startLocation + (endLocation - startLocation) * CGFloat(offset - index + 1) / segmentCount
      }
      index = end
    }
    var stops = rawStops.enumerated().map { item in
      ColorStop(color: item.element.color, location: min(1, max(0, locations[item.offset] ?? 0)))
    }
    stops.sort { $0.location < $1.location }
    for offset in 1..<stops.count where stops[offset].location < stops[offset - 1].location {
      stops[offset] = ColorStop(color: stops[offset].color, location: stops[offset - 1].location)
    }
    return stops
  }
}

// MARK: - Color parsing

enum RimeColorParser {
  /// Accepts Rime's `0xAABBGGRR` / `0xBBGGRR` (ABGR order) and CSS `#RGB` / `#RGBA` / `#RRGGBB` / `#RRGGBBAA`.
  static func color(from colorStr: String, inSpace colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor? {
    let trimmed = colorStr.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.lowercased() == "transparent" {
      return color(alpha: 0, red: 0, green: 0, blue: 0, colorSpace: colorSpace)
    }
    if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      let (_, alpha, blue, green, red) = matched.output
      return color(alpha: Int(alpha, radix: 16)!, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!,
                   blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    }
    if let matched = try? /0x([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      let (_, blue, green, red) = matched.output
      return color(alpha: 255, red: Int(red, radix: 16)!, green: Int(green, radix: 16)!,
                   blue: Int(blue, radix: 16)!, colorSpace: colorSpace)
    }
    if let matched = try? /#([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      return color(alpha: Int(matched.output.4, radix: 16)!, red: Int(matched.output.1, radix: 16)!,
                   green: Int(matched.output.2, radix: 16)!, blue: Int(matched.output.3, radix: 16)!,
                   colorSpace: colorSpace)
    }
    if let matched = try? /#([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})([A-Fa-f0-9]{2})/.wholeMatch(in: trimmed) {
      return color(alpha: 255, red: Int(matched.output.1, radix: 16)!,
                   green: Int(matched.output.2, radix: 16)!, blue: Int(matched.output.3, radix: 16)!,
                   colorSpace: colorSpace)
    }
    if let matched = try? /#([A-Fa-f0-9])([A-Fa-f0-9])([A-Fa-f0-9])([A-Fa-f0-9])/.wholeMatch(in: trimmed) {
      return color(alpha: Int(matched.output.4, radix: 16)! * 17, red: Int(matched.output.1, radix: 16)! * 17,
                   green: Int(matched.output.2, radix: 16)! * 17, blue: Int(matched.output.3, radix: 16)! * 17,
                   colorSpace: colorSpace)
    }
    if let matched = try? /#([A-Fa-f0-9])([A-Fa-f0-9])([A-Fa-f0-9])/.wholeMatch(in: trimmed) {
      return color(alpha: 255, red: Int(matched.output.1, radix: 16)! * 17,
                   green: Int(matched.output.2, radix: 16)! * 17, blue: Int(matched.output.3, radix: 16)! * 17,
                   colorSpace: colorSpace)
    }
    return nil
  }

  static func color(alpha: Int, red: Int, green: Int, blue: Int, colorSpace: SquirrelTheme.RimeColorSpace) -> NSColor {
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

// MARK: - Rendering

enum ThemeFillRenderer {
  /// Builds a layer that fills `path`, using `box` as the gradient canvas (so one gradient spans the whole panel).
  static func fillLayer(path: CGPath?, fill: ThemeFill, box: CGRect? = nil) -> CALayer? {
    switch fill {
    case .solid(let color):
      guard let path else { return nil }
      let layer = CAShapeLayer()
      layer.path = path
      layer.fillRule = .evenOdd
      layer.fillColor = color.cgColor
      return layer
    case .gradient(let kind, let stops):
      return gradientLayer(path: path, kind: kind, stops: stops, box: box, strokeWidth: nil)
    }
  }

  /// Builds a layer that strokes `path`, using `box` as the gradient canvas.
  static func strokeLayer(path: CGPath?, fill: ThemeFill, lineWidth: CGFloat, box: CGRect? = nil) -> CALayer? {
    switch fill {
    case .solid(let color):
      guard let path else { return nil }
      let layer = CAShapeLayer()
      layer.path = path
      layer.fillRule = .evenOdd
      layer.strokeColor = color.cgColor
      layer.fillColor = nil
      layer.lineWidth = lineWidth
      return layer
    case .gradient(let kind, let stops):
      return gradientLayer(path: path, kind: kind, stops: stops, box: box, strokeWidth: lineWidth)
    }
  }

  /// Wraps `layer` in a container that applies an outer clip mask, keeping the layer's own mask free for its shape.
  static func masked(_ layer: CALayer, with maskPath: CGPath?, frame: CGRect) -> CALayer {
    guard let maskPath else { return layer }
    let container = CALayer()
    container.frame = frame
    container.addSublayer(layer)
    let mask = CAShapeLayer()
    mask.frame = CGRect(origin: .zero, size: frame.size)
    mask.path = maskPath
    mask.fillRule = .evenOdd
    container.mask = mask
    return container
  }

  private static func gradientLayer(path: CGPath?, kind: GradientKind, stops: [ColorStop],
                                    box: CGRect?, strokeWidth: CGFloat?) -> CALayer? {
    guard let path, !path.isEmpty else { return nil }
    let pathBox = path.boundingBoxOfPath
    guard !pathBox.isNull, pathBox.width > 0, pathBox.height > 0 else {
      return fillLayer(path: path, fill: .solid(ThemeFill.sample(stops, at: 0.5)))
    }
    var frame = box ?? pathBox
    if let strokeWidth {
      frame = frame.insetBy(dx: -strokeWidth, dy: -strokeWidth)
    }
    let layer = CAGradientLayer()
    layer.type = gradientType(kind)
    layer.frame = frame
    layer.colors = stops.map { $0.color.cgColor }
    layer.locations = stops.map { NSNumber(value: Double($0.location)) }
    let (startPoint, endPoint) = endpoints(kind, frame)
    layer.startPoint = startPoint
    layer.endPoint = endPoint

    var transform = CGAffineTransform(translationX: -frame.minX, y: -frame.minY)
    let mask = CAShapeLayer()
    mask.frame = layer.bounds
    mask.path = path.copy(using: &transform)
    mask.fillRule = .evenOdd
    if let strokeWidth {
      mask.strokeColor = NSColor.black.cgColor
      mask.lineWidth = strokeWidth
    } else {
      mask.fillColor = NSColor.black.cgColor
    }
    layer.mask = mask
    return layer
  }

  private static func gradientType(_ kind: GradientKind) -> CAGradientLayerType {
    switch kind {
    case .linear:
      return .axial
    case .radial:
      return .radial
    case .conic:
      return .conic
    }
  }

  static func endpoints(_ kind: GradientKind, _ box: CGRect) -> (CGPoint, CGPoint) {
    let width = max(box.width, 1)
    let height = max(box.height, 1)
    switch kind {
    case .linear(let angle):
      let rad = angle * .pi / 180
      var directionX = sin(rad)
      var directionY = -cos(rad)
      let scale = 1 / max(max(abs(directionX), abs(directionY)), 0.0001)
      directionX *= scale
      directionY *= scale
      let start = CGPoint(x: 0.5 - directionX / 2, y: 0.5 - directionY / 2)
      let end = CGPoint(x: 0.5 + directionX / 2, y: 0.5 + directionY / 2)
      return (start, end)
    case .radial(let center):
      let radiusX = max(center.x * width, (1 - center.x) * width)
      let radiusY = max(center.y * height, (1 - center.y) * height)
      let radius = hypot(radiusX, radiusY)
      let start = CGPoint(x: center.x, y: center.y)
      let end = CGPoint(x: center.x + radius / width, y: center.y + radius / height)
      return (start, end)
    case .conic(let angle):
      let rad = angle * .pi / 180
      let start = CGPoint(x: 0.5, y: 0.5)
      let end = CGPoint(x: 0.5 + sin(rad) * 0.5, y: 0.5 - cos(rad) * 0.5)
      return (start, end)
    }
  }
}
