#import <Cocoa/Cocoa.h>

@class SquirrelConfig;

@interface SquirrelPanel : NSObject

@property(nonatomic, assign) BOOL horizontal;
@property(nonatomic, assign) BOOL inlinePreedit;

// position of input caret on screen.
@property(nonatomic, assign) NSRect position;

-(void)showPreedit:(NSString*)preedit
          selRange:(NSRange)selRange
          caretPos:(NSUInteger)caretPos
        candidates:(NSArray*)candidates
          comments:(NSArray*)comments
            labels:(NSString*)labels
       highlighted:(NSUInteger)index;

-(void)hide;

-(void)updateStatus:(NSString*)message;

-(void)updateConfig:(SquirrelConfig*)config;

@end
