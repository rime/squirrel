#import <Carbon/Carbon.h>

static const char kInstallLocation[] = "/Library/Input Methods/Squirrel.app";
static const CFStringRef kHansInputModeID =
    CFSTR("im.rime.inputmethod.Squirrel.Hans");
static const CFStringRef kHantInputModeID =
    CFSTR("im.rime.inputmethod.Squirrel.Hant");

#define HANS_INPUT_MODE (1 << 0)
#define HANT_INPUT_MODE (1 << 1)

void RegisterInputSource(void) {
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
      NULL, (UInt8*)kInstallLocation, (CFIndex)strlen(kInstallLocation), false);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
    CFRelease(installedLocationURL);
    NSLog(@"Registered input source from %s", kInstallLocation);
  }
}

void ActivateInputSource(int enabled_modes) {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource =
        (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID);
    // NSLog(@"Examining input source: %@", sourceID);
    if ((!CFStringCompare(sourceID, kHansInputModeID, 0) &&
         ((enabled_modes & HANS_INPUT_MODE) != 0)) ||
        (!CFStringCompare(sourceID, kHantInputModeID, 0) &&
         ((enabled_modes & HANT_INPUT_MODE) != 0))) {
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
    TISInputSourceRef inputSource =
        (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i - 1);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID);
    // NSLog(@"Examining input source: %@", sourceID);
    if (!CFStringCompare(sourceID, kHansInputModeID, 0) ||
        !CFStringCompare(sourceID, kHantInputModeID, 0)) {
      CFBooleanRef isEnabled = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled);
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
    TISInputSourceRef inputSource =
        (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID);
    // NSLog(@"Examining input source: %@", sourceID);
    if (!CFStringCompare(sourceID, kHansInputModeID, 0) ||
        !CFStringCompare(sourceID, kHantInputModeID, 0)) {
      CFBooleanRef isEnabled = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled);
      if (CFBooleanGetValue(isEnabled)) {
        if (!CFStringCompare(sourceID, kHansInputModeID, 0)) {
          input_modes |= HANS_INPUT_MODE;
        } else if (!CFStringCompare(sourceID, kHantInputModeID, 0)) {
          input_modes |= HANT_INPUT_MODE;
        }
      }
    }
  }
  CFRelease(sourceList);
  NSLog(@"EnabledInputModes: %d", input_modes);
  return input_modes;
}
