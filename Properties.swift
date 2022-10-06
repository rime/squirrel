import Foundation

@objc public class Properties: NSObject {
  @objc public static let shared = Properties()

  @AppProperty(key: "BasicKeyboardLayout", defaultValue: "")
  public var basicKeyboardLayout: String
}
