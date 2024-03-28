
#import "SquirrelApplicationDelegate.h"
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import <rime_api.h>
#import <string.h>

void RegisterInputSource(void);
void DisableInputSource(void);
void EnableInputSource(void);
void SelectInputSource(void);

// Each input method needs a unique connection name.
// Note that periods and spaces are not allowed in the connection name.
static NSString* const kConnectionName = @"Squirrel_1_Connection";

int main(int argc, char* argv[]) {
  if (argc > 1 && !strcmp("--quit", argv[1])) {
    NSString* bundleId = [NSBundle mainBundle].bundleIdentifier;
    NSArray<NSRunningApplication*>* runningSquirrels =
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

  if (argc > 1 && (!strcmp("--register-input-source", argv[1]) ||
                   !strcmp("--install", argv[1]))) {
    RegisterInputSource();
    return 0;
  }

  if (argc > 1 && !strcmp("--enable-input-source", argv[1])) {
    EnableInputSource();
    return 0;
  }

  if (argc > 1 && !strcmp("--disable-input-source", argv[1])) {
    DisableInputSource();
    return 0;
  }

  if (argc > 1 && !strcmp("--select-input-source", argv[1])) {
    SelectInputSource();
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
    NSBundle* main = [NSBundle mainBundle];
    IMKServer* server __unused =
        [[IMKServer alloc] initWithName:kConnectionName
                       bundleIdentifier:main.bundleIdentifier];

    // load the bundle explicitly because in this case the input method is a
    // background only application
    [main loadNibNamed:@"MainMenu"
                  owner:[NSApplication sharedApplication]
        topLevelObjects:nil];

    // opencc will be configured with relative dictionary paths
    [[NSFileManager defaultManager]
        changeCurrentDirectoryPath:main.sharedSupportPath];

    if (NSApp.squirrelAppDelegate.problematicLaunchDetected) {
      NSLog(@"Problematic launch detected!");
      NSArray* args = @[ @"Problematic launch detected! \
                       Squirrel may be suffering a crash due to imporper configuration. \
                       Revert previous modifications to see if the problem recurs." ];
      [NSTask
          launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/say"
                                                   isDirectory:NO]
                              arguments:args
                                  error:nil
                     terminationHandler:nil];
    } else {
      [NSApp.squirrelAppDelegate setupRime];
      [NSApp.squirrelAppDelegate startRimeWithFullCheck:false];
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
