//
//  SquirrelPanel.h
//  Squirrel
//
//  Created by 弓辰 on 2012/2/13.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct {
  BOOL horizontal;
  NSString* labelFontName;
  int labelFontSize;
  NSString* fontName;
  int fontSize;
  double alpha;
  double cornerRadius;
  double borderHeight;
  double borderWidth;
  NSString *backgroundColor;
  NSString *candidateLabelColor;
  NSString *candidateTextColor;
  NSString *highlightedCandidateLabelColor;
  NSString *highlightedCandidateTextColor;
  NSString *highlightedCandidateBackColor;
  NSString *commentTextColor;
  NSString *candidateFormat;
} SquirrelUIStyle;

@interface SquirrelPanel : NSObject {
  NSRect _position;
  NSWindow* _window;
  NSView* _view;
  NSMutableDictionary* _attrs;
  NSMutableDictionary* _highlightedAttrs;
  NSMutableDictionary *_labelAttrs;
  NSMutableDictionary *_labelHighlightedAttrs;
  NSMutableDictionary* _commentAttrs;
  BOOL _horizontal;
  NSString* _candidateFormat;
}

-(void)show;
-(void)hide;
-(void)updatePosition:(NSRect)caretPos;
-(void)updateCandidates:(NSArray*)candidates
            andComments:(NSArray*)comments
             withLabels:(NSString*)labels
            highlighted:(NSUInteger)index;
-(void)updateUIStyle:(SquirrelUIStyle*)style;

@end
