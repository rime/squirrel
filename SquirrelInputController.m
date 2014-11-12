
#import "SquirrelInputController.h"
#import "SquirrelApplicationDelegate.h"
#import "macos_keycode.h"
#import "utf8.h"
#import <rime_api.h>
#import <rime/key_table.h>

// forward declaration of 'Private' category
@interface SquirrelInputController(Private)
-(void)createSession;
-(void)destroySession;
-(void)rimeConsumeCommittedText;
-(void)rimeUpdate;
-(void)updateAppOptions;
@end

// implementation of the public interface
@implementation SquirrelInputController

/*!
 @method
 @abstract   Receive incoming event
 @discussion This method receives key events from the client application.
 */
-(BOOL)handleEvent:(NSEvent*)event client:(id)sender
{
  // Return YES to indicate the the key input was received and dealt with.
  // Key processing will not continue in that case.  In other words the
  // system will not deliver a key down event to the application.
  // Returning NO means the original key down will be passed on to the client.

//  NSLog(@"handleEvent:client:");

  _currentClient = sender;
  
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (!_session || !RimeFindSession(_session)) {
    [self createSession];
    if (!_session) {
      [pool release];
      return NO;
    }
  }
  
  NSString *app = [_currentClient bundleIdentifier];
//  NSLog(@"app = %@", app);
//  NSLog(@"_currentApp = %@", _currentApp);
  
  if (![_currentApp isEqualToString:app]) {
    _currentApp = [app copy];
    [self updateAppOptions];
  }

  BOOL handled = NO;
  NSUInteger modifiers = [event modifierFlags];

  switch ([event type]) {
    case NSFlagsChanged:
      {
        if (_lastModifier == modifiers) {
          handled = YES;
          break;
        }
        //NSLog(@"FLAGSCHANGED client: %@, modifiers: 0x%lx", sender, modifiers);
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        int release_mask = 0;
        int changes = _lastModifier ^ modifiers;
        if (changes & OSX_CAPITAL_MASK)
        {
          // NOTE: rime assumes XK_Caps_Lock to be sent before modifier changes,
          // while NSFlagsChanged event has the flag changed already.
          // so it is necessary to revert kLockMask.
          rime_modifiers ^= kLockMask;
          [self processKey:XK_Caps_Lock modifiers:rime_modifiers];
        }
        if (changes & OSX_SHIFT_MASK)
        {
          release_mask = modifiers & OSX_SHIFT_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Shift_L modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_CTRL_MASK)
        {
          release_mask = modifiers & OSX_CTRL_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Control_L modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_ALT_MASK)
        {
          release_mask = modifiers & OSX_ALT_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Alt_L modifiers:(rime_modifiers | release_mask)];
        }
        if (changes & OSX_COMMAND_MASK)
        {
          release_mask = modifiers & OSX_COMMAND_MASK ? 0 : kReleaseMask;
          [self processKey:XK_Super_L modifiers:(rime_modifiers | release_mask)];
          // do not update UI when using Command key
          break;
        }
        [self rimeUpdate];
      }
      break;
    case NSKeyDown:
    {
      // ignore Command+X hotkeys.
      if (modifiers & OSX_COMMAND_MASK)
        break;

      NSInteger keyCode = [event keyCode];
      NSString* keyChars = [event charactersIgnoringModifiers];
      if (!isalpha([keyChars UTF8String][0]))
      {
        keyChars = [event characters];
      }
      //NSLog(@"KEYDOWN client: %@, modifiers: 0x%lx, keyCode: %ld, keyChars: [%@]",
      //      sender, modifiers, keyCode, keyChars);

      // translate osx keyevents to rime keyevents
      int rime_keycode = osx_keycode_to_rime_keycode(keyCode,
                                                     [keyChars UTF8String][0],
                                                     modifiers & OSX_SHIFT_MASK,
                                                     modifiers & OSX_CAPITAL_MASK);
      if (rime_keycode)
      {
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        handled = [self processKey: rime_keycode modifiers: rime_modifiers];
        [self rimeUpdate];
      }
    }
      break;
    case NSLeftMouseDown:
    {
      [self commitComposition:_currentClient];
    }
      break;
    defaults:
      break;
  }

  [pool release];

  _lastModifier = modifiers;
  _lastEventType = [event type];

  return handled;
}

-(BOOL)processKey:(int)rime_keycode modifiers:(int)rime_modifiers
{
  // TODO add special key event preprocessing here

  BOOL handled = (BOOL)RimeProcessKey(_session, rime_keycode, rime_modifiers);
  //NSLog(@"rime_keycode: 0x%x, rime_modifiers: 0x%x, handled = %d", rime_keycode, rime_modifiers, handled);

  // TODO add special key event postprocessing here

  if (!handled) {
    BOOL isVimBackInCommandMode = rime_keycode == XK_Escape ||
    ((rime_modifiers & kControlMask) && (rime_keycode == XK_c ||
                                         rime_keycode == XK_C ||
                                         rime_keycode == XK_bracketleft));
    if (isVimBackInCommandMode) {
      NSString* app = [_currentClient bundleIdentifier];
      if ([app isEqualToString:@"org.vim.MacVim"] && !RimeGetOption(_session, "ascii_mode")) {
        RimeSetOption(_session, "ascii_mode", True);
        NSLog(@"disable conversion to Chinese in MacVim's command mode");
      }
    }
  }

  // Simulate key-ups for every interesting key-down for chord-typing.
  if (handled) {
    bool is_basic_latin = rime_keycode >= XK_space && rime_keycode <= XK_asciitilde && rime_modifiers == 0;
    if (is_basic_latin && RimeGetOption(_session, "_chord_typing")) {
      [self updateChord:rime_keycode];
    }
    else {
      [self clearChord];
    }
  }

  return handled;
}

-(void)onChordTimer:(NSTimer *)timer
{
  if (_chord[0] && _session) {
    // simulate key-ups
    for (char *p = _chord; *p; ++p) {
      RimeProcessKey(_session, *p, kReleaseMask);
    }
    [self rimeUpdate];
  }
  [self clearChord];
}

-(void)updateChord:(int)ch
{
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
  if (_chordTimer && [_chordTimer isValid]) {
    [_chordTimer invalidate];
  }
  NSTimeInterval interval = [(SquirrelApplicationDelegate *)[NSApp delegate] chordDuration];
  _chordTimer = [NSTimer scheduledTimerWithTimeInterval:interval
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
    if ([_chordTimer isValid]) {
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
  if ([(SquirrelApplicationDelegate *)[NSApp delegate] useUSKeyboardLayout]) {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];
  }
  _preeditString = @"";
}

-(id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)inputClient
{
  //NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server delegate:delegate client:inputClient]) {
    _currentClient = inputClient;
    [self createSession];
  }
  return self;
}

-(void)deactivateServer:(id)sender
{
  //NSLog(@"deactivateServer:");
  [[(SquirrelApplicationDelegate *)[NSApp delegate] panel] hide];
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
  // FIXME: chrome's address bar issues this callback when showing suggestions.
  if ([[sender bundleIdentifier] isEqualToString:@"com.google.Chrome"])
    return;
  // force committing existing Rime composition
  if (_session && RimeCommitComposition(_session)) {
    [self rimeConsumeCommittedText];
  }
}

// a piece of comment from SunPinyin's macos wrapper says:
// > though we specified the showPrefPanel: in SunPinyinApplicationDelegate as the
// > action receiver, the IMKInputController will actually receive the event.
// so here we deliver messages to our responsible SquirrelApplicationDelegate
-(void)deploy:(id)sender
{
  [(SquirrelApplicationDelegate *)[NSApp delegate] deploy:sender];
}

-(void)syncUserData:(id)sender
{
  [(SquirrelApplicationDelegate *)[NSApp delegate] syncUserData:sender];
}

-(void)configure:(id)sender
{
  [(SquirrelApplicationDelegate *)[NSApp delegate] configure:sender];
}

-(void)checkForUpdates:(id)sender
{
  [[(SquirrelApplicationDelegate *)[NSApp delegate] updater] performSelector:@selector(checkForUpdates:) withObject:sender];
}

-(void)openWiki:(id)sender
{
  [(SquirrelApplicationDelegate *)[NSApp delegate] openWiki:sender];
}

-(NSMenu*)menu
{
  return [(SquirrelApplicationDelegate *)[NSApp delegate] menu];
}

-(NSArray*)candidates:(id)sender
{
  return _candidates;
}

-(void)dealloc
{
  [self destroySession];
  [_preeditString release];
  [_candidates release];
  [_schemaId release];
  [_currentApp release];
  [super dealloc];
}

-(void)commitString:(NSString*)string
{
  //NSLog(@"commitString:");
  [_currentClient insertText:string
            replacementRange:NSMakeRange(NSNotFound, 0)];

  [_preeditString release];
  _preeditString = @"";

  [[(SquirrelApplicationDelegate *)[NSApp delegate] panel] hide];
}

-(void)showPreeditString:(NSString*)preedit
                selRange:(NSRange)range
                caretPos:(NSUInteger)pos
{
  //NSLog(@"showPreeditString: '%@'", preedit);

  if ([_preeditString isEqual:preedit] &&
      _caretPos == pos && _selRange.location == range.location && _selRange.length == range.length)
    return;

  [preedit retain];
  [_preeditString release];
  _preeditString = preedit;
  _selRange = range;
  _caretPos = pos;

  //NSLog(@"selRange.location = %ld, selRange.length = %ld; caretPos = %ld", range.location, range.length, pos);
  NSDictionary* attrs;
  NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:preedit];
  if (range.location > 0) {
    NSRange convertedRange = NSMakeRange(0, range.location);
    attrs = [self markForStyle:kTSMHiliteConvertedText atRange:convertedRange];
    [attrString setAttributes:attrs range:convertedRange];
  }
  {
    NSRange remainingRange = NSMakeRange(range.location, [preedit length] - range.location);
    attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:remainingRange];
    [attrString setAttributes:attrs range:remainingRange];
  }
  [_currentClient setMarkedText:attrString
                 selectionRange:NSMakeRange(pos, 0)
               replacementRange:NSMakeRange(NSNotFound, 0)];

  [attrString release];
}

-(void)showPreedit:(NSString*)preedit
      withSelRange:(NSRange)selRange
        atCaretPos:(NSUInteger)caretPos
     andCandidates:(NSArray*)candidates
       andComments:(NSArray*)comments
        withLabels:(NSString*)labels
       highlighted:(NSUInteger)index
{
  //NSLog(@"showPreedit: ... andCandidates:");
  [candidates retain];
  [_candidates release];
  _candidates = candidates;
  NSRect inputPos;
  [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&inputPos];
  SquirrelPanel* panel = [(SquirrelApplicationDelegate *)[NSApp delegate] panel];
  [panel updatePosition:inputPos];
  [panel updatePreedit:preedit
          withSelRange:selRange
            atCaretPos:caretPos
         andCandidates:candidates
           andComments:comments
            withLabels:labels
           highlighted:index];
}

@end // SquirrelController


// implementation of private interface
@implementation SquirrelInputController(Private)

-(void)createSession
{
  NSString* app = [_currentClient bundleIdentifier];
  NSLog(@"createSession: %@", app);
  _currentApp = [app copy];
  _session = RimeCreateSession();
  
  [_schemaId release];
  _schemaId = nil;

  if (_session) {
    [self updateAppOptions];
  }
}

-(void)updateAppOptions
{
  if (!_currentApp) return;
  NSLog(@"setAppOptions: %@", _currentApp);
  // optionally, set app specific options
  NSDictionary* appOptions = [(SquirrelApplicationDelegate *)[NSApp delegate] appOptions];
  NSDictionary* options = [appOptions objectForKey:_currentApp];
  if (options) {
    for (NSString* key in options) {
      NSNumber* value = [options objectForKey:key];
      if (value) {
        NSLog(@"set app option: %@ = %d", key, [value boolValue]);
        RimeSetOption(_session, [key UTF8String], [value boolValue]);
      }
    }
  }
}

-(void)destroySession
{
  //NSLog(@"destroySession:");
  if (_session) {
    RimeDestroySession(_session);
    _session = 0;
  }
  [self clearChord];
}

-(void)rimeConsumeCommittedText
{
  RIME_STRUCT(RimeCommit, commit);
  if (RimeGetCommit(_session, &commit)) {
    NSString *commitText = [NSString stringWithUTF8String:commit.text];
    [self commitString: commitText];
    RimeFreeCommit(&commit);
  }
}

-(void)loadSchemaSpecificSettings:(NSString*)schemaId {
  RimeConfig config;
  if (RimeSchemaOpen([schemaId UTF8String], &config)) {
    [(SquirrelApplicationDelegate *)[NSApp delegate] updateUIStyle:&config initialize:NO];
    RimeConfigClose(&config);
  }
}

-(void)rimeUpdate
{
  //NSLog(@"update");
  [self rimeConsumeCommittedText];

  RIME_STRUCT(RimeStatus, status);
  if (RimeGetStatus(_session, &status)) {
    // enable schema specific ui style
    if (!_schemaId || strcmp([_schemaId UTF8String], status.schema_id) != 0) {
      [_schemaId release];
      _schemaId = [[NSString alloc] initWithUTF8String:status.schema_id];
      [self loadSchemaSpecificSettings:_schemaId];
      // inline preedit
      _inlinePreedit = [[(SquirrelApplicationDelegate *)[NSApp delegate] panel] inlinePreedit] &&
          !RimeGetOption(_session, "no_inline") &&   // not disabled in app options
          ![_schemaId isEqualToString:@".default"];  // not in switcher where app options are not accessible
      // if not inline, embed soft cursor in preedit string
      RimeSetOption(_session, "soft_cursor", !_inlinePreedit);
    }
    RimeFreeStatus(&status);
  }

  RIME_STRUCT(RimeContext, ctx);
  if (RimeGetContext(_session, &ctx)) {
    // update preedit text
    const char *preedit = ctx.composition.preedit;
    NSString *preeditText = @"";
    if (preedit) {
      preeditText = [NSString stringWithUTF8String:preedit];
    }
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
      [candidates addObject:[NSString stringWithUTF8String:ctx.menu.candidates[i].text]];
      if (ctx.menu.candidates[i].comment) {
        [comments addObject:[NSString stringWithUTF8String:ctx.menu.candidates[i].comment]];
      }
      else {
        [comments addObject:@""];
      }
    }
    NSString* labels = @"";
    if (ctx.menu.select_keys) {
      labels = [NSString stringWithUTF8String:ctx.menu.select_keys];
    }
    [self showPreedit:(_inlinePreedit ? nil : preeditText)
         withSelRange:selRange
           atCaretPos:caretPos
        andCandidates:candidates
          andComments:comments
           withLabels:labels
          highlighted:ctx.menu.highlighted_candidate_index];
    RimeFreeContext(&ctx);
  }
}

@end // SquirrelController(Private)
