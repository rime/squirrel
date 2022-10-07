import Foundation

@objc public class Properties: NSObject {
  @objc public static let shared = Properties()
  public static let kDefaultBasicKeyboardLayout = "com.apple.keylayout.ABC"

  @AppProperty(key: "BasicKeyboardLayout", defaultValue: "kDefaultBasicKeyboardLayout")
  public var basicKeyboardLayout: String
}
