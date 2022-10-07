import Foundation

public var sessionControllers: Set<SquirrelInputController> = .init()

@objc public extension SquirrelInputController {
  static var isBasicKeyboardLayoutDefinedValidInPlist: Bool {
    TISInputSource.generate(from: Properties.shared.basicKeyboardLayout) != nil
  }

  static var basicKeyboardLayoutNameVerified: String? {
    let result = Properties.shared.basicKeyboardLayout
    return (TISInputSource.generate(from: result) != nil) ? result : nil
  }

  func overrideKeyboard() {
    DispatchQueue.main.async { [self] in
      if let verified = Self.basicKeyboardLayoutNameVerified {
        client()?.overrideKeyboard(withKeyboardNamed: verified)
      }
    }
  }

  func registerSessionControllerIntoSet() {
    sessionControllers.insert(self)
  }

  func removeSessionControllerFromSet() {
    sessionControllers.remove(self)
  }
}
