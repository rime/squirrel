#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController
- (BOOL)selectCandidate:(NSInteger)index;
- (BOOL)pageUp:(BOOL)up;
@end
