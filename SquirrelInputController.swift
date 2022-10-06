import Foundation

@objc public extension SquirrelInputController { static var basicKeyboardLayoutNameVerified: String {
  let result = Properties.shared.basicKeyboardLayout
  return (TISInputSource.generate(from: result) != nil) ? result : "com.apple.keylayout.ABC"
}

func overrideKeyboard() {
  DispatchQueue.main.async { [self] in
    self.client()?.overrideKeyboard(withKeyboardNamed: Self.basicKeyboardLayoutNameVerified)
  }
}
}
