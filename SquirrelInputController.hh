#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController

// kPROCESS accepts miscellaneous / function keys (e.g. XK_Escape)
// The remaining 3 actions accept candidate indices (int), starting from item 0
// on page 0
typedef NS_ENUM(NSInteger, SquirrelAction) {
  kPROCESS = 0,
  kSELECT = 1,
  kHIGHLIGHT = 2,
  kDELETE = 3
};

typedef NS_ENUM(NSUInteger, SquirrelIndex) {
  // 0, 1, 2 ... are ordinal digits, used as (int) indices
  // 0xFFXX are rime keycodes (as function keys), for paging etc.
  kBackSpaceKey = 0xff08,   // XK_BackSpace
  kEscapeKey = 0xff1b,      // XK_Escape
  kCodeInputArea = 0xff37,  // XK_Codeinput
  kHomeKey = 0xff50,        // XK_Home
  kLeftKey = 0xff51,        // XK_Left
  kUpKey = 0xff52,          // XK_Up
  kRightKey = 0xff53,       // XK_Right
  kDownKey = 0xff54,        // XK_Down
  kPageUpKey = 0xff55,      // XK_Page_Up
  kPageDownKey = 0xff56,    // XK_Page_Down
  kEndKey = 0xff57,         // XK_End
  kExpandButton = 0xff04,
  kCompressButton = 0xff05,
  kLockButton = 0xff06,
  kVoidSymbol = 0xffffff  // XK_VoidSymbol
};

@property(weak, readonly, nullable, direct, class)
    SquirrelInputController* currentController;
@property(nonatomic, strong, readonly, nonnull)
    NSAppearance* viewEffectiveAppearance API_AVAILABLE(macos(10.14));
@property(nonatomic, strong, readonly, nonnull, direct)
    NSMutableArray<NSString*>* candidateTexts;
@property(nonatomic, strong, readonly, nonnull, direct)
    NSMutableArray<NSString*>* candidateComments;

- (void)moveCursor:(NSUInteger)cursorPosition
         toPosition:(NSUInteger)targetPosition
      inlinePreedit:(BOOL)inlinePreedit
    inlineCandidate:(BOOL)inlineCandidate __attribute__((objc_direct));
- (void)performAction:(SquirrelAction)action
              onIndex:(SquirrelIndex)index __attribute__((objc_direct));

@end  // SquirrelInputController
