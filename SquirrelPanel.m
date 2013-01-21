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

typedef struct {
  CTLineRef line;
  
  CGColorRef bgColor;
  CGRect bgRect;
  
  CGFloat width;
  CGFloat height;
  CGFloat ascent;
  CGFloat descent;
  CGFloat leading;
} SquirrelCandidate;

@interface SquirrelView : NSView
{
  SquirrelCandidate *_candidates;
  NSUInteger _candidateCount;
  NSSize _contentSize;
  
  NSColor *_backgroundColor;
  CGFloat _cornerRadius;
  CGFloat _borderHeight;
  CGFloat _borderWidth;
  BOOL _horizontal;
  
  CGFloat _horizontalSpacing;
  CGFloat _verticalSpacing;
}

@property (nonatomic, retain) NSColor *backgroundColor;
@property (nonatomic, assign) CGFloat cornerRadius;
@property (nonatomic, assign) CGFloat borderHeight;
@property (nonatomic, assign) CGFloat borderWidth;
@property (nonatomic, assign) BOOL horizontal;
@property (nonatomic, readonly) NSSize contentSize;

- (void)setMultiplierForHorizontalSpacing:(double)horizontalMultiplier
             multiplierForVerticalSpacing:(double)verticalMultiplier
                            candidateFont:(NSFont *)font;

-(void)setContents:(NSArray *)contents;

@end


@implementation SquirrelView

@synthesize backgroundColor = _backgroundColor;
@synthesize cornerRadius = _cornerRadius;
@synthesize borderHeight = _borderHeight;
@synthesize borderWidth = _borderWidth;
@synthesize horizontal = _horizontal;
@synthesize contentSize = _contentSize;

-(NSColor *)backgroundColor
{
  if (_backgroundColor != nil) {
    return _backgroundColor;
  }
  
  return [NSColor windowBackgroundColor];
}

-(CGFloat)borderHeight
{
  return MAX(_borderHeight, _cornerRadius);
}

-(CGFloat)borderWidth
{
  return MAX(_borderWidth, _cornerRadius);
}

- (void)setMultiplierForHorizontalSpacing:(double)horizontalMultiplier
             multiplierForVerticalSpacing:(double)verticalMultiplier
                            candidateFont:(NSFont *)font
{
  CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFDictionarySetValue(attributes, kCTFontAttributeName, font);
  
  CFAttributedStringRef attributedString = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("m"), attributes);
  CFRelease(attributes);
  
  CTLineRef line = CTLineCreateWithAttributedString(attributedString);
  CFRelease(attributedString);
  
  CGFloat ascent, descent, leading;
  double width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
  CFRelease(line);
  
  _horizontalSpacing = width * horizontalMultiplier;
  _verticalSpacing = (descent + leading) * verticalMultiplier;
}

-(void)setContents:(NSArray *)contents
{
  if (_candidates != NULL) {
    NSUInteger i;
    for (i = 0; i < _candidateCount; i++) {
      CFRelease(_candidates[i].line);
      if (_candidates[i].bgColor != NULL) CGColorRelease(_candidates[i].bgColor);
    }
    
    free(_candidates);
    _candidates = NULL;
    _candidateCount = 0;
    _contentSize = NSZeroSize;
  }
  
  if (contents == nil || [contents count] == 0) {
    return;
  }
  
  _candidateCount = [contents count];
  _candidates = (SquirrelCandidate *)calloc(_candidateCount, sizeof(SquirrelCandidate));
  
  NSUInteger i = 0;
  for (i = 0; i < _candidateCount; i++) {
    NSAttributedString *attributedString = [contents objectAtIndex:i];
    
    __block NSRange bgRange;
    __block NSColor *bgColor = nil;
    [attributedString enumerateAttribute:NSBackgroundColorAttributeName
                                 inRange:NSMakeRange(0, [attributedString length])
                                 options:0
                              usingBlock:^(id value, NSRange range, BOOL *stop) {
                                if (bgColor != nil) return; // should only occur once for now...
                                bgColor = [value retain];
                                bgRange = range;
                              }];
    
    _candidates[i].line = CTLineCreateWithAttributedString((CFAttributedStringRef)attributedString);
    _candidates[i].width = CTLineGetTypographicBounds(_candidates[i].line, &_candidates[i].ascent, &_candidates[i].descent, &_candidates[i].leading);
    _candidates[i].height = _candidates[i].ascent + _candidates[i].descent + _candidates[i].leading;
    
    if (_horizontal) {
      _contentSize.width += _candidates[i].width;
      _contentSize.height = MAX(_contentSize.height, _candidates[i].height);
    }
    else {
      _contentSize.width = MAX(_contentSize.width, _candidates[i].width);
      _contentSize.height += _candidates[i].height;
    }
    
    if (bgColor != nil) {
      CGFloat components[4];
      [[bgColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getComponents:components];
      [bgColor release];
      
      CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
      _candidates[i].bgColor = CGColorCreate(colorSpace, components);
      CGColorSpaceRelease(colorSpace);
      
      CFIndex startIndex = bgRange.location;
      CFIndex endIndex = NSMaxRange(bgRange);
      
      CGFloat startOffset = CTLineGetOffsetForStringIndex(_candidates[i].line, startIndex, NULL);
      CGFloat endOffset;
      if (endIndex < [attributedString length]) {
        endOffset = CTLineGetOffsetForStringIndex(_candidates[i].line, endIndex, NULL);
      }
      else {
        endOffset = _candidates[i].width;
      }
      
      _candidates[i].bgRect = CGRectMake(startOffset, -_candidates[i].descent, endOffset - startOffset, _candidates[i].height);
    }
  }
    
  if (_horizontal) {
    _contentSize.width += (_candidateCount - 1) * _horizontalSpacing;
  }
  else {
    _contentSize.height += (_candidateCount - 1) * _verticalSpacing;
  }
  
  [self setNeedsDisplay:YES];
}

-(void)drawRect:(NSRect)rect
{
  if (_candidates == NULL) {
    return;
  }
  
  [[self backgroundColor] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:_cornerRadius yRadius:_cornerRadius] fill];
  
  CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  CGContextSaveGState(ctx);
  CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
  
  CGSize offset = CGSizeMake([self borderWidth], [self borderHeight]);
  NSInteger i;
  
  if (_horizontal) {
    for (i = 0; i < _candidateCount; i++) {
      CGFloat xOffset = offset.width;
      CGFloat yOffset = offset.height + _candidates[i].descent;
      
      offset.width += _candidates[i].width;
      offset.width += _horizontalSpacing;
      
      if (_candidates[i].bgColor != NULL) {
        CGContextSetFillColorWithColor(ctx, _candidates[i].bgColor);
        CGContextFillRect(ctx, CGRectOffset(_candidates[i].bgRect, xOffset, yOffset));
      }
      
      CGContextSetTextPosition(ctx, xOffset, yOffset);
      CTLineDraw(_candidates[i].line, ctx);
    }
  }
  else {
    for (i = _candidateCount - 1; i >= 0; i--) {
      CGFloat xOffset = offset.width;
      CGFloat yOffset = offset.height + _candidates[i].descent;
      
      offset.height += _candidates[i].height;
      offset.height += _verticalSpacing;
      
      if (_candidates[i].bgColor != NULL) {
        CGContextSetFillColorWithColor(ctx, _candidates[i].bgColor);
        CGContextFillRect(ctx, CGRectOffset(_candidates[i].bgRect, xOffset, yOffset));
      }
      
      CGContextSetTextPosition(ctx, xOffset, yOffset);
      CTLineDraw(_candidates[i].line, ctx);
    }
  }
  
  CGContextRestoreGState(ctx);
}

@end


@implementation SquirrelPanel

-(id)init
{
  //NSLog(@"SqurrelPanel init");
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
  
  _candidateFormat = @"%c. %@";
  return self;
}

-(void)show
{
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
  if ([candidates count] == 0) {
    [self hide];
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
  
  NSMutableArray *contents = [[NSMutableArray alloc] initWithCapacity:[candidates count]];
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
    
    [contents addObject:line];
    [line release];
  }
  
  [(SquirrelView*)_view setContents:contents];
  [contents release];
  [self show];
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
  struct {
    CGFloat r, g, b, a;
  } f, b;
  
  [[foregroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&f.r
                                                                     green:&f.g
                                                                      blue:&f.b
                                                                     alpha:&f.a];
  
  [[backgroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace] getRed:&b.r
                                                                     green:&b.g
                                                                      blue:&b.b
                                                                     alpha:&b.a];
  
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
  [(SquirrelView *)_view setHorizontal:style->horizontal];
  
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
  
  [(SquirrelView *)_view setMultiplierForHorizontalSpacing:style->horizontalSpacingMultiplier
                              multiplierForVerticalSpacing:style->verticalSpacingMultiplier
                                             candidateFont:font];
  
  [_window setAlphaValue:style->alpha];
  
  [style->candidateFormat retain];
  [_candidateFormat release];
  _candidateFormat = style->candidateFormat ? style->candidateFormat : @"%c. %@";
}

@end
