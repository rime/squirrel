#import <Cocoa/Cocoa.h>

@interface SquirrelUIStyle : NSObject<NSCopying> {
}

@property (nonatomic, assign) BOOL horizontal;
@property (nonatomic, assign) BOOL inlinePreedit;
@property (nonatomic, copy) NSString* labelFontName;
@property (nonatomic, assign) int labelFontSize;
@property (nonatomic, copy) NSString* fontName;
@property (nonatomic, assign) int fontSize;
@property (nonatomic, assign) double alpha;
@property (nonatomic, assign) double cornerRadius;
@property (nonatomic, assign) double borderHeight;
@property (nonatomic, assign) double borderWidth;
@property (nonatomic, assign) double lineSpacing;
@property (nonatomic, assign) double spacing;
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, copy) NSString *textColor;
@property (nonatomic, copy) NSString *candidateLabelColor;
@property (nonatomic, copy) NSString *candidateTextColor;
@property (nonatomic, copy) NSString *highlightedTextColor;
@property (nonatomic, copy) NSString *highlightedBackColor;
@property (nonatomic, copy) NSString *highlightedCandidateLabelColor;
@property (nonatomic, copy) NSString *highlightedCandidateTextColor;
@property (nonatomic, copy) NSString *highlightedCandidateBackColor;
@property (nonatomic, copy) NSString *highlightedCommentTextColor;
@property (nonatomic, copy) NSString *commentTextColor;
@property (nonatomic, copy) NSString *candidateFormat;

@end

@interface SquirrelPanel : NSObject

@property (nonatomic, readonly) BOOL horizontal;
@property (nonatomic, readonly) BOOL inlinePreedit;

-(void)show;
-(void)hide;
-(void)updatePosition:(NSRect)caretPos;
-(void)updatePreedit:(NSString*)preedit
        withSelRange:(NSRange)selRange
          atCaretPos:(NSUInteger)caretPos
       andCandidates:(NSArray*)candidates
         andComments:(NSArray*)comments
          withLabels:(NSString*)labels
        highlighted:(NSUInteger)index;
-(void)updateMessage:(NSString*)msg;
-(void)showStatus:(NSString*)msg;
-(void)hideStatus:(NSTimer*)timer;
-(void)updateUIStyle:(SquirrelUIStyle*)style;

@end
