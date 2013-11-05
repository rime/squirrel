#import <Carbon/Carbon.h>

static const unsigned char kInstalledLocation[] =
    "/Library/Input Methods/Squirrel.app";
static NSString *const kSourceID =
    @"com.googlecode.rimeime.inputmethod.Squirrel";

void RegisterInputSource() {
  CFURLRef installedLocationURL = CFURLCreateFromFileSystemRepresentation(
      NULL, kInstalledLocation, strlen((const char *)kInstalledLocation), NO);
  if (installedLocationURL) {
    TISRegisterInputSource(installedLocationURL);
  }
}

void ActivateInputSource() {
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    if ([sourceID isEqualToString:kSourceID]) {
      TISEnableInputSource(inputSource);
      TISSelectInputSource(inputSource);
      break;
    }
  }
}

BOOL IsInputSourceActive() {
  BOOL isActive = NO;
  CFArrayRef sourceList = TISCreateInputSourceList(NULL, true);
  for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
    TISInputSourceRef inputSource = (TISInputSourceRef)(CFArrayGetValueAtIndex(
        sourceList, i));
    NSString *sourceID = (NSString *)(TISGetInputSourceProperty(
        inputSource, kTISPropertyInputSourceID));
    if ([sourceID isEqualToString:kSourceID]) {
      CFBooleanRef isEnabled = (CFBooleanRef)(TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled));
      CFBooleanRef isSelected = (CFBooleanRef)(TISGetInputSourceProperty(
          inputSource, kTISPropertyInputSourceIsEnabled));
      if (CFBooleanGetValue(isEnabled) || CFBooleanGetValue(isSelected)) {
        isActive = YES;
        break;
      }
    }
  }
  return isActive;
}


