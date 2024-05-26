//
//  MacOSKeyCodes.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

import Carbon
import AppKit

struct SquirrelKeycode {

  static func osxModifiersToRime(modifiers: NSEvent.ModifierFlags) -> UInt32 {
    var ret: UInt32 = 0
    if modifiers.contains(.capsLock) {
      ret |= kLockMask.rawValue
    }
    if modifiers.contains(.shift) {
      ret |= kShiftMask.rawValue
    }
    if modifiers.contains(.control) {
      ret |= kControlMask.rawValue
    }
    if modifiers.contains(.option) {
      ret |= kAltMask.rawValue
    }
    if modifiers.contains(.command) {
      ret |= kSuperMask.rawValue
    }
    return ret
  }

  static func osxKeycodeToRime(keycode: UInt16, keychar: Character?, shift: Bool, caps: Bool) -> UInt32 {
    if let code = keycodeMappings[Int(keycode)] {
      return UInt32(code)
    }

    if let keychar = keychar, keychar.isASCII, let codeValue = keychar.unicodeScalars.first?.value {
      // NOTE: IBus/Rime use different keycodes for uppercase/lowercase letters.
      if keychar.isLowercase && (shift || caps) {
        // lowercase -> Uppercase
        return keychar.uppercased().unicodeScalars.first!.value
      }

      switch codeValue {
      case 0x20...0x7e:
        return codeValue
      case 0x1b:
        return UInt32(XK_bracketleft)
      case 0x1c:
        return UInt32(XK_backslash)
      case 0x1d:
        return UInt32(XK_bracketright)
      case 0x1f:
        return UInt32(XK_minus)
      default:
        break
      }
    }

    return UInt32(XK_VoidSymbol)
  }

  private static let keycodeMappings: [Int: Int32] = [
    // modifiers
    kVK_CapsLock: XK_Caps_Lock,
    kVK_Command: XK_Super_L,  // XK_Meta_L?
    kVK_RightCommand: XK_Super_R,  // XK_Meta_R?
    kVK_Control: XK_Control_L,
    kVK_RightControl: XK_Control_R,
    kVK_Function: XK_Hyper_L,
    kVK_Option: XK_Alt_L,
    kVK_RightOption: XK_Alt_R,
    kVK_Shift: XK_Shift_L,
    kVK_RightShift: XK_Shift_R,

    // special
    kVK_Delete: XK_BackSpace,
    kVK_Escape: XK_Escape,
    kVK_ForwardDelete: XK_Delete,
    kVK_Help: XK_Help,
    kVK_Return: XK_Return,
    kVK_Space: XK_space,
    kVK_Tab: XK_Tab,

    // function
    kVK_F1: XK_F1,
    kVK_F2: XK_F2,
    kVK_F3: XK_F3,
    kVK_F4: XK_F4,
    kVK_F5: XK_F5,
    kVK_F6: XK_F6,
    kVK_F7: XK_F7,
    kVK_F8: XK_F8,
    kVK_F9: XK_F9,
    kVK_F10: XK_F10,
    kVK_F11: XK_F11,
    kVK_F12: XK_F12,
    kVK_F13: XK_F13,
    kVK_F14: XK_F14,
    kVK_F15: XK_F15,
    kVK_F16: XK_F16,
    kVK_F17: XK_F17,
    kVK_F18: XK_F18,
    kVK_F19: XK_F19,
    kVK_F20: XK_F20,

    // cursor
    kVK_UpArrow: XK_Up,
    kVK_DownArrow: XK_Down,
    kVK_LeftArrow: XK_Left,
    kVK_RightArrow: XK_Right,
    kVK_PageUp: XK_Page_Up,
    kVK_PageDown: XK_Page_Down,
    kVK_Home: XK_Home,
    kVK_End: XK_End,

    // keypad
    kVK_ANSI_Keypad0: XK_KP_0,
    kVK_ANSI_Keypad1: XK_KP_1,
    kVK_ANSI_Keypad2: XK_KP_2,
    kVK_ANSI_Keypad3: XK_KP_3,
    kVK_ANSI_Keypad4: XK_KP_4,
    kVK_ANSI_Keypad5: XK_KP_5,
    kVK_ANSI_Keypad6: XK_KP_6,
    kVK_ANSI_Keypad7: XK_KP_7,
    kVK_ANSI_Keypad8: XK_KP_8,
    kVK_ANSI_Keypad9: XK_KP_9,
    kVK_ANSI_KeypadClear: XK_Clear,
    kVK_ANSI_KeypadDecimal: XK_KP_Decimal,
    kVK_ANSI_KeypadEquals: XK_KP_Equal,
    kVK_ANSI_KeypadMinus: XK_KP_Subtract,
    kVK_ANSI_KeypadMultiply: XK_KP_Multiply,
    kVK_ANSI_KeypadPlus: XK_KP_Add,
    kVK_ANSI_KeypadDivide: XK_KP_Divide,
    kVK_ANSI_KeypadEnter: XK_KP_Enter,

    // other
    kVK_ISO_Section: XK_section,
    kVK_JIS_Yen: XK_yen,
    kVK_JIS_Underscore: XK_underscore,
    kVK_JIS_KeypadComma: XK_comma,
    kVK_JIS_Eisu: XK_Eisu_Shift,
    kVK_JIS_Kana: XK_Kana_Shift
  ]
}
