#import "SquirrelInputController.h"

#import "SquirrelDomainServer.h"
#import "SquirrelApplicationDelegate.h"
#import "SquirrelConfig.h"
#import "SquirrelPanel.h"
#import "macos_keycode.h"
#import "utf8.h"
#import <rime_api.h>
#import <rime/key_table.h>

@interface SquirrelInputController(Private)
-(void)createSession;
-(void)destroySession;
-(void)rimeConsumeCommittedText;
// -(void)rimeUpdate;
-(void)updateAppOptions;
@end

@implementation SquirrelInputController {
  id _currentClient;
  NSString *_preeditString;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray *_candidates;
  NSUInteger _lastModifier;
  NSEventType _lastEventType;
  RimeSessionId _session;
  NSString *_schemaId;
  BOOL _inlinePreedit;
  // for chord-typing
  char _chord[128];
  NSTimer *_chordTimer;
  NSTimeInterval _chordDuration;
  NSString *_currentApp;

  SquirrelDomainServer *_domainServerInstance;
}

/*!
 @method
 @abstract   Receive incoming event
 @discussion This method receives key events from the client application.
 */
- (BOOL)handleEvent:(NSEvent*)event client:(id)sender
{
  // Return YES to indicate the the key input was received and dealt with.
  // Key processing will not continue in that case.  In other words the
  // system will not deliver a key down event to the application.
  // Returning NO means the original key down will be passed on to the client.

  _currentClient = sender;

  NSUInteger modifiers = event.modifierFlags;

  BOOL handled = NO;

  @autoreleasepool {
    if (!_session || !rime_get_api()->find_session(_session)) {
      [self createSession];
      if (!_session) {
        return NO;
      }
    }

    NSString* app = [_currentClient bundleIdentifier];

    if (![_currentApp isEqualToString:app]) {
      _currentApp = [app copy];
      [self updateAppOptions];
    }

    switch (event.type) {
      case NSFlagsChanged: {
        if (_lastModifier == modifiers) {
          handled = YES;
          break;
        }
        //NSLog(@"FLAGSCHANGED client: %@, modifiers: 0x%lx", sender, modifiers);
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        int release_mask = 0;
        int changes = _lastModifier ^ modifiers;
        if (changes & OSX_CAPITAL_MASK) {
          // NOTE: rime assumes XK_Caps_Lock to be sent before modifier changes,
          // while NSFlagsChanged event has the flag changed already.
          // so it is necessary to revert kLockMask.
          rime_modifiers ^= kLockMask;
          [self processKey:XK_Caps_Lock modifiers:rime_modifiers];
        }
        if (changes & OSX_SHIFT_MASK) {
          release_mask = modifiers & OSX_SHIFT_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Shift_L
                 modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_CTRL_MASK) {
          release_mask = modifiers & OSX_CTRL_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Control_L
                 modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_ALT_MASK) {
          release_mask = modifiers & OSX_ALT_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Alt_L modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_COMMAND_MASK) {
          release_mask = modifiers & OSX_COMMAND_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Super_L
                 modifiers:(rime_modifiers | release_mask)];
          // do not update UI when using Command key
          break;
        }
        [self rimeUpdate];
      } break;
      case NSKeyDown: {
        // ignore Command+X hotkeys.
        if (modifiers & OSX_COMMAND_MASK)
          break;

        NSInteger keyCode = event.keyCode;
        NSString* keyChars = event.charactersIgnoringModifiers;
        if (!isalpha(keyChars.UTF8String[0])) {
          keyChars = event.characters;
        }
        //NSLog(@"KEYDOWN client: %@, modifiers: 0x%lx, keyCode: %ld, keyChars: [%@]",
        //      sender, modifiers, keyCode, keyChars);

        // translate osx keyevents to rime keyevents
        int rime_keycode = osx_keycode_to_rime_keycode(
          keyCode, keyChars.UTF8String[0], modifiers & OSX_SHIFT_MASK,
          modifiers & OSX_CAPITAL_MASK);
        if (rime_keycode) {
          int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
          handled = [self processKey:rime_keycode modifiers:rime_modifiers];
          [self rimeUpdate];
        }
      } break;
      case NSLeftMouseDown: {
        [self commitComposition:_currentClient];
      } break;
      default:
        break;
    }
  }

  _lastModifier = modifiers;
  _lastEventType = event.type;

  return handled;
}

-(BOOL)processKey:(int)rime_keycode modifiers:(int)rime_modifiers
{
  // TODO add special key event preprocessing here

  // in horizontal mode, arrow keys may behave differently.
  Bool is_horizontal_mode = NSApp.squirrelAppDelegate.panel.horizontal;
  if (is_horizontal_mode != rime_get_api()->get_option(_session, "_horizontal")) {
    rime_get_api()->set_option(_session, "_horizontal", is_horizontal_mode);
  }

  BOOL handled = (BOOL)rime_get_api()->process_key(_session, rime_keycode, rime_modifiers);
  //NSLog(@"rime_keycode: 0x%x, rime_modifiers: 0x%x, handled = %d", rime_keycode, rime_modifiers, handled);

  // TODO add special key event postprocessing here

  if (!handled) {
    BOOL isEmacsBackInCommandMode = rime_keycode == XK_Escape ||
      rime_keycode == XK_F17 ||
    ((rime_modifiers & kControlMask) && (rime_keycode == XK_g ));
    if (isEmacsBackInCommandMode) {
      NSString* app = [_currentClient bundleIdentifier];
      if (([app isEqualToString:@"org.gnu.Emacs"] ||
           [app isEqualToString:@"com.googlecode.iterm2"] )&&
          !rime_get_api()->get_option(_session, "ascii_mode")) {
        [self clearComposition];
        rime_get_api()->set_option(_session, "ascii_mode", True);
        NSLog(@"disable conversion to Chinese in Emacs's command mode");
      }
    }

    BOOL isVimBackInCommandMode = rime_keycode == XK_Escape ||
    ((rime_modifiers & kControlMask) && (rime_keycode == XK_c ||
                                         rime_keycode == XK_C ||
                                         rime_keycode == XK_bracketleft));
    if (isVimBackInCommandMode) {
      NSString* app = [_currentClient bundleIdentifier];
      if ([app isEqualToString:@"org.vim.MacVim"] &&
          !rime_get_api()->get_option(_session, "ascii_mode")) {
        rime_get_api()->set_option(_session, "ascii_mode", True);
        NSLog(@"disable conversion to Chinese in MacVim's command mode");
      }
    }
  }

  // Simulate key-ups for every interesting key-down for chord-typing.
  if (handled) {
    bool is_chording_key = rime_modifiers == 0 &&
        ((rime_keycode >= XK_space && rime_keycode <= XK_asciitilde) ||
         rime_keycode == XK_Tab ||
         rime_keycode == XK_BackSpace ||
         rime_keycode == XK_Return);
    if (is_chording_key &&
        rime_get_api()->get_option(_session, "_chord_typing")) {
      [self updateChord:rime_keycode];
    }
    else {
      [self clearChord];
    }
  }

  return handled;
}

static char keycode_to_char(int keycode) {
  switch (keycode) {
    case XK_Tab:
      return '\t';
    case XK_BackSpace:
      return'\b';
    case XK_Return:
      return '\n';
    default:
      return (char)keycode;
  }
}

static int char_to_keycode(char ch) {
  switch (ch) {
    case '\t':
      return XK_Tab;
    case '\b':
      return XK_BackSpace;
    case '\n':
      return XK_Return;
    default:
      return ch;
  }
}

-(void)onChordTimer:(NSTimer *)timer
{
  int processed_keys = 0;
  if (_chord[0] && _session) {
    // simulate key-ups
    for (char *p = _chord; *p; ++p) {
      if (rime_get_api()->process_key(_session, char_to_keycode(*p), kReleaseMask))
        ++processed_keys;
    }
  }
  [self clearChord];
  if (processed_keys) {
    [self rimeUpdate];
  }
}

-(void)updateChord:(int)keycode
{
  char ch = keycode_to_char(keycode);
  char *p = strchr(_chord, ch);
  if (p != NULL) {
    // just repeating
    return;
  }
  else {
    // append ch to _chord
    p = strchr(_chord, '\0');
    *p++ = ch;
    *p = '\0';
  }
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

-(void)clearChord
{
  if (_chord[0]) {
    _chord[0] = '\0';
  }
  if (_chordTimer) {
    if (_chordTimer.valid) {
      [_chordTimer invalidate];
    }
    _chordTimer = nil;
  }
}

-(NSUInteger)recognizedEvents:(id)sender
{
  //NSLog(@"recognizedEvents:");
  return NSKeyDownMask | NSFlagsChangedMask | NSLeftMouseDownMask;
}

-(void)activateServer:(id)sender
{
  //NSLog(@"activateServer:");
  if ([NSApp.squirrelAppDelegate.config getBool:@"us_keyboard_layout"]) {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];
  }
  _preeditString = @"";
  [_domainServerInstance updateLastSession:self session:_session app:_currentApp];
}

-(instancetype)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)inputClient
{
  //NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server delegate:delegate client:inputClient]) {
    _currentClient = inputClient;
    [self createSession];
  }

  _domainServerInstance=[SquirrelDomainServer sharedInstance];
  return self;
}

-(void)deactivateServer:(id)sender
{
  //NSLog(@"deactivateServer:");
  [NSApp.squirrelAppDelegate.panel hide];
  [self commitComposition:sender];
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

-(void)commitComposition:(id)sender
{
  //NSLog(@"commitComposition:");
  // The issue of address bar in Chrome does not exist anymore (version 47)
  //  - FIXME: chrome's address bar issues this callback when showing suggestions.
  /* if ([[sender bundleIdentifier] isEqualToString:@"com.google.Chrome"])
    return; */
  // force committing existing Rime composition
  if (_session && rime_get_api()->commit_composition(_session)) {
    [self rimeConsumeCommittedText];
  }
}
-(void)clearComposition
{
  if (_session) {
    rime_get_api()->clear_composition(_session);
  }

  [NSApp.squirrelAppDelegate.panel hide];
}



// a piece of comment from SunPinyin's macos wrapper says:
// > though we specified the showPrefPanel: in SunPinyinApplicationDelegate as the
// > action receiver, the IMKInputController will actually receive the event.
// so here we deliver messages to our responsible SquirrelApplicationDelegate
-(void)deploy:(id)sender
{
  [NSApp.squirrelAppDelegate deploy:sender];
}

-(void)syncUserData:(id)sender
{
  [NSApp.squirrelAppDelegate syncUserData:sender];
}

-(void)configure:(id)sender
{
  [NSApp.squirrelAppDelegate configure:sender];
}

-(void)checkForUpdates:(id)sender
{
  [NSApp.squirrelAppDelegate.updater performSelector:@selector(checkForUpdates:) withObject:sender];
}

-(void)openWiki:(id)sender
{
  [NSApp.squirrelAppDelegate openWiki:sender];
}

-(NSMenu*)menu
{
  return NSApp.squirrelAppDelegate.menu;
}

-(NSArray*)candidates:(id)sender
{
  return _candidates;
}

-(void)dealloc
{
  [self destroySession];
}

-(void)commitString:(NSString*)string
{
  //NSLog(@"commitString:");
  [_currentClient insertText:string
            replacementRange:NSMakeRange(NSNotFound, 0)];

  _preeditString = @"";

  [NSApp.squirrelAppDelegate.panel hide];
}

-(void)showPreeditString:(NSString*)preedit
                selRange:(NSRange)range
                caretPos:(NSUInteger)pos
{
  //NSLog(@"showPreeditString: '%@'", preedit);

  if ([_preeditString isEqualToString:preedit] &&
      _caretPos == pos && _selRange.location == range.location && _selRange.length == range.length)
    return;

  _preeditString = preedit;
  _selRange = range;
  _caretPos = pos;

  //NSLog(@"selRange.location = %ld, selRange.length = %ld; caretPos = %ld",
  //      range.location, range.length, pos);
  NSDictionary* attrs;
  NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:preedit];
  if (range.location > 0) {
    NSRange convertedRange = NSMakeRange(0, range.location);
    attrs = [self markForStyle:kTSMHiliteConvertedText atRange:convertedRange];
    [attrString setAttributes:attrs range:convertedRange];
  }
  {
    NSRange remainingRange = NSMakeRange(range.location, preedit.length - range.location);
    attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:remainingRange];
    [attrString setAttributes:attrs range:remainingRange];
  }
  [_currentClient setMarkedText:attrString
                 selectionRange:NSMakeRange(pos, 0)
               replacementRange:NSMakeRange(NSNotFound, 0)];

}

-(void)showPanelWithPreedit:(NSString*)preedit
                   selRange:(NSRange)selRange
                   caretPos:(NSUInteger)caretPos
                 candidates:(NSArray*)candidates
                   comments:(NSArray*)comments
                     labels:(NSString*)labels
                highlighted:(NSUInteger)index
{
  //NSLog(@"showPanelWithPreedit:...:");
  _candidates = candidates;
  NSRect inputPos;
  [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&inputPos];
  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  panel.position = inputPos;
  [panel showPreedit:preedit
            selRange:selRange
            caretPos:caretPos
          candidates:candidates
            comments:comments
              labels:labels
         highlighted:index];
}
-(void)rimeUpdate
{
  //NSLog(@"rimeUpdate");
  [self rimeConsumeCommittedText];

  RIME_STRUCT(RimeStatus, status);
  if (rime_get_api()->get_status(_session, &status)) {
    // enable schema specific ui style
    if (!_schemaId || strcmp(_schemaId.UTF8String, status.schema_id) != 0) {
      _schemaId = @(status.schema_id);
      [NSApp.squirrelAppDelegate loadSchemaSpecificSettings:_schemaId];
      // inline preedit
      _inlinePreedit = NSApp.squirrelAppDelegate.panel.inlinePreedit &&
          !rime_get_api()->get_option(_session, "no_inline");  // not disabled in app options
      // if not inline, embed soft cursor in preedit string
      rime_get_api()->set_option(_session, "soft_cursor", !_inlinePreedit);
    }
    rime_get_api()->free_status(&status);
  }

  RIME_STRUCT(RimeContext, ctx);
  if (rime_get_api()->get_context(_session, &ctx)) {
    // update preedit text
    const char *preedit = ctx.composition.preedit;
    NSString *preeditText = preedit ? @(preedit) : @"";

    NSUInteger start = utf8len(preedit, ctx.composition.sel_start);
    NSUInteger end = utf8len(preedit, ctx.composition.sel_end);
    NSUInteger caretPos = utf8len(preedit, ctx.composition.cursor_pos);
    NSRange selRange = NSMakeRange(start, end - start);
    if (_inlinePreedit) {
      [self showPreeditString:preeditText selRange:selRange caretPos:caretPos];
    }
    else {
      NSRange empty = {0, 0};
      // TRICKY: display a non-empty string to prevent iTerm2 from echoing each character in preedit.
      // note this is a full-shape space U+3000; using half shape characters like "..." will result in
      // an unstable baseline when composing Chinese characters.
      [self showPreeditString:(preedit ? @"　" : @"") selRange:empty caretPos:0];
    }
    // update candidates
    NSMutableArray *candidates = [NSMutableArray array];
    NSMutableArray *comments = [NSMutableArray array];
    NSUInteger i;
    for (i = 0; i < ctx.menu.num_candidates; ++i) {
      [candidates addObject:@(ctx.menu.candidates[i].text)];
      if (ctx.menu.candidates[i].comment) {
        [comments addObject:@(ctx.menu.candidates[i].comment)];
      }
      else {
        [comments addObject:@""];
      }
    }
    NSString* labels = @"";
    if (ctx.menu.select_keys) {
      labels = @(ctx.menu.select_keys);
    }
    [self showPanelWithPreedit:(_inlinePreedit ? nil : preeditText)
                      selRange:selRange
                      caretPos:caretPos
                    candidates:candidates
                      comments:comments
                        labels:labels
                   highlighted:ctx.menu.highlighted_candidate_index];
    rime_get_api()->free_context(&ctx);
  } else {
    [NSApp.squirrelAppDelegate.panel hide];
  }
}

@end // SquirrelController


// implementation of private interface
@implementation SquirrelInputController(Private)

-(void)createSession
{
  NSString* app = [_currentClient bundleIdentifier];
  NSLog(@"createSession: %@", app);
  _currentApp = [app copy];
  _session = rime_get_api()->create_session();

  _schemaId = nil;

  if (_session) {
    [self updateAppOptions];
  }
}

-(void)updateAppOptions
{
  if (!_currentApp)
    return;
  SquirrelAppOptions* appOptions = [NSApp.squirrelAppDelegate.config getAppOptions:_currentApp];
  if (appOptions) {
    for (NSString* key in appOptions) {
      BOOL value = appOptions[key].boolValue;
      NSLog(@"set app option: %@ = %d", key, value);
      rime_get_api()->set_option(_session, key.UTF8String, value);
    }
  }
}

-(void)destroySession
{
  //NSLog(@"destroySession:");
  if (_session) {
    rime_get_api()->destroy_session(_session);
    [_domainServerInstance destroySession:_session];
    _session = 0;
  }
  [self clearChord];
}

-(void)rimeConsumeCommittedText
{
  RIME_STRUCT(RimeCommit, commit);
  if (rime_get_api()->get_commit(_session, &commit)) {
    NSString *commitText = @(commit.text);
    [self commitString: commitText];
    rime_get_api()->free_commit(&commit);
  }
}


@end // SquirrelController(Private)
