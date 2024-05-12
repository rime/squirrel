#import "macos_keycode.hh"

#import <rime/key_table.h>
#import <Carbon/Carbon.h>

int rime_modifiers_from_mac_modifiers(NSEventModifierFlags modifiers) {
  int ret = 0;

  if ((modifiers & NSEventModifierFlagCapsLock) != 0)
    ret |= kLockMask;
  if ((modifiers & NSEventModifierFlagShift) != 0)
    ret |= kShiftMask;
  if ((modifiers & NSEventModifierFlagControl) != 0)
    ret |= kControlMask;
  if ((modifiers & NSEventModifierFlagOption) != 0)
    ret |= kAltMask;
  if ((modifiers & NSEventModifierFlagCommand) != 0)
    ret |= kSuperMask;

  return ret;
}

int rime_keycode_from_mac_keycode(ushort mac_keycode) {
  switch (mac_keycode) {
    case kVK_CapsLock:
      return XK_Caps_Lock;
    case kVK_Command:
      return XK_Super_L;  // XK_Meta_L?
    case kVK_RightCommand:
      return XK_Super_R;  // XK_Meta_R?
    case kVK_Control:
      return XK_Control_L;
    case kVK_RightControl:
      return XK_Control_R;
    case kVK_Function:
      return XK_Hyper_L;
    case kVK_Option:
      return XK_Alt_L;
    case kVK_RightOption:
      return XK_Alt_R;
    case kVK_Shift:
      return XK_Shift_L;
    case kVK_RightShift:
      return XK_Shift_R;
    // special
    case kVK_Delete:
      return XK_BackSpace;
    case kVK_Enter_Powerbook:
      return XK_ISO_Enter;
    case kVK_Escape:
      return XK_Escape;
    case kVK_ForwardDelete:
      return XK_Delete;
    case kVK_Help:
      return XK_Help;
    case kVK_Return:
      return XK_Return;
    case kVK_Space:
      return XK_space;
    case kVK_Tab:
      return XK_Tab;
    // function
    case kVK_F1:
      return XK_F1;
    case kVK_F2:
      return XK_F2;
    case kVK_F3:
      return XK_F3;
    case kVK_F4:
      return XK_F4;
    case kVK_F5:
      return XK_F5;
    case kVK_F6:
      return XK_F6;
    case kVK_F7:
      return XK_F7;
    case kVK_F8:
      return XK_F8;
    case kVK_F9:
      return XK_F9;
    case kVK_F10:
      return XK_F10;
    case kVK_F11:
      return XK_F11;
    case kVK_F12:
      return XK_F12;
    case kVK_F13:
      return XK_F13;
    case kVK_F14:
      return XK_F14;
    case kVK_F15:
      return XK_F15;
    case kVK_F16:
      return XK_F16;
    case kVK_F17:
      return XK_F17;
    case kVK_F18:
      return XK_F18;
    case kVK_F19:
      return XK_F19;
    case kVK_F20:
      return XK_F20;
    // cursor
    case kVK_UpArrow:
      return XK_Up;
    case kVK_DownArrow:
      return XK_Down;
    case kVK_LeftArrow:
      return XK_Left;
    case kVK_RightArrow:
      return XK_Right;
    case kVK_PageUp:
      return XK_Page_Up;
    case kVK_PageDown:
      return XK_Page_Down;
    case kVK_Home:
      return XK_Home;
    case kVK_End:
      return XK_End;
    // keypad
    case kVK_ANSI_Keypad0:
      return XK_KP_0;
    case kVK_ANSI_Keypad1:
      return XK_KP_1;
    case kVK_ANSI_Keypad2:
      return XK_KP_2;
    case kVK_ANSI_Keypad3:
      return XK_KP_3;
    case kVK_ANSI_Keypad4:
      return XK_KP_4;
    case kVK_ANSI_Keypad5:
      return XK_KP_5;
    case kVK_ANSI_Keypad6:
      return XK_KP_6;
    case kVK_ANSI_Keypad7:
      return XK_KP_7;
    case kVK_ANSI_Keypad8:
      return XK_KP_8;
    case kVK_ANSI_Keypad9:
      return XK_KP_9;
    case kVK_ANSI_KeypadEnter:
      return XK_KP_Enter;
    case kVK_ANSI_KeypadClear:
      return XK_Clear;
    case kVK_ANSI_KeypadDecimal:
      return XK_KP_Decimal;
    case kVK_ANSI_KeypadEquals:
      return XK_KP_Equal;
    case kVK_ANSI_KeypadMinus:
      return XK_KP_Subtract;
    case kVK_ANSI_KeypadMultiply:
      return XK_KP_Multiply;
    case kVK_ANSI_KeypadPlus:
      return XK_KP_Add;
    case kVK_ANSI_KeypadDivide:
      return XK_KP_Divide;
    // pc keyboard
    case kVK_PC_Application:
      return XK_Menu;
    // OSX_VK_PC_Power -> ?
    //  JIS keyboard
    case kVK_JIS_KeypadComma:
      return XK_KP_Separator;
    case kVK_JIS_Eisu:
      return XK_Eisu_toggle;
    case kVK_JIS_Kana:
      return XK_Kana_Shift;

    default:
      return 0;
  }
}

int rime_keycode_from_keychar(unichar keychar, bool shift, bool caps) {
  // NOTE: IBus/Rime use different keycodes for uppercase/lowercase letters.
  if (keychar >= 'a' && keychar <= 'z' && (!!shift != !!caps)) {
    // lowercase -> Uppercase
    return keychar - 'a' + 'A';
  }

  if (keychar >= 0x20 && keychar <= 0x7e) {
    return keychar;
  }

  switch (keychar) {
    // ASCII control characters
    case NSNewlineCharacter:
      return XK_Linefeed;
    case NSBackTabCharacter:
      return XK_ISO_Left_Tab;
    // Function key characters
    case NSF21FunctionKey:
      return XK_F21;
    case NSF22FunctionKey:
      return XK_F22;
    case NSF23FunctionKey:
      return XK_F23;
    case NSF24FunctionKey:
      return XK_F24;
    case NSF25FunctionKey:
      return XK_F25;
    case NSF26FunctionKey:
      return XK_F26;
    case NSF27FunctionKey:
      return XK_F27;
    case NSF28FunctionKey:
      return XK_F28;
    case NSF29FunctionKey:
      return XK_F29;
    case NSF30FunctionKey:
      return XK_F30;
    case NSF31FunctionKey:
      return XK_F31;
    case NSF32FunctionKey:
      return XK_F32;
    case NSF33FunctionKey:
      return XK_F33;
    case NSF34FunctionKey:
      return XK_F34;
    case NSF35FunctionKey:
      return XK_F35;
    // Misc functional key characters
    case NSInsertFunctionKey:
      return XK_Insert;
    case NSBeginFunctionKey:
      return XK_Begin;
    case NSScrollLockFunctionKey:
      return XK_Scroll_Lock;
    case NSPauseFunctionKey:
      return XK_Pause;
    case NSSysReqFunctionKey:
      return XK_Sys_Req;
    case NSBreakFunctionKey:
      return XK_Break;
    case NSStopFunctionKey:
      return XK_Cancel;
    case NSPrintFunctionKey:
      return XK_Print;
    case NSClearLineFunctionKey:
      return XK_Num_Lock;
    case NSPrevFunctionKey:
      return XK_Prior;
    case NSNextFunctionKey:
      return XK_Next;
    case NSSelectFunctionKey:
      return XK_Select;
    case NSExecuteFunctionKey:
      return XK_Execute;
    case NSUndoFunctionKey:
      return XK_Undo;
    case NSRedoFunctionKey:
      return XK_Redo;
    case NSFindFunctionKey:
      return XK_Find;
    case NSModeSwitchFunctionKey:
      return XK_Mode_switch;

    default:
      return 0;
  }
}

static const char* rime_modidifers[] = {
    "Shift",    // 1 << 0
    "Lock",     // 1 << 1
    "Control",  // 1 << 2
    "Alt",      // 1 << 3
    "Super",    // 1 << 26
    "Hyper",    // 1 << 27
    "Meta",     // 1 << 28
};

int rime_modifiers_from_name(const char* modifier_name) {
  if (modifier_name == NULL) {
    return 0;
  }
  for (int i = 0; i < 6; ++i) {
    if (strcmp(modifier_name, rime_modidifers[i]) == 0) {
      return 1 << (i < 4 ? i : i + 22);
    }
  }
  return 0;
}

int rime_keycode_from_name(const char* key_name) {
  int keycode = RimeGetKeycodeByName(key_name);
  return keycode == XK_VoidSymbol ? 0 : keycode;
}
