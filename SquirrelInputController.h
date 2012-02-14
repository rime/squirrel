
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import <rime_api.h>

@interface SquirrelInputController : IMKInputController {
  id                          _currentClient;         // the current active client
  NSString                   *_preeditString;         // the cached preedit string
  NSArray                    *_candidates;
  NSUInteger                  _lastModifier;
  NSEventType                 _lastEventType;
  RimeSessionId               _session;
}

-(void)commitString:(NSString*)string;
-(void)showPreeditString:(NSString*)string
                selRange:(NSRange)range
                caretPos:(NSUInteger)pos;
-(void)showCandidates:(NSArray*)candidates
          highlighted:(NSUInteger)index;
-(void)rimeUpdate;

@end
