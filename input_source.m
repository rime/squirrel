#import <Carbon/Carbon.h>

static const char kInstallLocation[] =
  "/Library/Input Methods/Squirrel.app";

static const CFStringRef kHansInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Hans");
static const CFStringRef kHantInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Hant");
static const CFStringRef kCantInputModeID =
  CFSTR("im.rime.inputmethod.Squirrel.Cant");

typedef NS_OPTIONS(int, RimeInputMode) {
  DEFAULT_INPUT_MODE  = 1 << 0,
  HANS_INPUT_MODE     = 1 << 0,
  HANT_INPUT_MODE     = 1 << 1,
  CANT_INPUT_MODE     = 1 << 2
};

void RegisterInputSource(void) {
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation
    (NULL, (UInt8 *)kInstallLocation, (CFIndex)strlen(kInstallLocation), false);
  if (installedLocationURL) {
    TISRegisterInputSource((CFURLRef)CFAutorelease(installedLocationURL));
    NSLog(@"Registered input source from %s", kInstallLocation);
  }
}

void ActivateInputSource(RimeInputMode modes) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if ((!CFStringCompare(sourceID, kHansInputModeID, 0) && (modes & HANS_INPUT_MODE)) ||
        (!CFStringCompare(sourceID, kHantInputModeID, 0) && (modes & HANT_INPUT_MODE)) ||
        (!CFStringCompare(sourceID, kCantInputModeID, 0) && (modes & CANT_INPUT_MODE))) {
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
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if (!CFStringCompare(sourceID, kHansInputModeID, 0) ||
        !CFStringCompare(sourceID, kHantInputModeID, 0) ||
        !CFStringCompare(sourceID, kCantInputModeID, 0)) {
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

RimeInputMode GetEnabledInputModes(void) {
  RimeInputMode input_modes = 0;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID);
    //NSLog(@"Examining input source: %@", sourceID);
    if (!CFStringCompare(sourceID, kHansInputModeID, 0) ||
        !CFStringCompare(sourceID, kHantInputModeID, 0) ||
        !CFStringCompare(sourceID, kCantInputModeID, 0)) {
      CFBooleanRef isEnabled = (CFBooleanRef)
        TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceIsEnabled);
      if (CFBooleanGetValue(isEnabled)) {
        if (!CFStringCompare(sourceID, kHansInputModeID, 0)) {
          input_modes |= HANS_INPUT_MODE;
        } else if (!CFStringCompare(sourceID, kHantInputModeID, 0)) {
          input_modes |= HANT_INPUT_MODE;
        } else if (!CFStringCompare(sourceID, kCantInputModeID, 0)) {
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
    NSArray *languages = [NSBundle preferredLocalizationsFromArray:
                          @[@"zh-Hans", @"zh-Hant", @"zh-HK"]];
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
