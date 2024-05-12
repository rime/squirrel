#import "SquirrelInputController.hh"

#import "SquirrelApplicationDelegate.hh"
#import "SquirrelConfig.hh"
#import "SquirrelPanel.hh"
#import "macos_keycode.hh"
#import <rime_api.h>
#import <rime/key_table.h>

__attribute__((objc_direct_members))
@interface SquirrelInputController (Private)
- (void)createSession;
- (void)destroySession;
- (BOOL)rimeConsumeCommittedText;
- (void)rimeUpdate;
- (void)updateCandidate:(RimeCandidate*)candidate atIndex:(NSUInteger)index;
@end

static NSString* const kFullWidthSpace = @"　";
static const int N_KEY_ROLL_OVER = 50;

@implementation SquirrelInputController {
  NSMutableAttributedString* _inlineString;
  NSString* _originalString;
  NSString* _composedString;
  NSString* _schemaId;
  NSRange _selRange;
  NSRange _candidateIndices;
  NSRange _inlineSelRange;
  NSUInteger _inlineCaretPos;
  NSUInteger _currentIndex;
  NSEventModifierFlags _lastModifiers;
  NSEventType _lastEventType;
  uint _lastEventCount;
  RimeSessionId _session;
  BOOL _inlinePreedit;
  BOOL _inlineCandidate;
  BOOL _goodOldCapsLock;
  BOOL _showingSwitcherMenu;
  // app-specific options
  SquirrelAppOptions* _appOptions;
  // for chord-typing
  NSTimer* _chordTimer;
  NSTimeInterval _chordDuration;
  int _chordKeyCodes[N_KEY_ROLL_OVER];
  int _chordModifiers[N_KEY_ROLL_OVER];
  int _chordKeyCount;
}

static SquirrelInputController __weak* _currentController = nil;
static NSString* _currentApp;
static Bool _asciiMode = -1;

+ (void)setCurrentController:(SquirrelInputController*)controller {
  _currentController = controller;
  NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
}

+ (SquirrelInputController*)currentController {
  return _currentController;
}

- (NSAppearance*)viewEffectiveAppearance API_AVAILABLE(macos(10.14)) {
  return [self.client performSelector:@selector(viewEffectiveAppearance)]
             ?: NSApp.effectiveAppearance;
}

+ (NSSet<NSString*>*)keyPathsForValuesAffectingViewEffectiveAppearance {
  return [NSSet setWithObjects:@"client.viewEffectiveAppearance", nil];
}

/*!
 @method
 @abstract   Receive incoming event
 @discussion This method receives key events from the client application.
 */
- (BOOL)handleEvent:(NSEvent*)event client:(id)sender {
  // Return YES to indicate the the key input was received and dealt with.
  // Key processing will not continue in that case.  In other words the
  // system will not deliver a key down event to the application.
  // Returning NO means the original key down will be passed on to the client.
  NSEventModifierFlags modifiers = event.modifierFlags;
  BOOL handled = NO;

  @autoreleasepool {
    if (_session == 0 || !rime_get_api()->find_session(_session)) {
      [self createSession];
      if (_session == 0) {
        return NO;
      }
    }

    NSString* app = [sender bundleIdentifier];
    if (![_currentApp isEqualToString:app]) {
      _currentApp = app.copy;
      _appOptions = [NSApp.squirrelAppDelegate.config getAppOptions:app];
    }
    int rime_modifiers = rime_modifiers_from_mac_modifiers(modifiers);
    ushort keyCode = (ushort)CGEventGetIntegerValueField(
        event.CGEvent, kCGKeyboardEventKeycode);

    switch (event.type) {
      case NSEventTypeFlagsChanged: {
        if (_lastModifiers == modifiers) {
          return YES;
        }
        // NSLog(@"FLAGSCHANGED client: %@, modifiers: 0x%lx", sender,
        // modifiers);
        int release_mask = 0;
        int rime_keycode = rime_keycode_from_mac_keycode(keyCode);
        NSUInteger changes = _lastModifiers ^ modifiers;
        if (changes & NSEventModifierFlagCapsLock) {
          // NOTE: rime assumes XK_Caps_Lock to be sent before modifier changes,
          // while NSFlagsChanged event has the flag changed already.
          // so it is necessary to revert kLockMask.
          rime_modifiers ^= kLockMask;
          [self processKey:rime_keycode modifiers:rime_modifiers];
        }
        if (changes & NSEventModifierFlagShift) {
          release_mask =
              modifiers & NSEventModifierFlagShift ? 0 : kReleaseMask;
          [self processKey:rime_keycode
                 modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & NSEventModifierFlagControl) {
          release_mask =
              modifiers & NSEventModifierFlagControl ? 0 : kReleaseMask;
          [self processKey:rime_keycode
                 modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & NSEventModifierFlagOption) {
          release_mask =
              modifiers & NSEventModifierFlagOption ? 0 : kReleaseMask;
          [self processKey:rime_keycode
                 modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & NSEventModifierFlagCommand) {
          release_mask =
              modifiers & NSEventModifierFlagCommand ? 0 : kReleaseMask;
          [self processKey:rime_keycode
                 modifiers:(rime_modifiers | release_mask)];
          // do not update UI when using Command key
          break;
        }
        [self rimeUpdate];
      } break;
      case NSEventTypeKeyDown: {
        // NSLog(@"KEYDOWN client: %@, modifiers: 0x%lx, keyCode: %d, keyChars:
        // [%@]",
        //       sender, modifiers, keyCode, keyChars);
        //  translate mac keydown events to rime keyevents
        int rime_keycode = rime_keycode_from_mac_keycode(keyCode);
        if (rime_keycode == 0) {
          NSString* keyChars = ((modifiers & NSEventModifierFlagShift) &&
                                !(modifiers & (NSEventModifierFlagControl |
                                               NSEventModifierFlagOption)))
                                   ? event.characters
                                   : event.charactersIgnoringModifiers;
          keyChars = keyChars.precomposedStringWithCanonicalMapping;
          rime_keycode = rime_keycode_from_keychar(
              [keyChars characterAtIndex:0],
              (modifiers & NSEventModifierFlagShift) != 0,
              (modifiers & NSEventModifierFlagCapsLock) != 0);
        }
        if (rime_keycode != 0) {
          if ((handled = [self processKey:rime_keycode
                                modifiers:rime_modifiers])) {
            [self rimeUpdate];
          }
        }
      } break;
      default:
        break;
    }
  }

  _lastModifiers = modifiers;
  _lastEventType = event.type;

  return handled;
}

- (BOOL)mouseDownOnCharacterIndex:(NSUInteger)index
                       coordinate:(NSPoint)point
                     withModifier:(NSUInteger)flags
                 continueTracking:(BOOL*)keepTracking
                           client:(id)sender {
  *keepTracking = NO;
  @autoreleasepool {
    if ((!_inlinePreedit && !_inlineCandidate) || _composedString.length == 0 ||
        _inlineCaretPos == index ||
        (flags & NSEventModifierFlagDeviceIndependentFlagsMask)) {
      return NO;
    }
    NSRange markedRange = [sender markedRange];
    NSPoint head =
        [[sender attributesForCharacterIndex:0
                         lineHeightRectangle:NULL][@"IMKBaseline"] pointValue];
    NSPoint tail =
        [[sender attributesForCharacterIndex:markedRange.length - 1
                         lineHeightRectangle:NULL][@"IMKBaseline"] pointValue];
    if (point.x > tail.x || index >= markedRange.length) {
      if (_inlineCandidate && !_inlinePreedit) {
        return NO;
      }
      [self performAction:kPROCESS onIndex:kEndKey];
    } else if (point.x < head.x || index <= 0) {
      [self performAction:kPROCESS onIndex:kHomeKey];
    } else {
      [self moveCursor:_inlineCaretPos
               toPosition:index
            inlinePreedit:_inlinePreedit
          inlineCandidate:_inlineCandidate];
    }
    return YES;
  }
}

- (BOOL)processKey:(int)rime_keycode
         modifiers:(int)rime_modifiers __attribute__((objc_direct)) {
  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  // with linear candidate list, arrow keys may behave differently.
  bool is_linear = panel.linear;
  if (is_linear != rime_get_api()->get_option(_session, "_linear")) {
    rime_get_api()->set_option(_session, "_linear", is_linear);
  }
  // with vertical text, arrow keys may behave differently.
  bool is_vertical = panel.vertical;
  if (is_vertical != rime_get_api()->get_option(_session, "_vertical")) {
    rime_get_api()->set_option(_session, "_vertical", is_vertical);
  }

  if (panel.tabular && !rime_modifiers && panel.visible &&
      (is_vertical
           ? rime_keycode == XK_Left || rime_keycode == XK_KP_Left ||
                 rime_keycode == XK_Right || rime_keycode == XK_KP_Right
           : rime_keycode == XK_Up || rime_keycode == XK_KP_Up ||
                 rime_keycode == XK_Down || rime_keycode == XK_KP_Down)) {
    if (rime_keycode >= XK_KP_Left && rime_keycode <= XK_KP_Down) {
      rime_keycode = rime_keycode - XK_KP_Left + XK_Left;
    }
    NSUInteger newIndex =
        [panel candidateIndexOnDirection:(SquirrelIndex)rime_keycode];
    if (newIndex != NSNotFound) {
      if (!panel.locked && !panel.expanded &&
          rime_keycode == (is_vertical ? XK_Left : XK_Down)) {
        panel.expanded = YES;
      }
      rime_get_api()->highlight_candidate(_session, newIndex);
      return YES;
    } else if (!panel.locked && panel.expanded && panel.sectionNum == 0 &&
               rime_keycode == (is_vertical ? XK_Right : XK_Up)) {
      panel.expanded = NO;
      return YES;
    }
  }

  bool handled =
      rime_get_api()->process_key(_session, rime_keycode, rime_modifiers);
  // NSLog(@"rime_keycode: 0x%x, rime_modifiers: 0x%x, handled = %d",
  // rime_keycode, rime_modifiers, handled);

  // TODO add special key event postprocessing here

  if (!handled) {
    BOOL isVimBackInCommandMode =
        rime_keycode == XK_Escape ||
        ((rime_modifiers & kControlMask) &&
         (rime_keycode == XK_c || rime_keycode == XK_C ||
          rime_keycode == XK_bracketleft));
    if (isVimBackInCommandMode &&
        rime_get_api()->get_option(_session, "vim_mode") &&
        !rime_get_api()->get_option(_session, "ascii_mode")) {
      [self cancelComposition];
      rime_get_api()->set_option(_session, "ascii_mode", True);
      // NSLog(@"turned Chinese mode off in vim-like editor's command mode");
      return YES;
    }
  }

  // Simulate key-ups for every interesting key-down for chord-typing.
  if (handled) {
    BOOL is_chording_key =
        (rime_keycode >= XK_space && rime_keycode <= XK_asciitilde) ||
        rime_keycode == XK_Control_L || rime_keycode == XK_Control_R ||
        rime_keycode == XK_Alt_L || rime_keycode == XK_Alt_R ||
        rime_keycode == XK_Shift_L || rime_keycode == XK_Shift_R;
    if (is_chording_key &&
        rime_get_api()->get_option(_session, "_chord_typing")) {
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
    inlineCandidate:(BOOL)inlineCandidate __attribute__((objc_direct));
{
  BOOL vertical = NSApp.squirrelAppDelegate.panel.vertical;
  @autoreleasepool {
    NSString* composition = !inlinePreedit && !inlineCandidate
                                ? _composedString
                                : _inlineString.string;
    RIME_STRUCT(RimeContext, ctx);
    if (cursorPosition > targetPosition) {
      NSString* targetPrefix = [[composition substringToIndex:targetPosition]
          stringByReplacingOccurrencesOfString:@" "
                                    withString:@""];
      NSString* prefix = [[composition substringToIndex:cursorPosition]
          stringByReplacingOccurrencesOfString:@" "
                                    withString:@""];
      while (targetPrefix.length < prefix.length) {
        rime_get_api()->process_key(_session, vertical ? XK_Up : XK_Left,
                                    kControlMask);
        rime_get_api()->get_context(_session, &ctx);
        if (inlineCandidate) {
          size_t length =
              ctx.composition.cursor_pos < ctx.composition.sel_end
                  ? (size_t)ctx.composition.cursor_pos
                  : strlen(ctx.commit_text_preview) -
                        (inlinePreedit ? 0
                                       : (size_t)(ctx.composition.cursor_pos -
                                                  ctx.composition.sel_end));
          prefix = [[NSString.alloc initWithBytes:ctx.commit_text_preview
                                           length:length
                                         encoding:NSUTF8StringEncoding]
              stringByReplacingOccurrencesOfString:@" "
                                        withString:@""];
        } else {
          prefix = [[NSString.alloc
              initWithBytes:ctx.composition.preedit
                     length:(NSUInteger)ctx.composition.cursor_pos
                   encoding:NSUTF8StringEncoding]
              stringByReplacingOccurrencesOfString:@" "
                                        withString:@""];
        }
        rime_get_api()->free_context(&ctx);
      }
    } else if (cursorPosition < targetPosition) {
      NSString* targetSuffix = [[composition substringFromIndex:targetPosition]
          stringByReplacingOccurrencesOfString:@" "
                                    withString:@""];
      NSString* suffix = [[composition substringFromIndex:cursorPosition]
          stringByReplacingOccurrencesOfString:@" "
                                    withString:@""];
      while (targetSuffix.length < suffix.length) {
        rime_get_api()->process_key(_session, vertical ? XK_Down : XK_Right,
                                    kControlMask);
        rime_get_api()->get_context(_session, &ctx);
        suffix = [@(ctx.composition.preedit + ctx.composition.cursor_pos +
                    (!inlinePreedit && !inlineCandidate ? 3 : 0))
            stringByReplacingOccurrencesOfString:@" "
                                      withString:@""];
        rime_get_api()->free_context(&ctx);
      }
    }
  }
  [self rimeUpdate];
}

- (void)performAction:(SquirrelAction)action
              onIndex:(SquirrelIndex)index __attribute__((objc_direct)) {
  // NSLog(@"perform action: %lu on index: %lu", action, index);
  bool handled = false;
  switch (action) {
    case kPROCESS:
      if (index >= 0xff08 && index <= 0xffff) {
        handled = rime_get_api()->process_key(_session, (int)index, 0);
      } else if (index >= kExpandButton && index <= kLockButton) {
        handled = true;
        _currentIndex = NSNotFound;
      }
      break;
    case kSELECT:
      handled = rime_get_api()->select_candidate(_session, index);
      break;
    case kHIGHLIGHT:
      handled = rime_get_api()->highlight_candidate(_session, index);
      _currentIndex = NSNotFound;
      break;
    case kDELETE:
      handled = rime_get_api()->delete_candidate(_session, index);
      break;
  }
  if (handled) {
    [self rimeUpdate];
  }
}

- (void)onChordTimer:(NSTimer*)timer {
  // chord release triggered by timer
  int processed_keys = 0;
  if (_chordKeyCount > 0 && _session != 0) {
    // simulate key-ups
    for (int i = 0; i < _chordKeyCount; ++i) {
      if (rime_get_api()->process_key(_session, _chordKeyCodes[i],
                                      (_chordModifiers[i] | kReleaseMask)))
        ++processed_keys;
    }
  }
  [self clearChord];
  if (processed_keys) {
    [self rimeUpdate];
  }
}

- (void)updateChord:(int)keycode
          modifiers:(int)modifiers __attribute__((objc_direct)) {
  // NSLog(@"update chord: {%s} << %x", _chord, keycode);
  for (int i = 0; i < _chordKeyCount; ++i) {
    if (_chordKeyCodes[i] == keycode)
      return;
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
  NSNumber* duration = [NSApp.squirrelAppDelegate.config
      getOptionalDoubleForOption:@"chord_duration"];
  if (duration.doubleValue > 0) {
    _chordDuration = duration.doubleValue;
  }
  _chordTimer = [NSTimer scheduledTimerWithTimeInterval:_chordDuration
                                                 target:self
                                               selector:@selector(onChordTimer:)
                                               userInfo:nil
                                                repeats:NO];
}

- (void)clearChord __attribute__((objc_direct)) {
  _chordKeyCount = 0;
  if (_chordTimer.valid) {
    [_chordTimer invalidate];
    _chordTimer = nil;
  }
}

- (NSUInteger)recognizedEvents:(id)sender {
  // NSLog(@"recognizedEvents:");
  return NSEventMaskKeyDown | NSEventMaskFlagsChanged |
         NSEventMaskLeftMouseDown;
}

static NSString* getOptionLabel(RimeSessionId session,
                                const char* option,
                                bool state) {
  if (RimeStringSlice short_label = rime_get_api()->get_state_label_abbreviated(
          session, option, state, true);
      short_label.str != NULL &&
      short_label.length >= strlen(short_label.str)) {
    return @(short_label.str);
  } else {
    RimeStringSlice long_label = rime_get_api()->get_state_label_abbreviated(
        session, option, state, false);
    NSString* label = @(long_label.str ?: nil);
    return [label
        substringWithRange:[label rangeOfComposedCharacterSequenceAtIndex:0]];
  }
}

- (void)showInitialStatus __attribute__((objc_direct)) {
  RIME_STRUCT(RimeStatus, status);
  if (_session != 0 && rime_get_api()->get_status(_session, &status)) {
    _schemaId = @(status.schema_id);
    NSString* schemaName =
        status.schema_name ? @(status.schema_name) : @(status.schema_id);
    NSMutableArray<NSString*>* options =
        [NSMutableArray.alloc initWithCapacity:3];
    if (NSString* asciiMode =
            getOptionLabel(_session, "ascii_mode", status.is_ascii_mode)) {
      [options addObject:asciiMode];
    }
    if (NSString* fullShape =
            getOptionLabel(_session, "full_shape", status.is_full_shape)) {
      [options addObject:fullShape];
    }
    if (NSString* asciiPunct =
            getOptionLabel(_session, "ascii_punct", status.is_ascii_punct)) {
      [options addObject:asciiPunct];
    }
    rime_get_api()->free_status(&status);
    NSString* foldedOptions =
        options.count == 0
            ? schemaName
            : [NSString
                  stringWithFormat:@"%@｜%@", schemaName,
                                   [options componentsJoinedByString:@" "]];
    [NSApp.squirrelAppDelegate.panel updateStatusLong:foldedOptions
                                          statusShort:schemaName];
    if (@available(macOS 14.0, *)) {
      _lastModifiers |= NSEventModifierFlagHelp;
    }
    [self rimeUpdate];
  }
}

- (void)activateServer:(id)sender {
  // NSLog(@"activateServer:");
  [SquirrelInputController setCurrentController:self];
  [self addObserver:NSApp.squirrelAppDelegate.panel
         forKeyPath:@"viewEffectiveAppearance"
            options:NSKeyValueObservingOptionNew |
                    NSKeyValueObservingOptionInitial
            context:nil];

  NSString* keyboardLayout =
      [NSApp.squirrelAppDelegate.config getStringForOption:@"keyboard_layout"];
  if ([@"last" caseInsensitiveCompare:keyboardLayout] == NSOrderedSame ||
      [keyboardLayout isEqualToString:@""]) {
    keyboardLayout = nil;
  } else if ([@"default" caseInsensitiveCompare:keyboardLayout] ==
             NSOrderedSame) {
    keyboardLayout = @"com.apple.keylayout.ABC";
  } else if (![keyboardLayout hasPrefix:@"com.apple.keylayout."]) {
    keyboardLayout =
        [@"com.apple.keylayout." stringByAppendingString:keyboardLayout];
  }
  if (keyboardLayout != nil) {
    [sender overrideKeyboardWithKeyboardNamed:keyboardLayout];
  }

  SquirrelConfig* defaultConfig = SquirrelConfig.alloc.init;
  if ([defaultConfig openWithConfigId:@"default"] &&
      [defaultConfig hasSection:@"ascii_composer"]) {
    _goodOldCapsLock =
        [defaultConfig getBoolForOption:@"ascii_composer/good_old_caps_lock"];
  }
  [defaultConfig close];
  if (!NSApp.squirrelAppDelegate.isCurrentInputMethod) {
    NSApp.squirrelAppDelegate.isCurrentInputMethod = YES;
    if (NSApp.squirrelAppDelegate.showNotifications ==
        kShowNotificationsAlways) {
      [self showInitialStatus];
    }
  }

  _lastModifiers = 0;
  _lastEventCount = 0;
  NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
  [super activateServer:sender];
}

- (instancetype)initWithServer:(IMKServer*)server
                      delegate:(id)delegate
                        client:(id)inputClient {
  // NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server
                          delegate:delegate
                            client:inputClient]) {
    [self createSession];
    _candidateTexts = NSMutableArray.alloc.init;
    _candidateComments = NSMutableArray.alloc.init;
  }
  return self;
}

- (void)deactivateServer:(id)sender {
  // NSLog(@"deactivateServer:");
  _asciiMode = rime_get_api()->get_option(_session, "ascii_mode");
  [self commitComposition:sender];
  [self removeObserver:NSApp.squirrelAppDelegate.panel
            forKeyPath:@"viewEffectiveAppearance"];
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
  // NSLog(@"commitComposition:");
  [self commitString:[self composedString:sender]];
  if (_session != 0) {
    rime_get_api()->clear_composition(_session);
  }
  [self hidePalettes];
}

- (void)clearBuffer __attribute__((objc_direct)) {
  NSApp.squirrelAppDelegate.panel.IbeamRect = NSZeroRect;
  _inlineString = nil;
  _originalString = nil;
  _composedString = nil;
}

// a piece of comment from SunPinyin's macos wrapper says:
// > though we specified the showPrefPanel: in SunPinyinApplicationDelegate as
// the > action receiver, the IMKInputController will actually receive the
// event. so here we deliver messages to our responsible
// SquirrelApplicationDelegate
- (void)showSwitcher:(id)sender {
  [NSApp.squirrelAppDelegate showSwitcher:@(_session)];
  [self rimeUpdate];
}

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

- (NSMenu*)menu {
  return NSApp.squirrelAppDelegate.menu;
}

- (NSAttributedString*)originalString:(id)sender {
  return [NSAttributedString.alloc initWithString:_originalString];
}

- (id)composedString:(id)sender {
  return [_composedString stringByReplacingOccurrencesOfString:@" "
                                                    withString:@""];
}

- (NSArray*)candidates:(id)sender {
  return [_candidateTexts subarrayWithRange:_candidateIndices];
}

- (void)hidePalettes {
  [NSApp.squirrelAppDelegate.panel hide];
  if (_session) {
    rime_get_api()->clear_composition(_session);
  }
  [super hidePalettes];
}

- (void)dealloc {
  // NSLog(@"dealloc");
  [self destroySession];
  [self clearBuffer];
}

- (NSRange)selectionRange {
  return NSMakeRange(_inlineCaretPos, 0);
}

- (NSRange)replacementRange {
  return NSMakeRange(NSNotFound, NSNotFound);
}

- (void)commitString:(id)string {
  // NSLog(@"commitString:");
  if (string != nil) {
    [self.client insertText:string
           replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  }
  [self clearBuffer];
}

- (void)cancelComposition {
  [self commitString:[self originalString:self.client]];
  [self hidePalettes];
  if (_session != 0) {
    rime_get_api()->clear_composition(_session);
  }
}

- (void)updateComposition {
  [self.client setMarkedText:_inlineString
              selectionRange:NSMakeRange(_inlineCaretPos, 0)
            replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)showInlineString:(NSString*)inlineString
            withSelRange:(NSRange)selRange
                caretPos:(NSUInteger)caretPos __attribute__((objc_direct)) {
  // NSLog(@"showPreeditString: '%@'", preedit);
  if (caretPos == _inlineCaretPos && NSEqualRanges(selRange, _inlineSelRange) &&
      [inlineString isEqualToString:_inlineString.string]) {
    return;
  }
  _inlineSelRange = selRange;
  _inlineCaretPos = caretPos;
  // NSLog(@"selRange.location = %ld, selRange.length = %ld; caretPos = %ld",
  //       range.location, range.length, pos);
  NSDictionary* attrs = [self markForStyle:kTSMHiliteRawText
                                   atRange:NSMakeRange(0, inlineString.length)];
  _inlineString = [NSMutableAttributedString.alloc initWithString:inlineString
                                                       attributes:attrs];
  if (selRange.location > 0) {
    [_inlineString
        addAttributes:[self markForStyle:kTSMHiliteConvertedText
                                 atRange:NSMakeRange(0, selRange.location)]
                range:NSMakeRange(0, selRange.location)];
  }
  if (selRange.location < caretPos) {
    [_inlineString addAttributes:[self markForStyle:kTSMHiliteSelectedRawText
                                            atRange:selRange]
                           range:selRange];
  }
  [self updateComposition];
}

- (CGRect)getIbeamRect __attribute__((objc_direct)) {
  NSRect IbeamRect = NSZeroRect;
  [self.client attributesForCharacterIndex:0 lineHeightRectangle:&IbeamRect];
  if (NSEqualRects(IbeamRect, NSZeroRect) && _inlineString.length == 0) {
    if (self.client.selectedRange.length == 0) {
      // activate inline session, in e.g. table cells, by fake inputs
      [self.client setMarkedText:@" "
                  selectionRange:NSMakeRange(0, 0)
                replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
      [self.client attributesForCharacterIndex:0
                           lineHeightRectangle:&IbeamRect];
      [self.client setMarkedText:@""
                  selectionRange:NSMakeRange(0, 0)
                replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    } else {
      [self.client
          attributesForCharacterIndex:self.client.selectedRange.location
                  lineHeightRectangle:&IbeamRect];
    }
  }
  if (NSIsEmptyRect(IbeamRect)) {
    return IbeamRect;
  }
  if (@available(
          macOS 14.0, *)) {  // avoid overlapping with cursor effects view
    if (_goodOldCapsLock && (_lastModifiers & NSEventModifierFlagCapsLock)) {
      _lastModifiers &= ~NSEventModifierFlagHelp;
      NSRect screenRect = NSScreen.mainScreen.frame;
      if (NSIntersectsRect(IbeamRect, screenRect)) {
        screenRect = NSScreen.mainScreen.visibleFrame;
        if (NSWidth(IbeamRect) > NSHeight(IbeamRect)) {
          NSRect capslockAccessory =
              NSMakeRect(NSMinX(IbeamRect) - 30, NSMinY(IbeamRect), 27,
                         NSHeight(IbeamRect));
          if (NSMinX(capslockAccessory) < NSMinX(screenRect)) {
            capslockAccessory.origin.x = NSMinX(screenRect);
          }
          if (NSMaxX(capslockAccessory) > NSMaxX(screenRect)) {
            capslockAccessory.origin.x =
                NSMaxX(screenRect) - NSWidth(capslockAccessory);
          }
          IbeamRect = NSUnionRect(IbeamRect, capslockAccessory);
        } else {
          NSRect capslockAccessory =
              NSMakeRect(NSMinX(IbeamRect), NSMinY(IbeamRect) - 26,
                         NSWidth(IbeamRect), 23);
          if (NSMinY(capslockAccessory) < NSMinY(screenRect)) {
            capslockAccessory.origin.y = NSMaxY(screenRect) + 3;
          }
          if (NSMaxY(capslockAccessory) > NSMaxY(screenRect)) {
            capslockAccessory.origin.y =
                NSMaxY(screenRect) - NSHeight(capslockAccessory);
          }
          IbeamRect = NSUnionRect(IbeamRect, capslockAccessory);
        }
      }
    }
  }
  return IbeamRect;
}

- (void)showPanelWithPreedit:(NSString*)preedit
                    selRange:(NSRange)selRange
                    caretPos:(NSUInteger)caretPos
            candidateIndices:(NSRange)candidateIndices
            hilitedCandidate:(NSUInteger)hilitedCandidate
                     pageNum:(NSUInteger)pageNum
                   finalPage:(BOOL)finalPage
                  didCompose:(BOOL)didCompose __attribute__((objc_direct)) {
  // NSLog(@"showPanelWithPreedit:...:");
  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  panel.IbeamRect = [self getIbeamRect];
  if (NSIsEmptyRect(panel.IbeamRect) && panel.statusMessage.length > 0) {
    [panel updateStatusLong:nil statusShort:nil];
  } else {
    [panel showPreedit:preedit
                selRange:selRange
                caretPos:caretPos
        candidateIndices:candidateIndices
        hilitedCandidate:hilitedCandidate
                 pageNum:pageNum
               finalPage:finalPage
              didCompose:didCompose];
  }
}

@end  // SquirrelController

// implementation of private interface
@implementation SquirrelInputController (Private)

- (void)createSession {
  NSString* app = self.client.bundleIdentifier;
  // NSLog(@"createSession: %@", app);
  _session = rime_get_api()->create_session();
  _schemaId = nil;
  if (_session != 0) {
    _appOptions = [NSApp.squirrelAppDelegate.config getAppOptions:app];
    if ([app isEqualToString:_currentApp] && _asciiMode >= 0) {
      rime_get_api()->set_option(_session, "ascii_mode", _asciiMode);
    }
    _currentApp = app;
    _asciiMode = -1;
    [self rimeUpdate];
  }
}

- (void)destroySession {
  // NSLog(@"destroySession:");
  if (_session != 0) {
    rime_get_api()->destroy_session(_session);
    _session = 0;
  }
  [self clearChord];
}

- (BOOL)rimeConsumeCommittedText {
  RIME_STRUCT(RimeCommit, commit);
  if (rime_get_api()->get_commit(_session, &commit)) {
    NSString* commitText = @(commit.text);
    [self commitString:commitText];
    rime_get_api()->free_commit(&commit);
    return YES;
  }
  return NO;
}

static inline NSUInteger UTF8LengthToUTF16Length(const char* string,
                                                 int length) {
  return [NSString.alloc initWithBytes:string
                                length:(NSUInteger)length
                              encoding:NSUTF8StringEncoding]
      .length;
}

static inline NSUInteger fmin(NSUInteger x, NSUInteger y) {
  return x < y ? x : y;
}

static inline NSUInteger fmax(NSUInteger x, NSUInteger y) {
  return x < y ? y : x;
}

- (void)rimeUpdate {
  // NSLog(@"rimeUpdate");
  BOOL didCommit = self.rimeConsumeCommittedText;
  BOOL didCompose = didCommit;

  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  RIME_STRUCT(RimeStatus, status);
  if (rime_get_api()->get_status(_session, &status)) {
    // enable schema specific ui style
    if (_schemaId == nil ||
        strcmp(_schemaId.UTF8String, status.schema_id) != 0) {
      _schemaId = @(status.schema_id);
      _showingSwitcherMenu = (BOOL)rime_get_api()->get_option(_session, "dumb");
      if (!_showingSwitcherMenu) {
        [NSApp.squirrelAppDelegate loadSchemaSpecificLabels:_schemaId];
        [NSApp.squirrelAppDelegate loadSchemaSpecificSettings:_schemaId
                                              withRimeSession:_session];
        // inline preedit
        _inlinePreedit = (panel.inlinePreedit &&
                          ![_appOptions boolValueForKey:@"no_inline"]) ||
                         [_appOptions boolValueForKey:@"inline"];
        _inlineCandidate = panel.inlineCandidate &&
                           ![_appOptions boolValueForKey:@"no_inline"];
        // if not inline, embed soft cursor in preedit string
        rime_get_api()->set_option(_session, "soft_cursor", !_inlinePreedit);
      } else {
        [NSApp.squirrelAppDelegate loadSchemaSpecificLabels:@""];
      }
      didCompose = YES;
    }
    rime_get_api()->free_status(&status);
  }

  RIME_STRUCT(RimeContext, ctx);
  if (rime_get_api()->get_context(_session, &ctx)) {
    BOOL showingStatus = panel.statusMessage.length > 0;
    // update preedit text
    const char* preedit = ctx.composition.preedit;
    NSString* preeditText = @(preedit ?: "");

    // update raw input
    const char* raw_input = rime_get_api()->get_input(_session);
    NSString* originalString = @(raw_input ?: "");
    didCompose |= ![originalString isEqualToString:_originalString];
    _originalString = originalString;

    // update composed string
    if (preedit == NULL || _showingSwitcherMenu) {
      _composedString = @"";
    } else if (!_inlinePreedit) {  // remove soft cursor
      char composed[strlen(preedit) - 2];
      strlcpy(composed, preedit, (size_t)ctx.composition.cursor_pos + 1);
      strlcat(composed, preedit + ctx.composition.cursor_pos + 3,
              strlen(preedit) - 2);
      _composedString = @(composed);
    } else {
      _composedString = @(preedit);
    }

    NSUInteger start =
        UTF8LengthToUTF16Length(preedit, ctx.composition.sel_start);
    NSUInteger end = UTF8LengthToUTF16Length(preedit, ctx.composition.sel_end);
    NSUInteger caretPos =
        UTF8LengthToUTF16Length(preedit, ctx.composition.cursor_pos);
    NSUInteger length =
        UTF8LengthToUTF16Length(preedit, ctx.composition.length);
    NSUInteger numCandidates = (NSUInteger)ctx.menu.num_candidates;
    NSUInteger pageNum = (NSUInteger)ctx.menu.page_no;
    NSUInteger pageSize = (NSUInteger)ctx.menu.page_size;
    NSUInteger hilitedCandidate =
        numCandidates == 0 ? NSNotFound
                           : (NSUInteger)ctx.menu.highlighted_candidate_index;
    BOOL finalPage = (BOOL)ctx.menu.is_last_page;

    NSRange selRange = NSMakeRange(start, end - start);
    didCompose |= !NSEqualRanges(_selRange, selRange) &&
                  hilitedCandidate == 0 && pageNum == 0;
    _selRange = selRange;
    // update expander and section status in tabular layout;
    // already processed the action if _currentIndex == NSNotFound
    if (panel.tabular && !showingStatus) {
      if (numCandidates == 0 || didCompose) {
        panel.sectionNum = 0;
      } else if (_currentIndex != NSNotFound) {
        NSUInteger currentPageNum = _currentIndex / pageSize;
        if (!panel.locked && panel.expanded && panel.firstLine &&
            pageNum == 0 && hilitedCandidate == 0 && _currentIndex == 0) {
          panel.expanded = NO;
        } else if (!panel.locked && !panel.expanded &&
                   pageNum > currentPageNum) {
          panel.expanded = YES;
        }
        if (panel.expanded && pageNum > currentPageNum &&
            panel.sectionNum < (panel.vertical ? 2 : 4)) {
          panel.sectionNum =
              fmin(panel.sectionNum + pageNum - currentPageNum,
                   (finalPage ? 4UL : 3UL) - (panel.vertical ? 2UL : 0UL));
        } else if (panel.expanded && pageNum < currentPageNum &&
                   panel.sectionNum > 0) {
          panel.sectionNum = fmax(panel.sectionNum + pageNum - currentPageNum,
                                  pageNum == 0 ? 0UL : 1UL);
        }
      }
      hilitedCandidate += pageSize * panel.sectionNum;
    }
    NSUInteger extraCandidates =
        panel.expanded
            ? (finalPage ? panel.sectionNum : (panel.vertical ? 2 : 4)) *
                  pageSize
            : 0;
    _candidateIndices = NSMakeRange((pageNum - panel.sectionNum) * pageSize,
                                    numCandidates + extraCandidates);
    _currentIndex = hilitedCandidate + _candidateIndices.location;

    if (showingStatus) {
      [self clearBuffer];
    } else if (!_showingSwitcherMenu && _inlineCandidate) {
      NSString* candidatePreviewText = @(ctx.commit_text_preview ?: "");
      if (_inlinePreedit) {
        if (end <= caretPos && caretPos < length) {
          candidatePreviewText = [candidatePreviewText
              stringByAppendingString:[preeditText
                                          substringFromIndex:caretPos]];
        }
        if (!didCommit || candidatePreviewText.length > 0) {
          [self
              showInlineString:candidatePreviewText
                  withSelRange:NSMakeRange(start, candidatePreviewText.length -
                                                      (length - end) - start)
                      caretPos:caretPos < end ? caretPos
                                              : candidatePreviewText.length -
                                                    (length - caretPos)];
        }
      } else {  // preedit includes the soft cursor
        if (end < caretPos && caretPos <= length) {
          candidatePreviewText = [candidatePreviewText
              substringToIndex:candidatePreviewText.length - (caretPos - end)];
        } else if (caretPos < end && end < length) {
          candidatePreviewText = [candidatePreviewText
              substringToIndex:candidatePreviewText.length - (length - end)];
        }
        if (!didCommit || candidatePreviewText.length > 0) {
          [self showInlineString:candidatePreviewText
                    withSelRange:NSMakeRange(
                                     start, candidatePreviewText.length - start)
                        caretPos:caretPos < end ? caretPos
                                                : candidatePreviewText.length];
        }
      }
    } else if (!_showingSwitcherMenu) {
      if (_inlinePreedit) {
        if (!didCommit || preeditText.length > 0) {
          [self showInlineString:preeditText
                    withSelRange:NSMakeRange(start, end - start)
                        caretPos:caretPos];
        }
      } else {
        if (!didCommit || preedit != NULL) {
          [self showInlineString:@"" withSelRange:NSMakeRange(0, 0) caretPos:0];
        }
      }
    }

    // cache (more) candidates
    if (didCompose || numCandidates == 0) {
      [_candidateTexts removeAllObjects];
      [_candidateComments removeAllObjects];
    }
    NSUInteger index = _candidateTexts.count;
    NSUInteger endIndex = pageSize * pageNum;
    // cache candidates
    if (index < endIndex) {
      RimeCandidateListIterator iterator;
      if (rime_get_api()->candidate_list_from_index(_session, &iterator,
                                                    (int)index)) {
        while (index < endIndex &&
               rime_get_api()->candidate_list_next(&iterator)) {
          [self updateCandidate:&iterator.candidate atIndex:index++];
        }
        rime_get_api()->candidate_list_end(&iterator);
      }
    }
    if (index < pageSize * pageNum + numCandidates) {
      for (NSUInteger i = 0; i < numCandidates; ++i) {
        [self updateCandidate:&ctx.menu.candidates[i] atIndex:index++];
      }
    }
    endIndex = NSMaxRange(_candidateIndices);
    if (index < endIndex) {
      RimeCandidateListIterator iterator;
      if (rime_get_api()->candidate_list_from_index(_session, &iterator,
                                                    (int)index)) {
        while (index < endIndex &&
               rime_get_api()->candidate_list_next(&iterator)) {
          [self updateCandidate:&iterator.candidate atIndex:index++];
        }
        rime_get_api()->candidate_list_end(&iterator);
        _candidateIndices.length -= endIndex - index;
      }
    }
    // remove old candidates that were not overwritted, if any, subscripted from
    // index
    [self updateCandidate:NULL atIndex:index];

    [self showPanelWithPreedit:_inlinePreedit && !_showingSwitcherMenu
                                   ? nil
                                   : preeditText
                      selRange:selRange
                      caretPos:_showingSwitcherMenu ? NSNotFound : caretPos
              candidateIndices:_candidateIndices
              hilitedCandidate:hilitedCandidate
                       pageNum:pageNum
                     finalPage:finalPage
                    didCompose:didCompose];
    rime_get_api()->free_context(&ctx);
  } else {
    [self hidePalettes];
    [self clearBuffer];
  }
}

- (void)updateCandidate:(RimeCandidate*)candidate atIndex:(NSUInteger)index {
  if (candidate == NULL || index > _candidateTexts.count) {
    if (index < _candidateTexts.count) {
      NSRange remove = NSMakeRange(index, _candidateTexts.count - index);
      [_candidateTexts removeObjectsInRange:remove];
      [_candidateComments removeObjectsInRange:remove];
    }
    return;
  }
  if (index == _candidateTexts.count ||
      strcmp(candidate->text, _candidateTexts[index].UTF8String) != 0) {
    _candidateTexts[index] = @(candidate->text);
  }
  if (index == _candidateComments.count ||
      strcmp(candidate->comment ?: "", _candidateComments[index].UTF8String) !=
          0) {
    _candidateComments[index] = @(candidate->comment ?: "");
  }
}

@end  // SquirrelController(Private)
