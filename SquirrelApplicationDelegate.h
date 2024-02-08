#import <Cocoa/Cocoa.h>

#import <rime_api.h>
@class SquirrelConfig;
@class SquirrelPanel;
@class SquirrelOptionSwitcher;

typedef enum {
  kShowNotificationsNever = 0,
  kShowNotificationsWhenAppropriate = 1,
  kShowNotificationsAlways = 2
} SquirrelNotificationPolicy;

// Note: the SquirrelApplicationDelegate is instantiated automatically as an outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, weak) IBOutlet NSMenu *menu;
@property(nonatomic, weak) IBOutlet SquirrelPanel *panel;
@property(nonatomic, weak) IBOutlet id updater;

@property(nonatomic, readonly, strong) SquirrelConfig *config;
@property(nonatomic, readonly) SquirrelNotificationPolicy showNotifications;

- (IBAction)deploy:(id)sender;
- (IBAction)syncUserData:(id)sender;
- (IBAction)configure:(id)sender;
- (IBAction)openWiki:(id)sender;
- (IBAction)openLogFolder:(id)sender;

- (void)setupRime;
- (void)startRimeWithFullCheck:(BOOL)fullCheck;
- (void)loadSettings;
- (void)loadSchemaSpecificSettings:(NSString *)schemaId
                   withRimeSession:(RimeSessionId)sessionId;
- (void)loadSchemaSpecificLabels:(NSString *)schemaId;

@property(nonatomic, readonly) BOOL problematicLaunchDetected;

@end

@interface NSApplication (SquirrelApp)

@property(nonatomic, readonly, strong) SquirrelApplicationDelegate *squirrelAppDelegate;

@end

// also used in main.m
extern void show_notification(const char *msg_text);
