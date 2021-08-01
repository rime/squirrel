#import <Cocoa/Cocoa.h>

@class SquirrelConfig;

@interface SquirrelPanel : NSWindow

// Linear candidate list, as opposed to stacked candidate list.
@property(nonatomic, readonly) BOOL linear;
// Vertical text, as opposed to horizontal text.
@property(nonatomic, readonly) BOOL vertical;
// Show preedit text inline.
@property(nonatomic, readonly) BOOL inlinePreedit;
// Show first candidate inline
@property(nonatomic, readonly) BOOL inlineCandidate;

// position of input caret on screen.
@property(nonatomic, assign) NSRect position;

-(void)showPreedit:(NSString*)preedit
          selRange:(NSRange)selRange
          caretPos:(NSUInteger)caretPos
        candidates:(NSArray*)candidates
          comments:(NSArray*)comments
            labels:(NSArray*)labels
       highlighted:(NSUInteger)index;

-(void)hide;

-(void)updateStatus:(NSString*)message;

-(void)loadConfig:(SquirrelConfig*)config
      forDarkMode:(BOOL)isDark;

@end
