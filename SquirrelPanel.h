#import <Cocoa/Cocoa.h>
#import "SquirrelInputController.h"

@class SquirrelConfig;

@interface SquirrelPanel : NSPanel

// Linear candidate list, as opposed to stacked candidate list.
@property(nonatomic, readonly) BOOL linear;
// Tabled candidate list, a subtype of linear candidate list with tabled layout.
@property(nonatomic, readonly) BOOL tabled;
// Vertical text, as opposed to horizontal text.
@property(nonatomic, readonly) BOOL vertical;
// Show preedit text inline.
@property(nonatomic, readonly) BOOL inlinePreedit;
// Show first candidate inline
@property(nonatomic, readonly) BOOL inlineCandidate;
// position of input caret on screen.
@property(nonatomic, assign) NSRect position;

@property(nonatomic, assign) SquirrelInputController *inputController;

- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray<NSString *> *)candidates
           comments:(NSArray<NSString *> *)comments
             labels:(NSArray<NSString *> *)labels
        highlighted:(NSUInteger)index
            pageNum:(NSUInteger)pageNum
           lastPage:(BOOL)lastPage
           turnPage:(NSUInteger)turnPage
             update:(BOOL)update;

- (void)hide;

- (void)updateStatusLong:(NSString *)messageLong
             statusShort:(NSString *)messageShort;

- (void)loadConfig:(SquirrelConfig *)config
       forDarkMode:(BOOL)isDark;

@end
