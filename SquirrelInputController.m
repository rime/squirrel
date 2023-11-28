#import "SquirrelInputController.h"

#import "SquirrelApplicationDelegate.h"
#import "SquirrelConfig.h"
#import "SquirrelPanel.h"
#import "macos_keycode.h"
#import <rime_api.h>
#import <rime/key_table.h>

@interface SquirrelInputController (Private)
- (void)createSession;
- (void)destroySession;
- (void)rimeConsumeCommittedText;
- (void)updateStyleOptions;
- (void)rimeUpdate;
@end

const int N_KEY_ROLL_OVER = 50;

@implementation SquirrelInputController {
  NSMutableAttributedString *_preeditString;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray<NSString *> *_candidates;
  NSEventModifierFlags _lastModifier;
  uint _lastEventCount;
  RimeSessionId _session;
  NSString *_schemaId;
  BOOL _inlinePreedit;
  BOOL _inlineCandidate;
  BOOL _showingSwitcherMenu;
  // app-specific bug fix
  BOOL _inlinePlaceHolder;
  BOOL _panellessCommitFix;
  // for chord-typing
  int _chordKeyCodes[N_KEY_ROLL_OVER];
  int _chordModifiers[N_KEY_ROLL_OVER];
  uint _chordKeyCount;
  NSTimer *_chordTimer;
  NSTimeInterval _chordDuration;
}

/*!
   @method
   @abstract   Receive incoming event
   @discussion This method receives key events from the client application.
 */
- (BOOL)handleEvent:(NSEvent *)event
             client:(id)sender
{
  // Return YES to indicate the the key input was received and dealt with.
  // Key processing will not continue in that case.  In other words the
  // system will not deliver a key down event to the application.
  // Returning NO means the original key down will be passed on to the client.

  NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  BOOL handled = NO;

  @autoreleasepool {
    if (!_session || !rime_get_api()->find_session(_session)) {
      [self createSession];
      if (!_session) {
        return NO;
      }
    }

    NSString *app = [sender bundleIdentifier];

    if (![_currentApp isEqualToString:app]) {
      _currentApp = [app copy];
      [self updateAppOptions];
    }

    switch (event.type) {
      case NSEventTypeFlagsChanged: {
        if (_lastModifier == modifiers) {
          handled = YES;
          break;
        }

        //NSLog(@"FLAGSCHANGED client: %@, modifiers: 0x%lx", sender, modifiers);
        int release_mask = 0;
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        ushort keyCode = (ushort)CGEventGetIntegerValueField(event.CGEvent, kCGKeyboardEventKeycode);
        int rime_keycode = osx_keycode_to_rime_keycode(keyCode, 0, 0, 0);
        uint eventCount = CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventFlagsChanged) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventKeyDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventLeftMouseDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventRightMouseDown) +
                          CGEventSourceCounterForEventType(kCGEventSourceStateCombinedSessionState, kCGEventOtherMouseDown);
        _lastModifier = modifiers;
        switch (keyCode) {
          case kVK_CapsLock:
            if (!_goodOldCapsLock) {
              set_caps_lock_led(false);
              Bool caps_lock_on = rime_get_api()->get_option(_session, "caps_lock_on");
              rime_modifiers = caps_lock_on ? rime_modifiers | kLockMask : rime_modifiers & ~kLockMask;
              rime_get_api()->set_option(_session, "caps_lock_on", !caps_lock_on);
            } else {
              rime_modifiers ^= kLockMask;
            }
            [self processKey:rime_keycode modifiers:rime_modifiers];
            break;
          case kVK_Shift:
          case kVK_RightShift:
            release_mask = modifiers & NSEventModifierFlagShift ? 0 : kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Control:
          case kVK_RightControl:
            release_mask = modifiers & NSEventModifierFlagControl ? 0 : kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Option:
          case kVK_RightOption:
            release_mask = modifiers & NSEventModifierFlagOption ? 0 : kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Function:
            release_mask = modifiers & NSEventModifierFlagFunction ? 0 : kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
          case kVK_Command:
          case kVK_RightCommand:
            release_mask = modifiers & NSEventModifierFlagCommand ? 0 : kReleaseMask | (eventCount - _lastEventCount == 1 ? 0 : kIgnoredMask);
            [self processKey:rime_keycode modifiers:(rime_modifiers | release_mask)];
            break;
        }
        [self rimeUpdate];
        _lastEventCount = eventCount;
      } break;
      case NSEventTypeKeyDown: {
        ushort keyCode = event.keyCode;
        NSString *keyChars = ((modifiers & NSEventModifierFlagShift) && !(modifiers & NSEventModifierFlagControl) &&
                              !(modifiers & NSEventModifierFlagOption)) ? event.characters : event.charactersIgnoringModifiers;
        //NSLog(@"KEYDOWN client: %@, modifiers: 0x%lx, keyCode: %d, keyChars: [%@]",
        //      sender, modifiers, keyCode, keyChars);

        // translate osx keyevents to rime keyevents
        int rime_keycode = osx_keycode_to_rime_keycode(keyCode, [keyChars characterAtIndex:0],
                                                       modifiers & NSEventModifierFlagShift,
                                                       modifiers & NSEventModifierFlagCapsLock);
        if (rime_keycode) {
          int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
          // revert non-modifier function keys' FunctionKeyMask (FwdDel, Navigations, F1..F19)
          if ((keyCode <= 0xff && keyCode >= 0x60) || keyCode == 0x50 || keyCode == 0x4f ||
              keyCode == 0x47 || keyCode == 0x40) {
            rime_modifiers ^= kHyperMask;
          }
          handled = [self processKey:rime_keycode modifiers:rime_modifiers];
          [self rimeUpdate];
        }
      } break;
      default:
        break;
    }
  }
  return handled;
}

- (BOOL)processKey:(int)rime_keycode 
         modifiers:(int)rime_modifiers
{
  // with linear candidate list, arrow keys may behave differently.
  Bool is_linear = NSApp.squirrelAppDelegate.panel.linear;
  if (is_linear != rime_get_api()->get_option(_session, "_linear")) {
    rime_get_api()->set_option(_session, "_linear", is_linear);
  }
  // with vertical text, arrow keys may behave differently.
  Bool is_vertical = NSApp.squirrelAppDelegate.panel.vertical;
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
      rime_get_api()->set_option(_session, "ascii_mode", True);
      // NSLog(@"turned Chinese mode off in vim-like editor's command mode");
    }
  }

  // Simulate key-ups for every interesting key-down for chord-typing.
  if (handled) {
    BOOL is_chording_key =
      (rime_keycode >= XK_space && rime_keycode <= XK_asciitilde) ||
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

- (void)perform:(rimeAction)action 
        onIndex:(rimeIndex)index {
  bool handled = false;
  if (action == kSELECT && ((index >= '!' && index <= '~') ||
      index == kPageUp || index == kPageDown || index == kEscape)) {
    handled = rime_get_api()->process_key(_session, (int)index, 0);
  } else if (action == kCHOOSE && index >= '!' && index <= '~') {
    handled = rime_get_api()->process_key(_session, (int)index, kAltMask);
  } else if (action == kDELETE && index >= 0 && index < 10) {
    // kDELETE takes ordinal digits (instead of characters) as indexes
    handled= rime_get_api()->delete_candidate_on_current_page(_session, (size_t)index);
  }
  if (handled) {
    [self rimeUpdate];
  }
}

- (void)onChordTimer:(NSTimer *)timer
{
  // chord release triggered by timer
  int processed_keys = 0;
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
  if (processed_keys) {
    [self rimeUpdate];
  }
}

- (void)updateChord:(int)keycode
          modifiers:(int)modifiers
{
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
  if (_chordTimer && _chordTimer.valid) {
    [_chordTimer invalidate];
  }
  _chordDuration = 0.1;
  NSNumber *duration = [NSApp.squirrelAppDelegate.config getOptionalDouble:@"chord_duration"];
  if (duration && duration.doubleValue > 0) {
    _chordDuration = duration.doubleValue;
  }
  _chordTimer = [NSTimer scheduledTimerWithTimeInterval:_chordDuration
                                                 target:self
                                               selector:@selector(onChordTimer:)
                                               userInfo:nil
                                                repeats:NO];
}

- (void)clearChord
{
  _chordKeyCount = 0;
  if (_chordTimer) {
    if (_chordTimer.valid) {
      [_chordTimer invalidate];
    }
    _chordTimer = nil;
  }
}

- (NSUInteger)recognizedEvents:(id)sender
{
  //NSLog(@"recognizedEvents:");
  return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (void)activateServer:(id)sender
{
  //NSLog(@"activateServer:");
  NSString *keyboardLayout = [NSApp.squirrelAppDelegate.config getString:@"keyboard_layout"];
  if ([keyboardLayout isEqualToString:@"last"] || [keyboardLayout isEqualToString:@""]) {
    keyboardLayout = nil;
  } else if ([keyboardLayout isEqualToString:@"default"]) {
    keyboardLayout = @"com.apple.keylayout.ABC";
  } else if (![keyboardLayout hasPrefix:@"com.apple.keylayout."]) {
    keyboardLayout = [@"com.apple.keylayout." stringByAppendingString:keyboardLayout];
  }
  if (keyboardLayout) {
    [sender overrideKeyboardWithKeyboardNamed:keyboardLayout];
  }
  
  if (!_session || !RimeFindSession(_session)) {
    _session = RimeCreateSession();
  }
  [super activateServer:sender];
}

- (instancetype)initWithServer:(IMKServer *)server 
                      delegate:(id)delegate
                        client:(id)inputClient
{
  //NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server delegate:delegate client:inputClient]) {
    [self createSession];
    _preeditString = [[NSMutableAttributedString alloc] init];
  }
  return self;
}

- (void)deactivateServer:(id)sender
{
  //NSLog(@"deactivateServer:");
  [self commitComposition:sender];
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

- (void)commitComposition:(id)sender
{
  //NSLog(@"commitComposition:");
  if (_session) {
    NSString *composition = [self composedString:sender];
    [[NSPasteboard generalPasteboard] setString:composition forType:NSPasteboardTypeString];
    [self commitString:composition];
    [self hidePalettes];
    rime_get_api()->clear_composition(_session);
  }
}

// a piece of comment from SunPinyin's macos wrapper says:
// > though we specified the showPrefPanel: in SunPinyinApplicationDelegate as the
// > action receiver, the IMKInputController will actually receive the event.
// so here we deliver messages to our responsible SquirrelApplicationDelegate
- (void)deploy:(id)sender
{
  [NSApp.squirrelAppDelegate deploy:sender];
  [self createSession];
}

- (void)syncUserData:(id)sender
{
  [NSApp.squirrelAppDelegate syncUserData:sender];
}

- (void)configure:(id)sender
{
  [NSApp.squirrelAppDelegate configure:sender];
}

- (void)checkForUpdates:(id)sender
{
  [NSApp.squirrelAppDelegate.updater performSelector:@selector(checkForUpdates:) 
                                          withObject:sender];
}

- (void)openWiki:(id)sender
{
  [NSApp.squirrelAppDelegate openWiki:sender];
}

- (void)openLogFolder:(id)sender
{
  [NSApp.squirrelAppDelegate openLogFolder:sender];
}

- (NSMenu *)menu
{
  return NSApp.squirrelAppDelegate.menu;
}

- (NSAttributedString *)originalString:(id)sender
{
  const char *raw_input = RimeGetInput(_session);
  return [[NSAttributedString alloc] initWithString:raw_input ? @(raw_input) : @""];
}

- (id)composedString:(id)sender
{
  RimeCommitComposition(_session);
  RIME_STRUCT(RimeCommit, commit);
  RimeGetCommit(_session, &commit);
  const char *composedString = commit.text;
  RimeFreeCommit(&commit);
  return composedString ? @(composedString) : @"";
}

- (NSArray *)candidates:(id)sender
{
  return _candidates;
}

- (void)hidePalettes
{
  [NSApp.squirrelAppDelegate.panel hide];
}

- (void)dealloc
{
  [self destroySession];
  _preeditString = nil;
}

- (NSRange)selectionRange
{
  return NSMakeRange(_caretPos, 0);
}

- (NSRange)replacementRange
{
  return NSMakeRange(NSNotFound, NSNotFound);
}

- (void)commitString:(id)string
{
  //NSLog(@"commitString:");
  [self.client insertText:string
         replacementRange:self.replacementRange];

  [_preeditString deleteCharactersInRange:NSMakeRange(0, _preeditString.length)];
}

- (void)cancelComposition
{
  [self commitString:[self originalString:self.client]];
  rime_get_api()->clear_composition(_session);
}

- (void)updateComposition
{
  [self.client setMarkedText:_preeditString
              selectionRange:self.selectionRange
            replacementRange:self.replacementRange];
}

- (void)showPreeditString:(NSString *)preedit
                 selRange:(NSRange)range
                 caretPos:(NSUInteger)pos
{
  if (_inlinePlaceHolder && _candidates.count > 0 && preedit.length == 0) {
    preedit = @" ";
  }
  //NSLog(@"showPreeditString: '%@'", preedit);
  if ([preedit isEqualToString:_preeditString.string] &&
      NSEqualRanges(range, _selRange) && pos == _caretPos) {
    if (_inlinePlaceHolder) {
      [self updateComposition];
    }
    return;
  }
  _selRange = range;
  _caretPos = pos;
  //NSLog(@"selRange.location = %ld, selRange.length = %ld; caretPos = %ld",
  //      range.location, range.length, pos);
  NSDictionary *attrs;
  _preeditString = [[NSMutableAttributedString alloc] initWithString:preedit];
  if (range.location > 0) {
    NSRange convertedRange = NSMakeRange(0, range.location);
    attrs = [self markForStyle:kTSMHiliteConvertedText atRange:convertedRange];
    [_preeditString addAttributes:attrs range:convertedRange];
  }
  if (range.location < pos) {
    attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:range];
    [_preeditString addAttributes:attrs range:range];
  }
  [self updateComposition];
}

- (void)showPanelWithPreedit:(NSString *)preedit
                    selRange:(NSRange)selRange
                    caretPos:(NSUInteger)caretPos
                  candidates:(NSArray<NSString *> *)candidates
                    comments:(NSArray<NSString *> *)comments
                 highlighted:(NSUInteger)index
                     pageNum:(NSUInteger)pageNum
                    lastPage:(BOOL)lastPage
{
  //NSLog(@"showPanelWithPreedit:...:");
  _candidates = candidates;
  NSRect inputPos;
  [self.client attributesForCharacterIndex:0 lineHeightRectangle:&inputPos];
  SquirrelPanel *panel = NSApp.squirrelAppDelegate.panel;
  if (@available(macOS 14.0, *)) {  // avoid overlapping with cursor effects view
    if (_lastModifier & NSEventModifierFlagCapsLock) {
      NSRect screenRect = [[NSScreen mainScreen] frame];
      if (NSIntersectsRect(inputPos, screenRect)) {
        screenRect = [[NSScreen mainScreen] visibleFrame];
        if (NSWidth(inputPos) > NSHeight(inputPos)) {
          NSRect capslockAccessory = NSMakeRect(NSMinX(inputPos) - 30, NSMinY(inputPos), 27, NSHeight(inputPos));
          if (NSMinX(capslockAccessory) < NSMinX(screenRect))
            capslockAccessory.origin.x = NSMinX(screenRect);
          if (NSMaxX(capslockAccessory) > NSMaxX(screenRect))
            capslockAccessory.origin.x = NSMaxX(screenRect) - NSWidth(capslockAccessory);
          inputPos = NSUnionRect(inputPos, capslockAccessory);
        } else {
          NSRect capslockAccessory = NSMakeRect(NSMinX(inputPos), NSMinY(inputPos) - 26, NSWidth(inputPos), 23);
          if (NSMinY(capslockAccessory) < NSMinY(screenRect))
            capslockAccessory.origin.y = NSMaxY(screenRect) + 3;
          if (NSMaxY(capslockAccessory) > NSMaxY(screenRect))
            capslockAccessory.origin.y = NSMaxY(screenRect) - NSHeight(capslockAccessory);
          inputPos = NSUnionRect(inputPos, capslockAccessory);
        }
      }
    }
  }
  panel.inputController = self;
  panel.level = self.client.windowLevel + 1;
  panel.position = inputPos;
  [panel showPreedit:preedit
            selRange:selRange
            caretPos:caretPos
          candidates:candidates
            comments:comments
         highlighted:index
             pageNum:pageNum
            lastPage:lastPage];
}

@end // SquirrelController


// implementation of private interface
@implementation SquirrelInputController (Private)

- (void)createSession
{
  NSString *app = [self.client bundleIdentifier];
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
          Bool value = [appOptions[key] intValue];
          //NSLog(@"set app option: %@ = %d", key, value);
          rime_get_api()->set_option(_session, key.UTF8String, value);
        }
        _panellessCommitFix = [appOptions[@"panelless_commit_fix"] boolValue];
        _inlinePlaceHolder = [appOptions[@"inline_placeholder"] boolValue];
      }
    }
  }
}

- (void)destroySession
{
  //NSLog(@"destroySession:");
  if (_session) {
    rime_get_api()->destroy_session(_session);
    _session = 0;
  }
  [self clearChord];
}

- (void)rimeConsumeCommittedText
{
  RIME_STRUCT(RimeCommit, commit);
  if (rime_get_api()->get_commit(_session, &commit)) {
    NSString *commitText = @(commit.text);
    if (_preeditString.length == 0 && _panellessCommitFix) {
      [self showPreeditString:@" " selRange:NSMakeRange(0, 0) caretPos:0];
    }
    [self commitString:commitText];
    rime_get_api()->free_commit(&commit);
  }
}

- (void)updateStyleOptions
{
  // update the list of switchers that change styles and color-themes
  SquirrelOptionSwitcher *optionSwitcher;
  SquirrelConfig *schema = [[SquirrelConfig alloc] init];
  if ([schema openWithSchemaId:_schemaId baseConfig:NSApp.squirrelAppDelegate.config] &&
      [schema hasSection:@"style"]) {
    optionSwitcher = [schema getOptionSwitcher];
  } else {
    optionSwitcher = [[SquirrelOptionSwitcher alloc] initWithSchemaId:_schemaId switcher:@{} optionGroups:@{}];
  }
  [schema close];
  NSMutableDictionary *switcher = [optionSwitcher mutableSwitcher];
  NSSet<NSString *> *prevStates = [NSSet setWithArray:optionSwitcher.optionStates];
  for (NSString *state in prevStates) {
    NSString *updatedState;
    NSArray<NSString *> *optionGroup = [optionSwitcher.switcher allKeysForObject:state];
    for (NSString *option in optionGroup) {
      if (rime_get_api()->get_option(_session, option.UTF8String)) {
        updatedState = option;
        break;
      }
    }
    updatedState = updatedState ? : [@"!" stringByAppendingString:optionGroup[0]];
    if (![updatedState isEqualToString:state]) {
      for (NSString *option in optionGroup) {
        switcher[option] = updatedState;
      }
    }
  }
  [optionSwitcher updateSwitcher:switcher];
  [NSApp.squirrelAppDelegate.panel setOptionSwitcher:optionSwitcher];
}

- (void)rimeUpdate
{
  //NSLog(@"rimeUpdate");
  [self rimeConsumeCommittedText];

  RIME_STRUCT(RimeStatus, status);
  if (rime_get_api()->get_status(_session, &status)) {
    // enable schema specific ui style
    if ((!_schemaId || strcmp(_schemaId.UTF8String, status.schema_id))) {
      _schemaId = @(status.schema_id);
      _showingSwitcherMenu = rime_get_api()->get_option(_session, "dumb");
      if (!_showingSwitcherMenu) {
        [self updateStyleOptions];
        [NSApp.squirrelAppDelegate loadSchemaSpecificLabels:_schemaId];
        [NSApp.squirrelAppDelegate loadSchemaSpecificSettings:_schemaId];
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
    // update raw input
    const char *raw_input = rime_get_api()->get_input(_session);
    [_originalString setString:raw_input ? @(raw_input) : @""];

    // update preedit text
    const char *preedit = ctx.composition.preedit;
    NSString *preeditText = preedit ? @(preedit) : @"";

    NSUInteger start = [[NSString alloc] initWithBytes:preedit length:(NSUInteger)ctx.composition.sel_start encoding:NSUTF8StringEncoding].length;
    NSUInteger end = [[NSString alloc] initWithBytes:preedit length:(NSUInteger)ctx.composition.sel_end encoding:NSUTF8StringEncoding].length;
    NSUInteger caretPos = [[NSString alloc] initWithBytes:preedit length:(NSUInteger)ctx.composition.cursor_pos encoding:NSUTF8StringEncoding].length;
    NSUInteger length = [[NSString alloc] initWithBytes:preedit length:(NSUInteger)ctx.composition.length encoding:NSUTF8StringEncoding].length;
    NSUInteger numCandidate = (NSUInteger)ctx.menu.num_candidates;

    // update candidates
    NSMutableArray<NSString *> *candidates = [[NSMutableArray alloc] initWithCapacity:numCandidate];
    NSMutableArray<NSString *> *comments = [[NSMutableArray alloc] initWithCapacity:numCandidate];
    for (NSUInteger i = 0; i < numCandidate; ++i) {
      [candidates addObject:@(ctx.menu.candidates[i].text)];
      [comments addObject:@(ctx.menu.candidates[i].comment ? : "")];
    }
    [self showPanelWithPreedit:(_inlinePreedit && !_showingSwitcherMenu ? nil : preeditText)
                      selRange:NSMakeRange(start, end - start)
                      caretPos:(_showingSwitcherMenu ? NSNotFound : caretPos)
                    candidates:candidates
                      comments:comments
                   highlighted:(NSUInteger)ctx.menu.highlighted_candidate_index
                       pageNum:(NSUInteger)ctx.menu.page_no
                      lastPage:(BOOL)ctx.menu.is_last_page];

    if (!_showingSwitcherMenu) {
      if (_inlineCandidate) {
        const char *candidatePreview = ctx.commit_text_preview;
        NSString *candidatePreviewText = candidatePreview ? @(candidatePreview) : @"";
        if (_inlinePreedit) {
          if ((caretPos >= end) && (caretPos < length)) {
            candidatePreviewText = [candidatePreviewText stringByAppendingString:
                                    [preeditText substringWithRange:NSMakeRange(caretPos, length - caretPos)]];
          }
          [self showPreeditString:candidatePreviewText
                         selRange:NSMakeRange(start, candidatePreviewText.length - (length - end) - start)
                         caretPos:caretPos <= start ? caretPos : candidatePreviewText.length - (length - caretPos)];
        } else {
          if ((end < caretPos) && (caretPos > start)) {
            candidatePreviewText = [candidatePreviewText substringWithRange:
                                    NSMakeRange(0, candidatePreviewText.length - (caretPos - end))];
          } else if ((end < length) && (caretPos < end)) {
            candidatePreviewText = [candidatePreviewText substringWithRange:
                                    NSMakeRange(0, candidatePreviewText.length - (length - end))];
          }
          [self showPreeditString:candidatePreviewText
                         selRange:NSMakeRange(start - (caretPos < end), candidatePreviewText.length - start + (caretPos < end))
                         caretPos:(caretPos < end ? caretPos : candidatePreviewText.length)];
        }
      } else {
        if (_inlinePreedit && !_showingSwitcherMenu) {
          [self showPreeditString:preeditText selRange:NSMakeRange(start, end - start) caretPos:caretPos];
        } else {
          [self showPreeditString:@"" selRange:NSMakeRange(0, 0) caretPos:0];
        }
      }
    }
    rime_get_api()->free_context(&ctx);
  } else {
    [self hidePalettes];
  }
}

@end // SquirrelController(Private)
