#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController

- (BOOL)perform:(NSUInteger)action onIndex:(NSUInteger)index;

@end

#define kSELECT 0x1
#define kDELETE 0x2
#define kCHOOSE 0x3
