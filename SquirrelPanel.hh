#import "SquirrelInputController.hh"

@class SquirrelConfig;
@class SquirrelOptionSwitcher;

@interface SquirrelPanel : NSPanel <NSWindowDelegate>

// Show preedit text inline.
@property(nonatomic, readonly, direct) BOOL inlinePreedit;
// Show primary candidate inline
@property(nonatomic, readonly, direct) BOOL inlineCandidate;
// Vertical text orientation, as opposed to horizontal text orientation.
@property(nonatomic, readonly, direct) BOOL vertical;
// Linear candidate list layout, as opposed to stacked candidate list layout.
@property(nonatomic, readonly, direct) BOOL linear;
// Tabular candidate list layout, initializes as tab-aligned linear layout,
// expandable to stack 5 (3 for vertical) pages/sections of candidates
@property(nonatomic, readonly, direct) BOOL tabular;
@property(nonatomic, readonly, direct) BOOL locked;
@property(nonatomic, readonly, direct) BOOL firstLine;
@property(nonatomic, direct) BOOL expanded;
@property(nonatomic, direct) NSUInteger sectionNum;
// position of the text input I-beam cursor on screen.
@property(nonatomic, direct) NSRect IbeamRect;
@property(nonatomic, readonly, strong, nullable) NSScreen* screen;
// Status message before pop-up is displayed; nil before normal panel is
// displayed
@property(nonatomic, readonly, strong, nullable, direct)
    NSString* statusMessage;
// Store switch options that change style (color theme) settings
@property(nonatomic, strong, nonnull, direct)
    SquirrelOptionSwitcher* optionSwitcher;

// query
- (NSUInteger)candidateIndexOnDirection:(SquirrelIndex)arrowKey
    __attribute__((objc_direct));
// status message
- (void)updateStatusLong:(NSString* _Nullable)messageLong
             statusShort:(NSString* _Nullable)messageShort
    __attribute__((objc_direct));
// display
- (void)showPreedit:(NSString* _Nullable)preedit
            selRange:(NSRange)selRange
            caretPos:(NSUInteger)caretPos
    candidateIndices:(NSRange)indexRange
    hilitedCandidate:(NSUInteger)hilitedCandidate
             pageNum:(NSUInteger)pageNum
           finalPage:(BOOL)finalPage
          didCompose:(BOOL)didCompose __attribute__((objc_direct));
- (void)hide __attribute__((objc_direct));
// settings
- (void)loadConfig:(SquirrelConfig* _Nonnull)config
    __attribute__((objc_direct));
- (void)loadLabelConfig:(SquirrelConfig* _Nonnull)config
           directUpdate:(BOOL)update __attribute__((objc_direct));
- (void)updateScriptVariant __attribute__((objc_direct));

@end  // SquirrelPanel
