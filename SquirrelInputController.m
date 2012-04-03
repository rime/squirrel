
#import "SquirrelInputController.h"
#import "SquirrelApplicationDelegate.h"
#import "macos_keycode.h"
#import <rime_api.h>
#import <rime/key_table.h>

// forward declaration of 'Private' category
@interface SquirrelInputController(Private)
-(void)createSession;
-(void)destroySession;
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

  //NSLog(@"handleEvent:client:");
  
  if (!_session) {
    [self createSession];
    if (!_session) return NO;
  }
  
  _currentClient = sender;
  BOOL handled = NO;
  
  NSUInteger modifiers = [event modifierFlags];  
  switch ([event type]) {
    case NSFlagsChanged:
      {
        if (_lastModifier == modifiers)
          return YES;
        //NSLog(@"FLAGSCHANGED self: 0x%x, client: 0x%x, modifiers: 0x%x", self, sender, modifiers);
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        int release_mask = 0;
        int changes = _lastModifier ^ modifiers;
        if (changes & OSX_SHIFT_MASK)
        {
          release_mask = modifiers & OSX_SHIFT_MASK ? 0 : kReleaseMask;
          RimeProcessKey(_session, XK_Shift_L, rime_modifiers | release_mask);
        }
        if (changes & OSX_CTRL_MASK)
        {
          release_mask = modifiers & OSX_CTRL_MASK ? 0 : kReleaseMask;
          RimeProcessKey(_session, XK_Control_L, rime_modifiers | release_mask);
        }
        if (changes & OSX_ALT_MASK)
        {
          release_mask = modifiers & OSX_ALT_MASK ? 0 : kReleaseMask;
          RimeProcessKey(_session, XK_Alt_L, rime_modifiers | release_mask);
        }
        if (changes & OSX_COMMAND_MASK)
        {
          release_mask = modifiers & OSX_COMMAND_MASK ? 0 : kReleaseMask;
          RimeProcessKey(_session, XK_Super_L, rime_modifiers | release_mask);
        }
        [self rimeUpdate];
      }
      break;
    case NSKeyDown:
    {
      NSInteger keyCode = [event keyCode];
      NSString* keyChars = [event characters];
      //NSLog(@"KEYDOWN self: 0x%x, client: 0x%x, modifiers: 0x%x, keyCode: %d, keyChars: [%@]", 
      //      self, sender, modifiers, keyCode, keyChars);
      // ignore Command+X hotkeys.
      if (modifiers & OSX_CAPITAL_MASK || modifiers & OSX_COMMAND_MASK)
        break;
      // translate osx keyevents to rime keyevents
      int rime_keycode = osx_keycode_to_rime_keycode(keyCode,
                                                     [keyChars UTF8String][0],
                                                     modifiers & OSX_SHIFT_MASK);
      if (rime_keycode)
      {
        int rime_modifiers = osx_modifiers_to_rime_modifiers(modifiers);
        handled = (BOOL)RimeProcessKey(_session, rime_keycode, rime_modifiers);
        [self rimeUpdate];
      }
    }
      break;
    defaults:
      break;
  }
  
  _lastModifier = modifiers;
  _lastEventType = [event type];
  return handled;
}

-(NSUInteger)recognizedEvents:(id)sender
{
  //NSLog(@"recognizedEvents:");
  return NSKeyDownMask | NSFlagsChangedMask;
}

-(void)activateServer:(id)sender
{
  //NSLog(@"activateServer:");
  if ([[NSApp delegate] useUSKeyboardLayout]) {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];
  }
}

-(id)initWithServer:(IMKServer*)server delegate:(id)delegate client:(id)inputClient
{
  //NSLog(@"initWithServer:delegate:client:");
  if (self = [super initWithServer:server delegate:delegate client:inputClient])
    [self createSession];
  
  return self;
}

-(void)deactivateServer:(id)sender
{
  //NSLog(@"deactivateServer:");
  [[[NSApp delegate] panel] hide];
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
  // TODO: force committing existing Rime composition
}

-(NSMenu*)menu
{
  return [[NSApp delegate] menu];
}

-(NSArray*)candidates:(id)sender
{
  return _candidates;
}

-(void)dealloc 
{
  [self destroySession];
  [super dealloc];
}

-(void)commitString:(NSString*)string
{
  //NSLog(@"commitString:");
  [_currentClient insertText:string 
            replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  
  [_preeditString release];
  _preeditString = nil;
  
  [[[NSApp delegate] panel] hide];
}

-(void)showPreeditString:(NSString*)preedit
                selRange:(NSRange)range
                caretPos:(NSUInteger)pos
{
  //NSLog(@"showPreeditString:");
  if ([_preeditString isEqual:preedit])
    return;

  [preedit retain];
  [_preeditString release];
  _preeditString = preedit;
  
  NSDictionary*       attrs;
  NSAttributedString* attrString;
  
  attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:range];
  attrString = [[NSAttributedString alloc] initWithString:preedit attributes:attrs];
  
  [_currentClient setMarkedText:attrString
                 selectionRange:NSMakeRange(pos, 0) 
               replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
  
  [attrString release];
}

-(void)showCandidates:(NSArray*)candidates
           withLabels:(NSString*)labels
          highlighted:(NSUInteger)index
{
  //NSLog(@"showCandidates:");
  [candidates retain];
  [_candidates release];
  _candidates = candidates;
  NSRect caretPos;
  [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&caretPos];
  SquirrelPanel* panel = [[NSApp delegate] panel];
  [panel updatePosition:caretPos];
  [panel updateCandidates:candidates withLabels:labels highlighted:index];
}

-(void)rimeUpdate
{
  //NSLog(@"update");
  
  RimeCommit commit;
  if (RimeGetCommit(_session, &commit)) {
    NSString *commitText = [NSString stringWithUTF8String:commit.text];
    [self commitString: commitText];
  }
  
  RimeContext ctx;
  if (RimeGetContext(_session, &ctx)) {
    // update preedit text
    const char *preedit = ctx.composition.preedit;
    NSString *preeditText = [NSString stringWithUTF8String:preedit];
    NSUInteger start = 0;
    NSUInteger end = 0;
    NSUInteger caretPos = 0;
    if (ctx.composition.sel_start < ctx.composition.sel_end) {
      start = utf8len(preedit, ctx.composition.sel_start);
      end = utf8len(preedit, ctx.composition.sel_end);
    }
    if (ctx.composition.cursor_pos > 0) {
      caretPos = utf8len(preedit, ctx.composition.cursor_pos);
    }
    NSRange selRange = NSMakeRange(start, end - start);
    [self showPreeditString:preeditText selRange:selRange caretPos:caretPos];
    // update candidates
    NSMutableArray *candidates = [NSMutableArray array];
    NSUInteger i;
    for (i = 0; i < ctx.menu.num_candidates; ++i) {
      [candidates addObject:[NSString stringWithUTF8String:ctx.menu.candidates[i]]];
    }
    NSString *labels = [NSString stringWithUTF8String:ctx.menu.select_keys];
    [self showCandidates:candidates
              withLabels:labels
             highlighted:ctx.menu.highlighted_candidate_index];
  }

}

@end // SquirrelController 


// implementation of private interface
@implementation SquirrelInputController(Private)

-(void)createSession
{
  //NSLog(@"createSession:");
  _session = RimeCreateSession();
}

-(void)destroySession
{
  //NSLog(@"destroySession:");
  if (_session) {
    RimeDestroySession(_session);
    _session = 0;
  }
}

@end // SquirrelController(Private)
