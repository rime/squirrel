
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
  BOOL _enableNotifications;
  BOOL _enableBuitinNotifcations;
  BOOL _preferNotificationCenter;
  NSDictionary* _appOptions;
}

-(NSMenu*)menu;
-(SquirrelPanel*)panel;
-(id)updater;
-(BOOL)useUSKeyboardLayout;
-(BOOL)enableNotifications;
-(BOOL)preferNotificationCenter;
-(NSDictionary*)appOptions;

-(IBAction)deploy:(id)sender;
-(IBAction)syncUserData:(id)sender;
-(IBAction)configure:(id)sender;
-(IBAction)openWiki:(id)sender;

-(void)startRimeWithFullCheck:(BOOL)fullCheck;
-(void)loadSquirrelConfig;
-(BOOL)problematicLaunchDetected;

@end

// also used in main.m
extern void (*show_message)(const char* msg_text, const char* msg_id);
