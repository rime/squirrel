#import <Cocoa/Cocoa.h>
#import "SquirrelInputController.h"
@class SquirrelConfig;
@class SquirrelOptionSwitcher;

@interface SquirrelPanel : NSPanel <NSWindowDelegate>

typedef NS_ENUM(NSUInteger, SquirrelAppear) {
  defaultAppear = 0,
  lightAppear = 0,
  darkAppear = 1
};

// Linear candidate list layout, as opposed to stacked candidate list layout.
@property(nonatomic, readonly) BOOL linear;
// Tabular candidate list layout, initializes as tab-aligned linear layout,
// expandable to stack 5 (3 for vertical) pages/sections of candidates
@property(nonatomic, readonly) BOOL tabular;
@property(nonatomic, readonly) BOOL locked;
@property(nonatomic, readonly) BOOL firstLine;
@property(nonatomic) BOOL expanded;
@property(nonatomic) NSUInteger sectionNum;
// Vertical text orientation, as opposed to horizontal text orientation.
@property(nonatomic, readonly) BOOL vertical;
// Show preedit text inline.
@property(nonatomic, readonly) BOOL inlinePreedit;
// Show primary candidate inline
@property(nonatomic, readonly) BOOL inlineCandidate;
// Store switch options that change style (color theme) settings
@property(nonatomic, strong, nullable) SquirrelOptionSwitcher* optionSwitcher;
// Status message before pop-up is displayed; nil before normal panel is
// displayed
@property(nonatomic, strong, readonly, nullable) NSString* statusMessage;
// Store candidates and comments queried from rime
@property(nonatomic, strong, nullable) NSMutableArray<NSString*>* candidates;
@property(nonatomic, strong, nullable) NSMutableArray<NSString*>* comments;
// position of the text input I-beam cursor on screen.
@property(nonatomic) NSRect IbeamRect;

@property(nonatomic, assign, nullable) SquirrelInputController* inputController;

- (NSUInteger)candidateIndexOnDirection:(SquirrelIndex)arrowKey;

- (void)showPreedit:(NSString* _Nullable)preedit
            selRange:(NSRange)selRange
            caretPos:(NSUInteger)caretPos
    candidateIndices:(NSRange)indexRange
    highlightedIndex:(NSUInteger)highlightedIndex
             pageNum:(NSUInteger)pageNum
           finalPage:(BOOL)finalPage
          didCompose:(BOOL)didCompose;

- (void)hide;

- (void)updateStatusLong:(NSString* _Nullable)messageLong
             statusShort:(NSString* _Nullable)messageShort;

- (void)loadConfig:(SquirrelConfig* _Nonnull)config;

- (void)loadLabelConfig:(SquirrelConfig* _Nonnull)config
           directUpdate:(BOOL)update;

@end  // SquirrelPanel
