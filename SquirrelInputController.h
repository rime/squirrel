#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController

typedef enum {
  kSELECT = 1, // accepts indices in both digits and selection keys
  kDELETE = 2, // only accepts indices in digits, e.g. (int) 1
  kCHOOSE = 3 // only accepts indices in selection keys, e.g. (char) '1' / 'A'
} rimeAction;

typedef enum {
  // 0 ... 9 are ordinal digits, used as (int) index
  // 0x21 ... 0x7e are ASCII chars (as selection keys)
  // other rime keycodes (as function keys), for paging etc.
  kEscape     = 0xff1b, // XK_Escape
  kPageUp     = 0xff55, // XK_Page_Up
  kPageDown   = 0xff56, // XK_Page_Down
  kVoidSymbol = 0xffffff // XK_VoidSymbol
} rimeIndex;

- (void)perform:(rimeAction)action
        onIndex:(rimeIndex)index;

@end
