
#import <Cocoa/Cocoa.h>

// Note: the SquirrelApplicationDelegate is instantiated automatically as an outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject
{
    IBOutlet NSMenu* _menu;
}

-(NSMenu*)menu;

@end
