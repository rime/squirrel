#import "SquirrelInputController.h"

#import "SquirrelApplicationDelegate.h"
#import "SquirrelConfig.h"
#import "SquirrelPanel.h"
#import "macos_keycode.h"
#import <rime_api.h>
#import <rime/key_table.h>
#import <Carbon/Carbon.h>
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/hidsystem/IOHIDLib.h>

const int N_KEY_ROLL_OVER = 50;
static NSString *const kFullWidthSpace = @"　";

@implementation SquirrelInputController {
  NSMutableAttributedString *_preeditString;
  NSString *_originalString;
  NSString *_composedString;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray<NSString *> *_candidates;
  NSEventModifierFlags _lastModifiers;
  uint _lastEventCount;
  RimeSessionId _session;
  NSString *_schemaId;
  BOOL _inlinePreedit;
  BOOL _inlineCandidate;
  BOOL _showingSwitcherMenu;
  BOOL _goodOldCapsLock;
  // app-specific bug fix
  BOOL _inlinePlaceholder;
  BOOL _panellessCommitFix;
  int _inlineOffset;
  // for chord-typing
  int _chordKeyCodes[N_KEY_ROLL_OVER];
  int _chordModifiers[N_KEY_ROLL_OVER];
  uint _chordKeyCount;
  NSTimer *_chordTimer;
  NSTimeInterval _chordDuration;
}

static SquirrelInputController *_currentController = nil;
static NSMapTable<SquirrelInputController *, NSDate *> *_controllerDeactivationTime = NSMapTable.weakToWeakObjectsMapTable;

+ (void)setCurrentController:(SquirrelInputController *)controller {
  _currentController = controller;
  NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
}

+ (SquirrelInputController *)currentController {
  return _currentController;
}

+ (void)setDeactivationTimeForController:(SquirrelInputController *)controller {
  [_controllerDeactivationTime setObject:[[NSDate alloc] init] forKey:controller];
}

+ (void)removeDeactivationTimeForController:(SquirrelInputController *)controller {
  [_controllerDeactivationTime removeObjectForKey:controller];
}

+ (NSDate *)lastDeactivationTime {
  return [_controllerDeactivationTime objectForKey:_currentController];
}

/*!
   @method
   @abstract   Receive incoming event
   @discussion This method receives key events from the client application.
 */
- (BOOL)handleEvent:(NSEvent *)event
             client:(id)sender {
  // Return YES to indicate the the key input was received and dealt with.
  // Key processing will not continue in that case.  In other words the
  // system will not deliver a key down event to the application.
  // Returning NO means the original key down will be passed on to the client.
  BOOL handled = NO;

  @autoreleasepool {
    if (!_session || !rime_get_api()->find_session(_session)) {
      [self createSession];
      if (!_session) {
        return NO;
      }
    }
    NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    int rime_modifiers = get_rime_modifiers(modifiers);
    ushort keyCode = (ushort)CGEventGetIntegerValueField(event.CGEvent, kCGKeyboardEventKeycode);

    switch (event.type) {
      case NSEventTypeFlagsChanged: {
        if (_lastModifiers == modifiers) {
          handled = YES;
          break;
        }
        //NSLog(@"FLAGSCHANGED client: %@, modifiers: 0x%lx", sender, modifiers);
        int release_mask = 0;
        int rime_keycode = get_rime_keycode(keyCode, 0, false, false);
        uint eventCount = CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventFlagsChanged) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventKeyDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventLeftMouseDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventRightMouseDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventOtherMouseDown);
        _lastModifiers = modifiers;
        switch (keyCode) {
          case kVK_CapsLock:
            if (!_goodOldCapsLock) {
              set_CapsLock_LED_state(false);
              Bool ascii_mode = rime_get_api()->get_option(_session, "ascii_mode");
              rime_modifiers = ascii_mode ? rime_modifiers | kLockMask : rime_modifiers & ~kLockMask;
            } else {
              rime_modifiers ^= kLockMask;
            }
            handled = [self processKey:rime_keycode modifiers:rime_modifiers];
            break;
          case kVK_Shift:
          case kVK_RightShift:
            release_mask = modifiers & NSEventModifierFlagShift ? 0 :
              kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            handled = [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Control:
          case kVK_RightControl:
            release_mask = modifiers & NSEventModifierFlagControl ? 0 :
              kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            handled = [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Option:
          case kVK_RightOption:
            release_mask = modifiers & NSEventModifierFlagOption ? 0 :
              kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            handled = [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Function:
            release_mask = modifiers & NSEventModifierFlagFunction ? 0 : 
              kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            handled = [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Command:
          case kVK_RightCommand:
            release_mask = modifiers & NSEventModifierFlagCommand ? 0 :
              kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            handled = [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
        }
        if (NSApp.squirrelAppDelegate.panel.statusMessage || handled) {
          [self rimeUpdate];
          handled = YES;
        }
        _lastEventCount = eventCount;
      } break;
      case NSEventTypeKeyDown: {
        NSString *keyChars = ((modifiers & NSEventModifierFlagShift) &&
                              !(modifiers & NSEventModifierFlagControl) &&
                              !(modifiers & NSEventModifierFlagOption)) ?
                             event.characters : event.charactersIgnoringModifiers;
        //NSLog(@"KEYDOWN client: %@, modifiers: 0x%lx, keyCode: %d, keyChars: [%@]",
        //      sender, modifiers, keyCode, keyChars);

        // translate osx keyevents to rime keyevents
        int rime_keycode = get_rime_keycode(keyCode, [keyChars characterAtIndex:0],
                                            (bool)(modifiers & NSEventModifierFlagShift),
                                            (bool)(modifiers & NSEventModifierFlagCapsLock));
        if (rime_keycode != XK_VoidSymbol) {
          // revert non-modifier function keys' FunctionKeyMask (FwdDel, Navigations, F1..F19)
          if ((keyCode <= 0xff && keyCode >= 0x60) || keyCode == 0x50 ||
              keyCode == 0x4f || keyCode == 0x47 || keyCode == 0x40) {
            rime_modifiers ^= kHyperMask;
          }
          if ((handled = [self processKey:rime_keycode modifiers:rime_modifiers])) {
            [self rimeUpdate];
          } else if (_panellessCommitFix && self.client.markedRange.length > 0) {
            if (rime_keycode == XK_Delete || (rime_keycode >= XK_Home && rime_keycode <= XK_KP_Delete) ||
                (rime_keycode >= XK_BackSpace && rime_keycode <= XK_Escape)) {
              [self showPlaceholder:@""];
            } else if (!(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagCommand)) &&
                       event.characters.length > 0) {
              [self showPlaceholder:nil];
              [self.client insertText:event.characters
                     replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
              return YES;
            }
          }
        }
      } break;
      default:
        break;
    }
  }
  return handled;
}

- (BOOL)mouseDownOnCharacterIndex:(NSUInteger)index
                       coordinate:(NSPoint)point
                     withModifier:(NSUInteger)flags
                 continueTracking:(BOOL *)keepTracking
                           client:(id)sender {
  *keepTracking = NO;
  @autoreleasepool {
    if ((!_inlinePreedit && !_inlineCandidate) ||
        _composedString.length == 0 || _caretPos == index ||
        (flags & NSEventModifierFlagDeviceIndependentFlagsMask)) {
      return NO;
    }
    NSRange markedRange = [sender markedRange];
    NSPoint head = [[sender attributesForCharacterIndex:0
                                    lineHeightRectangle:NULL][@"IMKBaseline"] pointValue];
    NSPoint tail = [[sender attributesForCharacterIndex:markedRange.length - 1
                                    lineHeightRectangle:NULL][@"IMKBaseline"] pointValue];
    if (point.x > tail.x || index >= markedRange.length) {
      if (_inlineCandidate && !_inlinePreedit) {
        return NO;
      }
      [self perform:kSELECT onIndex:kEnd];
    } else if (point.x < head.x || index <= 0) {
      [self perform:kSELECT onIndex:kHome];
    } else {
      [self moveCursor:_caretPos
            toPosition:index
         inlinePreedit:_inlinePreedit
       inlineCandidate:_inlineCandidate];
    }
    return YES;
  }
}

void set_CapsLock_LED_state(bool target_state) {
  io_service_t ioService = IOServiceGetMatchingService(kIOMasterPortDefault,
                            IOServiceMatching(kIOHIDSystemClass));
  io_connect_t ioConnect = 0;
  IOServiceOpen(ioService, mach_task_self_, kIOHIDParamConnectType, &ioConnect);
  bool current_state = false;
  IOHIDGetModifierLockState(ioConnect, kIOHIDCapsLockState, &current_state);
  if (current_state != target_state) {
    IOHIDSetModifierLockState(ioConnect, kIOHIDCapsLockState, target_state);
  }
  IOServiceClose(ioConnect);
}

- (BOOL)processKey:(int)rime_keycode
         modifiers:(int)rime_modifiers {
  // with linear candidate list, arrow keys may behave differently.
  Bool is_linear = (Bool)NSApp.squirrelAppDelegate.panel.linear;
  if (is_linear != rime_get_api()->get_option(_session, "_linear")) {
    rime_get_api()->set_option(_session, "_linear", is_linear);
  }
  // with vertical text, arrow keys may behave differently.
  Bool is_vertical = (Bool)NSApp.squirrelAppDelegate.panel.vertical;
  if (is_vertical != rime_get_api()->get_option(_session, "_vertical")) {
    rime_get_api()->set_option(_session, "_vertical", is_vertical);
  }

  BOOL handled = (BOOL)rime_get_api()->process_key(_session, rime_keycode, rime_modifiers);
  //NSLog(@"rime_keycode: 0x%x, rime_modifiers: 0x%x, handled = %d", rime_keycode, rime_modifiers, handled);

  // TODO add special key event postprocessing here

  if (!handled) {
    BOOL isVimBackInCommandMode = rime_keycode == XK_Escape ||
          ((rime_modifiers & kControlMask) && (rime_keycode == XK_c ||
            rime_keycode == XK_C || rime_keycode == XK_bracketleft));
    if (isVimBackInCommandMode && rime_get_api()->get_option(_session, "vim_mode") &&
        !rime_get_api()->get_option(_session, "ascii_mode")) {
      [self cancelComposition];
      rime_get_api()->set_option(_session, "ascii_mode", True);
      // NSLog(@"turned Chinese mode off in vim-like editor's command mode");
      return YES;
    }
  }

  // Simulate key-ups for every interesting key-down for chord-typing.
  if (handled) {
    BOOL is_chording_key = (rime_keycode >= XK_space && rime_keycode <= XK_asciitilde) ||
                            rime_keycode == XK_Control_L || rime_keycode == XK_Control_R ||
                            rime_keycode == XK_Alt_L || rime_keycode == XK_Alt_R ||
                            rime_keycode == XK_Shift_L || rime_keycode == XK_Shift_R;
    if (is_chording_key && rime_get_api()->get_option(_session, "_chord_typing")) {
      [self updateChord:rime_keycode modifiers:rime_modifiers];
    } else if ((rime_modifiers & kReleaseMask) == 0) {
      // non-chording key pressed
      [self clearChord];
    }
  }

  return handled;
}

- (void)moveCursor:(NSUInteger)cursorPosition
        toPosition:(NSUInteger)targetPosition
     inlinePreedit:(BOOL)inlinePreedit
   inlineCandidate:(BOOL)inlineCandidate {
  BOOL vertical = NSApp.squirrelAppDelegate.panel.vertical;
  NSString *composition = !inlinePreedit && !inlineCandidate ? _composedString : _preeditString.string;
  RIME_STRUCT(RimeContext, ctx);
  if (cursorPosition > targetPosition) {
    NSString *targetPrefix = [[composition substringToIndex:targetPosition]
                              stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *prefix = [[composition substringToIndex:cursorPosition]
                        stringByReplacingOccurrencesOfString:@" " withString:@""];
    while (targetPrefix.length < prefix.length) {
      rime_get_api()->process_key(_session, vertical ? XK_Up : XK_Left, kControlMask);
      rime_get_api()->get_context(_session, &ctx);
      if (inlineCandidate) {
        size_t length = ctx.composition.cursor_pos < ctx.composition.sel_end ?
          (size_t)ctx.composition.cursor_pos : strlen(ctx.commit_text_preview) -
          (inlinePreedit ? 0 : (size_t)(ctx.composition.cursor_pos - ctx.composition.sel_end));
        prefix = [[[NSString alloc] initWithBytes:ctx.commit_text_preview
                                           length:(NSUInteger)length
                                         encoding:NSUTF8StringEncoding]
                  stringByReplacingOccurrencesOfString:@" " withString:@""];
      } else {
        prefix = [[[NSString alloc] initWithBytes:ctx.composition.preedit
                                           length:(NSUInteger)ctx.composition.cursor_pos
                                         encoding:NSUTF8StringEncoding]
                  stringByReplacingOccurrencesOfString:@" " withString:@""];
      }
      rime_get_api()->free_context(&ctx);
    }
  } else if (cursorPosition < targetPosition) {
    NSString *targetSuffix = [[composition substringFromIndex:targetPosition]
                              stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *suffix = [[composition substringFromIndex:cursorPosition]
                        stringByReplacingOccurrencesOfString:@" " withString:@""];
    while (targetSuffix.length < suffix.length) {
      rime_get_api()->process_key(_session, vertical ? XK_Down : XK_Right, kControlMask);
      rime_get_api()->get_context(_session, &ctx);
      suffix = [@(ctx.composition.preedit + ctx.composition.cursor_pos + (!inlinePreedit && !inlineCandidate ? 3 : 0))
                stringByReplacingOccurrencesOfString:@" " withString:@""];
      rime_get_api()->free_context(&ctx);
    }
  }
  [self rimeUpdate];
}

- (void)perform:(SquirrelAction)action
        onIndex:(SquirrelIndex)index {
  //NSLog(@"perform action: %lu on index: %lu", action, index);
  bool handled = false;
  if (index >= '!' && index <= '~' && (action == kSELECT || action == kHILITE)) {
    handled = rime_get_api()->process_key(_session, (int)index, action == kHILITE ? kAltMask : 0);
  } else if (index >= 0xff08 && index <= 0xffff && action == kSELECT) {
    handled = rime_get_api()->process_key(_session, (int)index, 0);
  } else if (index >= 0 && index < 10) {
    switch (action) {
      case kDELETE:
        handled = rime_get_api()->delete_candidate_on_current_page(_session, (size_t)index);
        break;
      case kSELECT:
        handled = rime_get_api()->select_candidate_on_current_page(_session, (size_t)index);
        break;
      case kHILITE:
        handled = rime_get_api()->highlight_candidate_on_current_page(_session, (size_t)index);
        break;
    }
  }
  if (handled) {
    [self rimeUpdate];
  }
}

- (void)onChordTimer:(NSTimer *)timer {
  // chord release triggered by timer
  uint processed_keys = 0;
  if (_chordKeyCount && _session) {
    // simulate key-ups
    for (uint i = 0; i < _chordKeyCount; ++i) {
      if (rime_get_api()->process_key(_session, _chordKeyCodes[i],
                                      (_chordModifiers[i] | kReleaseMask))) {
        ++processed_keys;
      }
    }
  }
  [self clearChord];
  if (processed_keys > 0) {
    [self rimeUpdate];
  }
}

- (void)updateChord:(int)keycode
          modifiers:(int)modifiers {
  //NSLog(@"update chord: {%s} << %x", _chord, keycode);
  for (uint i = 0; i < _chordKeyCount; ++i) {
    if (_chordKeyCodes[i] == keycode) {
      return;
    }
  }
  if (_chordKeyCount >= N_KEY_ROLL_OVER) {
    // you are cheating. only one human typist (fingers <= 10) is supported.
    return;
  }
  _chordKeyCodes[_chordKeyCount] = keycode;
  _chordModifiers[_chordKeyCount] = modifiers;
  ++_chordKeyCount;
  // reset timer
  if (_chordTimer.valid) {
    [_chordTimer invalidate];
  }
  _chordDuration = 0.1;
  NSNumber *duration = [NSApp.squirrelAppDelegate.config 
                        getOptionalDouble:@"chord_duration"];
  if (duration.doubleValue > 0) {
    _chordDuration = duration.doubleValue;
  }
  _chordTimer = [NSTimer scheduledTimerWithTimeInterval:_chordDuration
                                                 target:self
                                               selector:@selector(onChordTimer:)
                                               userInfo:nil
                                                repeats:NO];
}

- (void)clearChord {
  _chordKeyCount = 0;
  if (_chordTimer.valid) {
    [_chordTimer invalidate];
    _chordTimer = nil;
  }
}

- (NSUInteger)recognizedEvents:(id)sender {
  //NSLog(@"recognizedEvents:");
  return NSEventMaskKeyDown|NSEventMaskFlagsChanged|NSEventMaskLeftMouseDown;
}

NSString *getOptionLabel(RimeSessionId session, const char *option, Bool state) {
  RimeStringSlice short_label = rime_get_api()->
    get_state_label_abbreviated(session, option, state, True);
  if (short_label.str && short_label.length >= strlen(short_label.str)) {
    return @(short_label.str);
  } else {
    RimeStringSlice long_label = rime_get_api()->
      get_state_label_abbreviated(session, option, state, False);
    NSString *label = long_label.str ? @(long_label.str) : nil;
    return [label substringWithRange:[label rangeOfComposedCharacterSequenceAtIndex:0]];
  }
}

- (void)showInitialStatus {
  RIME_STRUCT(RimeStatus, status);
  if (_session && rime_get_api()->get_status(_session, &status)) {
    _schemaId = @(status.schema_id);
    NSString *schemaName = status.schema_name ? @(status.schema_name) : @(status.schema_id);
    NSMutableArray<NSString *> *options = [[NSMutableArray alloc] initWithCapacity:3];
    NSString *asciiMode = getOptionLabel(_session, "ascii_mode", status.is_ascii_mode);
    if (asciiMode) {
      [options addObject:asciiMode];
    }
    NSString *fullShape = getOptionLabel(_session, "full_shape", status.is_full_shape);
    if (fullShape) {
      [options addObject:fullShape];
    }
    NSString *asciiPunct = getOptionLabel(_session, "ascii_punct", status.is_ascii_punct);
    if (asciiPunct) {
      [options addObject:asciiPunct];
    }
    rime_get_api()->free_status(&status);
    NSString *foldedOptions = options.count == 0 ? schemaName :
      [NSString stringWithFormat:@"%@｜%@", schemaName, [options componentsJoinedByString:@" "]];
    [NSApp.squirrelAppDelegate.panel updateStatusLong:foldedOptions statusShort:schemaName];
    if (@available(macOS 14.0, *)) {
      _lastModifiers |= NSEventModifierFlagHelp;
    }
    [self rimeUpdate];
  }
}

- (void)activateServer:(id)sender {
  //NSLog(@"activateServer:");
  NSString *keyboardLayout = [NSApp.squirrelAppDelegate.config
                              getString:@"keyboard_layout"];
  if ([keyboardLayout isEqualToString:@"last"] ||
      [keyboardLayout isEqualToString:@""]) {
    keyboardLayout = nil;
  } else if ([keyboardLayout isEqualToString:@"default"]) {
    keyboardLayout = @"com.apple.keylayout.ABC";
  } else if (![keyboardLayout hasPrefix:@"com.apple.keylayout."]) {
    keyboardLayout = [@"com.apple.keylayout."
                      stringByAppendingString:keyboardLayout];
  }
  if (keyboardLayout) {
    [sender overrideKeyboardWithKeyboardNamed:keyboardLayout];
  }

  [SquirrelInputController removeDeactivationTimeForController:self];
  if (NSApp.squirrelAppDelegate.showNotifications == kShowNotificationsAlways) {
    if (!SquirrelInputController.currentController ||
        SquirrelInputController.lastDeactivationTime.timeIntervalSinceNow < -1.0) {
      [self showInitialStatus];
    }
  }
  [SquirrelInputController setCurrentController:self];

  SquirrelConfig *defaultConfig = [[SquirrelConfig alloc] init];
  if ([defaultConfig openWithConfigId:@"default"] &&
      [defaultConfig hasSection:@"ascii_composer"]) {
    _goodOldCapsLock = [defaultConfig getBool:
                        @"ascii_composer/good_old_caps_lock"];
  }
  [defaultConfig close];
  [super activateServer:sender];
}

- (instancetype)initWithServer:(IMKServer *)server
                      delegate:(id)delegate
                        client:(id)inputClient {
  //NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server delegate:delegate
                            client:inputClient]) {
    [self createSession];
  }
  return self;
}

- (void)deactivateServer:(id)sender {
  //NSLog(@"deactivateServer:");
  [self commitComposition:sender];
  [SquirrelInputController setDeactivationTimeForController:self];
  [super deactivateServer:sender];
}

/*!
   @method
   @abstract   Called when a user action was taken that ends an input session.
   Typically triggered by the user selecting a new input method
   or keyboard layout.
   @discussion When this method is called your controller should send the
   current input buffer to the client via a call to
   insertText:replacementRange:.  Additionally, this is the time
   to clean up if that is necessary.
 */

- (void)commitComposition:(id)sender {
  //NSLog(@"commitComposition:");
  [self commitString:[self composedString:sender]];
  [self hidePalettes];
  if (_session) {
    rime_get_api()->clear_composition(_session);
  }
}

- (void)clearBuffer {
  NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
  _preeditString = nil;
  _originalString = nil;
  _composedString = nil;
}

// a piece of comment from SunPinyin's macos wrapper says:
// > though we specified the showPrefPanel: in SunPinyinApplicationDelegate as the
// > action receiver, the IMKInputController will actually receive the event.
// so here we deliver messages to our responsible SquirrelApplicationDelegate
- (void)deploy:(id)sender {
  [NSApp.squirrelAppDelegate deploy:sender];
}

- (void)syncUserData:(id)sender {
  [NSApp.squirrelAppDelegate syncUserData:sender];
}

- (void)configure:(id)sender {
  [NSApp.squirrelAppDelegate configure:sender];
}

- (void)checkForUpdates:(id)sender {
  [NSApp.squirrelAppDelegate.updater performSelector:@selector(checkForUpdates:)
                                          withObject:sender];
}

- (void)openWiki:(id)sender {
  [NSApp.squirrelAppDelegate openWiki:sender];
}

- (void)openLogFolder:(id)sender {
  [NSApp.squirrelAppDelegate openLogFolder:sender];
}

- (NSMenu *)menu {
  return NSApp.squirrelAppDelegate.menu;
}

- (NSAttributedString *)originalString:(id)sender {
  return [[NSAttributedString alloc] initWithString:_originalString];
}

- (id)composedString:(id)sender {
  return [_composedString stringByReplacingOccurrencesOfString:@" "
                                                    withString:@""];
}

- (NSArray *)candidates:(id)sender {
  return _candidates;
}

- (void)hidePalettes {
  [NSApp.squirrelAppDelegate.panel hide];
  [super hidePalettes];
}

- (void)dealloc {
  //NSLog(@"dealloc");
  [self destroySession];
  [self clearBuffer];
}

- (NSRange)selectionRange {
  return NSMakeRange(_caretPos, 0);
}

- (NSRange)replacementRange {
  return NSMakeRange(NSNotFound, NSNotFound);
}

- (void)commitString:(id)string {
  //NSLog(@"commitString:");
  if (string) {
    [self.client insertText:string
           replacementRange:self.replacementRange];
  }
  [self clearBuffer];
}

- (void)cancelComposition {
  [self commitString:[self originalString:self.client]];
  rime_get_api()->clear_composition(_session);
}

- (void)updateComposition {
  [self.client setMarkedText:_preeditString
              selectionRange:self.selectionRange
            replacementRange:self.replacementRange];
}

- (void)showPlaceholder:(NSString *)placeholder {
  NSDictionary* attrs = [self markForStyle:kTSMHiliteSelectedRawText
                                   atRange:NSMakeRange(0, placeholder ? placeholder.length : 1)];
  _preeditString = [[NSMutableAttributedString alloc] initWithString:placeholder ? : @"█"
                                                          attributes:attrs];
  _caretPos = 0;
  [self updateComposition];
}

- (void)showPreeditString:(NSString *)preedit
                 selRange:(NSRange)range
                 caretPos:(NSUInteger)pos {
  //NSLog(@"showPreeditString: '%@'", preedit);
  if ([preedit isEqualToString:_preeditString.string] &&
      NSEqualRanges(range, _selRange) && pos == _caretPos) {
    return;
  }
  _selRange = range;
  _caretPos = pos;
  //NSLog(@"selRange.location = %ld, selRange.length = %ld; caretPos = %ld",
  //      range.location, range.length, pos);
  NSDictionary* attrs = [self markForStyle:kTSMHiliteRawText
                                   atRange:NSMakeRange(0, preedit.length)];
  _preeditString = [[NSMutableAttributedString alloc] initWithString:preedit
                                                          attributes:attrs];
  if (range.location > 0) {
    [_preeditString addAttributes:[self markForStyle:kTSMHiliteConvertedText
                                             atRange:NSMakeRange(0, range.location)]
                            range:NSMakeRange(0, range.location)];
  }
  if (range.location < pos) {
    [_preeditString addAttributes:[self markForStyle:kTSMHiliteSelectedRawText
                                             atRange:range]
                            range:range];
  }
  [self updateComposition];
}

- (CGRect)getIbeamRect {
  NSRect IbeamRect = NSZeroRect;
  [self.client attributesForCharacterIndex:0
                       lineHeightRectangle:&IbeamRect];
  if (NSEqualRects(IbeamRect, NSZeroRect) && _preeditString.length == 0) {
    if (self.client.selectedRange.length == 0) {
      // activate inline session, in e.g. table cells, by fake inputs
      [self.client setMarkedText:@" "
                  selectionRange:NSMakeRange(0, 0)
                replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      [self.client attributesForCharacterIndex:0
                           lineHeightRectangle:&IbeamRect];
      [self.client setMarkedText:_preeditString
                  selectionRange:NSMakeRange(0, 0)
                replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    } else {
      [self.client attributesForCharacterIndex:self.client.selectedRange.location
                           lineHeightRectangle:&IbeamRect];
    }
  }
  if (NSIsEmptyRect(IbeamRect)) {
    return IbeamRect;
  }
  NSWidth(IbeamRect) > NSHeight(IbeamRect) ? IbeamRect.origin.x += _inlineOffset
                                           : IbeamRect.origin.y += _inlineOffset;
  if (@available(macOS 14.0, *)) {  // avoid overlapping with cursor effects view
    if ((_goodOldCapsLock && (_lastModifiers & NSEventModifierFlagCapsLock)) ||
        (_lastModifiers & NSEventModifierFlagHelp)) {
      _lastModifiers &= ~NSEventModifierFlagHelp;
      NSRect screenRect = NSScreen.mainScreen.frame;
      if (NSIntersectsRect(IbeamRect, screenRect)) {
        screenRect = NSScreen.mainScreen.visibleFrame;
        if (NSWidth(IbeamRect) > NSHeight(IbeamRect)) {
          NSRect capslockAccessory = NSMakeRect(NSMinX(IbeamRect) - 30, NSMinY(IbeamRect),
                                                27, NSHeight(IbeamRect));
          if (NSMinX(capslockAccessory) < NSMinX(screenRect))
            capslockAccessory.origin.x = NSMinX(screenRect);
          if (NSMaxX(capslockAccessory) > NSMaxX(screenRect))
            capslockAccessory.origin.x = NSMaxX(screenRect) - NSWidth(capslockAccessory);
          IbeamRect = NSUnionRect(IbeamRect, capslockAccessory);
        } else {
          NSRect capslockAccessory = NSMakeRect(NSMinX(IbeamRect), NSMinY(IbeamRect) - 26,
                                                NSWidth(IbeamRect), 23);
          if (NSMinY(capslockAccessory) < NSMinY(screenRect))
            capslockAccessory.origin.y = NSMaxY(screenRect) + 3;
          if (NSMaxY(capslockAccessory) > NSMaxY(screenRect))
            capslockAccessory.origin.y = NSMaxY(screenRect) - NSHeight(capslockAccessory);
          IbeamRect = NSUnionRect(IbeamRect, capslockAccessory);
        }
      }
    }
  }
  return IbeamRect;
}

- (void)showPanelWithPreedit:(NSString *)preedit
                    selRange:(NSRange)selRange
                    caretPos:(NSUInteger)caretPos
                  candidates:(NSArray<NSString *> *)candidates
                    comments:(NSArray<NSString *> *)comments
            highlightedIndex:(NSUInteger)highlightedIndex
                     pageNum:(NSUInteger)pageNum
                    lastPage:(BOOL)lastPage {
  //NSLog(@"showPanelWithPreedit:...:");
  _candidates = candidates;
  SquirrelPanel *panel = NSApp.squirrelAppDelegate.panel;
  panel.IbeamRect = [self getIbeamRect];
  if (NSIsEmptyRect(panel.IbeamRect) && panel.statusMessage.length > 0) {
    [panel updateStatusLong:nil statusShort:nil];
  } else {
    [panel showPreedit:preedit
              selRange:selRange
              caretPos:caretPos
            candidates:candidates
              comments:comments
      highlightedIndex:highlightedIndex
               pageNum:pageNum
              lastPage:lastPage];
  }
}

#pragma mark - Private methods

- (void)createSession {
  NSString *app = self.client.bundleIdentifier;
  //NSLog(@"createSession: %@", app);
  _session = rime_get_api()->create_session();
  _schemaId = nil;
  if (_session) {
    char *rime_client = NULL;
    if (!rime_get_api()->get_property(_session, "client", rime_client, 100) ||
        ![app isEqualToString:@(rime_client)]) {
      rime_get_api()->set_property(_session, "client", app.UTF8String);
      SquirrelAppOptions *appOptions = [NSApp.squirrelAppDelegate.config getAppOptions:app];
      if (appOptions) {
        for (NSString *key in appOptions) {
          NSNumber *number = appOptions[key];
          if (!strcmp(number.objCType, @encode(BOOL))) {
            Bool value = number.intValue;
            //NSLog(@"set app option: %@ = %d", key, value);
            rime_get_api()->set_option(_session, key.UTF8String, value);
          }
        }
        _panellessCommitFix = appOptions[@"panelless_commit_fix"].boolValue;
        _inlinePlaceholder = appOptions[@"inline_placeholder"].boolValue;
        _inlineOffset = appOptions[@"inline_offset"].intValue;
      }
    }
    _lastModifiers = 0;
    _lastEventCount = 0;
    NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
    [self rimeUpdate];
  }
}

- (void)destroySession {
  //NSLog(@"destroySession:");
  if (_session) {
    rime_get_api()->destroy_session(_session);
    _session = 0;
  }
  [self clearChord];
}

- (BOOL)rimeConsumeCommittedText {
  RIME_STRUCT(RimeCommit, commit);
  if (rime_get_api()->get_commit(_session, &commit)) {
    NSString *commitText = @(commit.text);
    if (_panellessCommitFix) {
      [self showPlaceholder:commitText];
      [self commitString:commitText];
      [self showPlaceholder:sizeof(commit.text) == 1 ? @"" : nil];
    } else {
      [self commitString:commitText];
    }
    rime_get_api()->free_commit(&commit);
    return YES;
  }
  return NO;
}

NSUInteger inline UTF8LengthToUTF16Length(const char* string, int length) {
  return [[NSString alloc] initWithBytes:string
                                  length:(NSUInteger)length
                                encoding:NSUTF8StringEncoding].length;
}

- (void)rimeUpdate {
  //NSLog(@"rimeUpdate");
  BOOL didCommit = [self rimeConsumeCommittedText];

  RIME_STRUCT(RimeStatus, status);
  if (rime_get_api()->get_status(_session, &status)) {
    // enable schema specific ui style
    if (!_schemaId || strcmp(_schemaId.UTF8String, status.schema_id)) {
      _schemaId = @(status.schema_id);
      _showingSwitcherMenu = (BOOL)rime_get_api()->get_option(_session, "dumb");
      if (!_showingSwitcherMenu) {
        [NSApp.squirrelAppDelegate loadSchemaSpecificLabels:_schemaId];
        [NSApp.squirrelAppDelegate loadSchemaSpecificSettings:_schemaId
                                              withRimeSession:_session];
        // inline preedit
        _inlinePreedit = (NSApp.squirrelAppDelegate.panel.inlinePreedit &&
                          !rime_get_api()->get_option(_session, "no_inline")) ||
                         rime_get_api()->get_option(_session, "inline");
        _inlineCandidate = (NSApp.squirrelAppDelegate.panel.inlineCandidate &&
                            !rime_get_api()->get_option(_session, "no_inline"));
        // if not inline, embed soft cursor in preedit string
        rime_get_api()->set_option(_session, "soft_cursor", !_inlinePreedit);
      } else {
        [NSApp.squirrelAppDelegate loadSchemaSpecificLabels:@""];
      }
    }
    rime_get_api()->free_status(&status);
  }

  RIME_STRUCT(RimeContext, ctx);
  if (rime_get_api()->get_context(_session, &ctx)) {
    BOOL showingStatus = NSApp.squirrelAppDelegate.panel.statusMessage.length > 0;
    // update raw input
    const char *raw_input = rime_get_api()->get_input(_session);
    _originalString = raw_input ? @(raw_input) : @"";

    // update preedit text
    const char *preedit = ctx.composition.preedit;
    NSString *preeditText = preedit ? @(preedit) : @"";

    // update composed string
    if (!preedit || _showingSwitcherMenu) {
      _composedString = @"";
    } else if (rime_get_api()->get_option(_session, "soft_cursor")) {
      size_t cursorPos = (size_t)ctx.composition.cursor_pos -
        (ctx.composition.cursor_pos < ctx.composition.sel_end ? 3 : 0);
      char composed[strlen(preedit) - 2];
      strlcpy(composed, preedit, cursorPos + 1);
      strlcat(composed, preedit + cursorPos + 3, strlen(preedit) - 2);
      _composedString = @(composed);
    } else {
      _composedString = @(preedit);
    }

    NSUInteger start = UTF8LengthToUTF16Length(preedit, ctx.composition.sel_start);
    NSUInteger end = UTF8LengthToUTF16Length(preedit, ctx.composition.sel_end);
    NSUInteger caretPos = UTF8LengthToUTF16Length(preedit, ctx.composition.cursor_pos);
    NSUInteger length = UTF8LengthToUTF16Length(preedit, ctx.composition.length);
    NSUInteger numCandidate = (NSUInteger)ctx.menu.num_candidates;

    if (showingStatus) {
      [self clearBuffer];
    } else if (_showingSwitcherMenu) {
      if (_inlinePlaceholder) {
        [self updateComposition];
      }
    } else if (_inlineCandidate) {
      const char *candidatePreview = ctx.commit_text_preview;
      NSString *candidatePreviewText = candidatePreview ? @(candidatePreview) : @"";
      if (_inlinePreedit) {
        if (end <= caretPos && caretPos < length) {
          candidatePreviewText = [candidatePreviewText stringByAppendingString:
                                  [preeditText substringWithRange:NSMakeRange(caretPos, length - caretPos)]];
        }
        if (!didCommit || candidatePreviewText.length > 0) {
          [self showPreeditString:candidatePreviewText
                         selRange:NSMakeRange(start, candidatePreviewText.length - (length - end) - start)
                         caretPos:caretPos < end ? caretPos : candidatePreviewText.length - (length - caretPos)];
        }
      } else { // preedit includes the soft cursor
        if (end < caretPos && caretPos <= length) {
          candidatePreviewText = [candidatePreviewText substringToIndex:candidatePreviewText.length - (caretPos - end)];
        } else if (caretPos < end && end < length) {
          candidatePreviewText = [candidatePreviewText substringToIndex:candidatePreviewText.length - (length - end)];
        }
        if (!didCommit || candidatePreviewText.length > 0) {
          [self showPreeditString:candidatePreviewText
                         selRange:NSMakeRange(start - (caretPos < end),
                                              candidatePreviewText.length - start + (caretPos < end))
                         caretPos:caretPos < end ? caretPos - 1 : candidatePreviewText.length];
        }
      }
    } else {
      if (_inlinePreedit && !_showingSwitcherMenu) {
        if (_inlinePlaceholder && preeditText.length == 0 && numCandidate > 0) {
          [self showPlaceholder:kFullWidthSpace];
        } else if (!didCommit || preeditText.length > 0) {
          [self showPreeditString:preeditText
                         selRange:NSMakeRange(start, end - start)
                         caretPos:caretPos];
        }
      } else {
        if (_inlinePlaceholder && preedit) {
          [self showPlaceholder:kFullWidthSpace];
        } else if (!didCommit || preedit) {
          [self showPreeditString:@"" selRange:NSMakeRange(0, 0) caretPos:0];
        }
      }
    }
    // update candidates
    NSMutableArray *candidates = [[NSMutableArray alloc] initWithCapacity:numCandidate];
    NSMutableArray *comments = [[NSMutableArray alloc] initWithCapacity:numCandidate];
    for (NSUInteger i = 0; i < numCandidate; ++i) {
      [candidates addObject:@(ctx.menu.candidates[i].text)];
      [comments addObject:@(ctx.menu.candidates[i].comment ? : "")];
    }
    [self showPanelWithPreedit:_inlinePreedit && !_showingSwitcherMenu ? nil : preeditText
                      selRange:NSMakeRange(start, end - start)
                      caretPos:_showingSwitcherMenu ? NSNotFound : caretPos
                    candidates:candidates
                      comments:comments
              highlightedIndex:(NSUInteger)ctx.menu.highlighted_candidate_index
                       pageNum:(NSUInteger)ctx.menu.page_no
                      lastPage:(BOOL)ctx.menu.is_last_page];
    rime_get_api()->free_context(&ctx);
  } else {
    [self hidePalettes];
    [self clearBuffer];
  }
}

@end // SquirrelInputController
