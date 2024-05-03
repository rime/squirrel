
#ifndef _MACOS_KEYCODE_HH_
#define _MACOS_KEYCODE_HH_

#import <AppKit/AppKit.h>

// credit goes to tekezo@
// https://github.com/tekezo/Karabiner/blob/master/src/bridge/generator/keycode/data/KeyCode.data

enum {
  // powerbook
  kVK_Enter_Powerbook = 0x34,
  // pc keyboard
  kVK_PC_Application = 0x6e,
  kVK_PC_Power = 0x7f,
};
// conversion functions

int rime_modifiers_from_mac_modifiers(NSEventModifierFlags modifiers);
int rime_keycode_from_mac_keycode(ushort mac_keycode);
int rime_keycode_from_keychar(unichar keychar, bool shift, bool caps);

int rime_modifiers_from_name(const char* modifier_name);
int rime_keycode_from_name(const char* key_name);

#endif /* _MACOS_KEYCODE_HH_ */
