
#import "SquirrelApplicationDelegate.h"
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import <rime_api.h>

typedef NS_OPTIONS(int, RimeInputMode) {
  DEFAULT_INPUT_MODE = 1 << 0,
  HANS_INPUT_MODE = 1 << 0,
  HANT_INPUT_MODE = 1 << 1
};

void RegisterInputSource(void);
RimeInputMode GetEnabledInputModes(void);
void DeactivateInputSource(void);
void ActivateInputSource(RimeInputMode input_modes);

// Each input method needs a unique connection name.
// Note that periods and spaces are not allowed in the connection name.
static NSString* const kConnectionName = @"Squirrel_1_Connection";

int main(int argc, char* argv[]) {
  if (argc > 1 && !strcmp("--quit", argv[1])) {
    NSString* bundleId = [NSBundle mainBundle].bundleIdentifier;
    NSArray* runningSquirrels =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId];
    for (NSRunningApplication* squirrelApp in runningSquirrels) {
      [squirrelApp terminate];
    }
    return 0;
  }

  if (argc > 1 && !strcmp("--reload", argv[1])) {
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:@"SquirrelReloadNotification"
                      object:nil];
    return 0;
  }

  if (argc > 1 && !strcmp("--install", argv[1])) {
    // register and enable Squirrel
    RegisterInputSource();
    int input_modes = GetEnabledInputModes();
    DeactivateInputSource();
    ActivateInputSource(input_modes ? input_modes : DEFAULT_INPUT_MODE);
    return 0;
  }

  if (argc > 1 && !strcmp("--build", argv[1])) {
    // notification
    show_notification("deploy_update");
    // build all schemas in current directory
    RIME_STRUCT(RimeTraits, builder_traits);
    builder_traits.app_name = "rime.squirrel-builder";
    rime_get_api()->setup(&builder_traits);
    rime_get_api()->deployer_initialize(NULL);
    return rime_get_api()->deploy() ? 0 : 1;
  }

  if (argc > 1 && !strcmp("--sync", argv[1])) {
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:@"SquirrelSyncNotification"
                      object:nil];
    return 0;
  }

  @autoreleasepool {
    // find the bundle identifier and then initialize the input method server
    NSBundle* main = [NSBundle mainBundle];
    IMKServer* server __unused =
        [[IMKServer alloc] initWithName:kConnectionName
                       bundleIdentifier:main.bundleIdentifier];

    // load the bundle explicitly because in this case the input method is a
    // background only application
    [main loadNibNamed:@"MainMenu"
                  owner:NSApplication.sharedApplication
        topLevelObjects:nil];

    // opencc will be configured with relative dictionary paths
    [[NSFileManager defaultManager]
        changeCurrentDirectoryPath:main.sharedSupportPath];

    if (NSApp.squirrelAppDelegate.problematicLaunchDetected) {
      NSLog(@"Problematic launch detected!");
      NSArray* args = @[ @"Problematic launch detected! \
                       Squirrel may be suffering a crash due to imporper configuration. \
                       Revert previous modifications to see if the problem recurs." ];
      [NSTask launchedTaskWithLaunchPath:@"/usr/bin/say" arguments:args];
    } else {
      [NSApp.squirrelAppDelegate setupRime];
      [NSApp.squirrelAppDelegate startRimeWithFullCheck:NO];
      [NSApp.squirrelAppDelegate loadSettings];
      NSLog(@"Squirrel reporting!");
    }

    // finally run everything
    [[NSApplication sharedApplication] run];

    NSLog(@"Squirrel is quitting...");
    rime_get_api()->finalize();
  }
  return 0;
}
