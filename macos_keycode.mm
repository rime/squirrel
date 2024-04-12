#import "macos_keycode.hh"

#import <rime/key_table.h>
#import <Carbon/Carbon.h>

int osx_modifiers_to_rime_modifiers(NSEventModifierFlags modifiers) {
  int ret = 0;

  if (modifiers & NSEventModifierFlagCapsLock)
    ret |= kLockMask;
  if (modifiers & NSEventModifierFlagShift)
    ret |= kShiftMask;
  if (modifiers & NSEventModifierFlagControl)
    ret |= kControlMask;
  if (modifiers & NSEventModifierFlagOption)
    ret |= kAltMask;
  if (modifiers & NSEventModifierFlagCommand)
    ret |= kSuperMask;

  return ret;
}

static const struct keycode_mapping_t {
  int osx_keycode, rime_keycode;
} keycode_mappings[] = {
    // modifiers
    {kVK_CapsLock, XK_Caps_Lock},
    {kVK_Command, XK_Super_L},       // XK_Meta_L?
    {kVK_RightCommand, XK_Super_R},  // XK_Meta_R?
    {kVK_Control, XK_Control_L},
    {kVK_RightControl, XK_Control_R},
    {kVK_Function, XK_Hyper_L},
    {kVK_Option, XK_Alt_L},
    {kVK_RightOption, XK_Alt_R},
    {kVK_Shift, XK_Shift_L},
    {kVK_RightShift, XK_Shift_R},

    // special
    {kVK_Delete, XK_BackSpace},
    {kVK_ANSI_KeypadEnter, XK_KP_Enter},
    // kVK_ENTER_POWERBOOK -> ?
    {kVK_Escape, XK_Escape},
    {kVK_ForwardDelete, XK_Delete},
    //{kVK_HELP, XK_Help}, // the same keycode with kVK_PC_INSERT
    {kVK_Return, XK_Return},
    {kVK_Space, XK_space},
    {kVK_Tab, XK_Tab},

    // function
    {kVK_F1, XK_F1},
    {kVK_F2, XK_F2},
    {kVK_F3, XK_F3},
    {kVK_F4, XK_F4},
    {kVK_F5, XK_F5},
    {kVK_F6, XK_F6},
    {kVK_F7, XK_F7},
    {kVK_F8, XK_F8},
    {kVK_F9, XK_F9},
    {kVK_F10, XK_F10},
    {kVK_F11, XK_F11},
    {kVK_F12, XK_F12},
    {kVK_F13, XK_F13},
    {kVK_F14, XK_F14},
    {kVK_F15, XK_F15},
    {kVK_F16, XK_F16},
    {kVK_F17, XK_F17},
    {kVK_F18, XK_F18},
    {kVK_F19, XK_F19},

    // cursor
    {kVK_UpArrow, XK_Up},
    {kVK_DownArrow, XK_Down},
    {kVK_LeftArrow, XK_Left},
    {kVK_RightArrow, XK_Right},
    {kVK_PageUp, XK_Page_Up},
    {kVK_PageDown, XK_Page_Down},
    {kVK_Home, XK_Home},
    {kVK_End, XK_End},

    // keypad
    {kVK_ANSI_Keypad0, XK_KP_0},
    {kVK_ANSI_Keypad1, XK_KP_1},
    {kVK_ANSI_Keypad2, XK_KP_2},
    {kVK_ANSI_Keypad3, XK_KP_3},
    {kVK_ANSI_Keypad4, XK_KP_4},
    {kVK_ANSI_Keypad5, XK_KP_5},
    {kVK_ANSI_Keypad6, XK_KP_6},
    {kVK_ANSI_Keypad7, XK_KP_7},
    {kVK_ANSI_Keypad8, XK_KP_8},
    {kVK_ANSI_Keypad9, XK_KP_9},
    {kVK_ANSI_KeypadClear, XK_Clear},
    {kVK_ANSI_KeypadDecimal, XK_KP_Decimal},
    {kVK_ANSI_KeypadEquals, XK_KP_Equal},
    {kVK_ANSI_KeypadMinus, XK_KP_Subtract},
    {kVK_ANSI_KeypadMultiply, XK_KP_Multiply},
    {kVK_ANSI_KeypadPlus, XK_KP_Add},
    {kVK_ANSI_KeypadDivide, XK_KP_Divide},

    // pc keyboard
    {kVK_PC_Application, XK_Menu},
    {kVK_PC_Insert, XK_Insert},
    //{kVK_PC_Keypad NumLock, XK_Num_Lock}, // the same keycode as
    // kVK_ANSI_KeypadClear
    {kVK_PC_Pause, XK_Pause},
    // kVK_PC_POWER -> ?
    {kVK_PC_PrintScreen, XK_Print},
    {kVK_PC_ScrollLock, XK_Scroll_Lock},

    // JIS keyboard
    {kVK_JIS_KeypadComma, XK_KP_Separator},
    {kVK_JIS_Eisu, XK_Eisu_toggle},
    {kVK_JIS_Kana, XK_Kana_Shift},

    {-1, -1}};

int osx_keycode_to_rime_keycode(int keycode, int keychar, int shift, int caps) {
  for (const struct keycode_mapping_t* mapping = keycode_mappings;
       mapping->osx_keycode >= 0; ++mapping) {
    if (keycode == mapping->osx_keycode) {
      return mapping->rime_keycode;
    }
  }

  // NOTE: IBus/Rime use different keycodes for uppercase/lowercase letters.
  if (keychar >= 'a' && keychar <= 'z' && (!!shift != !!caps)) {
    // lowercase -> Uppercase
    return keychar - 'a' + 'A';
  }

  if (keychar >= 0x20 && keychar <= 0x7e) {
    return keychar;
  } else if (keychar == 0x1b) {  // ^[
    return XK_bracketleft;
  } else if (keychar == 0x1c) {  // ^\
    return XK_backslash;
  } else if (keychar == 0x1d) {  // ^]
    return XK_bracketright;
  } else if (keychar == 0x1f) {  // ^_
    return XK_minus;
  }

  return XK_VoidSymbol;
}

static const char* rime_modidifers[] = {
    "Lock",     // 1 << 16
    "Shift",    // 1 << 17
    "Control",  // 1 << 18
    "Alt",      // 1 << 19
    "Super",    // 1 << 20
    NULL,       // 1 << 21
    NULL,       // 1 << 22
    "Hyper",    // 1 << 23
};

NSEventModifierFlags parse_macos_modifiers(const char* modifier_name) {
  static const size_t n = sizeof(rime_modidifers) / sizeof(const char*);
  if (!modifier_name)
    return 0;
  for (size_t i = 0; i < n; ++i) {
    if (rime_modidifers[i] && !strcmp(modifier_name, rime_modidifers[i])) {
      return (1 << (i + 16));
    }
  }
  return 0;
}

int parse_rime_modifiers(const char* modifier_name) {
  return RimeGetModifierByName(modifier_name);
}

int parse_keycode(const char* key_name) {
  return RimeGetKeycodeByName(key_name);
}
