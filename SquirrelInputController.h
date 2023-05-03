#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController
- (BOOL)actionWithCandidate:(NSInteger)index;
@end
