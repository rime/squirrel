//
//  SquirrelPanel.h
//  Squirrel
//
//  Created by 弓辰 on 2012/2/13.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SquirrelPanel : NSObject {
  NSRect _position;
  NSWindow* _window;
  NSView* _view;
  NSMutableDictionary* _attrs;
}

-(void)show;
-(void)hide;
-(void)updatePosition:(NSRect)caretPos;
-(void)updateCandidates:(NSArray*)candidates
             withLabels:(NSString*)labels
            highlighted:(NSUInteger)index;

@end
