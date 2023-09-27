#import <Cocoa/Cocoa.h>

@class SquirrelConfig;
@class SquirrelPanel;
@class SquirrelOptionSwitcher;

// Note: the SquirrelApplicationDelegate is instantiated automatically as an outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject

@property(nonatomic, copy) IBOutlet NSMenu *menu;
@property(nonatomic, strong) IBOutlet SquirrelPanel *panel;
@property(nonatomic, strong) IBOutlet id updater;

@property(nonatomic, readonly, strong) SquirrelConfig *config;
@property(nonatomic, readonly) BOOL enableNotifications;

- (IBAction)deploy:(id)sender;
- (IBAction)syncUserData:(id)sender;
- (IBAction)configure:(id)sender;
- (IBAction)openWiki:(id)sender;

- (void)setupRime;
- (void)startRimeWithFullCheck:(BOOL)fullCheck;
- (void)loadSettings;
- (void)loadSchemaSpecificSettings:(NSString *)schemaId;
- (void)loadSchemaSpecificLabels:(NSString *)schemaId;

@property(nonatomic, readonly) BOOL problematicLaunchDetected;

@end

@interface NSApplication (SquirrelApp)

@property(nonatomic, readonly, strong) SquirrelApplicationDelegate *squirrelAppDelegate;

@end

// also used in main.m
extern void show_message(const char *msg_text, const char *msg_id);
