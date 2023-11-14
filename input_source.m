#import <Carbon/Carbon.h>

static const char kInstallLocation[] =
  "/Library/Input Methods/Squirrel.app";

static CFStringRef kHansInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Hans");
static CFStringRef kHantInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Hant");
static CFStringRef kCantInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Cant");

#define HANS_INPUT_MODE (1 << 0)
#define HANT_INPUT_MODE (1 << 1)
#define CANT_INPUT_MODE (1 << 2)

void RegisterInputSource(void) {
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
    NULL, (UInt8 *)kInstallLocation, (CFIndex)strlen(kInstallLocation), false);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
    CFRelease(installedLocationURL);
    NSLog(@"Registered input source from %s", kInstallLocation);
  }
}

void ActivateInputSource(int enabled_modes) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if ((CFStringCompare(sourceID, kHansInputModeID, 0) == 0 &&
         (enabled_modes & HANS_INPUT_MODE) != 0) ||
        (CFStringCompare(sourceID, kHantInputModeID, 0) == 0 &&
         (enabled_modes & HANT_INPUT_MODE) != 0) ||
        (CFStringCompare(sourceID, kCantInputModeID, 0) == 0 &&
         (enabled_modes & CANT_INPUT_MODE) != 0)) {
      OSStatus enableError = TISEnableInputSource(inputSource);
      if (enableError) {
        NSLog(@"Error %d. Failed to enable input mode: %@", enableError, sourceID);
      } else {
        NSLog(@"Enabled input mode: %@", sourceID);
        CFBooleanRef isSelectable = (CFBooleanRef)
          TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsSelectCapable);
        if (CFBooleanGetValue(isSelectable)) {
          OSStatus selectError = TISSelectInputSource(inputSource);
          if (selectError) {
            NSLog(@"Error %d. Failed to select input mode: %@", selectError, sourceID);
          } else {
            NSLog(@"Selected input mode: %@", sourceID);
          }
        }
      }
    }
  }
  CFRelease(sourceList);
}

void DeactivateInputSource(void) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = CFArrayGetCount(sourceList); i > 0; --i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i - 1);
    CFStringRef sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if (CFStringCompare(sourceID, kHansInputModeID, 0) == 0 ||
        CFStringCompare(sourceID, kHantInputModeID, 0) == 0 ||
        CFStringCompare(sourceID, kCantInputModeID, 0) == 0) {
      CFBooleanRef isEnabled = (CFBooleanRef)
        TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled);
      if (CFBooleanGetValue(isEnabled)) {
        OSStatus disableError = TISDisableInputSource(inputSource);
        if (disableError) {
          NSLog(@"Error %d. Failed to disable input source: %@", disableError, sourceID);
        } else {
          NSLog(@"Disabled input source: %@", sourceID);
        }
      }
    }
  }
  CFRelease(sourceList);
}

int GetEnabledInputModes(void) {
  int input_modes = 0;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if (CFStringCompare(sourceID, kHansInputModeID, 0) == 0 ||
        CFStringCompare(sourceID, kHantInputModeID, 0) == 0 ||
        CFStringCompare(sourceID, kCantInputModeID, 0) == 0) {
      CFBooleanRef isEnabled = (CFBooleanRef)
        TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled);
      if (CFBooleanGetValue(isEnabled)) {
        if (CFStringCompare(sourceID, kHansInputModeID, 0) == 0) {
          input_modes |= HANS_INPUT_MODE;
        } else if (CFStringCompare(sourceID, kHantInputModeID, 0) == 0) {
          input_modes |= HANT_INPUT_MODE;
        } else if (CFStringCompare(sourceID, kCantInputModeID, 0) == 0) {
          input_modes |= CANT_INPUT_MODE;
        }
      }
    }
  }
  CFRelease(sourceList);
  if (input_modes != 0) {
    NSLog(@"Enabled Input Modes:%s%s%s",
          input_modes & HANS_INPUT_MODE ? " Hans" : "",
          input_modes & HANT_INPUT_MODE ? " Hant" : "",
          input_modes & CANT_INPUT_MODE ? " Cant" : "");
  } else {
    NSArray<NSString *> *languages =
      [NSBundle preferredLocalizationsFromArray:@[@"zh-Hans", @"zh-Hant", @"zh-HK"]];
    if (languages.count > 0) {
      NSString *lang = languages.firstObject;
      if ([lang isEqualToString:@"zh-Hans"]) {
        input_modes |= HANS_INPUT_MODE;
      } else if ([lang isEqualToString:@"zh-Hant"]) {
        input_modes |= HANT_INPUT_MODE;
      } else if ([lang isEqualToString:@"zh-HK"]) {
        input_modes |= CANT_INPUT_MODE;
      }
    }
    if (input_modes != 0) {
      NSLog(@"Preferred Input Mode:%s%s%s",
            input_modes & HANS_INPUT_MODE ? " Hans" : "",
            input_modes & HANT_INPUT_MODE ? " Hant" : "",
            input_modes & CANT_INPUT_MODE ? " Cant" : "");
    } else {
      input_modes = HANS_INPUT_MODE;
      NSLog(@"Default Input Mode:%s%s%s",
            input_modes & HANS_INPUT_MODE ? " Hans" : "",
            input_modes & HANT_INPUT_MODE ? " Hant" : "",
            input_modes & CANT_INPUT_MODE ? " Cant" : "");
    }
  }
  return input_modes;
}
