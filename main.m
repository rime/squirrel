
#import "SquirrelApplicationDelegate.h"
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import <rime_api.h>
#import <string.h>

void RegisterInputSource(void);
int GetEnabledInputModes(void);
void DeactivateInputSource(void);
void ActivateInputSource(int input_modes);

#define DEFAULT_INPUT_MODE 1

// Each input method needs a unique connection name.
// Note that periods and spaces are not allowed in the connection name.
const NSString *kConnectionName = @"Squirrel_1_Connection";

int main(int argc, char *argv[]) {
  if (argc > 1 && !strcmp("--quit", argv[1])) {
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    NSArray *runningSquirrels =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId];
    for (NSRunningApplication *squirrelApp in runningSquirrels) {
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
    show_message("deploy_update", "deploy");
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
    NSBundle *main = [NSBundle mainBundle];
    IMKServer *server __unused =
        [[IMKServer alloc] initWithName:(NSString *)kConnectionName
                       bundleIdentifier:main.bundleIdentifier];

    // load the bundle explicitly because in this case the input method is a
    // background only application
    [main loadNibNamed:@"MainMenu" owner:[NSApplication sharedApplication] topLevelObjects:NULL];

    // opencc will be configured with relative dictionary paths
    [[NSFileManager defaultManager]
        changeCurrentDirectoryPath:main.sharedSupportPath];

    if (NSApp.squirrelAppDelegate.problematicLaunchDetected) {
      NSLog(@"Problematic launch detected!");
      NSArray *args = @[@"-v", NSLocalizedString(@"say_voice", nil),
                        NSLocalizedString(@"problematic_launch", nil)];
      [NSTask launchedTaskWithExecutableURL:[[NSURL alloc] initFileURLWithPath:@"/usr/bin/say"]
                                  arguments:args error:nil terminationHandler:nil];
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
