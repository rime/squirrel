#import <Cocoa/Cocoa.h>

@class SquirrelConfig;

@interface SquirrelPanel : NSObject

// Linear candidate list, as opposed to stacked candidate list.
@property(nonatomic, assign) BOOL linear;
// Vertical text, as opposed to horizontal text.
@property(nonatomic, assign) BOOL vertical;
@property(nonatomic, assign) BOOL inlinePreedit;

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

-(void)updateConfig:(SquirrelConfig*)config;

@end
