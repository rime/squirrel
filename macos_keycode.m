#import "macos_keycode.h"
#import <rime/key_table.h>


int osx_modifiers_to_rime_modifiers(unsigned long modifiers) {
  int ret = 0;

  if (modifiers & OSX_CAPITAL_MASK)
    ret |= kLockMask;
  if (modifiers & OSX_SHIFT_MASK)
    ret |= kShiftMask;
  if (modifiers & OSX_CTRL_MASK)
    ret |= kControlMask;
  if (modifiers & OSX_ALT_MASK)
    ret |= kAltMask;
  if (modifiers & OSX_COMMAND_MASK)
    ret |= kSuperMask;
  if (modifiers & OSX_FN_MASK)
    ret |= kHyperMask;

  return ret;
}

static struct keycode_mapping_t {
  int osx_keycode, rime_keycode;
} keycode_mappings[] = {
  // modifiers
  { OSX_VK_CAPSLOCK,          XK_Caps_Lock    },
  { OSX_VK_COMMAND_L,         XK_Super_L      }, // XK_Meta_L?
  { OSX_VK_COMMAND_R,         XK_Super_R      }, // XK_Meta_R?
  { OSX_VK_CONTROL_L,         XK_Control_L    },
  { OSX_VK_CONTROL_R,         XK_Control_R    },
  { OSX_VK_FN,                XK_Hyper_L      },
  { OSX_VK_OPTION_L,          XK_Alt_L        },
  { OSX_VK_OPTION_R,          XK_Alt_R        },
  { OSX_VK_SHIFT_L,           XK_Shift_L      },
  { OSX_VK_SHIFT_R,           XK_Shift_R      },

  // special
  { OSX_VK_DELETE,            XK_BackSpace    },
  { OSX_VK_ENTER,             XK_KP_Enter     },
  //OSX_VK_ENTER_POWERBOOK -> ?
  { OSX_VK_ESCAPE,            XK_Escape       },
  { OSX_VK_FORWARD_DELETE,    XK_Delete       },
  //{OSX_VK_HELP, XK_Help}, // the same keycode as OSX_VK_PC_INSERT
  { OSX_VK_RETURN,            XK_Return       },
  { OSX_VK_SPACE,             XK_space        },
  { OSX_VK_TAB,               XK_Tab          },

  // function
  { OSX_VK_F1,                XK_F1           },
  { OSX_VK_F2,                XK_F2           },
  { OSX_VK_F3,                XK_F3           },
  { OSX_VK_F4,                XK_F4           },
  { OSX_VK_F5,                XK_F5           },
  { OSX_VK_F6,                XK_F6           },
  { OSX_VK_F7,                XK_F7           },
  { OSX_VK_F8,                XK_F8           },
  { OSX_VK_F9,                XK_F9           },
  { OSX_VK_F10,               XK_F10          },
  { OSX_VK_F11,               XK_F11          },
  { OSX_VK_F12,               XK_F12          },
  { OSX_VK_F13,               XK_F13          },
  { OSX_VK_F14,               XK_F14          },
  { OSX_VK_F15,               XK_F15          },
  { OSX_VK_F16,               XK_F16          },
  { OSX_VK_F17,               XK_F17          },
  { OSX_VK_F18,               XK_F18          },
  { OSX_VK_F19,               XK_F19          },

  // cursor
  { OSX_VK_CURSOR_UP,         XK_Up           },
  { OSX_VK_CURSOR_DOWN,       XK_Down         },
  { OSX_VK_CURSOR_LEFT,       XK_Left         },
  { OSX_VK_CURSOR_RIGHT,      XK_Right        },
  { OSX_VK_PAGEUP,            XK_Page_Up      },
  { OSX_VK_PAGEDOWN,          XK_Page_Down    },
  { OSX_VK_HOME,              XK_Home         },
  { OSX_VK_END,               XK_End          },

  // keypad
  { OSX_VK_KEYPAD_0,          XK_KP_0         },
  { OSX_VK_KEYPAD_1,          XK_KP_1         },
  { OSX_VK_KEYPAD_2,          XK_KP_2         },
  { OSX_VK_KEYPAD_3,          XK_KP_3         },
  { OSX_VK_KEYPAD_4,          XK_KP_4         },
  { OSX_VK_KEYPAD_5,          XK_KP_5         },
  { OSX_VK_KEYPAD_6,          XK_KP_6         },
  { OSX_VK_KEYPAD_7,          XK_KP_7         },
  { OSX_VK_KEYPAD_8,          XK_KP_8         },
  { OSX_VK_KEYPAD_9,          XK_KP_9         },
  { OSX_VK_KEYPAD_CLEAR,      XK_Clear        },
  { OSX_VK_KEYPAD_COMMA,      XK_KP_Separator },
  { OSX_VK_KEYPAD_DOT,        XK_KP_Decimal   },
  { OSX_VK_KEYPAD_EQUAL,      XK_KP_Equal     },
  { OSX_VK_KEYPAD_MINUS,      XK_KP_Subtract  },
  { OSX_VK_KEYPAD_MULTIPLY,   XK_KP_Multiply  },
  { OSX_VK_KEYPAD_PLUS,       XK_KP_Add       },
  { OSX_VK_KEYPAD_SLASH,      XK_KP_Divide    },

  // pc keyboard
  { OSX_VK_PC_APPLICATION,    XK_Menu         },
  { OSX_VK_PC_INSERT,         XK_Insert       },
  //{OSX_VK_PC_KEYPAD_NUMLOCK, XK_Num_Lock}, // the same keycode as OSX_VK_KEYPAD_CLEAR
  { OSX_VK_PC_PAUSE,          XK_Pause        },
  //OSX_VK_PC_POWER -> ?
  { OSX_VK_PC_PRINTSCREEN,    XK_Print        },
  { OSX_VK_PC_SCROLLLOCK,     XK_Scroll_Lock  },

  // JIS keyboard
  { OSX_VK_JIS_EISUU,         XK_Eisu_toggle  },
  { OSX_VK_JIS_KANA,          XK_Kana_Lock    },

  { -1,                       -1              }
};

int osx_keycode_to_rime_keycode(int keycode, int keychar, int shift, int caps) {
  for (struct keycode_mapping_t *mapping = keycode_mappings;
       mapping->osx_keycode >= 0;
       ++mapping) {
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
  }

  switch (keychar) {
    case 0x0003:
      return XK_KP_Enter;
      break;
    case 0x0008:
      return XK_BackSpace;
      break;
    case 0x0009:
    case 0x0019:
      return XK_Tab;
      break;
    case 0x000a:
      return XK_Return;
      break;
    case 0xF728:
      return XK_Delete;
      break;
    case 0xF700:
      return XK_Up;
      break;
    case 0xF701:
      return XK_Down;
      break;
    case 0xF702:
      return XK_Left;
      break;
    case 0xF703:
      return XK_Right;
      break;
    case 0xF704:
      return XK_F1;
      break;
    case 0xF705:
      return XK_F2;
      break;
    case 0xF706:
      return XK_F3;
      break;
    case 0xF707:
      return XK_F4;
      break;
    case 0xF708:
      return XK_F5;
      break;
    case 0xF709:
      return XK_F6;
      break;
    case 0xF70A:
      return XK_F7;
      break;
    case 0xF70B:
      return XK_F8;
      break;
    case 0xF70C:
      return XK_F9;
      break;
    case 0xF70D:
      return XK_F10;
      break;
    case 0xF70E:
      return XK_F11;
      break;
    case 0xF70F:
      return XK_F12;
      break;
    case 0xF710:
      return XK_F13;
      break;
    case 0xF711:
      return XK_F14;
      break;
    case 0xF712:
      return XK_F15;
      break;
    case 0xF713:
      return XK_F16;
      break;
    case 0xF714:
      return XK_F17;
      break;
    case 0xF715:
      return XK_F18;
      break;
    case 0xF716:
      return XK_F19;
      break;
    case 0xF717:
      return XK_F20;
      break;
    case 0xF718:
      return XK_F21;
      break;
    case 0xF719:
      return XK_F22;
      break;
    case 0xF71A:
      return XK_F23;
      break;
    case 0xF71B:
      return XK_F24;
      break;
    case 0xF71C:
      return XK_F25;
      break;
    case 0xF71D:
      return XK_F26;
      break;
    case 0xF71E:
      return XK_F27;
      break;
    case 0xF71F:
      return XK_F28;
      break;
    case 0xF720:
      return XK_F29;
      break;
    case 0xF721:
      return XK_F30;
      break;
    case 0xF722:
      return XK_F31;
      break;
    case 0xF723:
      return XK_F32;
      break;
    case 0xF724:
      return XK_F33;
      break;
    case 0xF725:
      return XK_F34;
      break;
    case 0xF726:
      return XK_F35;
      break;
    case 0xF72A:
      return XK_Begin;
      break;
    case 0xF72C:
      return XK_Page_Up;
      break;
    case 0xF72D:
      return XK_Page_Down;
      break;
    case 0xF729:
      return XK_Home;
      break;
    case 0xF72B:
      return XK_End;
      break;
    case 0xF732:
      return XK_Break;
      break;
    case 0xF73A:
      return XK_Clear;
      break;
    case 0xF739:
      return XK_Num_Lock;
      break;
    case 0xF73E:
      return XK_Delete;
      break;
    case 0xF742:
      return XK_Execute;
      break;
    case 0xF745:
      return XK_Find;
      break;
    case 0xF746:
      return XK_Help;
      break;
    case 0xF727:
      return XK_Insert;
      break;
    case 0xF735:
      return XK_Menu;
      break;
    case 0xF747:
      return XK_Mode_switch;
      break;
    case 0xF730:
      return XK_Pause;
      break;
    case 0xF738:
      return XK_Print;
      break;
    case 0xF744:
      return XK_Redo;
      break;
    case 0xF72F:
      return XK_Scroll_Lock;
      break;
    case 0xF741:
      return XK_Select;
      break;
    case 0xF734:
      return XK_Cancel;
      break;
    case 0xF731:
      return XK_Sys_Req;
      break;
    case 0xF743:
      return XK_Undo;
      break;
    default:
      return XK_VoidSymbol;
      break;
  }
}
