#import <Carbon/Carbon.h>

static const unsigned char kInstalledLocation[] =
    "/Library/Input Methods/Squirrel.app";
static NSString *const kSourceID =
    @"com.googlecode.rimeime.inputmethod.Squirrel";
static NSString *const kInputModeID =
    @"com.googlecode.rimeime.inputmethod.Squirrel.Rime";

void RegisterInputSource() {
  NSLog(@"RegisterInputSource.");
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
      NULL, kInstalledLocation, strlen((const char *)kInstalledLocation), NO);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
    CFRelease(installedLocationURL);
  }
}

void ActivateInputSource() {
  NSLog(@"ActivateInputSource.");
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    //NSLog(@"examining input source '%@", sourceID);
    if ([sourceID isEqualToString:kSourceID] ||
        [sourceID isEqualToString:kInputModeID]) {
      TISEnableInputSource(inputSource);
      CFBooleanRef isSelectable = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsSelectCapable);
      if (CFBooleanGetValue(isSelectable)) {
        NSLog(@"selecting input source '%@'.", sourceID);
        TISSelectInputSource(inputSource);
      }
      NSLog(@"'%@' should have been activated.", sourceID);
    }
  }
  CFRelease(sourceList);
}

void DeactivateInputSource() {
  NSLog(@"DeactivateInputSource.");
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (int i = CFArrayGetCount(sourceList); i > 0; --i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i - 1));
    NSString *sourceID = (NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    //NSLog(@"examining input source '%@", sourceID);
    if ([sourceID isEqualToString:kSourceID] ||
        [sourceID isEqualToString:kInputModeID]) {
      TISDisableInputSource(inputSource);
      NSLog(@"'%@' should have been deactivated.", sourceID);
    }
  }
  CFRelease(sourceList);
}

BOOL IsInputSourceActive() {
  int active = 0;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    NSLog(@"examining input source '%@'", sourceID);
    if ([sourceID isEqualToString:kSourceID] ||
        [sourceID isEqualToString:kInputModeID]) {
      CFBooleanRef isEnabled = (CFBooleanRef)(TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled));
      if (CFBooleanGetValue(isEnabled)) {
        ++active;
      }
    }
  }
  CFRelease(sourceList);
  NSLog(@"IsInputSourceActive: %d / 2", active);
  return active == 2;  // 1 active input method + 1 active input mode
}
