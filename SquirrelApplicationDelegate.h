#import <Cocoa/Cocoa.h>

#import <rime_api.h>
@class SquirrelConfig;
@class SquirrelPanel;
@class SquirrelOptionSwitcher;

// Note: the SquirrelApplicationDelegate is instantiated automatically as an
// outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject <NSApplicationDelegate>

typedef NS_ENUM(NSUInteger, SquirrelNotificationPolicy) {
  kShowNotificationsNever = 0,
  kShowNotificationsWhenAppropriate = 1,
  kShowNotificationsAlways = 2
};

@property(nonatomic, weak, nullable) IBOutlet NSMenu* menu;
@property(nonatomic, weak, nullable) IBOutlet SquirrelPanel* panel;
@property(nonatomic, weak, nullable) IBOutlet id updater;

@property(nonatomic, strong, readonly, nullable) SquirrelConfig* config;
@property(nonatomic, readonly) SquirrelNotificationPolicy showNotifications;

- (IBAction)deploy:(id _Nullable)sender;
- (IBAction)syncUserData:(id _Nullable)sender;
- (IBAction)configure:(id _Nullable)sender;
- (IBAction)openWiki:(id _Nullable)sender;

- (void)setupRime;
- (void)startRimeWithFullCheck:(BOOL)fullCheck;
- (void)loadSettings;
- (void)loadSchemaSpecificSettings:(NSString* _Nonnull)schemaId
                   withRimeSession:(RimeSessionId)sessionId;
- (void)loadSchemaSpecificLabels:(NSString* _Nonnull)schemaId;

@property(nonatomic, readonly) BOOL problematicLaunchDetected;

@end  // SquirrelApplicationDelegate

@interface NSApplication (SquirrelApp)

@property(nonatomic, strong, readonly, nonnull)
    SquirrelApplicationDelegate* squirrelAppDelegate;

@end  // NSApplication (SquirrelApp)

// also used in main.m
extern void show_notification(const char* _Nonnull msg_text);
