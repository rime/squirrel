//
//  SquirrelPanel.m
//  Squirrel
//
//  Created by 弓辰 on 2012/2/13.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "SquirrelPanel.h"

static const int kOffsetHeight = 5;
static const int kFontSize = 24;
static const double kAlpha = 1.0;

@interface SquirrelView : NSView
{
  NSAttributedString* _content;
}

@property (nonatomic, retain) NSColor *backgroundColor;
@property (nonatomic, assign) double cornerRadius;
@property (nonatomic, assign) double borderHeight;
@property (nonatomic, assign) double borderWidth;

-(NSSize)contentSize;
-(void)setContent:(NSAttributedString*)content;

@end


@implementation SquirrelView

@synthesize backgroundColor = _backgroundColor;
@synthesize cornerRadius = _cornerRadius;
@synthesize borderHeight = _borderHeight;
@synthesize borderWidth = _borderWidth;

-(double)borderHeight
{
  return MAX(_borderHeight, _cornerRadius);
}

-(double)borderWidth
{
  return MAX(_borderWidth, _cornerRadius);
}

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
  if (!_content) {
    return;
  }

  if ([self backgroundColor]) {
    [[self backgroundColor] setFill];
  }
  else {
    [[NSColor windowBackgroundColor] setFill];
  }
  
  [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:_cornerRadius yRadius:_cornerRadius] fill];

  NSPoint point = rect.origin;
  point.x += [self borderWidth];
  point.y += [self borderHeight];
  [_content drawAtPoint:point];
}

@end


@implementation SquirrelPanel

-(id)init
{
//  NSLog(@"SqurrelPanel init");
  _position = NSMakeRect(0, 0, 0, 0);
  _window = [[NSWindow alloc] initWithContentRect:_position
                                        styleMask:NSBorderlessWindowMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
  [_window setAlphaValue:kAlpha];
  [_window setLevel:NSScreenSaverWindowLevel + 1];
  [_window setHasShadow:YES];    
  [_window setOpaque:NO];
  [_window setBackgroundColor:[NSColor clearColor]];
  _view = [[SquirrelView alloc] initWithFrame:[[_window contentView] frame]];
  [_window setContentView:_view];
  
  _attrs = [[NSMutableDictionary alloc] init];
  [_attrs setObject:[NSColor controlTextColor] forKey:NSForegroundColorAttributeName];
  [_attrs setObject:[NSFont userFontOfSize:kFontSize] forKey:NSFontAttributeName];
  
  _highlightedAttrs = [[NSMutableDictionary alloc] init];
  [_highlightedAttrs setObject:[NSColor selectedControlTextColor] forKey:NSForegroundColorAttributeName];
  [_highlightedAttrs setObject:[NSColor selectedTextBackgroundColor] forKey:NSBackgroundColorAttributeName];
  [_highlightedAttrs setObject:[NSFont userFontOfSize:kFontSize] forKey:NSFontAttributeName];
  
  _labelAttrs = [_attrs mutableCopy];
  _labelHighlightedAttrs = [_highlightedAttrs mutableCopy];
  
  _commentAttrs = [[NSMutableDictionary alloc] init];
  [_commentAttrs setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
  [_commentAttrs setObject:[NSFont userFontOfSize:kFontSize] forKey:NSFontAttributeName];
  
  _horizontal = NO;
  _candidateFormat = @"%c. %@ ";
  _paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] retain];
  
  _numCandidates = 0;
  _message = nil;
  _statusTimer = nil;
  
  return self;
}

-(void)show
{
//  NSLog(@"show: %d %@", _numCandidates, _message);
  
  NSRect window_rect = [_window frame];
  // resize frame
  NSSize content_size = [(SquirrelView*)_view contentSize];
  window_rect.size.height = content_size.height + [(SquirrelView*)_view borderHeight] * 2;
  window_rect.size.width = content_size.width + [(SquirrelView*)_view borderWidth] * 2;
  // reposition window
  window_rect.origin.x = NSMinX(_position);
  window_rect.origin.y = NSMinY(_position) - kOffsetHeight - NSHeight(window_rect);
  // fit in current screen
  NSRect screen_rect = [[NSScreen mainScreen] frame];
  NSArray* screens = [NSScreen screens];
  NSUInteger i;
  for (i = 0; i < [screens count]; ++i) {
    NSRect rect = [[screens objectAtIndex:i] frame];
    if (NSPointInRect(_position.origin, rect)) {
      screen_rect = rect;
      break;
    }
  }
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
//  NSLog(@"hide:");
  [_window orderOut:nil];
}

-(void)updatePosition:(NSRect)caretPos
{
  _position = caretPos;
}

-(void)updateCandidates:(NSArray*)candidates
            andComments:(NSArray*)comments
             withLabels:(NSString*)labels
            highlighted:(NSUInteger)index
{
  _numCandidates = [candidates count];
//  NSLog(@"updateCandidates: %d %@", _numCandidates, _message);
  if (_numCandidates) {
    [self updateMessage:nil];
    if (_statusTimer) {
      [_statusTimer invalidate];
      _statusTimer = nil;
    }
  }
  else {
    if (_message) {
      [self showStatus:_message];
      [self updateMessage:nil];
    }
    else if (!_statusTimer) {
      [self hide];
    }
    return;
  }
  
  NSRange labelRange, labelRange2, pureCandidateRange;
  NSString *labelFormat, *labelFormat2, *pureCandidateFormat;
  {
    // in our candiate format, everything other than '%@' is
    // considered as a part of the label
    
    labelRange = [_candidateFormat rangeOfString:@"%c"];
    if (labelRange.location == NSNotFound) {
      labelRange2 = labelRange;
      labelFormat2 = labelFormat = nil;
      
      pureCandidateRange = NSMakeRange(0, [_candidateFormat length]);
      pureCandidateFormat = _candidateFormat;
    }
    else {
      pureCandidateRange = [_candidateFormat rangeOfString:@"%@"];
      if (pureCandidateRange.location == NSNotFound) {
        // this should never happen, but just ensure that Squirrel
        // would not crash when such edge case occurs...
        
        labelFormat = _candidateFormat;
        
        labelRange2 = pureCandidateRange;
        labelFormat2 = nil;
        
        pureCandidateFormat = @"";
      }
      else {
        if (NSMaxRange(pureCandidateRange) >= [_candidateFormat length]) {
          // '%@' is at the end, so label2 does not exist
          labelRange2 = NSMakeRange(NSNotFound, 0);
          labelFormat2 = nil;
          
          // fix label1, everything other than '%@' is label1
          labelRange.location = 0;
          labelRange.length = pureCandidateRange.location;
        }
        else {
          labelRange = NSMakeRange(0, pureCandidateRange.location);
          labelRange2 = NSMakeRange(NSMaxRange(pureCandidateRange), [_candidateFormat length] - NSMaxRange(pureCandidateRange));
          
          labelFormat2 = [_candidateFormat substringWithRange:labelRange2];
        }
        
        pureCandidateFormat = @"%@";
        labelFormat = [_candidateFormat substringWithRange:labelRange];
      }
    }
  }
  
  NSMutableAttributedString* text = [[NSMutableAttributedString alloc] init];
  NSUInteger i;
  for (i = 0; i < [candidates count]; ++i) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
    
    // default: 1. 2. 3... custom: A. B. C...
    char label_character = (i < [labels length]) ? [labels characterAtIndex:i] : ((i + 1) % 10 + '0');
    
    NSDictionary *attrs = _attrs, *labelAttrs = _labelAttrs;
    if (i == index) {
      attrs = _highlightedAttrs;
      labelAttrs = _labelHighlightedAttrs;
    }
    
    if (labelRange.location != NSNotFound) {
      [line appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:labelFormat, label_character]
                                                                    attributes:labelAttrs] autorelease]];
    }
    
    [line appendAttributedString:[[[NSAttributedString alloc] initWithString:[candidates objectAtIndex:i]
                                                                  attributes:attrs] autorelease]];
    
    if (labelRange2.location != NSNotFound) {
      [line appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:labelFormat2, label_character]
                                                                    attributes:labelAttrs] autorelease]];
    }
    
    if (i < [comments count] && [[comments objectAtIndex:i] length] != 0) {
      [line appendAttributedString:[[[NSAttributedString alloc] initWithString: [comments objectAtIndex:i]
                                                                    attributes:_commentAttrs] autorelease]];
    }
    if (i > 0) {
      [text appendAttributedString:[[[NSAttributedString alloc] initWithString: (_horizontal ? @" " : @"\n")
                                                                    attributes:_attrs] autorelease]];
    }
    
    [text appendAttributedString:line];
    [line release];
  }
    [text addAttribute:NSParagraphStyleAttributeName
               value:(id)_paragraphStyle
               range:NSMakeRange(0, [text length])];
  
  [(SquirrelView*)_view setContent:text];
  [text release];
  [self show];
}

-(void)updateMessage:(NSString *)msg
{
//  NSLog(@"updateMessage: %@ -> %@", _message, msg);
  [msg retain];
  [_message release];
  _message = msg;
}

-(void)showStatus:(NSString *)msg
{
//  NSLog(@"showStatus: %@", msg);
  
  NSMutableAttributedString* text = [[NSMutableAttributedString alloc] init];
  [text appendAttributedString:[[[NSAttributedString alloc] initWithString: msg
                                                                attributes:_commentAttrs] autorelease]];
  [(SquirrelView*)_view setContent:text];
  [text release];
  [self show];
  
  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  _statusTimer = [NSTimer scheduledTimerWithTimeInterval:1.2
                                                  target:self
                                                selector:@selector(hideStatus:)
                                                userInfo:nil
                                                 repeats:NO];
}

-(void)hideStatus:(NSTimer *)timer
{
//  NSLog(@"hideStatus: %@", _message);
  [_message release];
  _message = nil;
  [_statusTimer invalidate];
  _statusTimer = nil;
  [self hide];
}

-(NSColor *)colorFromString:(NSString *)string
{
  if (string == nil) {
    return nil;
  }
  
  int r = 0, g = 0, b =0, a = 0xff;
  if ([string length] == 10) {
    // 0xffccbbaa
    sscanf([string UTF8String], "0x%02x%02x%02x%02x", &a, &b, &g, &r);
  }
  else if ([string length] == 8) {
    // 0xccbbaa
    sscanf([string UTF8String], "0x%02x%02x%02x", &b, &g, &r);
  }
  
  return [NSColor colorWithDeviceRed:(CGFloat)r / 255. green:(CGFloat)g / 255. blue:(CGFloat)b / 255. alpha:(CGFloat)a / 255.];
}

static inline NSColor *blendColors(NSColor *foregroundColor, NSColor *backgroundColor)
{
  if (!backgroundColor) {
    //return foregroundColor;
    backgroundColor = [NSColor lightGrayColor];
  }
  
  struct {
    CGFloat r, g, b, a;
  } f, b;
  
  [[foregroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&f.r
                                                                     green:&f.g
                                                                      blue:&f.b
                                                                     alpha:&f.a];
  //NSLog(@"fg: %f %f %f %f", f.r, f.g, f.b, f.a);
  
  [[backgroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&b.r
                                                                     green:&b.g
                                                                      blue:&b.b
                                                                     alpha:&b.a];
  //NSLog(@"bg: %f %f %f %f", b.r, b.g, b.b, b.a);
  
#define blend_value(f, b) (((f) * 2.0 + (b)) / 3.0)
  return [NSColor colorWithDeviceRed:blend_value(f.r, b.r)
                               green:blend_value(f.g, b.g)
                                blue:blend_value(f.b, b.b)
                               alpha:f.a];
#undef blend_value
}

static inline NSFontDescriptor *getFontDescriptor(NSString *fullname)
{
  if (fullname == nil) {
    return nil;
  }
  
  NSArray *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray *validFontDescriptors = [NSMutableArray arrayWithCapacity:[fontNames count]];
  for (NSString *fontName in fontNames) {
    fontName = [fontName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([NSFont fontWithName:fontName size:0.0] != nil) {
      // If the font name is not valid, NSFontDescriptor will still create something for us.
      // However, when we draw the actual text, Squirrel will crash if there is any font descriptor
      // with invalid font name.
      [validFontDescriptors addObject:[NSFontDescriptor fontDescriptorWithName:fontName size:0.0]];
    }
  }
  
  if ([validFontDescriptors count] == 0) {
    return nil;
  }
  else if ([validFontDescriptors count] == 1) {
    return [validFontDescriptors objectAtIndex:0];
  }
  
  NSFontDescriptor *initialFontDescriptor = [validFontDescriptors objectAtIndex:0];
  NSArray *fallbackDescriptors = [validFontDescriptors subarrayWithRange:NSMakeRange(1, [validFontDescriptors count] - 1)];
  NSDictionary *attributes = [NSDictionary dictionaryWithObject:fallbackDescriptors forKey:NSFontCascadeListAttribute];
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

-(void)updateUIStyle:(SquirrelUIStyle *)style
{
  _horizontal = style->horizontal;
  
  if (style->fontSize == 0) {  // default size
    style->fontSize = kFontSize;
  }
  if (style->labelFontSize == 0) {
    style->labelFontSize = style->fontSize;
  }
  
  NSFontDescriptor* fontDescriptor = nil;
  NSFont* font = nil;
  if (style->fontName != nil) {
    fontDescriptor = getFontDescriptor(style->fontName);
    if (fontDescriptor != nil) {
      font = [NSFont fontWithDescriptor:fontDescriptor size:style->fontSize];
    }
  }
  if (font == nil) {
    // use default font
    font = [NSFont userFontOfSize:style->fontSize];
  }
  NSFontDescriptor* labelFontDescriptor = nil;
  NSFont* labelFont = nil;
  if (style->labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(style->labelFontName);
    if (labelFontDescriptor == nil) {
      labelFontDescriptor = fontDescriptor;
    }
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:style->labelFontSize];
    }
  }
  if (labelFont == nil) {
    if (fontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:fontDescriptor size:style->labelFontSize];
    }
    else {
      labelFont = [NSFont fontWithName:[font fontName] size:style->labelFontSize];
    }
  }
  [_attrs setObject:font forKey:NSFontAttributeName];
  [_highlightedAttrs setObject:font forKey:NSFontAttributeName];
  [_labelAttrs setObject:labelFont forKey:NSFontAttributeName];
  [_labelHighlightedAttrs setObject:labelFont forKey:NSFontAttributeName];
  [_commentAttrs setObject:font forKey:NSFontAttributeName];
  
  if (style->backgroundColor != nil) {
    NSColor *color = [self colorFromString:style->backgroundColor];
    [(SquirrelView *) _view setBackgroundColor:(color)];
  }
  else {
    // default color
    [(SquirrelView *) _view setBackgroundColor:nil];
  }
  
  if (style->candidateTextColor != nil) {
    NSColor *color = [self colorFromString:style->candidateTextColor];
    [_attrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  else {
    [_attrs setObject:[NSColor controlTextColor] forKey:NSForegroundColorAttributeName];
  }
  
  if (style->candidateLabelColor != nil) {
    NSColor *color = [self colorFromString:style->candidateLabelColor];
    [_labelAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  else {
    NSColor *color = blendColors([_attrs objectForKey:NSForegroundColorAttributeName], [(SquirrelView *)_view backgroundColor]);
    [_labelAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  
  if (style->highlightedCandidateTextColor != nil) {
    NSColor *color = [self colorFromString:style->highlightedCandidateTextColor];
    [_highlightedAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  else {
    [_highlightedAttrs setObject:[NSColor selectedControlTextColor] forKey:NSForegroundColorAttributeName];
  }

  if (style->highlightedCandidateBackColor != nil) {
    NSColor *color = [self colorFromString:style->highlightedCandidateBackColor];
    [_highlightedAttrs setObject:color forKey:NSBackgroundColorAttributeName];
  }
  else {
    [_highlightedAttrs setObject:[NSColor selectedTextBackgroundColor] forKey:NSBackgroundColorAttributeName];
  }
  
  if (style->highlightedCandidateLabelColor != nil) {
    NSColor *color = [self colorFromString:style->highlightedCandidateLabelColor];
    [_labelHighlightedAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  else {
    NSColor *color = blendColors([_highlightedAttrs objectForKey:NSForegroundColorAttributeName],
                                 [_highlightedAttrs objectForKey:NSBackgroundColorAttributeName]);
    [_labelHighlightedAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  [_labelHighlightedAttrs setObject:[_highlightedAttrs objectForKey:NSBackgroundColorAttributeName] forKey:NSBackgroundColorAttributeName];
  
  if (style->commentTextColor != nil) {
    NSColor *color = [self colorFromString:style->commentTextColor];
    [_commentAttrs setObject:color forKey:NSForegroundColorAttributeName];
  }
  else {
    [_commentAttrs setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
  }
  
  [(SquirrelView *) _view setCornerRadius:style->cornerRadius];
  [(SquirrelView *) _view setBorderHeight:style->borderHeight];
  [(SquirrelView *) _view setBorderWidth:style->borderWidth];

  [_window setAlphaValue:style->alpha];
  
  [style->candidateFormat retain];
  [_candidateFormat release];
  _candidateFormat = style->candidateFormat ? style->candidateFormat : @"%c. %@ ";

  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  [paragraphStyle setParagraphSpacing:style->lineSpacing];
  [_paragraphStyle release];
  _paragraphStyle = paragraphStyle;
}

@end
