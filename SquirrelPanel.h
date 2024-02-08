#import <Cocoa/Cocoa.h>
#import "SquirrelInputController.h"

@class SquirrelConfig;
@class SquirrelOptionSwitcher;

typedef enum {
  defaultAppear = 0,
  lightAppear   = 0,
  darkAppear    = 1
} SquirrelAppear;

@interface SquirrelPanel : NSPanel <NSWindowDelegate>

// Linear candidate list layout, as opposed to stacked candidate list layout.
@property(nonatomic, readonly) BOOL linear;
// Tabled candidate list layout, a subtype of linear candidate list with tabled layout.
@property(nonatomic, readonly) BOOL tabled;
// Vertical text orientation, as opposed to horizontal text orientation.
@property(nonatomic, readonly) BOOL vertical;
// Show preedit text inline.
@property(nonatomic, readonly) BOOL inlinePreedit;
// Show primary candidate inline
@property(nonatomic, readonly) BOOL inlineCandidate;
// Store switch options that change style (color theme) settings
@property(nonatomic, strong) SquirrelOptionSwitcher *optionSwitcher;
// option(s) on Chinese script (simplification/traditional, or radio group thereof)
@property(nonatomic, strong) NSArray<NSString *> *scriptOptions;
// position of the text input I-beam cursor on screen.
@property(nonatomic, assign) NSRect IbeamRect;

@property(nonatomic, strong) NSString *statusMessage;

@property(nonatomic, assign) SquirrelInputController *inputController;

- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray<NSString *> *)candidates
           comments:(NSArray<NSString *> *)comments
   highlightedIndex:(NSUInteger)highlightedIndex
            pageNum:(NSUInteger)pageNum
           lastPage:(BOOL)lastPage;

- (void)hide;

- (void)updateStatusLong:(NSString *)messageLong
             statusShort:(NSString *)messageShort;

- (void)loadConfig:(SquirrelConfig *)config
     forAppearance:(SquirrelAppear)appear;

- (void)loadLabelConfig:(SquirrelConfig *)config
           directUpdate:(BOOL)update;

@end
