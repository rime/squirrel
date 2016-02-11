
#import <Cocoa/Cocoa.h>
#import <rime_api.h>
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
  NSTimeInterval _chordDuration;
  SquirrelUIStyle* _baseStyle;
}

@property (nonatomic, readonly, copy) NSMenu *menu;
@property (nonatomic, readonly, strong) SquirrelPanel *panel;
@property (nonatomic, readonly, strong) id updater;
@property (nonatomic, readonly) BOOL useUSKeyboardLayout;
@property (nonatomic, readonly) BOOL enableNotifications;
@property (nonatomic, readonly) BOOL preferNotificationCenter;
@property (nonatomic, readonly, copy) NSDictionary *appOptions;
@property (nonatomic, readonly) NSTimeInterval chordDuration;

-(IBAction)deploy:(id)sender;
-(IBAction)syncUserData:(id)sender;
-(IBAction)configure:(id)sender;
-(IBAction)openWiki:(id)sender;

-(void)setupRime;
-(void)startRimeWithFullCheck:(BOOL)fullCheck;
-(void)loadSquirrelConfig;
@property (nonatomic, readonly) BOOL problematicLaunchDetected;

-(void)updateUIStyle:(RimeConfig*)config initialize:(BOOL)initializing;

@end

@interface NSApplication (SquirrelApp)

@property(nonatomic, readonly, strong) SquirrelApplicationDelegate *squirrelAppDelegate;

@end

// also used in main.m
extern void (*show_message)(const char* msg_text, const char* msg_id);
