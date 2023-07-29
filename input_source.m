#import <Carbon/Carbon.h>

static const unsigned char kInstallLocation[] =
    "/Library/Input Methods/Squirrel.app";

static NSString *const kHansInputModeID =
    @"im.rime.inputmethod.Squirrel.Hans";
static NSString *const kHantInputModeID =
    @"im.rime.inputmethod.Squirrel.Hant";
static NSString *const kCantInputModeID =
    @"im.rime.inputmethod.Squirrel.Cant";

#define HANS_INPUT_MODE (1 << 0)
#define HANT_INPUT_MODE (1 << 1)
#define CANT_INPUT_MODE (1 << 2)

void RegisterInputSource(void) {
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
      NULL, kInstallLocation, strlen((const char *)kInstallLocation), NO);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
    CFRelease(installedLocationURL);
    NSLog(@"Registered input source from %s", kInstallLocation);
  }
}

void ActivateInputSource(int enabled_modes) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (__bridge NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    //NSLog(@"Examining input source: %@", sourceID);
    if (([sourceID isEqualToString:kHansInputModeID] &&
         ((enabled_modes & HANS_INPUT_MODE) != 0)) ||
        ([sourceID isEqualToString:kHantInputModeID] &&
         ((enabled_modes & HANT_INPUT_MODE) != 0)) ||
        ([sourceID isEqualToString:kCantInputModeID] &&
         ((enabled_modes & CANT_INPUT_MODE) != 0))) {
      TISEnableInputSource(inputSource);
      NSLog(@"Enabled input source: %@", sourceID);
      CFBooleanRef isSelectable = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsSelectCapable);
      if (CFBooleanGetValue(isSelectable)) {
        TISSelectInputSource(inputSource);
        NSLog(@"Selected input source: %@", sourceID);
      }
    }
  }
  CFRelease(sourceList);
}

void DeactivateInputSource(void) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = CFArrayGetCount(sourceList); i > 0; --i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i - 1));
    NSString *sourceID = (__bridge NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    //NSLog(@"Examining input source: %@", sourceID);
    if ([sourceID isEqualToString:kHansInputModeID] ||
        [sourceID isEqualToString:kHantInputModeID] ||
        [sourceID isEqualToString:kCantInputModeID]) {
      CFBooleanRef isEnabled = (CFBooleanRef)(TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled));
      if (CFBooleanGetValue(isEnabled)) {
        TISDisableInputSource(inputSource);
        NSLog(@"Disabled input source: %@", sourceID);
      }
    }
  }
  CFRelease(sourceList);
}

int GetEnabledInputModes(void) {
  int input_modes = 0;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (__bridge NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    //NSLog(@"Examining input source: %@", sourceID);
    if ([sourceID isEqualToString:kHansInputModeID] ||
        [sourceID isEqualToString:kHantInputModeID] ||
        [sourceID isEqualToString:kCantInputModeID]) {
      CFBooleanRef isEnabled = (CFBooleanRef)(TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled));
      if (CFBooleanGetValue(isEnabled)) {
        if ([sourceID isEqualToString:kHansInputModeID])
          input_modes |= HANS_INPUT_MODE;
        else if ([sourceID isEqualToString:kHantInputModeID])
          input_modes |= HANT_INPUT_MODE;
        else if ([sourceID isEqualToString:kCantInputModeID])
          input_modes |= CANT_INPUT_MODE;
      }
    }
  }
  CFRelease(sourceList);
  if (input_modes != 0) {
    NSLog(@"EnabledInputModes: %d", input_modes);
  } else {
    NSArray<NSString *> *languages = [NSBundle preferredLocalizationsFromArray:@[@"zh-Hans", @"zh-Hant", @"zh-HK", @"yue"]];
    for (NSString *lang in languages) {
      if ([lang isEqualToString:@"zh-Hans"])
        input_modes |= HANS_INPUT_MODE;
      else if ([lang isEqualToString:@"zh-Hant"])
        input_modes |= HANT_INPUT_MODE;
      else if ([lang isEqualToString:@"zh-HK"])
        input_modes |= CANT_INPUT_MODE;
    }
    if (input_modes != 0) {
      NSLog(@"PreferredInputModes: %d", input_modes);
    } else {
      input_modes = HANS_INPUT_MODE;
      NSLog(@"DefaultInputMode: %d", input_modes);
    }
  }
  return input_modes;
}
