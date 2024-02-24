
#ifndef _MACOS_KEYCODE_H_
#define _MACOS_KEYCODE_H_

// masks

#define OSX_CAPITAL_MASK      1 << 16
#define OSX_SHIFT_MASK        1 << 17
#define OSX_CTRL_MASK         1 << 18
#define OSX_ALT_MASK          1 << 19
#define OSX_COMMAND_MASK      1 << 20
#define OSX_FN_MASK           1 << 23

// key codes
//
// credit goes to tekezo@
// https://github.com/tekezo/Karabiner/blob/master/src/bridge/generator/keycode/data/KeyCode.data

// ----------------------------------------
// alphabet

#define OSX_VK_A 0x0
#define OSX_VK_B 0xb
#define OSX_VK_C 0x8
#define OSX_VK_D 0x2
#define OSX_VK_E 0xe
#define OSX_VK_F 0x3
#define OSX_VK_G 0x5
#define OSX_VK_H 0x4
#define OSX_VK_I 0x22
#define OSX_VK_J 0x26
#define OSX_VK_K 0x28
#define OSX_VK_L 0x25
#define OSX_VK_M 0x2e
#define OSX_VK_N 0x2d
#define OSX_VK_O 0x1f
#define OSX_VK_P 0x23
#define OSX_VK_Q 0xc
#define OSX_VK_R 0xf
#define OSX_VK_S 0x1
#define OSX_VK_T 0x11
#define OSX_VK_U 0x20
#define OSX_VK_V 0x9
#define OSX_VK_W 0xd
#define OSX_VK_X 0x7
#define OSX_VK_Y 0x10
#define OSX_VK_Z 0x6

// ----------------------------------------
// number

#define OSX_VK_KEY_0 0x1d
#define OSX_VK_KEY_1 0x12
#define OSX_VK_KEY_2 0x13
#define OSX_VK_KEY_3 0x14
#define OSX_VK_KEY_4 0x15
#define OSX_VK_KEY_5 0x17
#define OSX_VK_KEY_6 0x16
#define OSX_VK_KEY_7 0x1a
#define OSX_VK_KEY_8 0x1c
#define OSX_VK_KEY_9 0x19

// ----------------------------------------
// symbol

// BACKQUOTE is also known as grave accent or backtick.
#define OSX_VK_BACKQUOTE     0x32
#define OSX_VK_BACKSLASH     0x2a
#define OSX_VK_BRACKET_LEFT  0x21
#define OSX_VK_BRACKET_RIGHT 0x1e
#define OSX_VK_COMMA         0x2b
#define OSX_VK_DOT           0x2f
#define OSX_VK_EQUAL         0x18
#define OSX_VK_MINUS         0x1b
#define OSX_VK_QUOTE         0x27
#define OSX_VK_SEMICOLON     0x29
#define OSX_VK_SLASH         0x2c

// ----------------------------------------
// keypad

#define OSX_VK_KEYPAD_0        0x52
#define OSX_VK_KEYPAD_1        0x53
#define OSX_VK_KEYPAD_2        0x54
#define OSX_VK_KEYPAD_3        0x55
#define OSX_VK_KEYPAD_4        0x56
#define OSX_VK_KEYPAD_5        0x57
#define OSX_VK_KEYPAD_6        0x58
#define OSX_VK_KEYPAD_7        0x59
#define OSX_VK_KEYPAD_8        0x5b
#define OSX_VK_KEYPAD_9        0x5c
#define OSX_VK_KEYPAD_CLEAR    0x47
#define OSX_VK_KEYPAD_COMMA    0x5f
#define OSX_VK_KEYPAD_DOT      0x41
#define OSX_VK_KEYPAD_EQUAL    0x51
#define OSX_VK_KEYPAD_MINUS    0x4e
#define OSX_VK_KEYPAD_MULTIPLY 0x43
#define OSX_VK_KEYPAD_PLUS     0x45
#define OSX_VK_KEYPAD_SLASH    0x4b

// ----------------------------------------
// special

#define OSX_VK_DELETE          0x33
#define OSX_VK_ENTER           0x4c
#define OSX_VK_ENTER_POWERBOOK 0x34
#define OSX_VK_ESCAPE          0x35
#define OSX_VK_FORWARD_DELETE  0x75
#define OSX_VK_HELP            0x72
#define OSX_VK_RETURN          0x24
#define OSX_VK_SPACE           0x31
#define OSX_VK_TAB             0x30

// ----------------------------------------
// function
#define OSX_VK_F1  0x7a
#define OSX_VK_F2  0x78
#define OSX_VK_F3  0x63
#define OSX_VK_F4  0x76
#define OSX_VK_F5  0x60
#define OSX_VK_F6  0x61
#define OSX_VK_F7  0x62
#define OSX_VK_F8  0x64
#define OSX_VK_F9  0x65
#define OSX_VK_F10 0x6d
#define OSX_VK_F11 0x67
#define OSX_VK_F12 0x6f
#define OSX_VK_F13 0x69
#define OSX_VK_F14 0x6b
#define OSX_VK_F15 0x71
#define OSX_VK_F16 0x6a
#define OSX_VK_F17 0x40
#define OSX_VK_F18 0x4f
#define OSX_VK_F19 0x50

// ----------------------------------------
// functional

#define OSX_VK_BRIGHTNESS_DOWN 0x91
#define OSX_VK_BRIGHTNESS_UP   0x90
#define OSX_VK_DASHBOARD       0x82
#define OSX_VK_EXPOSE_ALL      0xa0
#define OSX_VK_LAUNCHPAD       0x83
#define OSX_VK_MISSION_CONTROL 0xa0

// ----------------------------------------
// cursor

#define OSX_VK_CURSOR_UP    0x7e
#define OSX_VK_CURSOR_DOWN  0x7d
#define OSX_VK_CURSOR_LEFT  0x7b
#define OSX_VK_CURSOR_RIGHT 0x7c

#define OSX_VK_PAGEUP   0x74
#define OSX_VK_PAGEDOWN 0x79
#define OSX_VK_HOME     0x73
#define OSX_VK_END      0x77

// ----------------------------------------
// modifiers
#define OSX_VK_CAPSLOCK  0x39
#define OSX_VK_COMMAND_L 0x37
#define OSX_VK_COMMAND_R 0x36
#define OSX_VK_CONTROL_L 0x3b
#define OSX_VK_CONTROL_R 0x3e
#define OSX_VK_FN        0x3f
#define OSX_VK_OPTION_L  0x3a
#define OSX_VK_OPTION_R  0x3d
#define OSX_VK_SHIFT_L   0x38
#define OSX_VK_SHIFT_R   0x3c

// ----------------------------------------
// pc keyboard

#define OSX_VK_PC_APPLICATION    0x6e
#define OSX_VK_PC_BS             0x33
#define OSX_VK_PC_DEL            0x75
#define OSX_VK_PC_INSERT         0x72
#define OSX_VK_PC_KEYPAD_NUMLOCK 0x47
#define OSX_VK_PC_PAUSE          0x71
#define OSX_VK_PC_POWER          0x7f
#define OSX_VK_PC_PRINTSCREEN    0x69
#define OSX_VK_PC_SCROLLLOCK     0x6b

// ----------------------------------------
// international

#define OSX_VK_DANISH_DOLLAR 0xa
#define OSX_VK_DANISH_LESS_THAN 0x32

#define OSX_VK_FRENCH_DOLLAR      0x1e
#define OSX_VK_FRENCH_EQUAL       0x2c
#define OSX_VK_FRENCH_HAT         0x21
#define OSX_VK_FRENCH_MINUS       0x18
#define OSX_VK_FRENCH_RIGHT_PAREN 0x1b

#define OSX_VK_GERMAN_CIRCUMFLEX   0xa
#define OSX_VK_GERMAN_LESS_THAN    0x32
#define OSX_VK_GERMAN_PC_LESS_THAN 0x80
#define OSX_VK_GERMAN_QUOTE        0x18
#define OSX_VK_GERMAN_A_UMLAUT     0x27
#define OSX_VK_GERMAN_O_UMLAUT     0x29
#define OSX_VK_GERMAN_U_UMLAUT     0x21

#define OSX_VK_ITALIAN_BACKSLASH 0xa
#define OSX_VK_ITALIAN_LESS_THAN 0x32

#define OSX_VK_JIS_ATMARK        0x21
#define OSX_VK_JIS_BRACKET_LEFT  0x1e
#define OSX_VK_JIS_BRACKET_RIGHT 0x2a
#define OSX_VK_JIS_COLON         0x27
#define OSX_VK_JIS_DAKUON        0x21
#define OSX_VK_JIS_EISUU         0x66
#define OSX_VK_JIS_HANDAKUON     0x1e
#define OSX_VK_JIS_HAT           0x18
#define OSX_VK_JIS_KANA          0x68
#define OSX_VK_JIS_PC_HAN_ZEN    0x32
#define OSX_VK_JIS_UNDERSCORE    0x5e
#define OSX_VK_JIS_YEN           0x5d

#define OSX_VK_RUSSIAN_PARAGRAPH 0xa
#define OSX_VK_RUSSIAN_TILDE     0x32

#define OSX_VK_SPANISH_LESS_THAN         0x32
#define OSX_VK_SPANISH_ORDINAL_INDICATOR 0xa

#define OSX_VK_SWEDISH_LESS_THAN 0x32
#define OSX_VK_SWEDISH_SECTION   0xa

#define OSX_VK_SWISS_LESS_THAN 0x32
#define OSX_VK_SWISS_SECTION   0xa

#define OSX_VK_UK_SECTION 0xa

// conversion functions

int osx_modifiers_to_rime_modifiers(unsigned long modifiers);
int osx_keycode_to_rime_keycode(int keycode, int keychar, int shift, int caps);


#endif /* _MACOS_KEYCODE_H_ */
