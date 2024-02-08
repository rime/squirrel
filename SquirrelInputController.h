#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

typedef enum {
  kSELECT = 1, // accepts indices in digits, selection keys, and keycodes (XK_Escape)
  kHILITE = 2, // accepts indices in digits and selection keys (char '1' / 'A')
  kDELETE = 3  // only accepts indices in digits (int 1)
} rimeAction;

typedef NS_ENUM(NSUInteger, rimeIndex) {
  // 0 ... 9 are ordinal digits, used as (int) index
  // 0x21 ... 0x7e are ASCII chars (as selection keys)
  // other rime keycodes (as function keys), for paging etc.
  kBackSpace  = 0xff08, // XK_BackSpace
  kEscape     = 0xff1b, // XK_Escape
  kHome       = 0xff50, // XK_Home
  kPageUp     = 0xff55, // XK_Page_Up
  kPageDown   = 0xff56, // XK_Page_Down
  kEnd        = 0xff57, // XK_End
  kVoidSymbol = 0xffffff // XK_VoidSymbol
};

@interface SquirrelInputController : IMKInputController

- (void)perform:(rimeAction)action
        onIndex:(rimeIndex)index;

@end
