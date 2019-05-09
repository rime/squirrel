#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

@interface SquirrelInputController : IMKInputController
-(void)rimeUpdate;
-(void)clearComposition;
@end
