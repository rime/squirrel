
#ifndef _MACOS_KEYCODE_HH_
#define _MACOS_KEYCODE_HH_

#import <AppKit/AppKit.h>

// credit goes to tekezo@
// https://github.com/tekezo/Karabiner/blob/master/src/bridge/generator/keycode/data/KeyCode.data

// ----------------------------------------
// pc keyboard

#define kVK_PC_Application 0x6e
#define kVK_PC_BS 0x33
#define kVK_PC_Del 0x75
#define kVK_PC_Insert 0x72
#define kVK_PC_KeypadNumLock 0x47
#define kVK_PC_Pause 0x71
#define kVK_PC_Power 0x7f
#define kVK_PC_PrintScreen 0x69
#define kVK_PC_ScrollLock 0x6b

// conversion functions

int osx_modifiers_to_rime_modifiers(NSEventModifierFlags modifiers);
int osx_keycode_to_rime_keycode(int keycode, int keychar, int shift, int caps);

NSEventModifierFlags parse_macos_modifiers(const char* modifier_name);
int parse_rime_modifiers(const char* modifier_name);
int parse_keycode(const char* key_name);

#endif /* _MACOS_KEYCODE_HH_ */
