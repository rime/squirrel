
#import <Cocoa/Cocoa.h>
#import "SquirrelPanel.h"

// Note: the SquirrelApplicationDelegate is instantiated automatically as an outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject
{
  IBOutlet NSMenu* _menu;
  IBOutlet SquirrelPanel* _panel;
  // global options
  bool _useUSKeyboardLayout;
}

-(NSMenu*)menu;
-(SquirrelPanel*)panel;
-(bool)useUSKeyboardLayout;

-(void)loadConfig;

@end
