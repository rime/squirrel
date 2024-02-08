#ifndef _MACOS_KEYCODE_H_
#define _MACOS_KEYCODE_H_

#import <AppKit/AppKit.h>

// credit goes to tekezo@
// https://github.com/tekezo/Karabiner/blob/master/src/bridge/generator/keycode/data/KeyCode.data

// pc keyboard

#define kVK_PC_Application            0x6e
#define kVK_PC_BS                     0x33
#define kVK_PC_Del                    0x75
#define kVK_PC_Insert                 0x72
#define kVK_PC_KeypadNumLock          0x47
#define kVK_PC_Pause                  0x71
#define kVK_PC_Power                  0x7f
#define kVK_PC_PrintScreen            0x69
#define kVK_PC_ScrollLock             0x6b

// conversion functions

int get_rime_modifiers(NSEventModifierFlags modifiers);
int get_rime_keycode(ushort keycode, unichar keychar, bool shift, bool caps);


#endif /* _MACOS_KEYCODE_H_ */
