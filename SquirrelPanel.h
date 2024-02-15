#import <Cocoa/Cocoa.h>
#import "SquirrelInputController.h"

@class SquirrelConfig;
@class SquirrelOptionSwitcher;

@interface SquirrelPanel : NSPanel <NSWindowDelegate>

typedef NS_ENUM(NSUInteger, SquirrelAppear) {
  defaultAppear = 0,
  lightAppear   = 0,
  darkAppear    = 1
};

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
// Status message before pop-up is displayed; nil before normal panel is displayed
@property(nonatomic, strong, readonly) NSString *statusMessage;
// position of the text input I-beam cursor on screen.
@property(nonatomic, assign) NSRect IbeamRect;

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

@end // SquirrelPanel
