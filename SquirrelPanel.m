//
//  SquirrelPanel.m
//  Squirrel
//
//  Created by 弓辰 on 2012/2/13.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "SquirrelPanel.h"

static const int kBorderHeight = 10;
static const int kBorderWidth = 10;
static const int kOffsetHeight = 5;
static const int kFontSize = 24;
static const double kAlpha = 1.0;

@interface SquirrelView : NSView
{
  NSAttributedString* _content;
}

-(NSSize)contentSize;
-(void)setContent:(NSAttributedString*)content;

@end


@implementation SquirrelView

-(NSSize)contentSize
{
  if (!_content) return NSMakeSize(0, 0);
  return [_content size];
}

-(void)setContent:(NSAttributedString*)content
{
  [content retain];
  [_content release];
  _content = content;
  [self setNeedsDisplay:YES];
}

-(void)drawRect:(NSRect)rect
{
  if (!_content) return;
  [[NSColor windowBackgroundColor] set];
  NSRectFill([self bounds]);
  NSPoint point = rect.origin;
  point.x += kBorderWidth;
  point.y += kBorderHeight;
  [_content drawAtPoint:point];
}

@end


@implementation SquirrelPanel

-(id)init
{
  _position = NSMakeRect(0, 0, 0, 0);
  _window = [[NSWindow alloc] initWithContentRect:_position
                                        styleMask:NSBorderlessWindowMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
  [_window setAlphaValue:kAlpha];
  [_window setLevel:NSScreenSaverWindowLevel + 1];
  [_window setHasShadow:YES];    
  [_window setOpaque:NO];
  _view = [[SquirrelView alloc] initWithFrame:[[_window contentView] frame]];
  [_window setContentView:_view];
  
  _attrs = [[NSMutableDictionary alloc] init];
  [_attrs setObject:[NSColor textColor] forKey:NSForegroundColorAttributeName];
  [_attrs setObject:[NSFont systemFontOfSize:kFontSize] forKey:NSFontAttributeName];
  
  return self;
}

-(void)show
{
  NSRect window_rect = [_window frame];
  // resize frame
  NSSize content_size = [(SquirrelView*)_view contentSize];
  window_rect.size.height = content_size.height + kBorderHeight * 2;
  window_rect.size.width = content_size.width + kBorderWidth * 2;
  // reposition window
  window_rect.origin.x = NSMinX(_position);
  window_rect.origin.y = NSMinY(_position) - kOffsetHeight - NSHeight(window_rect);
  // fit in current screen
  NSRect screen_rect = [[NSScreen mainScreen] frame];
  if (NSMaxX(window_rect) > NSMaxX(screen_rect)) {
    window_rect.origin.x = NSMaxX(screen_rect) - NSWidth(window_rect);
  }
  if (NSMinX(window_rect) < NSMinX(screen_rect)) {
    window_rect.origin.x = NSMinX(screen_rect);
  }
  if (NSMinY(window_rect) < NSMinY(screen_rect)) {
    window_rect.origin.y = NSMaxY(_position) + kOffsetHeight;
  }
  if (NSMaxY(window_rect) > NSMaxY(screen_rect)) {
    window_rect.origin.y = NSMaxY(screen_rect) - NSHeight(window_rect);
  }
  if (NSMinY(window_rect) < NSMinY(screen_rect)) {
    window_rect.origin.y = NSMinY(screen_rect);
  }
  // voila !
  [_window setFrame:window_rect display:YES];
  [_window orderFront:nil];
}

-(void)hide
{
  [_window orderOut:nil];
}

-(void)updatePosition:(NSRect)caretPos
{
  _position = caretPos;
}

-(void)updateCandidates:(NSArray*)candidates
             withLabels:(NSString*)labels
            highlighted:(NSUInteger)index
{
  if ([candidates count] == 0) {
    [self hide];
    return;
  }
  NSMutableAttributedString* text = [[NSMutableAttributedString alloc] init];
  NSUInteger i;
  for (i = 0; i < [candidates count]; ++i) {
    NSString* str;
    if (i < [labels length]) {
      str = [NSString stringWithFormat:@"%c. %@ ", [labels characterAtIndex:i], [candidates objectAtIndex:i]];
    }
    else {
      str = [NSString stringWithFormat:@"%d. %@ ", i + 1, [candidates objectAtIndex:i]];
    }
    NSMutableAttributedString* line = [[[NSMutableAttributedString alloc] initWithString:str attributes:_attrs] autorelease];
    if (i == index) {
      NSRange whole_line = NSMakeRange(0, [line length]);
      [line removeAttribute:NSForegroundColorAttributeName
                      range:whole_line];
      [line addAttribute:NSForegroundColorAttributeName
                   value:[NSColor selectedTextColor]
                   range:whole_line];
      [line addAttribute:NSBackgroundColorAttributeName
                   value:[NSColor selectedTextBackgroundColor]
                   range:whole_line];
    }
    if (i > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    }
    [text appendAttributedString:line];
  }
  [(SquirrelView*)_view setContent:text];
  [text release];
  [self show];
}

@end
