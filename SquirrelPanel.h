//
//  SquirrelPanel.h
//  Squirrel
//
//  Created by 弓辰 on 2012/2/13.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SquirrelUIStyle : NSObject<NSCopying> {
}

@property (nonatomic, assign) BOOL horizontal;
@property (nonatomic, copy) NSString* labelFontName;
@property (nonatomic, assign) int labelFontSize;
@property (nonatomic, copy) NSString* fontName;
@property (nonatomic, assign) int fontSize;
@property (nonatomic, assign) double alpha;
@property (nonatomic, assign) double cornerRadius;
@property (nonatomic, assign) double borderHeight;
@property (nonatomic, assign) double borderWidth;
@property (nonatomic, assign) double lineSpacing;
@property (nonatomic, copy) NSString *backgroundColor;
@property (nonatomic, copy) NSString *candidateLabelColor;
@property (nonatomic, copy) NSString *candidateTextColor;
@property (nonatomic, copy) NSString *highlightedCandidateLabelColor;
@property (nonatomic, copy) NSString *highlightedCandidateTextColor;
@property (nonatomic, copy) NSString *highlightedCandidateBackColor;
@property (nonatomic, copy) NSString *commentTextColor;
@property (nonatomic, copy) NSString *candidateFormat;

@end

@interface SquirrelPanel : NSObject {
  NSRect _position;
  NSWindow *_window;
  NSView *_view;
  NSMutableDictionary *_attrs;
  NSMutableDictionary *_highlightedAttrs;
  NSMutableDictionary *_labelAttrs;
  NSMutableDictionary *_labelHighlightedAttrs;
  NSMutableDictionary *_commentAttrs;
  BOOL _horizontal;
  NSString *_candidateFormat;
  NSParagraphStyle *_paragraphStyle;
  
  int _numCandidates;
  NSString *_message;
  NSTimer *_statusTimer;
  
  NSFont *_overridenFont;
  NSFont *_overridenLabelFont;
  NSString *_overridenCandidateFormat;
}

-(void)show;
-(void)hide;
-(void)updatePosition:(NSRect)caretPos;
-(void)updateCandidates:(NSArray*)candidates
            andComments:(NSArray*)comments
             withLabels:(NSString*)labels
            highlighted:(NSUInteger)index;
-(void)updateMessage:(NSString*)msg;
-(void)showStatus:(NSString*)msg;
-(void)hideStatus:(NSTimer*)timer;

-(void)updateUIStyle:(SquirrelUIStyle*)style;

@end
