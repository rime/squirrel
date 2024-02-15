#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController

typedef NS_ENUM(NSInteger, SquirrelAction) {
  kSELECT = 1, // accepts indices in digits, selection keys, and keycodes (XK_Escape)
  kHILITE = 2, // accepts indices in digits and selection keys (char '1' / 'A')
  kDELETE = 3  // only accepts indices in digits (int 1)
};

typedef NS_ENUM(NSUInteger, SquirrelIndex) {
  // 0 ... 9 are ordinal digits, used as (int) index
  // 0x21 ... 0x7e are ASCII chars (as selection keys)
  // other rime keycodes (as function keys), for paging etc.
  kBackSpace  = 0xff08, // XK_BackSpace
  kEscape     = 0xff1b, // XK_Escape
  kCodeInput  = 0xff37, // XK_Codeinput
  kHome       = 0xff50, // XK_Home
  kPageUp     = 0xff55, // XK_Page_Up
  kPageDown   = 0xff56, // XK_Page_Down
  kEnd        = 0xff57, // XK_End
  kVoidSymbol = 0xffffff // XK_VoidSymbol
};

@property(class, weak, readonly) SquirrelInputController *currentController;

- (void)moveCursor:(NSUInteger)cursorPosition
        toPosition:(NSUInteger)targetPosition
     inlinePreedit:(BOOL)inlinePreedit
   inlineCandidate:(BOOL)inlineCandidate;

- (void)perform:(SquirrelAction)action
        onIndex:(SquirrelIndex)index;

@end // SquirrelInputController
