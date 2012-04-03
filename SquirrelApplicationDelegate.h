
#import <Cocoa/Cocoa.h>
#import "SquirrelPanel.h"

// Note: the SquirrelApplicationDelegate is instantiated automatically as an outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject
{
  IBOutlet NSMenu* _menu;
  IBOutlet SquirrelPanel* _panel;
  IBOutlet id _updater;

  // global options
  BOOL _useUSKeyboardLayout;
}

-(NSMenu*)menu;
-(SquirrelPanel*)panel;
-(id)updater;
-(BOOL)useUSKeyboardLayout;

-(IBAction)deploy:(id)sender;
-(void)startRimeWithFullCheck:(BOOL)fullCheck;
-(void)loadSquirrelConfig;

@end
