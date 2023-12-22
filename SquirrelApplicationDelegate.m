#import "SquirrelApplicationDelegate.h"

#import <rime_api.h>
#import "SquirrelConfig.h"
#import "SquirrelPanel.h"

static NSString *kRimeWikiURL = @"https://github.com/rime/home/wiki";

@implementation SquirrelApplicationDelegate

- (IBAction)deploy:(id)sender {
  NSLog(@"Start maintenance...");
  [self shutdownRime];
  [self startRimeWithFullCheck:true];
  [self loadSettings];
}

- (IBAction)syncUserData:(id)sender {
  NSLog(@"Sync user data");
  rime_get_api()->sync_user_data();
}

- (IBAction)configure:(id)sender {
  [NSWorkspace.sharedWorkspace openURL:
    [NSURL fileURLWithPath:@"~/Library/Rime/".stringByExpandingTildeInPath isDirectory:YES]];
}

- (IBAction)openWiki:(id)sender {
  [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:kRimeWikiURL]];
}

- (IBAction)openLogFolder:(id)sender {
  NSString *tmpDir = NSTemporaryDirectory();
  NSString *logFile = [tmpDir stringByAppendingPathComponent:@"rime.squirrel.INFO"];
  [NSWorkspace.sharedWorkspace selectFile:logFile
                 inFileViewerRootedAtPath:tmpDir];
}

void show_message(const char *msg_text, const char *msg_id) {
  @autoreleasepool {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:NSLocalizedString(@"Squirrel", nil)];
    [notification setTitle:NSLocalizedString(@(msg_text), nil)];

    NSUserNotificationCenter *notificationCenter =
      NSUserNotificationCenter.defaultUserNotificationCenter;
    [notificationCenter removeAllDeliveredNotifications];
    [notificationCenter deliverNotification:notification];
  }
}

static void show_status_message(const char *msg_text_long, const char *msg_text_short, const char *msg_id) {
  SquirrelPanel *panel = NSApp.squirrelAppDelegate.panel;

  if (panel) {
    NSString *msgLong = msg_text_long ? @(msg_text_long) : nil;
    NSString *msgShort = msg_text_short ? @(msg_text_short) : nil;
    [panel updateStatusLong:msgLong statusShort:msgShort];
  }
}

static void notification_handler(void *context_object, RimeSessionId session_id,
                                 const char *message_type, const char *message_value) {
  if (!strcmp(message_type, "deploy")) {
    if (!strcmp(message_value, "start")) {
      show_message("deploy_start", message_type);
    } else if (!strcmp(message_value, "success")) {
      show_message("deploy_success", message_type);
    } else if (!strcmp(message_value, "failure")) {
      show_message("deploy_failure", message_type);
    }
    return;
  }
  id app_delegate = (__bridge id)context_object;
  // schema change
  if (!strcmp(message_type, "schema") &&
      app_delegate && [app_delegate enableNotifications]) {
    const char *schema_name = strchr(message_value, '/');
    if (schema_name) {
      ++schema_name;
      show_status_message(schema_name, schema_name, message_type);
    }
    return;
  }
  // option change
  if (!strcmp(message_type, "option") && app_delegate) {
    Bool state = message_value[0] != '!';
    const char *option_name = message_value + !state;
    if ([[app_delegate panel].optionSwitcher containsOption:@(option_name)]) {
      if ([[app_delegate panel].optionSwitcher updateGroupState:@(message_value) 
                                                       ofOption:@(option_name)]) {
        NSString *schemaId = [app_delegate panel].optionSwitcher.schemaId;
        [app_delegate loadSchemaSpecificLabels:schemaId];
        [app_delegate loadSchemaSpecificSettings:schemaId];
      }
    }
    if ([app_delegate enableNotifications]) {
      RimeStringSlice state_label_long = rime_get_api()->
        get_state_label_abbreviated(session_id, option_name, state, False);
      RimeStringSlice state_label_short = rime_get_api()->
        get_state_label_abbreviated(session_id, option_name, state, True);
      if (state_label_long.str || state_label_short.str) {
        const char *short_message = state_label_short.length < strlen(state_label_short.str) ? NULL : state_label_short.str;
        show_status_message(state_label_long.str, short_message, message_type);
      }
    }
  }
}

- (void)setupRime {
  NSString *userDataDir = @"~/Library/Rime".stringByExpandingTildeInPath;
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  if (![fileManager fileExistsAtPath:userDataDir]) {
    if (![fileManager createDirectoryAtPath:userDataDir
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil]) {
      NSLog(@"Error creating user data directory: %@", userDataDir);
    }
  }
  rime_get_api()->set_notification_handler(notification_handler, (__bridge void *)(self));
  RIME_STRUCT(RimeTraits, squirrel_traits);
  squirrel_traits.shared_data_dir = NSBundle.mainBundle.sharedSupportPath.UTF8String;
  squirrel_traits.user_data_dir = userDataDir.UTF8String;
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version =
    [NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] UTF8String];
  squirrel_traits.app_name = "rime.squirrel";
  rime_get_api()->setup(&squirrel_traits);
}

- (void)startRimeWithFullCheck:(bool)fullCheck
{
  NSLog(@"Initializing la rime...");
  rime_get_api()->initialize(NULL);
  // check for configuration updates
  if (rime_get_api()->start_maintenance(fullCheck)) {
    // update squirrel config
    rime_get_api()->deploy_config_file("squirrel.yaml", "config_version");
  }
}

- (void)shutdownRime {
  [_config close];
  rime_get_api()->finalize();
}

- (void)loadSettings {
  _config = [[SquirrelConfig alloc] init];
  if (![_config openBaseConfig]) {
    return;
  }

  _enableNotifications =
    ![[_config getString:@"show_notifications_when"] isEqualToString:@"never"];
  [self.panel loadConfig:_config forAppearance:defaultAppear];
  [self.panel loadConfig:_config forAppearance:darkAppear];
}

- (void)loadSchemaSpecificSettings:(NSString *)schemaId {
  if (schemaId.length == 0 || [schemaId characterAtIndex:0] == '.') {
    return;
  }
  SquirrelConfig *schema = [[SquirrelConfig alloc] init];
  if ([schema openWithSchemaId:schemaId baseConfig:self.config] &&
      [schema hasSection:@"style"]) {
    [self.panel loadConfig:schema forAppearance:defaultAppear];
    [self.panel loadConfig:schema forAppearance:darkAppear];
  } else {
    [self.panel loadConfig:self.config forAppearance:defaultAppear];
    [self.panel loadConfig:self.config forAppearance:darkAppear];
  }
  [schema close];
}

- (void)loadSchemaSpecificLabels:(NSString *)schemaId {
  SquirrelConfig *defaultConfig = [[SquirrelConfig alloc] init];
  [defaultConfig openWithConfigId:@"default"];
  if (schemaId.length == 0 || [schemaId characterAtIndex:0] == '.') {
    [self.panel loadLabelConfig:defaultConfig directUpdate:YES];
    [defaultConfig close];
    return;
  }
  SquirrelConfig *schema = [[SquirrelConfig alloc] init];
  if ([schema openWithSchemaId:schemaId baseConfig:defaultConfig] &&
      [schema hasSection:@"menu"]) {
    [self.panel loadLabelConfig:schema directUpdate:NO];
  } else {
    [self.panel loadLabelConfig:defaultConfig directUpdate:NO];
  }
  [schema close];
  [defaultConfig close];
}

// prevent freezing the system
- (BOOL)problematicLaunchDetected {
  BOOL detected = NO;
  NSURL *logfile = [[NSURL fileURLWithPath:NSTemporaryDirectory() 
                               isDirectory:YES] URLByAppendingPathComponent:@"squirrel_launch.dat"];
  NSLog(@"[DEBUG] archive: %@", logfile);
  NSData *archive = [NSData dataWithContentsOfURL:logfile
                                          options:NSDataReadingUncached
                                            error:nil];
  if (archive) {
    NSDate *previousLaunch = [NSKeyedUnarchiver unarchivedObjectOfClass:NSDate.class
                                                               fromData:archive error:nil];
    if (previousLaunch && previousLaunch.timeIntervalSinceNow >= -2) {
      detected = YES;
    }
  }
  NSDate *now = [NSDate date];
  NSData *record = [NSKeyedArchiver archivedDataWithRootObject:now 
                                         requiringSecureCoding:NO error:nil];
  NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:logfile error:nil];
  [fileHandle writeData:record];
  return detected;
}

- (void)workspaceWillPowerOff:(NSNotification *)aNotification {
  NSLog(@"Finalizing before logging out.");
  [self shutdownRime];
}

- (void)rimeNeedsReload:(NSNotification *)aNotification {
  NSLog(@"Reloading rime on demand.");
  [self deploy:nil];
}

- (void)rimeNeedsSync:(NSNotification *)aNotification {
  NSLog(@"Sync rime on demand.");
  [self syncUserData:nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  NSLog(@"Squirrel is quitting.");
  rime_get_api()->cleanup_all_sessions();
  return NSTerminateNow;
}

//add an awakeFromNib item so that we can set the action method.  Note that
//any menuItems without an action will be disabled when displayed in the Text
//Input Menu.
- (void)awakeFromNib {
  NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
  [center addObserver:self
             selector:@selector(workspaceWillPowerOff:)
                 name:NSWorkspaceWillPowerOffNotification
               object:nil];

  NSDistributedNotificationCenter *notifCenter = NSDistributedNotificationCenter.defaultCenter;
  [notifCenter addObserver:self
                  selector:@selector(rimeNeedsReload:)
                      name:@"SquirrelReloadNotification"
                    object:nil];

  [notifCenter addObserver:self
                  selector:@selector(rimeNeedsSync:)
                      name:@"SquirrelSyncNotification"
                    object:nil];
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
  if (_panel) {
    [_panel hide];
  }
}

@end  //SquirrelApplicationDelegate

@implementation NSApplication (SquirrelApp)

- (SquirrelApplicationDelegate *)squirrelAppDelegate {
  return (SquirrelApplicationDelegate *)self.delegate;
}

@end
