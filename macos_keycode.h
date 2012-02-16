
#ifndef _MACOS_KEYCODE_H_
#define _MACOS_KEYCODE_H_

/* get the definitions from <AppKit/NSEvent.h> and <Carbon/Events.h> */

#define OSX_SHIFT_MASK        1 << 17
#define OSX_CTRL_MASK         1 << 18
#define OSX_ALT_MASK          1 << 19
#define OSX_COMMAND_MASK      1 << 20

#define OSX_VK_SPACE          0x31
#define OSX_VK_MINUS          0x1B
#define OSX_VK_EQUALS         0x18
#define OSX_VK_COMMA          0x2B
#define OSX_VK_PERIOD         0x2F
#define OSX_VK_OPEN_BRACKET   0x21
#define OSX_VK_CLOSE_BRACKET  0x1E
#define OSX_VK_BACK_QUOTE     0x32

#define OSX_VK_TAB            0x30
#define OSX_VK_ENTER          0x24
#define OSX_VK_BACK_SPACE     0x33
#define OSX_VK_ESCAPE         0x35
#define OSX_VK_PAGE_UP        0x74
#define OSX_VK_PAGE_DOWN      0x79
#define OSX_VK_END            0x77
#define OSX_VK_HOME           0x73
#define OSX_VK_LEFT           0x7B
#define OSX_VK_UP             0x7E
#define OSX_VK_RIGHT          0x7C
#define OSX_VK_DOWN           0x7D
#define OSX_VK_DELETE         0x75

#define OSX_VK_CONTROL_L      0x3B
#define OSX_VK_CONTROL_R      0x3E
#define OSX_VK_SHIFT_L        0x38
#define OSX_VK_SHIFT_R        0x3C
#define OSX_VK_ALT            0x3A


int osx_modifiers_to_rime_modifiers(unsigned modifiers);
int osx_keycode_to_rime_keycode(int keycode, int keychar, int shift);


#endif /* _MACOS_KEYCODE_H_ */
