#import <Cocoa/Cocoa.h>
#import "rime_api.h"

@class SquirrelConfig;
@class SquirrelPanel;
@class SquirrelOptionSwitcher;

// Note: the SquirrelApplicationDelegate is instantiated automatically as an
// outlet of NSApp's instance
@interface SquirrelApplicationDelegate : NSObject <NSApplicationDelegate>

typedef NS_CLOSED_ENUM(NSUInteger, SquirrelNotificationPolicy) {
  kShowNotificationsNever = 0,
  kShowNotificationsWhenAppropriate = 1,
  kShowNotificationsAlways = 2
};

@property(nonatomic, weak, nullable) IBOutlet NSMenu* menu;
@property(nonatomic, weak, nullable) IBOutlet SquirrelPanel* panel;
@property(nonatomic, weak, nullable) IBOutlet id updater;

@property(nonatomic, readonly, strong, nullable, direct) SquirrelConfig* config;
@property(nonatomic, readonly, direct)
    SquirrelNotificationPolicy showNotifications;
@property(nonatomic, readonly, direct) BOOL problematicLaunchDetected;
@property(nonatomic, direct) BOOL isCurrentInputMethod;

- (IBAction)showSwitcher:(id _Nullable)sender __attribute__((objc_direct));
- (IBAction)deploy:(id _Nullable)sender __attribute__((objc_direct));
- (IBAction)syncUserData:(id _Nullable)sender __attribute__((objc_direct));
- (IBAction)configure:(id _Nullable)sender __attribute__((objc_direct));
- (IBAction)openWiki:(id _Nullable)sender __attribute__((objc_direct));

- (void)setupRime __attribute__((objc_direct));
- (void)startRimeWithFullCheck:(BOOL)fullCheck __attribute__((objc_direct));
- (void)loadSettings __attribute__((objc_direct));
- (void)loadSchemaSpecificSettings:(NSString* _Nonnull)schemaId
                   withRimeSession:(RimeSessionId)sessionId
    __attribute__((objc_direct));
- (void)loadSchemaSpecificLabels:(NSString* _Nonnull)schemaId
    __attribute__((objc_direct));

@end  // SquirrelApplicationDelegate

@interface NSApplication (SquirrelApp)

@property(nonatomic, strong, readonly, nonnull, direct)
    SquirrelApplicationDelegate* squirrelAppDelegate;

@end  // NSApplication (SquirrelApp)

// also used in main.m
extern void show_notification(const char* _Nonnull msg_text);
