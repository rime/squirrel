#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath {
  NSInteger i, numElements;
  // Need to begin a path here.
  CGPathRef immutablePath = NULL;

  // Then draw the path elements.
  numElements = [self elementCount];
  if (numElements > 0) {
    CGMutablePathRef path = CGPathCreateMutable();
    NSPoint points[3];
    BOOL didClosePath = YES;
    for (i = 0; i < numElements; i++) {
      switch ([self elementAtIndex:i associatedPoints:points]) {
      case NSMoveToBezierPathElement:
        CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
        break;
      case NSLineToBezierPathElement:
        CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
        didClosePath = NO;
        break;
      case NSCurveToBezierPathElement:
        CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                              points[1].x, points[1].y,
                              points[2].x, points[2].y);
        didClosePath = NO;
        break;
      case NSClosePathBezierPathElement:
        CGPathCloseSubpath(path);
        didClosePath = YES;
        break;
      }
    }

      // Be sure the path is closed or Quartz may not do valid hit detection.
    if (!didClosePath) {
        CGPathCloseSubpath(path);
    }
    immutablePath = CGPathCreateCopy(path);
    CGPathRelease(path);
  }
  return immutablePath;
}
@end

static const CGFloat kOffsetHeight = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c. %@";

@interface SquirrelTheme : NSObject

@property(nonatomic, assign) BOOL native;

@property(nonatomic, strong, readonly) NSColor *backgroundColor;
@property(nonatomic, strong, readonly) NSColor *highlightedStripColor;
@property(nonatomic, strong, readonly) NSColor *highlightedPreeditColor;
@property(nonatomic, strong, readonly) NSColor *preeditBackgroundColor;
@property(nonatomic, strong, readonly) NSColor *borderColor;

@property(nonatomic, readonly) CGFloat cornerRadius;
@property(nonatomic, readonly) CGFloat hilitedCornerRadius;
@property(nonatomic, readonly) NSSize edgeInset;
@property(nonatomic, readonly) CGFloat borderWidth;
@property(nonatomic, readonly) CGFloat linespace;
@property(nonatomic, readonly) CGFloat preeditLinespace;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) BOOL translucency;
@property(nonatomic, readonly) BOOL linear;
@property(nonatomic, readonly) BOOL vertical;
@property(nonatomic, readonly) BOOL inlinePreedit;
@property(nonatomic, readonly) BOOL inlineCandidate;

@property(nonatomic, strong, readonly) NSDictionary *attrs;
@property(nonatomic, strong, readonly) NSDictionary *highlightedAttrs;
@property(nonatomic, strong, readonly) NSDictionary *labelAttrs;
@property(nonatomic, strong, readonly) NSDictionary *labelHighlightedAttrs;
@property(nonatomic, strong, readonly) NSDictionary *commentAttrs;
@property(nonatomic, strong, readonly) NSDictionary *commentHighlightedAttrs;
@property(nonatomic, strong, readonly) NSDictionary *preeditAttrs;
@property(nonatomic, strong, readonly) NSDictionary *preeditHighlightedAttrs;
@property(nonatomic, strong, readonly) NSDictionary *pagingAttrs;
@property(nonatomic, strong, readonly) NSParagraphStyle *paragraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *preeditParagraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *pagingParagraphStyle;

@property(nonatomic, strong, readonly) NSString *prefixLabelFormat, *suffixLabelFormat;

- (void)setCandidateFormat:(NSString *)candidateFormat;

- (void)setBackgroundColor:(NSColor *)backgroundColor
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor;

- (void)setCornerRadius:(CGFloat)cornerRadius
    hilitedCornerRadius:(CGFloat)hilitedCornerRadius
              edgeInset:(NSSize)edgeInset
            borderWidth:(CGFloat)borderWidth
              linespace:(CGFloat)linespace
       preeditLinespace:(CGFloat)preeditLinespace
                  alpha:(CGFloat)alpha
           translucency:(BOOL)translucency
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate;

- (void)       setAttrs:(NSMutableDictionary *)attrs
             labelAttrs:(NSMutableDictionary *)labelAttrs
       highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
  labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
           commentAttrs:(NSMutableDictionary *)commentAttrs
commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
           preeditAttrs:(NSMutableDictionary *)preeditAttrs
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
            pagingAttrs:(NSMutableDictionary *)pagingAttrs;

- (void) setParagraphStyle:(NSParagraphStyle *)paragraphStyle
     preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle
      pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle;

@end

@implementation SquirrelTheme

- (void)setCandidateFormat:(NSString *)candidateFormat {
  // in the candiate format, everything other than '%@' is considered part of the label
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@" options:NSLiteralSearch];
  if (candidateRange.location == NSNotFound) {
    _prefixLabelFormat = candidateFormat;
    _suffixLabelFormat = nil;
    return;
  }
  if (candidateRange.location > 0) {
    // everything before '%@' is prefix label
    NSRange prefixLabelRange = NSMakeRange(0, candidateRange.location);
    _prefixLabelFormat = [candidateFormat substringWithRange:prefixLabelRange];
  } else {
    _prefixLabelFormat = nil;
  }
  if (NSMaxRange(candidateRange) < candidateFormat.length) {
    // everything after '%@' is suffix label
    NSRange suffixLabelRange = NSMakeRange(NSMaxRange(candidateRange),
                                           candidateFormat.length - NSMaxRange(candidateRange));
    _suffixLabelFormat = [candidateFormat substringWithRange:suffixLabelRange];
  } else {
    // '%@' is at the end, so suffix label does not exist
    _suffixLabelFormat = nil;
  }
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor {
  _backgroundColor = backgroundColor;
  _highlightedStripColor = highlightedStripColor;
  _highlightedPreeditColor = highlightedPreeditColor;
  _preeditBackgroundColor = preeditBackgroundColor;
  _borderColor = borderColor;
}

- (void)setCornerRadius:(double)cornerRadius
    hilitedCornerRadius:(double)hilitedCornerRadius
              edgeInset:(NSSize)edgeInset
            borderWidth:(double)borderWidth
              linespace:(double)linespace
       preeditLinespace:(double)preeditLinespace
                  alpha:(CGFloat)alpha
           translucency:(BOOL)translucency
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate {
  _cornerRadius = cornerRadius;
  _hilitedCornerRadius = hilitedCornerRadius;
  _edgeInset = edgeInset;
  _borderWidth = borderWidth;
  _linespace = linespace;
  _alpha = alpha;
  _translucency = translucency;
  _preeditLinespace = preeditLinespace;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
  _inlineCandidate = inlineCandidate;
}

- (void)       setAttrs:(NSMutableDictionary *)attrs
             labelAttrs:(NSMutableDictionary *)labelAttrs
       highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
  labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
           commentAttrs:(NSMutableDictionary *)commentAttrs
commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
           preeditAttrs:(NSMutableDictionary *)preeditAttrs
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
            pagingAttrs:(NSMutableDictionary *)pagingAttrs {
  _attrs = attrs;
  _labelAttrs = labelAttrs;
  _highlightedAttrs = highlightedAttrs;
  _labelHighlightedAttrs = labelHighlightedAttrs;
  _commentAttrs = commentAttrs;
  _commentHighlightedAttrs = commentHighlightedAttrs;
  _preeditAttrs = preeditAttrs;
  _preeditHighlightedAttrs = preeditHighlightedAttrs;
  _pagingAttrs = pagingAttrs;
}

- (void) setParagraphStyle:(NSParagraphStyle *)paragraphStyle
     preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle
      pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle {
  _paragraphStyle = paragraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
  _pagingParagraphStyle = pagingParagraphStyle;
}

@end

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextView *textView;
@property(nonatomic, readonly) NSRange highlightedRange;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) BOOL isDark;
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, assign) CGFloat seperatorWidth;
@property(nonatomic, readonly) CAShapeLayer *shape;

- (BOOL)isFlipped;
@property (NS_NONATOMIC_IOSONLY, getter=isFlipped, readonly) BOOL flipped;
- (void)     drawViewWith:(NSRange)hilightedRange
             preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange
              pagingRange:(NSRange)pagingRange;
- (NSRect)contentRectForRange:(NSRange)range;
@end

@implementation SquirrelView

SquirrelTheme *_defaultTheme;
SquirrelTheme *_darkTheme;

// Need flipped coordinate system, as required by textStorage
- (BOOL)isFlipped {
  return YES;
}

- (BOOL)isDark {
  if (@available(macOS 10.14, *)) {
    if ([NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua) {
      return YES;
    }
  }
  return NO;
}

- (SquirrelTheme *)selectTheme:(BOOL)isDark {
  return isDark ? _darkTheme : _defaultTheme;
}

- (SquirrelTheme *)currentTheme {
  return [self selectTheme:self.isDark];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
  }
  _textView = [[NSTextView alloc] initWithFrame:frameRect];
  // Use textStorage to store text and manage all text layout and draws
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSZeroSize];
  textContainer.lineFragmentPadding = 0.0;
  _textView.drawsBackground = NO;
  _textView.selectable = NO;
  [_textView replaceTextContainer:textContainer];
  _textView.layoutManager.backgroundLayoutEnabled = YES;
  _textView.layoutManager.usesFontLeading = NO;
  _textView.layoutManager.typesetterBehavior = NSTypesetterBehavior_10_4;
  _defaultTheme = [[SquirrelTheme alloc] init];
  _shape = [[CAShapeLayer alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
//    _textView.usesAdaptiveColorMappingForDarkAppearance = YES;
  }
  return self;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  NSRange glyphRange = [_textView.layoutManager glyphRangeForTextContainer:_textView.textContainer];
  NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
  return rect;
}

// Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
  return rect;
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void)     drawViewWith:(NSRange)hilightedRange
             preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange
              pagingRange:(NSRange)pagingRange {
  _highlightedRange = hilightedRange;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  _pagingRange = pagingRange;
  self.needsDisplay = YES;
}

// A tweaked sign function, to winddown corner radius when the size is small
double sign(double number) {
  if (number >= 2) {
    return 1;
  } else if (number <= -2) {
    return -1;
  } else {
    return number / 2;
  }
}

// Bezier cubic curve, which has continuous roundness
NSBezierPath *drawSmoothLines(NSArray<NSValue *> *vertex, CGFloat alpha, CGFloat beta) {
  NSBezierPath *path = [NSBezierPath bezierPath];
  if (vertex.count < 1)
    return path;
  NSPoint previousPoint = (vertex[vertex.count-1]).pointValue;
  NSPoint point = (vertex[0]).pointValue;
  NSPoint nextPoint;
  NSPoint control1;
  NSPoint control2;
  NSPoint target = previousPoint;
  NSPoint diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
  if (ABS(diff.x) >= ABS(diff.y)) {
    target.x += sign(diff.x/beta)*beta;
  } else {
    target.y += sign(diff.y/beta)*beta;
  }
  [path moveToPoint:target];
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
    previousPoint = (vertex[(vertex.count+i-1)%vertex.count]).pointValue;
    point = (vertex[i]).pointValue;
    nextPoint = (vertex[(i+1)%vertex.count]).pointValue;
    target = point;
    control1 = point;
    diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
    if (ABS(diff.x) >= ABS(diff.y)) {
      target.x -= sign(diff.x/beta)*beta;
      control1.x -= sign(diff.x/beta)*alpha;
    } else {
      target.y -= sign(diff.y/beta)*beta;
      control1.y -= sign(diff.y/beta)*alpha;
    }
    [path lineToPoint:target];
    target = point;
    control2 = point;
    diff = NSMakePoint(nextPoint.x - point.x, nextPoint.y - point.y);
    if (ABS(diff.x) > ABS(diff.y)) {
      control2.x += sign(diff.x/beta)*alpha;
      target.x += sign(diff.x/beta)*beta;
    } else {
      control2.y += sign(diff.y/beta)*alpha;
      target.y += sign(diff.y/beta)*beta;
    }
    [path curveToPoint:target controlPoint1:control1 controlPoint2:control2];
  }
  [path closePath];
  return path;
}

NSArray<NSValue *> *rectVertex(NSRect rect) {
  return @[
    @(rect.origin),
    @(NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)),
    @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)),
    @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y))
  ];
}

void xyTranslation(NSMutableArray<NSValue *> *shape, NSPoint direction) {
  for (NSUInteger i = 0; i < shape.count; i += 1) {
    NSPoint point = (shape[i]).pointValue;
    point.x += direction.x;
    point.y += direction.y;
    shape[i] = @(point);
  }
}

BOOL nearEmptyRect(NSRect rect) {
  return rect.size.height * rect.size.width < 1;
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is complete lines in the middle
- (void)multilineRectForRange:(NSRange)charRange leadingRect:(NSRect *)leadingRect bodyRect:(NSRect *)bodyRect trailingRect:(NSRect *)trailingRect {
  NSLayoutManager *layoutManager = _textView.layoutManager;
  NSTextContainer *textContainer = _textView.textContainer;
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  NSRange fullRangeInBoundingRect = [layoutManager glyphRangeForBoundingRect:boundingRect inTextContainer:textContainer];
  *leadingRect = NSZeroRect;
  *bodyRect = boundingRect;
  *trailingRect = NSZeroRect;
  if (boundingRect.origin.x <= 1 && fullRangeInBoundingRect.location < glyphRange.location) {
    *leadingRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(fullRangeInBoundingRect.location, glyphRange.location-fullRangeInBoundingRect.location) inTextContainer:textContainer];
    if (!nearEmptyRect(*leadingRect)) {
      bodyRect->size.height -= leadingRect->size.height;
      bodyRect->origin.y += leadingRect->size.height;
    }
    double rightEdge = NSMaxX(*leadingRect);
    leadingRect->origin.x = rightEdge;
    leadingRect->size.width = bodyRect->origin.x + bodyRect->size.width - rightEdge;
  }
  if (NSMaxRange(fullRangeInBoundingRect) > NSMaxRange(glyphRange)) {
    *trailingRect = [layoutManager boundingRectForGlyphRange:
                     NSMakeRange(NSMaxRange(glyphRange), NSMaxRange(fullRangeInBoundingRect)-NSMaxRange(glyphRange))
                                             inTextContainer:textContainer];
    if (!nearEmptyRect(*trailingRect)) {
      bodyRect->size.height -= trailingRect->size.height;
    }
    double leftEdge = NSMinX(*trailingRect);
    trailingRect->origin.x = bodyRect->origin.x;
    trailingRect->size.width = leftEdge - bodyRect->origin.x;
  } else if (NSMaxRange(fullRangeInBoundingRect) == NSMaxRange(glyphRange)) {
    *trailingRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:NULL];
    if (NSMaxX(*trailingRect) >= NSMaxX(boundingRect) - 1) {
      *trailingRect = NSZeroRect;
    } else if (!nearEmptyRect(*trailingRect)) {
      bodyRect->size.height -= trailingRect->size.height;
    }
  }
  NSRect lastLineRect = nearEmptyRect(*trailingRect) ? *bodyRect : *trailingRect;
  lastLineRect.size.width = textContainer.size.width - lastLineRect.origin.x;
  NSRange lastLineRange = [layoutManager glyphRangeForBoundingRect:lastLineRect inTextContainer:textContainer];
  NSGlyphProperty glyphProperty = [layoutManager propertyForGlyphAtIndex:NSMaxRange(lastLineRange)-1];
  while (lastLineRange.length>0 && (glyphProperty & NSGlyphPropertyElastic && glyphProperty & NSGlyphPropertyControlCharacter)) {
    lastLineRange.length -= 1;
    glyphProperty = [layoutManager propertyForGlyphAtIndex:NSMaxRange(lastLineRange)-1];
  }
  if (NSMaxRange(lastLineRange) == NSMaxRange(glyphRange)) {
    if (!nearEmptyRect(*trailingRect)) {
      *trailingRect = lastLineRect;
    } else {
      *bodyRect = lastLineRect;
    }
  }
  NSSize edgeInset = self.currentTheme.edgeInset;
  leadingRect->origin.x += edgeInset.width;
  leadingRect->origin.y += edgeInset.height;
  bodyRect->origin.x += edgeInset.width;
  bodyRect->origin.y += edgeInset.height;
  trailingRect->origin.x += edgeInset.width;
  trailingRect->origin.y += edgeInset.height;
}

// Based on the 3 boxes from multilineRectForRange, calculate the vertex of the polygon containing the text in range
NSArray<NSValue *> * multilineRectVertex(NSRect leadingRect, NSRect bodyRect, NSRect trailingRect) {
  if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && nearEmptyRect(trailingRect)) {
    return rectVertex(leadingRect);
  } else if (nearEmptyRect(bodyRect) && nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect)) {
    return rectVertex(trailingRect);
  } else if (nearEmptyRect(leadingRect) && nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    return rectVertex(bodyRect);
  } else if (nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], bodyVertex[2], bodyVertex[1]];
  } else if (nearEmptyRect(leadingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], bodyVertex[3], bodyVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && nearEmptyRect(bodyRect) && NSMaxX(leadingRect)>NSMinX(trailingRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[trailingVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], leadingVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[bodyVertex[0], leadingVertex[1], leadingVertex[0], leadingVertex[3], bodyVertex[2], trailingVertex[3], trailingVertex[2], trailingVertex[1]];
  } else {
    return @[];
  }
}

// If the point is outside the innerBox, will extend to reach the outerBox
void expand(NSMutableArray<NSValue *> *vertex, NSRect innerBorder, NSRect outerBorder) {
  for (NSUInteger i = 0; i < vertex.count; i += 1){
    NSPoint point = (vertex[i]).pointValue;
    if (point.x < innerBorder.origin.x) {
      point.x = outerBorder.origin.x;
    } else if (point.x > innerBorder.origin.x+innerBorder.size.width) {
      point.x = outerBorder.origin.x+outerBorder.size.width;
    }
    if (point.y < innerBorder.origin.y) {
      point.y = outerBorder.origin.y;
    } else if (point.y > innerBorder.origin.y+innerBorder.size.height) {
      point.y = outerBorder.origin.y+outerBorder.size.height;
    }
    [vertex replaceObjectAtIndex:i withObject:@(point)];
    vertex[i] = @(point);
  }
}

// All draws happen here
- (void)drawRect:(NSRect)dirtyRect {
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPath2;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *highlightedPreeditPath2;
  NSBezierPath *preeditPath;
  NSBezierPath *pagingPath;
  NSBezierPath *candidatePath;
  SquirrelTheme * theme = self.currentTheme;
  
  [NSBezierPath setDefaultLineWidth:0];
  NSRect backgroundRect = dirtyRect;
  NSRect textField = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);
  
  // Draw preedit Rect
  NSRect preeditRect = NSZeroRect;
  if (_preeditRange.length > 0) {
    preeditRect = [self contentRectForRange:_preeditRange];
    preeditRect.size.width = backgroundRect.size.width;
    preeditRect.size.height += theme.edgeInset.height/2 + theme.preeditLinespace;
    preeditRect.origin = backgroundRect.origin;
    if (_highlightedRange.length == 0) {
      preeditRect.size.height += theme.edgeInset.height*3/2 - theme.preeditLinespace;
    }
    if (theme.preeditBackgroundColor != nil) {
      preeditPath = drawSmoothLines(rectVertex(preeditRect), 0, 0);
    }
  }

  // Draw paging Rect
  NSRect pagingRect = NSZeroRect;
  if (_pagingRange.length > 0) {
    pagingRect = [self contentRectForRange:_pagingRange];
    pagingRect.size.width = backgroundRect.size.width;
    pagingRect.size.height += theme.edgeInset.height/2;
    pagingRect.origin.x = backgroundRect.origin.x;
    pagingRect.origin.y += theme.edgeInset.height*3/2;
    if (theme.preeditBackgroundColor != nil) {
      pagingPath = drawSmoothLines(rectVertex(pagingRect), 0, 0);
    }
  }

  // Draw candidate Rect
  CGFloat halfLinespace = theme.linespace / 2;
  NSRect candidateRect = backgroundRect;
  candidateRect.size.height -= preeditRect.size.height + pagingRect.size.height;
  candidateRect.origin.y += preeditRect.size.height;
  if (_preeditRange.length == 0) {
    candidateRect.size.height -= theme.edgeInset.height/2;
    candidateRect.origin.y += theme.edgeInset.height/2;
  }

  NSRect outerBox = NSInsetRect(candidateRect, theme.edgeInset.width, theme.edgeInset.height/2);
  NSRect innerBox = NSInsetRect(outerBox, theme.hilitedCornerRadius+1, theme.hilitedCornerRadius+1);
//  if (_preeditRange.length == 0) {
//    innerBox.origin.y += theme.edgeInset.height;
//    innerBox.size.height -= theme.edgeInset.height;
//    outerBox.origin.y += theme.edgeInset.height / 2;
//    outerBox.size.height -= theme.edgeInset.height / 2;
//  }
  
  if (theme.preeditBackgroundColor != NULL) {
    candidatePath = drawSmoothLines(rectVertex(outerBox), 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
  }

  // Drawhighlighted Rect
  if (_highlightedRange.length > 0 && theme.highlightedStripColor != nil) {
    if (theme.linear) {
      NSRect leadingRect;
      NSRect bodyRect;
      NSRect trailingRect;
      [self multilineRectForRange:_highlightedRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

      NSMutableArray<NSValue *> *highlightedPoints;
      NSMutableArray<NSValue *> *highlightedPoints2;
      // Handles the special case where containing boxes are separated
      if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPoints = [rectVertex(leadingRect) mutableCopy];
        highlightedPoints2 = [rectVertex(trailingRect) mutableCopy];
      } else {
        highlightedPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
      }

//      xyTranslation(highlightedPoints, NSMakePoint(0, -halfLinespace));
//      xyTranslation(highlightedPoints2, NSMakePoint(0, -halfLinespace));
//      innerBox.size.height -= halfLinespace;
      // Expand the boxes to reach proper border
//      expand(highlightedPoints, innerBox, outerBox);
//      expand(highlightedPoints2, innerBox, outerBox);
      highlightedPath = drawSmoothLines(highlightedPoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
      if (highlightedPoints2.count > 0) {
        highlightedPath2 = drawSmoothLines(highlightedPoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
      }
    } else {
      NSRect highlightedRect = [self contentRectForRange:_highlightedRange];
      highlightedRect.size.width = textField.size.width;
//      highlightedRect.size.height += halfLinespace;
      highlightedRect.origin.x = textField.origin.x;
      highlightedRect.origin.y += theme.edgeInset.height;
      //      if (_highlightedRange.location+_highlightedRange.length == _text.length) {
      //        highlightedRect.size.height += theme.edgeInset.height - halfLinespace;
      //      }
      //      if (_highlightedRange.location - ((_preeditRange.location == NSNotFound ? 0 : _preeditRange.location)+_preeditRange.length) <= 1) {
      //        if (_preeditRange.length == 0) {
      //          highlightedRect.size.height += theme.edgeInset.height - halfLinespace;
      //          highlightedRect.origin.y -= theme.edgeInset.height - halfLinespace;
      //        } else {
      //          highlightedRect.size.height += theme.hilitedCornerRadius / 2;
      //          highlightedRect.origin.y -= theme.hilitedCornerRadius / 2;
      //        }
      //      }
      NSMutableArray<NSValue *> *highlightedPoints = [rectVertex(highlightedRect) mutableCopy];
      expand(highlightedPoints, innerBox, outerBox);
      highlightedPath = drawSmoothLines(highlightedPoints, theme.hilitedCornerRadius*0.3, theme.hilitedCornerRadius*1.4);
    }
  }

  // Draw highlighted part of preedit text
  if (_highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:_highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

    NSRect outerBox = NSInsetRect(preeditRect, theme.edgeInset.width/2, theme.edgeInset.height/2);
    NSRect innerBox = NSInsetRect(outerBox, theme.edgeInset.width/2 + 1, theme.edgeInset.height/2 + 1);

    NSMutableArray<NSValue *> *highlightedPreeditPoints;
    NSMutableArray<NSValue *> *highlightedPreeditPoints2;
    // Handles the special case where containing boxes are separated
    if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
      highlightedPreeditPoints = [rectVertex(leadingRect) mutableCopy];
      highlightedPreeditPoints2 = [rectVertex(trailingRect) mutableCopy];
    } else {
      highlightedPreeditPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
    }
    // Expand the boxes to reach proper border
    expand(highlightedPreeditPoints, innerBox, outerBox);
    expand(highlightedPreeditPoints2, innerBox, outerBox);
    highlightedPreeditPath = drawSmoothLines(highlightedPreeditPoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    if (highlightedPreeditPoints2.count > 0) {
      highlightedPreeditPath2 = drawSmoothLines(highlightedPreeditPoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    }
  }

  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), theme.cornerRadius*0.3, theme.cornerRadius*1.4);
  _shape.path = backgroundPath.quartzPath;
  
  NSRect borderRect = NSInsetRect(backgroundRect, theme.edgeInset.width/2 - theme.borderWidth/2, theme.edgeInset.height/2 - theme.borderWidth/2);
  borderPath = drawSmoothLines(rectVertex(borderRect), 0.3*theme.cornerRadius, 1.4*theme.cornerRadius);
  borderPath.lineWidth = theme.borderWidth;
  // Nothing should extend beyond backgroundPath
  [backgroundPath addClip];
  
  // This block of code enables independent transparencies in highlighted colour and background colour.
  // Disabled because of the flaw: edges or rounded corners of the heighlighted area are rendered with undesirable shadows.
#if 0
  // Calculate intersections.
  if (![highlightedPath isEmpty]) {
    [backgroundPath appendBezierPath:[highlightedPath copy]];
    if (![highlightedPath2 isEmpty]) {
      [backgroundPath appendBezierPath:[highlightedPath2 copy]];
    }
  }

  if (![preeditPath isEmpty]) {
    [backgroundPath appendBezierPath:[preeditPath copy]];
  }

  if (![highlightedPreeditPath isEmpty]) {
    if (preeditPath != nil) {
      [preeditPath appendBezierPath:[highlightedPreeditPath copy]];
    } else {
      [backgroundPath appendBezierPath:[highlightedPreeditPath copy]];
    }
    if (![highlightedPreeditPath2 isEmpty]) {
      if (preeditPath != nil) {
        [preeditPath appendBezierPath:[highlightedPreeditPath2 copy]];
      } else {
        [backgroundPath appendBezierPath:[highlightedPreeditPath2 copy]];
      }
    }
  }
  [backgroundPath setWindingRule:NSEvenOddWindingRule];
  [preeditPath setWindingRule:NSEvenOddWindingRule];
#endif

  if (theme.preeditBackgroundColor && ![pagingPath isEmpty]) {
    [theme.preeditBackgroundColor setFill];
    [backgroundPath fill];
    [theme.backgroundColor setFill];
    [candidatePath fill];
  } else {
    [theme.backgroundColor setFill];
    [backgroundPath fill];
  }
  if (theme.highlightedStripColor && ![highlightedPath isEmpty]) {
    [theme.highlightedStripColor setFill];
    [highlightedPath fill];
    if (![highlightedPath2 isEmpty]) {
      [highlightedPath2 fill];
    }
  }
  if (theme.highlightedPreeditColor && ![highlightedPreeditPath isEmpty]) {
    [theme.highlightedPreeditColor setFill];
    [highlightedPreeditPath fill];
    if (![highlightedPreeditPath2 isEmpty]) {
      [highlightedPreeditPath2 fill];
    }
  }
  if (theme.borderColor && (theme.borderWidth > 0)) {
    [theme.borderColor setStroke];
    [borderPath stroke];
  }

  [_textView setTextContainerInset:theme.edgeInset];
  NSRange glyphRange = [_textView.layoutManager glyphRangeForTextContainer:_textView.textContainer];
  [_textView.layoutManager drawGlyphsForGlyphRange:glyphRange atPoint:textField.origin];

}

@end

@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;

  NSRange _preeditRange;
  NSRect _screenRect;
  CGFloat _maxHeight;
  CGFloat _maxTextWidth;

  NSString *_statusMessage;
  NSTimer *_statusTimer;
}

- (BOOL)linear {
  return _view.currentTheme.linear;
}

- (BOOL)vertical {
  return _view.currentTheme.vertical;
}

- (BOOL)inlinePreedit {
  return _view.currentTheme.inlinePreedit;
}

- (BOOL)inlineCandidate {
  return _view.currentTheme.inlineCandidate;
}

void fixDefaultFont(NSMutableAttributedString *text) {
  [text fixFontAttributeInRange:NSMakeRange(0, text.length)];
  NSRange currentFontRange = NSMakeRange(NSNotFound, 0);
  long i = 0;
  while (i < text.length) {
    NSFont *charFont = [text attribute:NSFontAttributeName atIndex:i effectiveRange:&currentFontRange];
    if ([charFont.fontName isEqualToString:@"AppleColorEmoji"]) {
      NSFontWeight fontWeight = [[charFont.fontDescriptor.fontAttributes objectForKey:NSFontWeightTrait] doubleValue];
      NSFont *defaultFont = [NSFont systemFontOfSize:charFont.pointSize weight:NSFontWeightThin];
      [text addAttribute:NSFontAttributeName value:defaultFont range:currentFontRange];
    }
    i = NSMaxRange(currentFontRange);
  }
}

+ (NSColor *)secondaryTextColor {
  if(@available(macOS 10.10, *)) {
    return [NSColor secondaryLabelColor];
  } else {
    return [NSColor disabledControlTextColor];
  }
}

- (void)initializeUIStyleForDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];
  theme.native = YES;
  theme.candidateFormat = kDefaultCandidateFormat;

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];

  NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
  attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  attrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *highlightedAttrs = [[NSMutableDictionary alloc] init];
  highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedMenuItemTextColor];
  highlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *labelAttrs = [attrs mutableCopy];
  labelAttrs[NSForegroundColorAttributeName] = [NSColor controlAccentColor];
  labelAttrs[NSFontAttributeName] = [NSFont userFixedPitchFontOfSize:kDefaultFontSize];

  NSMutableDictionary *labelHighlightedAttrs = [highlightedAttrs mutableCopy];
  labelHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor alternateSelectedControlTextColor];
  labelHighlightedAttrs[NSFontAttributeName] = [NSFont userFixedPitchFontOfSize:kDefaultFontSize];

  NSMutableDictionary *commentAttrs = [[NSMutableDictionary alloc] init];
  commentAttrs[NSForegroundColorAttributeName] = secondaryTextColor;
  commentAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *commentHighlightedAttrs = [[NSMutableDictionary alloc] init];
  commentHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor alternateSelectedControlTextColor];
  commentHighlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *preeditAttrs = [[NSMutableDictionary alloc] init];
  preeditAttrs[NSForegroundColorAttributeName] = [NSColor textColor];
  preeditAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *preeditHighlightedAttrs = [[NSMutableDictionary alloc] init];
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedTextColor];
  preeditHighlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *pagingAttrs = [[NSMutableDictionary alloc] init];
  pagingAttrs[NSForegroundColorAttributeName] = [NSColor controlAccentColor];
  pagingAttrs[NSFontAttributeName] = [NSFont fontWithName:@"AppleSymbols" size:kDefaultFontSize/1.5];

  NSParagraphStyle *paragraphStyle = [NSParagraphStyle defaultParagraphStyle];
  NSParagraphStyle *preeditParagraphStyle = [NSParagraphStyle defaultParagraphStyle];
  NSParagraphStyle *pagingParagraphStyle = [NSParagraphStyle defaultParagraphStyle];

  [theme          setAttrs:attrs
                labelAttrs:labelAttrs
          highlightedAttrs:highlightedAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs
               pagingAttrs:pagingAttrs];
  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle
      pagingParagraphStyle:pagingParagraphStyle];
}

- (instancetype)init {
  self = [super initWithContentRect:_position
                          styleMask:NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    self.alphaValue = 1.0;
    // _window.level = NSScreenSaverWindowLevel + 1;
    // ^ May fix visibility issue in fullscreen games.
    self.level = CGShieldingWindowLevel();
    self.hasShadow = YES;
    self.opaque = NO;
    self.backgroundColor = [NSColor clearColor];
    NSView *contentView = [[NSView alloc] init];
    _view = [[SquirrelView alloc] initWithFrame:self.contentView.frame];
    if (@available(macOS 10.14, *)) {
      _back = [[NSVisualEffectView alloc] init];
      _back.blendingMode = NSVisualEffectBlendingModeBehindWindow;
      _back.material = NSVisualEffectMaterialHUDWindow;
      _back.state = NSVisualEffectStateActive;
      _back.wantsLayer = YES;
      _back.layer.mask = _view.shape;
      [contentView addSubview:_back];
    }
    [contentView addSubview:_view];

    self.contentView = contentView;
    [self initializeUIStyleForDarkMode:NO];
    if (@available(macOS 10.14, *)) {
      [self initializeUIStyleForDarkMode:YES];
    }
    _maxHeight = 0;
  }
  return self;
}

- (void)getCurrentScreen {
  // get current screen
  _screenRect = [NSScreen mainScreen].frame;
  NSArray *screens = [NSScreen screens];

  NSUInteger i;
  for (i = 0; i < screens.count; ++i) {
    NSRect rect = [screens[i] frame];
    if (NSPointInRect(_position.origin, rect)) {
      _screenRect = rect;
      break;
    }
  }
}

// Get the window size, the windows will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  [self getCurrentScreen];
  SquirrelTheme *theme = _view.currentTheme;

  if (@available(macOS 10.14, *)) {
    NSAppearance *requestedAppearance = theme.native ? nil : [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    if (self.appearance != requestedAppearance) {
      self.appearance = requestedAppearance;
    }
  }

  //Break line if the text is too long, based on screen size.
  CGFloat textWidth = _view.textView.textStorage.size.width;
  NSFont *currentFont = theme.attrs[NSFontAttributeName];
  CGFloat fontScale = currentFont.pointSize / 12;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + fontScale / 12);
  _maxTextWidth = theme.vertical
  ? NSHeight(_screenRect) * textWidthRatio - theme.edgeInset.height * 2
  : NSWidth(_screenRect) * textWidthRatio - theme.edgeInset.width * 2;
  if (textWidth > _maxTextWidth) {
    textWidth = _maxTextWidth;
  }
  _view.textView.textContainer.containerSize = NSMakeSize(textWidth, 0);

  NSRect windowRect;
  // in vertical mode, the width and height are interchanged
  NSRect contentRect = _view.contentRect;
  if ((theme.vertical && NSMinY(_position) / NSHeight(_screenRect) <= textWidthRatio) ||
      (!theme.vertical && NSMinX(_position)+MAX(contentRect.size.width, _maxHeight)+theme.edgeInset.width*2 > NSMaxX(_screenRect))) {
    if (contentRect.size.width >= _maxHeight) {
      _maxHeight = contentRect.size.width;
    } else {
      contentRect.size.width = _maxHeight;
      _view.textView.textContainer.containerSize = NSMakeSize(_maxHeight, 0);
    }
  }

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  bool sweepVertical = NSWidth(_position) > NSHeight(_position);
  if (theme.vertical) {
    windowRect.size = NSMakeSize(contentRect.size.height + theme.edgeInset.height * 2,
                                 contentRect.size.width + theme.edgeInset.width * 2);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMinY(_position) / NSHeight(_screenRect) > textWidthRatio) {
      windowRect.origin.y = NSMinY(_position) - (sweepVertical ? 0 : kOffsetHeight) - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight) + theme.edgeInset.width;
    }
    // Make the first candidate fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
    if (!sweepVertical && _preeditRange.length > 0) {
      NSSize preeditSize = [_view contentRectForRange:_preeditRange].size;
      windowRect.origin.x += preeditSize.height + theme.edgeInset.width / 2;
    }
  } else {
    windowRect.size = NSMakeSize(contentRect.size.width + theme.edgeInset.width * 2,
                                 contentRect.size.height + theme.edgeInset.height * 2);
    if (sweepVertical) {
      // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
      if (NSMinX(_position) / NSWidth(_screenRect) > textWidthRatio) {
        windowRect.origin.x = NSMinX(_position) - kOffsetHeight - NSWidth(windowRect);
      } else {
        windowRect.origin.x = NSMaxX(_position) + kOffsetHeight + theme.edgeInset.width;
      }
      windowRect.origin.y = NSMinY(_position) - NSHeight(windowRect);
    } else {
      windowRect.origin = NSMakePoint(NSMinX(_position) - theme.edgeInset.width / 2,
                                      NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(_screenRect)) {
    windowRect.origin.x = (sweepVertical ? NSMinX(_position) - kOffsetHeight : NSMaxX(_screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(_screenRect)) {
    windowRect.origin.x = sweepVertical ? NSMaxX(_position) + kOffsetHeight : NSMinX(_screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    windowRect.origin.y = (sweepVertical ? NSMinY(_screenRect) : NSMaxY(_position) + kOffsetHeight);
  }
  if (NSMaxY(windowRect) > NSMaxY(_screenRect)) {
    windowRect.origin.y = (sweepVertical ? NSMaxY(_screenRect) : NSMinY(_position) - kOffsetHeight) - NSHeight(windowRect);
  }
  [self setFrame:windowRect display:YES];
  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    self.contentView.boundsRotation = -90.0;
    [self.contentView setBoundsOrigin:NSMakePoint(0, windowRect.size.width)];
  } else {
    self.contentView.boundsRotation = 0;
    [self.contentView setBoundsOrigin:NSMakePoint(0, 0)];
  }
  BOOL translucency = theme.translucency;
  [_view setFrame:self.contentView.bounds];
  if (@available(macOS 10.14, *)) {
    if (translucency) {
      [_back setFrame:self.contentView.bounds];
      _back.appearance = NSApp.effectiveAppearance;
      [_back setHidden:NO];
    } else {
      [_back setHidden:YES];
    }
  }
  self.alphaValue = theme.alpha;
  [self invalidateShadow];
  [self orderFront:nil];
  // voila !
}

- (void)hide {
  if (_statusTimer) {
    [_statusTimer invalidate];
    _statusTimer = nil;
  }
  [self orderOut:nil];
  _maxHeight = 0;
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray *)candidates
           comments:(NSArray *)comments
             labels:(NSArray *)labels
        highlighted:(NSUInteger)index
            pageNum:(NSUInteger)pageNum
           lastPage:(BOOL)lastPage {
  NSUInteger numCandidates = candidates.count;
  if (numCandidates || (preedit && preedit.length)) {
    _statusMessage = nil;
    if (_statusTimer) {
      [_statusTimer invalidate];
      _statusTimer = nil;
    }
  } else {
    if (_statusMessage) {
      [self showStatus:_statusMessage];
      _statusMessage = nil;
    } else if (!_statusTimer) {
      [self hide];
    }
    return;
  }

  SquirrelTheme *theme = _view.currentTheme;

  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  NSUInteger candidateStartPos = 0;
  _preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  // preedit
  if (preedit) {
    NSMutableAttributedString *preeditLine = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringToIndex:selRange.location].precomposedStringWithCanonicalMapping
                                           attributes:theme.preeditAttrs]];
    }
    if (selRange.length > 0) {
      NSUInteger highlightedPreeditStart = preeditLine.length;
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringWithRange:selRange].precomposedStringWithCanonicalMapping
                                           attributes:theme.preeditHighlightedAttrs]];
      highlightedPreeditRange = NSMakeRange(highlightedPreeditStart, preeditLine.length - highlightedPreeditStart);
    }
    if (NSMaxRange(selRange) < preedit.length) {
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringFromIndex:NSMaxRange(selRange)].precomposedStringWithCanonicalMapping
                                           attributes:theme.preeditAttrs]];
    }

    fixDefaultFont(preeditLine);
    NSMutableParagraphStyle *paragraphStylePreedit = [theme.preeditParagraphStyle mutableCopy];
    [preeditLine addAttribute:NSParagraphStyleAttributeName
                        value:paragraphStylePreedit
                        range:NSMakeRange(0, preeditLine.length)];
    
    [text appendAttributedString:preeditLine];
    _preeditRange = NSMakeRange(0, text.length);
    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                   attributes:theme.preeditAttrs]];
    }
    candidateStartPos = text.length;
  }

  // candidates
  CGFloat separatorWidth = NSWidth([[[NSAttributedString alloc] initWithString:(theme.linear ? @"  " : @"\n") attributes:theme.attrs] boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
//  _view.seperatorWidth = separatorWidth;
  CGFloat candidateTextWidth = 0 - separatorWidth;
  NSRange highlightedRange = NSMakeRange(NSNotFound, 0);
  NSUInteger i;
  for (i = 0; i < candidates.count; ++i) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    NSDictionary *attrs = (i == index) ? theme.highlightedAttrs : theme.attrs;
    NSDictionary *labelAttrs = (i == index) ? theme.labelHighlightedAttrs : theme.labelAttrs;
    NSDictionary *commentAttrs = (i == index) ? theme.commentHighlightedAttrs : theme.commentAttrs;
    CGFloat labelWidth = 0.0;

    if (theme.prefixLabelFormat != nil) {
      NSString *prefixLabelString;
      if (labels.count > 1 && i < labels.count) {
        NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        prefixLabelString = [[NSString stringWithFormat:theme.prefixLabelFormat, labelCharacter] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      } else {
        // default: 1. 2. 3...
        NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        prefixLabelString = [[NSString stringWithFormat:labelFormat, (i + 1) % 10] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      }

      [line appendAttributedString:[[NSAttributedString alloc] initWithString:prefixLabelString
                                                                   attributes:labelAttrs]];
      // get the label size for indent
      if (!theme.linear) {
        labelWidth = NSWidth([line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
      }
    }

    NSUInteger candidateStart = line.length;
    NSString *candidate = candidates[i];
    [line appendAttributedString:[[NSAttributedString alloc] initWithString:candidate.precomposedStringWithCanonicalMapping
                                                                 attributes:attrs]];
    // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
    [line addAttribute:NSWritingDirectionAttributeName value:@[@0] range:NSMakeRange(candidateStart, line.length-candidateStart)];

    if (i < comments.count && [comments[i] length] != 0) {
      NSUInteger commentStart = line.length;
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:@" "
                                                                   attributes:commentAttrs]];
      NSString *comment = comments[i];
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:comment.precomposedStringWithCanonicalMapping
                                                                   attributes:commentAttrs]];
    }

    if (theme.suffixLabelFormat != nil) {
      NSString *suffixLabelString;
      if (labels.count > 1 && i < labels.count) {
        NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        suffixLabelString = [[NSString stringWithFormat:theme.suffixLabelFormat, labelCharacter] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      } else {
        // default: 1. 2. 3...
        NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        suffixLabelString = [[NSString stringWithFormat:labelFormat, (i + 1) % 10] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      }
      NSUInteger suffixLabelStart = line.length;
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:suffixLabelString
                                                                   attributes:attrs]];
    }

    fixDefaultFont(line);
    // determine if the line is too wide and line break is needed, based on screen size.
    NSString *separtatorString = @"\u2029";
    if (theme.linear) {
      CGFloat lineWidth = NSWidth([line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
      candidateTextWidth += separatorWidth + lineWidth;
      if (candidateTextWidth > _maxTextWidth) {
        separtatorString = @"\u2028";
        candidateTextWidth = lineWidth;
      } else {
        separtatorString = @"  ";
      }
    }
    NSMutableAttributedString *separator = [[NSMutableAttributedString alloc] initWithString:separtatorString attributes:attrs];

    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    if (i == 0) {
//      paragraphStyleCandidate.paragraphSpacingBefore = theme.linespace / 2;
    } else {
      [text appendAttributedString:separator];
    }
    if (theme.linear) {
//      paragraphStyleCandidate.lineSpacing = theme.linespace;
    } else {
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    [line addAttribute:NSParagraphStyleAttributeName value:paragraphStyleCandidate range:NSMakeRange(0, line.length)];
    if (i == index) {
      highlightedRange = NSMakeRange(text.length, line.length);
    }
    [text appendAttributedString:line];
  }

  // paging indication
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);

  if (numCandidates) {
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.attrs]];

    NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] initWithString:@""
                                                                               attributes:theme.pagingAttrs];

    [paging appendAttributedString:[[NSMutableAttributedString alloc] initWithString:(pageNum ? @"◀" : @"◁")
                                                                          attributes:theme.pagingAttrs]];

    [paging appendAttributedString:[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %lu ", pageNum+1]
                                                                          attributes:theme.pagingAttrs]];

    [paging appendAttributedString:[[NSMutableAttributedString alloc] initWithString:(lastPage ? @"▷" : @"▶")
                                                                          attributes:theme.pagingAttrs]];

    fixDefaultFont(paging);
    NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
//    paragraphStylePaging.minimumLineHeight = minimumHeight(theme.pagingAttrs);
    [paging addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(0, paging.length)];

    pagingRange = NSMakeRange(text.length, paging.length);
    [text appendAttributedString:paging];
  }

  [_view.textView.textStorage setAttributedString:text];
  _view.textView.layoutOrientation = theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  // text done!
  [_view drawViewWith:highlightedRange preeditRange:_preeditRange highlightedPreeditRange:highlightedPreeditRange pagingRange:pagingRange];
  
  [self show];
}

- (void)updateStatus:(NSString *)message {
  _statusMessage = message;
}

- (void)showStatus:(NSString *)message {
  SquirrelTheme *theme = _view.currentTheme;
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:message.precomposedStringWithCanonicalMapping attributes:theme.commentAttrs];

  fixDefaultFont(text);
  [_view.textView.textStorage setAttributedString:text];
  _view.textView.layoutOrientation = theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  [_view drawViewWith:emptyRange preeditRange:emptyRange highlightedPreeditRange:emptyRange pagingRange:emptyRange];
  [self show];

  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  _statusTimer = [NSTimer scheduledTimerWithTimeInterval:kShowStatusDuration
                                                  target:self
                                                selector:@selector(hideStatus:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)hideStatus:(NSTimer *)timer {
  [self hide];
}

static inline NSColor *blendColors(NSColor *foregroundColor,
                                   NSColor *backgroundColor) {
  if (!backgroundColor) {
    // return foregroundColor;
    backgroundColor = [NSColor lightGrayColor];
  }
  return [[foregroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction ofColor:backgroundColor]
          colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static NSFontDescriptor *getFontDescriptor(NSString *fullname) {
  if (fullname == nil) {
    return nil;
  }

  NSArray *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray *validFontDescriptors = [NSMutableArray arrayWithCapacity:fontNames.count];
  for (__strong NSString *fontName in fontNames) {
    fontName = [fontName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([NSFont fontWithName:fontName size:0.0] != nil) {
      // If the font name is not valid, NSFontDescriptor will still create something for us.
      // However, when we draw the actual text, Squirrel will crash if there is any font descriptor
      // with invalid font name.
      [validFontDescriptors addObject:[NSFontDescriptor fontDescriptorWithName:fontName
                                                                          size:0.0]];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  } else if (validFontDescriptors.count == 1) {
    return validFontDescriptors[0];
  }

  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  NSArray *fallbackDescriptors = [validFontDescriptors
      subarrayWithRange:NSMakeRange(1, validFontDescriptors.count - 1)];
  NSDictionary *attributes = @{NSFontCascadeListAttribute : fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static void updateCandidateListLayout(BOOL *isLinearCandidateList, SquirrelConfig *config, NSString *prefix) {
  NSString* candidateListLayout = [config getString:[prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([candidateListLayout isEqualToString:@"stacked"]) {
    *isLinearCandidateList = false;
  } else if ([candidateListLayout isEqualToString:@"linear"]) {
    *isLinearCandidateList = true;
  } else {
    // Deprecated. Not to be confused with text_orientation: horizontal
    NSNumber *horizontal = [config getOptionalBool:[prefix stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinearCandidateList = horizontal.boolValue;
    }
  }
}

static void updateTextOrientation(BOOL *isVerticalText, SquirrelConfig *config, NSString *prefix) {
  NSString* textOrientation = [config getString:[prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVerticalText = false;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVerticalText = true;
  } else {
    NSNumber *vertical = [config getOptionalBool:[prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVerticalText = vertical.boolValue;
    }
  }
}

-(void)loadConfig:(SquirrelConfig *)config forDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];
  [[self class] updateTheme:theme withConfig:config forDarkMode:isDark];
}

+(void)updateTheme:(SquirrelTheme *)theme withConfig:(SquirrelConfig *)config forDarkMode:(BOOL)isDark {
  BOOL linear = NO;
  BOOL vertical = NO;
  updateCandidateListLayout(&linear, config, @"style");
  updateTextOrientation(&vertical, config, @"style");
  BOOL inlinePreedit = [config getBool:@"style/inline_preedit"];
  BOOL inlineCandidate = [config getBool:@"style/inline_candidate"];
  BOOL translucency = [config getBool:@"style/translucency"];
  NSString *candidateFormat = [config getString:@"style/candidate_format"];

  NSString *fontName = [config getString:@"style/font_face"];
  CGFloat fontSize = [config getDouble:@"style/font_point"];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  CGFloat labelFontSize = [config getDouble:@"style/label_font_point"];
  NSString *commentFontName = [config getString:@"style/comment_font_face"];
  CGFloat commentFontSize = [config getDouble:@"style/comment_font_point"];
  CGFloat alpha = fmin(fmax([config getDouble:@"style/alpha"], 0.0), 1.0);
  CGFloat cornerRadius = [config getDouble:@"style/corner_radius"];
  CGFloat hilitedCornerRadius = [config getDouble:@"style/hilited_corner_radius"];
  CGFloat borderHeight = [config getDouble:@"style/border_height"];
  CGFloat borderWidth = [config getDouble:@"style/border_width"];
  CGFloat lineSpacing = fmax([config getDouble:@"style/line_spacing"], hilitedCornerRadius);
  CGFloat spacing = fmax([config getDouble:@"style/spacing"], hilitedCornerRadius);
  CGFloat baseOffset = [config getDouble:@"style/base_offset"];

  NSColor *backgroundColor;
  NSColor *borderColor;
  NSColor *preeditBackgroundColor;
  NSColor *candidateLabelColor;
  NSColor *highlightedCandidateLabelColor;
  NSColor *textColor;
  NSColor *highlightedTextColor;
  NSColor *highlightedBackColor;
  NSColor *candidateTextColor;
  NSColor *highlightedCandidateTextColor;
  NSColor *highlightedCandidateBackColor;
  NSColor *commentTextColor;
  NSColor *highlightedCommentTextColor;

  NSString *colorScheme;
  if (isDark) {
    colorScheme = [config getString:@"style/color_scheme_dark"];
  }
  if (!colorScheme) {
    colorScheme = [config getString:@"style/color_scheme"];
  }
  BOOL isNative = !colorScheme || [colorScheme isEqualToString:@"native"];
  if (!isNative) {
    NSString *prefix = [@"preset_color_schemes/" stringByAppendingString:colorScheme];
    if (@available(macOS 10.12, *)) {
      config.colorSpace = [config getString:[prefix stringByAppendingString:@"/color_space"]];
    }
    backgroundColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]];
    borderColor = [config getColor:[prefix stringByAppendingString:@"/border_color"]];
    preeditBackgroundColor = [config getColor:[prefix stringByAppendingString:@"/preedit_back_color"]];
    textColor = [config getColor:[prefix stringByAppendingString:@"/text_color"]];
    highlightedTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_text_color"]];
    if (highlightedTextColor == nil) {
      highlightedTextColor = textColor;
    }
    highlightedBackColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_back_color"]];
    candidateTextColor =
        [config getColor:[prefix stringByAppendingString:@"/candidate_text_color"]];
    if (candidateTextColor == nil) {
      // in non-inline mode, 'text_color' is for rendering preedit text.
      // if not otherwise specified, candidate text is also rendered in this color.
      candidateTextColor = textColor;
    }
    highlightedCandidateTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_text_color"]];
    if (highlightedCandidateTextColor == nil) {
      highlightedCandidateTextColor = highlightedTextColor;
    }
    highlightedCandidateBackColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_back_color"]];
    if (highlightedCandidateBackColor == nil) {
      highlightedCandidateBackColor = highlightedBackColor;
    }
    commentTextColor =
        [config getColor:[prefix stringByAppendingString:@"/comment_text_color"]];
    highlightedCommentTextColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_comment_text_color"]];

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style' section

    updateCandidateListLayout(&linear, config, prefix);
    updateTextOrientation(&vertical, config, prefix);

    NSNumber *inlinePreeditOverridden =
        [config getOptionalBool:[prefix stringByAppendingString:@"/inline_preedit"]];
    if (inlinePreeditOverridden) {
      inlinePreedit = inlinePreeditOverridden.boolValue;
    }
    NSNumber *inlineCandidateOverridden =
        [config getOptionalBool:[prefix stringByAppendingString:@"/inline_candidate"]];
    if (inlineCandidateOverridden) {
      inlineCandidate = inlineCandidateOverridden.boolValue;
    }
    NSNumber *translucencyOverridden =
        [config getOptionalBool:[prefix stringByAppendingString:@"/translucency"]];
    if (translucencyOverridden) {
      translucency = translucencyOverridden.boolValue;
    }
    NSString *candidateFormatOverridden =
        [config getString:[prefix stringByAppendingString:@"/candidate_format"]];
    if (candidateFormatOverridden) {
      candidateFormat = candidateFormatOverridden;
    }

    NSString *fontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/font_face"]];
    if (fontNameOverridden) {
      fontName = fontNameOverridden;
    }
    NSNumber *fontSizeOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/font_point"]];
    if (fontSizeOverridden) {
      fontSize = fontSizeOverridden.doubleValue;
    }
    NSString *labelFontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
    if (labelFontNameOverridden) {
      labelFontName = labelFontNameOverridden;
    }
    NSNumber *labelFontSizeOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"]];
    if (labelFontSizeOverridden) {
      labelFontSize = labelFontSizeOverridden.doubleValue;
    }
    NSString *commentFontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/comment_font_face"]];
    if (commentFontNameOverridden) {
      commentFontName = commentFontNameOverridden;
    }
    NSNumber *commentFontSizeOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"]];
    if (commentFontSizeOverridden) {
      commentFontSize = commentFontSizeOverridden.doubleValue;
    }
    NSColor *candidateLabelColorOverridden =
        [config getColor:[prefix stringByAppendingString:@"/label_color"]];
    if (candidateLabelColorOverridden) {
      candidateLabelColor = candidateLabelColorOverridden;
    }
    NSColor *highlightedCandidateLabelColorOverridden =
        [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]];
    if (!highlightedCandidateLabelColorOverridden) {
      // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color'
      // are both valid
      highlightedCandidateLabelColorOverridden =
          [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]];
    }
    if (highlightedCandidateLabelColorOverridden) {
      highlightedCandidateLabelColor = highlightedCandidateLabelColorOverridden;
    }
    NSNumber *alphaOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/alpha"]];
    if (alphaOverridden) {
      alpha = fmin(fmax(alphaOverridden.doubleValue, 0.0), 1.0);
    }
    NSNumber *cornerRadiusOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/corner_radius"]];
    if (cornerRadiusOverridden) {
      cornerRadius = cornerRadiusOverridden.doubleValue;
    }
    NSNumber *hilitedCornerRadiusOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]];
    if (hilitedCornerRadiusOverridden) {
      hilitedCornerRadius = hilitedCornerRadiusOverridden.doubleValue;
    }
    NSNumber *borderHeightOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]];
    if (borderHeightOverridden) {
      borderHeight = borderHeightOverridden.doubleValue;
    }
    NSNumber *borderWidthOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]];
    if (borderWidthOverridden) {
      borderWidth = borderWidthOverridden.doubleValue;
    }
    NSNumber *lineSpacingOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]];
    if (lineSpacingOverridden) {
      lineSpacing = lineSpacingOverridden.doubleValue;
    }
    NSNumber *spacingOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]];
    if (spacingOverridden) {
      spacing = spacingOverridden.doubleValue;
    }
    NSNumber *baseOffsetOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]];
    if (baseOffsetOverridden) {
      baseOffset = baseOffsetOverridden.doubleValue;
    }
  }

  if (fontSize == 0) { // default size
    fontSize = kDefaultFontSize;
  }
  if (labelFontSize == 0) {
    labelFontSize = fontSize;
  }
  if (commentFontSize == 0) {
    commentFontSize = fontSize;
  }
  NSFontDescriptor *fontDescriptor = nil;
  NSFont *font = nil;
  if (fontName != nil) {
    fontDescriptor = getFontDescriptor(fontName);
    if (fontDescriptor != nil) {
      font = [NSFont fontWithDescriptor:fontDescriptor size:fontSize];
    }
  }
  if (font == nil) {
    // use default font
    font = [NSFont userFontOfSize:fontSize];
  }
  NSFontDescriptor *labelFontDescriptor = nil;
  NSFont *labelFont = nil;
  NSMutableDictionary *labelFontAttr;
  labelFontAttr[NSFontFixedAdvanceAttribute] = @(labelFontSize);
  labelFontAttr[NSFontSizeAttribute] = @(labelFontSize);
  if (labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(labelFontName);
    if (labelFontDescriptor == nil) {
      labelFontDescriptor = [fontDescriptor fontDescriptorByAddingAttributes:labelFontAttr];
    }
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize];
    }
  }
  if (labelFont == nil) {
    if (fontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:[fontDescriptor fontDescriptorByAddingAttributes:labelFontAttr] size:labelFontSize];
    } else {
      labelFont = [NSFont monospacedDigitSystemFontOfSize:labelFontSize weight:NSFontWeightRegular];
    }
  }
  NSFontDescriptor *commentFontDescriptor = nil;
  NSFont *commentFont = nil;
  if (commentFontName != nil) {
    commentFontDescriptor = getFontDescriptor(commentFontName);
    if (commentFontDescriptor == nil) {
      commentFontDescriptor = fontDescriptor;
    }
    if (commentFontDescriptor != nil) {
      commentFont = [NSFont fontWithDescriptor:commentFontDescriptor size:commentFontSize];
    }
  }
  if (commentFont == nil) {
    if (fontDescriptor != nil) {
      commentFont = [NSFont fontWithDescriptor:fontDescriptor size:commentFontSize];
    } else {
      commentFont = [NSFont fontWithName:font.fontName size:commentFontSize];
    }
  }
  NSFont *pagingFont = [NSFont fontWithName:@"AppleSymbols" size:labelFontSize/1.5];

  CGFloat lineHeight = font.ascender - font.descender;
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.alignment = NSTextAlignmentJustified;
  paragraphStyle.minimumLineHeight = lineHeight + lineSpacing/2;
  paragraphStyle.lineSpacing = lineSpacing/2;

  NSMutableParagraphStyle *preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.alignment = NSTextAlignmentLeft;
  preeditParagraphStyle.minimumLineHeight = lineHeight;
  preeditParagraphStyle.paragraphSpacing = spacing;

  NSMutableParagraphStyle *pagingParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  pagingParagraphStyle.alignment = NSTextAlignmentRight;

  // Use left-to-right marks to declare the default writing direction and prevent strong right-to-left
  // characters from setting the writing direction in case the label are direction-less symbols
  paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  preeditParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  pagingParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;

  NSMutableDictionary *attrs = [theme.attrs mutableCopy];
  NSMutableDictionary *highlightedAttrs = [theme.highlightedAttrs mutableCopy];
  NSMutableDictionary *labelAttrs = [theme.labelAttrs mutableCopy];
  NSMutableDictionary *labelHighlightedAttrs = [theme.labelHighlightedAttrs mutableCopy];
  NSMutableDictionary *commentAttrs = [theme.commentAttrs mutableCopy];
  NSMutableDictionary *commentHighlightedAttrs = [theme.commentHighlightedAttrs mutableCopy];
  NSMutableDictionary *preeditAttrs = [theme.preeditAttrs mutableCopy];
  NSMutableDictionary *preeditHighlightedAttrs = [theme.preeditHighlightedAttrs mutableCopy];
  NSMutableDictionary *pagingAttrs = [theme.pagingAttrs mutableCopy];

  attrs[NSFontAttributeName] = font;
  highlightedAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  commentHighlightedAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  preeditHighlightedAttrs[NSFontAttributeName] = font;
  pagingAttrs[NSFontAttributeName] = pagingFont;
  attrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  highlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  pagingAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  pagingAttrs[NSSuperscriptAttributeName] = @(-1);

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];

  backgroundColor = backgroundColor ? backgroundColor : [NSColor controlBackgroundColor];
  borderColor = borderColor ? borderColor : [NSColor gridColor];
  preeditBackgroundColor = preeditBackgroundColor ? preeditBackgroundColor : [NSColor windowBackgroundColor];
  candidateTextColor = candidateTextColor ? candidateTextColor : [NSColor controlTextColor];
  highlightedCandidateTextColor = highlightedCandidateTextColor ? highlightedCandidateTextColor : [NSColor selectedMenuItemTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? highlightedCandidateBackColor : [NSColor selectedContentBackgroundColor];
  candidateLabelColor = candidateLabelColor ? candidateLabelColor :
    isNative ? [NSColor controlAccentColor] : blendColors(highlightedCandidateBackColor, highlightedCandidateTextColor);
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? highlightedCandidateLabelColor :
    isNative ? [NSColor alternateSelectedControlTextColor] : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? commentTextColor : secondaryTextColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? highlightedCommentTextColor : [NSColor alternateSelectedControlTextColor];
  textColor = textColor ? textColor : [NSColor textColor];
  highlightedTextColor = highlightedTextColor ? highlightedTextColor : [NSColor selectedTextColor];
  highlightedBackColor = highlightedBackColor ? highlightedBackColor : [NSColor selectedTextBackgroundColor];

  attrs[NSForegroundColorAttributeName] = candidateTextColor;
  labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
  highlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateTextColor;
  labelHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateLabelColor;
  commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
  commentHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCommentTextColor;
  preeditAttrs[NSForegroundColorAttributeName] = textColor;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = highlightedTextColor;
  pagingAttrs[NSForegroundColorAttributeName] = candidateLabelColor;

  attrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  labelAttrs[NSVerticalGlyphFormAttributeName] =  vertical ? @YES : @NO;
  highlightedAttrs[NSVerticalGlyphFormAttributeName] =  vertical ? @YES : @NO;
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  commentAttrs[NSVerticalGlyphFormAttributeName] =  vertical ? @YES : @NO;
  commentHighlightedAttrs[NSVerticalGlyphFormAttributeName] =  vertical ? @YES : @NO;
  preeditAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  preeditHighlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  pagingAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;

  [theme          setAttrs:attrs
                labelAttrs:labelAttrs
          highlightedAttrs:highlightedAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs
               pagingAttrs:pagingAttrs];

  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle
      pagingParagraphStyle:pagingParagraphStyle];

  [theme setBackgroundColor:backgroundColor
      highlightedStripColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];

  borderHeight = MAX(borderHeight, cornerRadius - cornerRadius / sqrt(2));
  borderWidth = MAX(borderWidth, cornerRadius - cornerRadius / sqrt(2));
  NSSize edgeInset = vertical ? NSMakeSize(borderHeight, borderWidth) : NSMakeSize(borderWidth, borderHeight);

  [theme setCornerRadius:cornerRadius
     hilitedCornerRadius:hilitedCornerRadius
               edgeInset:edgeInset
             borderWidth:MAX(borderHeight, borderWidth)
               linespace:lineSpacing
        preeditLinespace:spacing
                   alpha:(alpha == 0 ? 1.0 : alpha)
            translucency:translucency
                  linear:linear
                vertical:vertical
           inlinePreedit:inlinePreedit
         inlineCandidate:inlineCandidate];

  theme.native = isNative;
  theme.candidateFormat = (candidateFormat ? candidateFormat : kDefaultCandidateFormat);
}

@end
