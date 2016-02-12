
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>
#import <rime_api.h>

@interface SquirrelInputController : IMKInputController

-(void)commitString:(NSString*)string;
-(void)showPreeditString:(NSString*)string
                selRange:(NSRange)range
                caretPos:(NSUInteger)pos;
-(void)showPanelWithPreedit:(NSString*)preedit
                   selRange:(NSRange)selRange
                   caretPos:(NSUInteger)caretPos
                 candidates:(NSArray*)candidates
                   comments:(NSArray*)comments
                     labels:(NSString*)labels
                highlighted:(NSUInteger)index;

-(BOOL)processKey:(int)rime_keycode modifiers:(int)rime_modifiers;

-(void)onChordTimer:(NSTimer *)timer;
-(void)updateChord:(int)ch;
-(void)clearChord;

@end
