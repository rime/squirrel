#import <Carbon/Carbon.h>

static const char kInstallLocation[] = "/Library/Input Methods/Squirrel.app";
static const CFStringRef kHansInputModeID =
    CFSTR("im.rime.inputmethod.Squirrel.Hans");
static const CFStringRef kHantInputModeID =
    CFSTR("im.rime.inputmethod.Squirrel.Hant");

#define HANS_INPUT_MODE (1 << 0)
#define HANT_INPUT_MODE (1 << 1)

#define DEFAULT_INPUT_MODE HANS_INPUT_MODE

int GetEnabledInputModes(void);

void RegisterInputSource(void) {
  int enabled_input_modes = GetEnabledInputModes();
  if (enabled_input_modes) {
    // Already registered.
    return;
  }
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
      NULL, (UInt8*)kInstallLocation, (CFIndex)strlen(kInstallLocation), false);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
    CFRelease(installedLocationURL);
    NSLog(@"Registered input source from %s", kInstallLocation);
  }
}

void EnableInputSource(void) {
  int enabled_input_modes = GetEnabledInputModes();
  if (enabled_input_modes) {
    // keep user's manually enabled input modes.
    return;
  }
  // neither is enabled, enable the default input mode.
  int input_modes_to_enable = DEFAULT_INPUT_MODE;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource =
        (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID);
    // NSLog(@"Examining input source: %@", sourceID);
    if ((!CFStringCompare(sourceID, kHansInputModeID, 0) &&
         ((input_modes_to_enable & HANS_INPUT_MODE) != 0)) ||
        (!CFStringCompare(sourceID, kHantInputModeID, 0) &&
         ((input_modes_to_enable & HANT_INPUT_MODE) != 0))) {
      CFBooleanRef isEnabled = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled);
      if (!CFBooleanGetValue(isEnabled)) {
        TISEnableInputSource(inputSource);
        NSLog(@"Enabled input source: %@", sourceID);
      }
    }
  }
  CFRelease(sourceList);
}

void SelectInputSource(void) {
  int enabled_input_modes = GetEnabledInputModes();
  int input_modes_to_select = ((enabled_input_modes & DEFAULT_INPUT_MODE) != 0)
                                  ? DEFAULT_INPUT_MODE
                                  : enabled_input_modes;
  if (!input_modes_to_select) {
    NSLog(@"No enabled input sources.");
    return;
  }
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (CFIndex i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource =
        (TISInputSourceRef)CFArrayGetValueAtIndex(sourceList, i);
    CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID);
    // NSLog(@"Examining input source: %@", sourceID);
    if ((!CFStringCompare(sourceID, kHansInputModeID, 0) &&
         ((input_modes_to_select & HANS_INPUT_MODE) != 0)) ||
        (!CFStringCompare(sourceID, kHantInputModeID, 0) &&
         ((input_modes_to_select & HANT_INPUT_MODE) != 0))) {
      // select the first enabled input mode in Squirrel.
      CFBooleanRef isEnabled = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled);
      if (!CFBooleanGetValue(isEnabled)) {
        continue;
      }
      CFBooleanRef isSelectable = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsSelectCapable);
      CFBooleanRef isSelected = (CFBooleanRef)TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsSelected);
      if (!CFBooleanGetValue(isSelected) && CFBooleanGetValue(isSelectable)) {
        TISSelectInputSource(inputSource);
        NSLog(@"Selected input source: %@", sourceID);
      }
      break;
    }
  }
  CFRelease(sourceList);
}

void DisableInputSource(void) {
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
