//
//  MacOSKeyCOdes.swift
//  Squirrel
//
//  Created by Leo Liu on 5/9/24.
//

struct SquirrelKeycode {
  static let capitalMask: UInt32 = 1 << 16
  static let shiftMask: UInt32 = 1 << 17
  static let ctrlMask: UInt32 = 1 << 18
  static let altMask: UInt32 = 1 << 19
  static let commandMask: UInt32 = 1 << 20
  
  // key codes
  //
  /* credit goes to tekezo@
   https://github.com/tekezo/Karabiner/blob/master/src/bridge/generator/keycode/data/KeyCode.data
   */
  // alphabet
  static let vkA: UInt32 = 0x0
  static let vkB: UInt32 = 0xb
  static let vkC: UInt32 = 0x8
  static let vkD: UInt32 = 0x2
  static let vkE: UInt32 = 0xe
  static let vkF: UInt32 = 0x3
  static let vkG: UInt32 = 0x5
  static let vkH: UInt32 = 0x4
  static let vkI: UInt32 = 0x22
  static let vkJ: UInt32 = 0x26
  static let vkK: UInt32 = 0x28
  static let vkL: UInt32 = 0x25
  static let vkM: UInt32 = 0x2e
  static let vkN: UInt32 = 0x2d
  static let vkO: UInt32 = 0x1f
  static let vkP: UInt32 = 0x23
  static let vkQ: UInt32 = 0xc
  static let vkR: UInt32 = 0xf
  static let vkS: UInt32 = 0x1
  static let vkT: UInt32 = 0x11
  static let vkU: UInt32 = 0x20
  static let vkV: UInt32 = 0x9
  static let vkW: UInt32 = 0xd
  static let vkX: UInt32 = 0x7
  static let vkY: UInt32 = 0x10
  static let vkZ: UInt32 = 0x6
  
  // ----------------------------------------
  // number

  static let vkKey0: UInt32 = 0x1d
  static let vkKey1: UInt32 = 0x12
  static let vkKey2: UInt32 = 0x13
  static let vkKey3: UInt32 = 0x14
  static let vkKey4: UInt32 = 0x15
  static let vkKey5: UInt32 = 0x17
  static let vkKey6: UInt32 = 0x16
  static let vkKey7: UInt32 = 0x1a
  static let vkKey8: UInt32 = 0x1c
  static let vkKey9: UInt32 = 0x19
  
  // ----------------------------------------
  // symbol

  // BACKQUOTE is also known as grave accent or backtick.
  static let vkBackquote: UInt32 = 0x32
  static let vkBackslash: UInt32 = 0x2a
  static let vkBracketLeft: UInt32 = 0x21
  static let vkBracketRight: UInt32 = 0x1e
  static let vkComma: UInt32 = 0x2b
  static let vkDot: UInt32 = 0x2f
  static let vkEqual: UInt32 = 0x18
  static let vkMinus: UInt32 = 0x1b
  static let vkQuote: UInt32 = 0x27
  static let vkSemicolon: UInt32 = 0x29
  static let vkSlash: UInt32 = 0x2c
  
  // ----------------------------------------
  // keypad

  static let vkKeypad0: UInt32 = 0x52
  static let vkKeypad1: UInt32 = 0x53
  static let vkKeypad2: UInt32 = 0x54
  static let vkKeypad3: UInt32 = 0x55
  static let vkKeypad4: UInt32 = 0x56
  static let vkKeypad5: UInt32 = 0x57
  static let vkKeypad6: UInt32 = 0x58
  static let vkKeypad7: UInt32 = 0x59
  static let vkKeypad8: UInt32 = 0x5b
  static let vkKeypad9: UInt32 = 0x5c
  static let vkKeypadClear: UInt32 = 0x47
  static let vkKeypadComma: UInt32 = 0x5f
  static let vkKeypadDot: UInt32 = 0x41
  static let vkKeypadEqual: UInt32 = 0x51
  static let vkKeypadMinus: UInt32 = 0x4e
  static let vkKeypadMultiply: UInt32 = 0x43
  static let vkKeypadPlus: UInt32 = 0x45
  static let vkKeypadSlash: UInt32 = 0x4b
  
  // ----------------------------------------
  // special

  static let vkDelete: UInt32 = 0x33
  static let vkEnter: UInt32 = 0x4c
  static let vkEnterPowerbook: UInt32 = 0x34
  static let vkEscape: UInt32 = 0x35
  static let vkForwardDelete: UInt32 = 0x75
  static let vkHelp: UInt32 = 0x72
  static let vkReturn: UInt32 = 0x24
  static let vkSpace: UInt32 = 0x31
  static let vkTab: UInt32 = 0x30
  
  // ----------------------------------------
  // function
  static let vkF1: UInt32 = 0x7a
  static let vkF2: UInt32 = 0x78
  static let vkF3: UInt32 = 0x63
  static let vkF4: UInt32 = 0x76
  static let vkF5: UInt32 = 0x60
  static let vkF6: UInt32 = 0x61
  static let vkF7: UInt32 = 0x62
  static let vkF8: UInt32 = 0x64
  static let vkF9: UInt32 = 0x65
  static let vkF10: UInt32 = 0x6d
  static let vkF11: UInt32 = 0x67
  static let vkF12: UInt32 = 0x6f
  static let vkF13: UInt32 = 0x69
  static let vkF14: UInt32 = 0x6b
  static let vkF15: UInt32 = 0x71
  static let vkF16: UInt32 = 0x6a
  static let vkF17: UInt32 = 0x40
  static let vkF18: UInt32 = 0x4f
  static let vkF19: UInt32 = 0x50
  
  // ----------------------------------------
  // functional

  static let vkBrightnessDown: UInt32 = 0x91
  static let vkBrightnessUp: UInt32 = 0x90
  static let vkDashboard: UInt32 = 0x82
  static let vkExposeAll: UInt32 = 0xa0
  static let vkLaunchpad: UInt32 = 0x83
  static let vkMissionControl: UInt32 = 0xa0
  
  // ----------------------------------------
  // cursor

  static let vkCursorUp: UInt32 = 0x7e
  static let vkCursorDown: UInt32 = 0x7d
  static let vkCursorLeft: UInt32 = 0x7b
  static let vkCursorRight: UInt32 = 0x7c

  static let vkPageUp: UInt32 = 0x74
  static let vkPageDown: UInt32 = 0x79
  static let vkHome: UInt32 = 0x73
  static let vkEnd: UInt32 = 0x77
  
  // ----------------------------------------
  // modifiers
  static let vkCapsLock: UInt32 = 0x39
  static let vkCommandL: UInt32 = 0x37
  static let vkCommandR: UInt32 = 0x36
  static let vkControlL: UInt32 = 0x3b
  static let vkControlR: UInt32 = 0x3e
  static let vkFn: UInt32 = 0x3f
  static let vkOptionL: UInt32 = 0x3a
  static let vkOptionR: UInt32 = 0x3d
  static let vkShiftL: UInt32 = 0x38
  static let vkShiftR: UInt32 = 0x3c
  
  // ----------------------------------------
  // pc keyboard

  static let vkPcApplication: UInt32 = 0x6e
  static let vkPcBs: UInt32 = 0x33
  static let vkPcDel: UInt32 = 0x75
  static let vkPcInsert: UInt32 = 0x72
  static let vkPcKeypadNumLock: UInt32 = 0x47
  static let vkPcPause: UInt32 = 0x71
  static let vkPcPower: UInt32 = 0x7f
  static let vkPcPrintScreen: UInt32 = 0x69
  static let vkPcScrollLock: UInt32 = 0x6b
  
  // ----------------------------------------
  // international

  static let vkDanishDollar: UInt32 = 0xa
  static let vkDanishLessThan: UInt32 = 0x32

  static let vkFrenchDollar: UInt32 = 0x1e
  static let vkFrenchEqual: UInt32 = 0x2c
  static let vkFrenchHat: UInt32 = 0x21
  static let vkFrenchMinus: UInt32 = 0x18
  static let vkFrenchRightParen: UInt32 = 0x1b

  static let vkGermanCircumflex: UInt32 = 0xa
  static let vkGermanLessThan: UInt32 = 0x32
  static let vkGermanPcLessThan: UInt32 = 0x80
  static let vkGermanQuote: UInt32 = 0x18
  static let vkGermanAUmlaut: UInt32 = 0x27
  static let vkGermanOUmlaut: UInt32 = 0x29
  static let vkGermanUUmlaut: UInt32 = 0x21

  static let vkItalianBackslash: UInt32 = 0xa
  static let vkItalianLessThan: UInt32 = 0x32

  static let vkJisAtmark: UInt32 = 0x21
  static let vkJisBracketLeft: UInt32 = 0x1e
  static let vkJisBracketRight: UInt32 = 0x2a
  static let vkJisColon: UInt32 = 0x27
  static let vkJisDakuon: UInt32 = 0x21
  static let vkJisEisuu: UInt32 = 0x66
  static let vkJisHandakuon: UInt32 = 0x1e
  static let vkJisHat: UInt32 = 0x18
  static let vkJisKana: UInt32 = 0x68
  static let vkJisPcHanZen: UInt32 = 0x32
  static let vkJisUnderscore: UInt32 = 0x5e
  static let vkJisYen: UInt32 = 0x5d

  static let vkRussianParagraph: UInt32 = 0xa
  static let vkRussianTilde: UInt32 = 0x32

  static let vkSpanishLessThan: UInt32 = 0x32
  static let vkSpanishOrdinalIndicator: UInt32 = 0xa

  static let vkSwedishLessThan: UInt32 = 0x32
  static let vkSwedishSection: UInt32 = 0xa

  static let vkSwissLessThan: UInt32 = 0x32
  static let vkSwissSection: UInt32 = 0xa

  static let vkUkSection: UInt32 = 0xa
  
  static func osxModifiersToRime(modifiers: UInt) -> UInt32 {
    var ret: UInt32 = 0
    if modifiers & UInt(capitalMask) != 0 {
      ret |= kLockMask.rawValue
    }
    if modifiers & UInt(shiftMask) != 0 {
      ret |= kShiftMask.rawValue
    }
    if modifiers & UInt(ctrlMask) != 0 {
      ret |= kControlMask.rawValue
    }
    if modifiers & UInt(altMask) != 0 {
      ret |= kAltMask.rawValue
    }
    if modifiers & UInt(commandMask) != 0 {
      ret |= kSuperMask.rawValue
    }
    return ret
  }
  
  static func osxKeycodeToRime(keycode: UInt16, keychar: Character, shift: Bool, caps: Bool) -> UInt32 {
    if let code = keycodeMappings[UInt32(keycode)] {
      return UInt32(code)
    }
    
    if keychar.isASCII, let codeValue = keychar.unicodeScalars.first?.value {
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
  
  private static let keycodeMappings: Dictionary<UInt32, Int32> = [
    // modifiers
    vkCapsLock: XK_Caps_Lock,
    vkCommandL: XK_Super_L,  // XK_Meta_L?
    vkCommandR: XK_Super_R,  // XK_Meta_R?
    vkControlL: XK_Control_L,
    vkControlR: XK_Control_R,
    vkFn: XK_Hyper_L,
    vkOptionL: XK_Alt_L,
    vkOptionR: XK_Alt_R,
    vkShiftL: XK_Shift_L,
    vkShiftR: XK_Shift_R,
    
    // special
    vkDelete: XK_BackSpace,
    vkEnter: XK_KP_Enter,
    // vkEnterPowerBook -> ?
    vkEscape: XK_Escape,
    vkForwardDelete: XK_Delete,
    //{vkHelp, XK_Help}, // the same keycode with OSX_VK_PC_INSERT
    vkReturn: XK_Return,
    vkSpace: XK_space,
    vkTab: XK_Tab,
    
    // function
    vkF1: XK_F1,
    vkF2: XK_F2,
    vkF3: XK_F3,
    vkF4: XK_F4,
    vkF5: XK_F5,
    vkF6: XK_F6,
    vkF7: XK_F7,
    vkF8: XK_F8,
    vkF9: XK_F9,
    vkF10: XK_F10,
    vkF11: XK_F11,
    vkF12: XK_F12,
    vkF13: XK_F13,
    vkF14: XK_F14,
    vkF15: XK_F15,
    vkF16: XK_F16,
    vkF17: XK_F17,
    vkF18: XK_F18,
    vkF19: XK_F19,
    
    // cursor
    vkCursorUp: XK_Up,
    vkCursorDown: XK_Down,
    vkCursorLeft: XK_Left,
    vkCursorRight: XK_Right,
    vkPageUp: XK_Page_Up,
    vkPageDown: XK_Page_Down,
    vkHome: XK_Home,
    vkEnd: XK_End,
    
    // keypad
    vkKeypad0: XK_KP_0,
    vkKeypad1: XK_KP_1,
    vkKeypad2: XK_KP_2,
    vkKeypad3: XK_KP_3,
    vkKeypad4: XK_KP_4,
    vkKeypad5: XK_KP_5,
    vkKeypad6: XK_KP_6,
    vkKeypad7: XK_KP_7,
    vkKeypad8: XK_KP_8,
    vkKeypad9: XK_KP_9,
    vkKeypadClear: XK_Clear,
    vkKeypadComma: XK_KP_Separator,
    vkKeypadDot: XK_KP_Decimal,
    vkKeypadEqual: XK_KP_Equal,
    vkKeypadMinus: XK_KP_Subtract,
    vkKeypadMultiply: XK_KP_Multiply,
    vkKeypadPlus: XK_KP_Add,
    vkKeypadSlash: XK_KP_Divide,
    
    // pc keyboard
    vkPcApplication: XK_Menu,
    vkPcInsert: XK_Insert,
    vkPcKeypadNumLock: XK_Num_Lock,
    vkPcPause: XK_Pause,
    // vkPcPower -> ?
    vkPcPrintScreen: XK_Print,
    vkPcScrollLock: XK_Scroll_Lock,
  ]
}
