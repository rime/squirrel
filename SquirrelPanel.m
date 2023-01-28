#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOffsetHeight = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c. %@";

@interface SquirrelTheme : NSObject

@property(nonatomic, assign) BOOL native;
@property(nonatomic, assign) BOOL memorizeSize;

@property(nonatomic, strong, readonly) NSColor *backgroundColor;
@property(nonatomic, strong, readonly) NSColor *highlightedBackColor;
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
@property(nonatomic, strong, readonly) NSParagraphStyle *paragraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *preeditParagraphStyle;

@property(nonatomic, strong, readonly) NSString *prefixLabelFormat, *suffixLabelFormat;

- (void)setCandidateFormat:(NSString *)candidateFormat;

- (void)setBackgroundColor:(NSColor *)backgroundColor
     highlightedBackColor:(NSColor *)highlightedBackColor
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
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs;

- (void) setParagraphStyle:(NSParagraphStyle *)paragraphStyle
     preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle;

@end

@implementation SquirrelTheme

- (void)setCandidateFormat:(NSString *)candidateFormat {
  // in the candiate format, everything other than '%@' is considered part of the label
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@"];
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
     highlightedBackColor:(NSColor *)highlightedBackColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor {
  _backgroundColor = backgroundColor;
  _highlightedBackColor = highlightedBackColor;
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
                  alpha:(double)alpha
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
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs {
  _attrs = attrs;
  _labelAttrs = labelAttrs;
  _highlightedAttrs = highlightedAttrs;
  _labelHighlightedAttrs = labelHighlightedAttrs;
  _commentAttrs = commentAttrs;
  _commentHighlightedAttrs = commentHighlightedAttrs;
  _preeditAttrs = preeditAttrs;
  _preeditHighlightedAttrs = preeditHighlightedAttrs;
}

- (void) setParagraphStyle:(NSParagraphStyle *)paragraphStyle
     preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle {
  _paragraphStyle = paragraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
}

@end

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextView *textView;
@property(nonatomic, readonly) NSArray<NSValue *> *candidateRanges;
@property(nonatomic, readonly) NSInteger hilightedIndex;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) BOOL isDark;
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, assign) CGFloat seperatorWidth;
@property(nonatomic, readonly) CAShapeLayer *shape;

- (void)         drawViewWith:(NSArray<NSValue *> *)candidateRanges
               hilightedIndex:(NSInteger)hilightedIndex
                 preeditRange:(NSRange)preeditRange
      highlightedPreeditRange:(NSRange)highlightedPreeditRange;
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
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSZeroSize];
  textContainer.lineFragmentPadding = 0.0;
  _textView.drawsBackground = NO;
  _textView.editable = NO;
  _textView.selectable = NO;
  [_textView replaceTextContainer:textContainer];
  _textView.layoutManager.backgroundLayoutEnabled = YES;
  _defaultTheme = [[SquirrelTheme alloc] init];
  _shape = [[CAShapeLayer alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
  }
  return self;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  NSRange glyphRange = [_textView.layoutManager glyphRangeForTextContainer:_textView.textContainer];
  NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
  __block long actualWidth = 0;
  [_textView.layoutManager enumerateLineFragmentsForGlyphRange:glyphRange usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *textContainer, NSRange glyphRange, BOOL *stop) {
    NSRange range = [self.textView.layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
    NSAttributedString *str = [self.textView.textStorage attributedSubstringFromRange:range];
    NSRange nonWhiteRange = [str.string rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet.invertedSet options:NSBackwardsSearch];
    if (nonWhiteRange.location != NSNotFound) {
      NSRange newRange = NSMakeRange(range.location, NSMaxRange(nonWhiteRange));
      NSRange newGlyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:newRange actualCharacterRange:NULL];
      CGFloat width = [self.textView.layoutManager boundingRectForGlyphRange:newGlyphRange inTextContainer:self.textView.textContainer].size.width;
      if (width > actualWidth) {
        actualWidth = width;
      }
    }
  }];
  if (actualWidth > 0) {
    rect.size.width = actualWidth;
  }
  return rect;
}

// Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
  return rect;
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void)         drawViewWith:(NSArray<NSValue *> *)candidateRanges
               hilightedIndex:(NSInteger)hilightedIndex
                 preeditRange:(NSRange)preeditRange
      highlightedPreeditRange:(NSRange)highlightedPreeditRange {
  _candidateRanges = candidateRanges;
  _hilightedIndex = hilightedIndex;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  self.needsDisplay = YES;
}

// A tweaked sign function, to winddown corner radius when the size is small
double sign(double number) {
  if (number >= 2) {
    return 1;
  } else if (number <= -2) {
    return -1;
  }else {
    return number / 2;
  }
}

// Bezier cubic curve, which has continuous roundness
CGMutablePathRef drawSmoothLines(NSArray<NSValue *> *vertex, NSSet<NSNumber *> * __nullable straightCorner, CGFloat alpha, CGFloat beta) {
  CGMutablePathRef path = CGPathCreateMutable();
  if (vertex.count < 1)
    return path;
  NSPoint previousPoint = [vertex[vertex.count-1] pointValue];
  NSPoint point = [vertex[0] pointValue];
  NSPoint nextPoint;
  NSPoint control1;
  NSPoint control2;
  NSPoint target = previousPoint;
  NSPoint diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
  if (!straightCorner || ![straightCorner containsObject:[NSNumber numberWithUnsignedInteger:vertex.count - 1]]) {
    if (ABS(diff.x) >= ABS(diff.y)) {
      target.x += sign(diff.x/beta)*beta;
    } else {
      target.y += sign(diff.y/beta)*beta;
    }
  }
  CGPathMoveToPoint(path, NULL, target.x, target.y);
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
    previousPoint = [vertex[(vertex.count+i-1)%vertex.count] pointValue];
    point = [vertex[i] pointValue];
    nextPoint = [vertex[(i+1)%vertex.count] pointValue];
    target = point;
    if (straightCorner && [straightCorner containsObject:[NSNumber numberWithUnsignedInteger:i]]) {
      CGPathAddLineToPoint(path, NULL, target.x, target.y);
    } else {
      control1 = point;
      diff = NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y);
      if (ABS(diff.x) >= ABS(diff.y)) {
        target.x -= sign(diff.x/beta)*beta;
        control1.x -= sign(diff.x/beta)*alpha;
      } else {
        target.y -= sign(diff.y/beta)*beta;
        control1.y -= sign(diff.y/beta)*alpha;
      }
      CGPathAddLineToPoint(path, NULL, target.x, target.y);
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
      CGPathAddCurveToPoint(path, NULL, control1.x, control1.y, control2.x, control2.y, target.x, target.y);
    }
  }
  CGPathCloseSubpath(path);
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
    NSPoint point = [shape[i] pointValue];
    point.x += direction.x;
    point.y += direction.y;
    [shape replaceObjectAtIndex:i withObject:@(point)];
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
  // Multiline, not starting from beginning
  if (boundingRect.origin.x <= 1 && fullRangeInBoundingRect.location < glyphRange.location) {
    *leadingRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(fullRangeInBoundingRect.location, glyphRange.location-fullRangeInBoundingRect.location) inTextContainer:textContainer];
    if (!nearEmptyRect(*leadingRect)) {
      bodyRect->size.height -= leadingRect->size.height;
      bodyRect->origin.y += leadingRect->size.height;
    }
    double rightEdge = NSMaxX(*leadingRect);
    leadingRect->origin.x = rightEdge;
    leadingRect->size.width = NSMaxX(*bodyRect) - rightEdge;
  }
  // Has trainling characters
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
  // Has no trainling charcater
  } else if (NSMaxRange(fullRangeInBoundingRect) == NSMaxRange(glyphRange)) {
    *trailingRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:NULL];
    if (NSMaxX(*trailingRect) >= NSMaxX(boundingRect) - 1) {
      *trailingRect = NSZeroRect;
    } else if (!nearEmptyRect(*trailingRect)) {
      bodyRect->size.height -= trailingRect->size.height;
    }
  }
  NSRect lastLineRect = nearEmptyRect(*trailingRect) ? *bodyRect : *trailingRect;
//  lastLineRect.size.width = textContainer.containerSize.width - lastLineRect.origin.x;
  NSRange lastLineRange = [layoutManager glyphRangeForBoundingRect:lastLineRect inTextContainer:textContainer];
  NSGlyphProperty glyphProperty = [layoutManager propertyForGlyphAtIndex:lastLineRange.location+lastLineRange.length-1];
  while (lastLineRange.length>0 && (glyphProperty == NSGlyphPropertyElastic || glyphProperty == NSGlyphPropertyControlCharacter)) {
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
    return @[bodyVertex[0], bodyVertex[1], bodyVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1]];
  } else if (nearEmptyRect(leadingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], bodyVertex[3], bodyVertex[0]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && nearEmptyRect(bodyRect) && NSMaxX(leadingRect)>NSMinX(trailingRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[trailingVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3], leadingVertex[0], leadingVertex[1], bodyVertex[0]];
  } else {
    return @[];
  }
}

// If the point is outside the innerBox, will extend to reach the outerBox
void expand(NSMutableArray<NSValue *> *vertex, NSRect innerBorder, NSRect outerBorder) {
  for (NSUInteger i = 0; i < vertex.count; i += 1){
    NSPoint point = [vertex[i] pointValue];
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
  }
}

CGPoint direction(CGPoint diff) {
  if (diff.y == 0 && diff.x > 0) {
    return NSMakePoint(0, 1);
  } else if (diff.y == 0 && diff.x < 0) {
    return NSMakePoint(0, -1);
  } else if (diff.x == 0 && diff.y > 0) {
    return NSMakePoint(-1, 0);
  } else if (diff.x == 0 && diff.y < 0) {
    return NSMakePoint(1, 0);
  } else {
    return NSMakePoint(0, 0);
  }
}

CAShapeLayer *shapeFromPath(CGPathRef path) {
  CAShapeLayer *layer = [CAShapeLayer layer];
  layer.path = path;
  layer.fillRule = kCAFillRuleEvenOdd;
  return layer;
}

// Assumes clockwise iteration
void enlarge(NSMutableArray<NSValue *> *vertex, CGFloat by) {
  if (by != 0) {
    NSPoint previousPoint;
    NSPoint point;
    NSPoint nextPoint;
    NSArray<NSValue *> *original = [[NSArray alloc] initWithArray:vertex];
    NSPoint newPoint;
    NSPoint displacement;
    for (NSUInteger i = 0; i < original.count; i += 1){
      previousPoint = [original[(original.count+i-1)%original.count] pointValue];
      point = [original[i] pointValue];
      nextPoint = [original[(i+1)%original.count] pointValue];
      newPoint = point;
      displacement = direction(NSMakePoint(point.x - previousPoint.x, point.y - previousPoint.y));
      newPoint.x += by * displacement.x;
      newPoint.y += by * displacement.y;
      displacement = direction(NSMakePoint(nextPoint.x - point.x, nextPoint.y - point.y));
      newPoint.x += by * displacement.x;
      newPoint.y += by * displacement.y;
      [vertex replaceObjectAtIndex:i withObject:@(newPoint)];
    }
  }
}

// Add gap between horizontal candidates
- (void)addGapBetweenHorizontalCandidates:(NSRect *)rect range:(NSRange)highlightedRange {
  if (NSMaxRange(highlightedRange) == _textView.textStorage.length) {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth;
      rect->origin.x -= _seperatorWidth / 2;
    }
  } else if (highlightedRange.location - ((_preeditRange.location == NSNotFound ? 0 : _preeditRange.location)+_preeditRange.length) <= 1) {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth / 2;
    }
  } else {
    if (!nearEmptyRect(*rect)) {
      rect->size.width += _seperatorWidth;
      rect->origin.x -= _seperatorWidth / 2;
    }
  }
}

void removeCorner(NSMutableArray<NSValue *> *highlightedPoints, NSMutableSet<NSNumber *> *rightCorners, NSRect containingRect) {
  if (highlightedPoints && rightCorners) {
    NSSet<NSNumber *> *originalRightCorners = [[NSSet<NSNumber *> alloc] initWithSet:rightCorners];
    for (NSNumber *cornerIndex in originalRightCorners) {
      NSUInteger index = cornerIndex.unsignedIntegerValue;
      NSPoint corner = [highlightedPoints[index] pointValue];
      CGFloat dist = MIN(NSMaxY(containingRect) - corner.y, corner.y - NSMinY(containingRect));
      if (dist < 1e-2) {
        [rightCorners removeObject:cornerIndex];
      }
    }
  }
}

- (void) linearMultilineForRect:(NSRect)bodyRect leadingRect:(NSRect)leadingRect trailingRect:(NSRect)trailingRect points1:(NSMutableArray<NSValue *> **)highlightedPoints points2:(NSMutableArray<NSValue *> **)highlightedPoints2 rightCorners:(NSMutableSet<NSNumber *> **)rightCorners rightCorners2:(NSMutableSet<NSNumber *> **)rightCorners2 {
  // Handles the special case where containing boxes are separated
  if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
    *highlightedPoints = [rectVertex(leadingRect) mutableCopy];
    *highlightedPoints2 = [rectVertex(trailingRect) mutableCopy];
    *rightCorners = [[NSMutableSet<NSNumber *> alloc] initWithObjects:@(2), @(3), nil];
  } else {
    *highlightedPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
    if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect)) {
      if (NSMaxX(trailingRect) < NSMaxX(leadingRect) && NSMinX(trailingRect) < NSMinX(leadingRect)) {
        *rightCorners = [[NSMutableSet<NSNumber *> alloc] initWithObjects:@(0), @(1), @(4), @(5), nil];
      } else if (NSMaxX(trailingRect) >= NSMaxX(leadingRect) && NSMinX(trailingRect) < NSMinX(leadingRect)) {
        *rightCorners = [[NSMutableSet<NSNumber *> alloc] initWithObjects:@(0), @(1), nil];
      }
    }
  }
  if ([*highlightedPoints2 count] > 0) {
    *rightCorners2 = [[NSMutableSet<NSNumber *> alloc] initWithObjects:@(0), @(1), nil];
  }
}

- (CGPathRef)drawHighlightedWith:(SquirrelTheme *)theme highlightedRange:(NSRange)highlightedRange backgroundRect:(NSRect)backgroundRect preeditRect:(NSRect)preeditRect containingRect:(NSRect)containingRect extraExpansion:(CGFloat)extraExpansion {
  NSRect currentContainingRect = containingRect;
  currentContainingRect.size.width += extraExpansion * 2;
  currentContainingRect.size.height += extraExpansion * 2;
  currentContainingRect.origin.x -= extraExpansion;
  currentContainingRect.origin.y -= extraExpansion;
  
  CGFloat halfLinespace = theme.linespace / 2;
  NSRect innerBox = backgroundRect;
  innerBox.size.width -= (theme.edgeInset.width + 1) * 2 - 2 * extraExpansion;
  innerBox.origin.x += theme.edgeInset.width + 1 - extraExpansion;
  innerBox.size.height += 2 * extraExpansion;
  innerBox.origin.y -= extraExpansion;
  if (_preeditRange.length == 0) {
    innerBox.origin.y += theme.edgeInset.height + 1;
    innerBox.size.height -= (theme.edgeInset.height + 1) * 2;
  } else {
    innerBox.origin.y += preeditRect.size.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 1;
    innerBox.size.height -= theme.edgeInset.height + preeditRect.size.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 2;
  }
  innerBox.size.height -= halfLinespace;
  NSRect outerBox = backgroundRect;
  outerBox.size.height -= preeditRect.size.height + MAX(0, theme.hilitedCornerRadius + theme.borderWidth) - 2 * extraExpansion;
  outerBox.size.width -= MAX(0, theme.hilitedCornerRadius + theme.borderWidth) - 2 * extraExpansion;
  outerBox.origin.x += MAX(0, theme.hilitedCornerRadius + theme.borderWidth) / 2 - extraExpansion;
  outerBox.origin.y += preeditRect.size.height + MAX(0, theme.hilitedCornerRadius + theme.borderWidth) / 2 - extraExpansion;
  
  double effectiveRadius = MAX(0, theme.hilitedCornerRadius + 2 * extraExpansion / theme.hilitedCornerRadius * MAX(0, theme.cornerRadius - theme.hilitedCornerRadius));
  CGMutablePathRef path = CGPathCreateMutable();
  
  if (theme.linear){
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:highlightedRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

    [self addGapBetweenHorizontalCandidates:&leadingRect range:highlightedRange];
    [self addGapBetweenHorizontalCandidates:&bodyRect range:highlightedRange];
    [self addGapBetweenHorizontalCandidates:&trailingRect range:highlightedRange];
    
    NSMutableArray<NSValue *> *highlightedPoints;
    NSMutableArray<NSValue *> *highlightedPoints2;
    NSMutableSet<NSNumber *> *rightCorners;
    NSMutableSet<NSNumber *> *rightCorners2;
    [self linearMultilineForRect:bodyRect leadingRect:leadingRect trailingRect:trailingRect points1:&highlightedPoints points2:&highlightedPoints2 rightCorners:&rightCorners rightCorners2:&rightCorners2];

    xyTranslation(highlightedPoints, NSMakePoint(0, -halfLinespace));
    xyTranslation(highlightedPoints2, NSMakePoint(0, -halfLinespace));
    // Expand the boxes to reach proper border
    enlarge(highlightedPoints, extraExpansion);
    expand(highlightedPoints, innerBox, outerBox);
    removeCorner(highlightedPoints, rightCorners, currentContainingRect);

    path = drawSmoothLines(highlightedPoints, rightCorners, 0.3*effectiveRadius, 1.4*effectiveRadius);
    if (highlightedPoints2.count > 0) {
      enlarge(highlightedPoints2, extraExpansion);
      expand(highlightedPoints2, innerBox, outerBox);
      removeCorner(highlightedPoints2, rightCorners2, currentContainingRect);
      CGPathRef path2 = drawSmoothLines(highlightedPoints2, rightCorners2, 0.3*effectiveRadius, 1.4*effectiveRadius);
      CGPathAddPath(path, NULL, path2);
    }
  } else {
    NSRect highlightedRect = [self contentRectForRange:highlightedRange];
    highlightedRect.size.width = backgroundRect.size.width;
    highlightedRect.size.height += theme.linespace;
    highlightedRect.origin = NSMakePoint(backgroundRect.origin.x, highlightedRect.origin.y + theme.edgeInset.height - halfLinespace);
    if (NSMaxRange(highlightedRange) == _textView.textStorage.length) {
      highlightedRect.size.height += theme.edgeInset.height - halfLinespace;
    }
    if (highlightedRange.location - ((_preeditRange.location == NSNotFound ? 0 : _preeditRange.location)+_preeditRange.length) <= 1) {
      if (_preeditRange.length == 0) {
        highlightedRect.size.height += theme.edgeInset.height - halfLinespace;
        highlightedRect.origin.y -= theme.edgeInset.height - halfLinespace;
      } else {
        highlightedRect.size.height += theme.hilitedCornerRadius / 2;
        highlightedRect.origin.y -= theme.hilitedCornerRadius / 2;
      }
    }
    NSMutableArray<NSValue *> *highlightedPoints = [rectVertex(highlightedRect) mutableCopy];
    enlarge(highlightedPoints, extraExpansion);
    expand(highlightedPoints, innerBox, outerBox);
    path = drawSmoothLines(highlightedPoints, nil, 0.3*effectiveRadius, 1.4*effectiveRadius);
  }
  return path;
}

// All draws happen here
- (void)drawRect:(NSRect)dirtyRect {
  CGPathRef backgroundPath = CGPathCreateMutable();
  CGPathRef highlightedPath = CGPathCreateMutable();
  CGMutablePathRef highlightedPreeditPath = CGPathCreateMutable();
  CGPathRef preeditPath = CGPathCreateMutable();
  SquirrelTheme * theme = self.currentTheme;

  NSPoint textFieldOrigin = dirtyRect.origin;
  textFieldOrigin.y += theme.edgeInset.height;
  textFieldOrigin.x += theme.edgeInset.width;

  // Draw preedit Rect
  NSRect backgroundRect = dirtyRect;
  NSRect containingRect = dirtyRect;
  containingRect.size.height -= (theme.hilitedCornerRadius + theme.borderWidth) * 2;
  containingRect.size.width -= (theme.hilitedCornerRadius + theme.borderWidth) * 2;
  containingRect.origin.x += theme.hilitedCornerRadius + theme.borderWidth;
  containingRect.origin.y += theme.hilitedCornerRadius + theme.borderWidth;

  // Draw preedit Rect
  NSRect preeditRect = NSZeroRect;
  if (_preeditRange.length > 0) {
    preeditRect = [self contentRectForRange:_preeditRange];
    preeditRect.size.width = backgroundRect.size.width;
    preeditRect.size.height += theme.edgeInset.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2;
    preeditRect.origin = backgroundRect.origin;
    if (_candidateRanges.count == 0) {
      preeditRect.size.height += theme.edgeInset.height - theme.preeditLinespace / 2 - theme.hilitedCornerRadius / 2;
    }
    if (theme.preeditBackgroundColor != nil) {
      preeditPath = drawSmoothLines(rectVertex(preeditRect), nil, 0, 0);
    }
  }

  // Draw highlighted Rect
  NSRange candidateRange = [_candidateRanges[_hilightedIndex] rangeValue];
  // Draw highlighted Rect
  if (candidateRange.length > 0 && theme.highlightedBackColor != nil) {
    highlightedPath = [self drawHighlightedWith:theme highlightedRange:candidateRange backgroundRect:backgroundRect preeditRect:preeditRect containingRect:containingRect extraExpansion:0];
  }

  // Draw highlighted part of preedit text
  if (_highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
    NSRect innerBox = preeditRect;
    innerBox.size.width -= (theme.edgeInset.width + 1) * 2;
    innerBox.origin.x += theme.edgeInset.width + 1;
    innerBox.origin.y += theme.edgeInset.height + 1;
    if (_candidateRanges.count == 0) {
      innerBox.size.height -= (theme.edgeInset.height + 1) * 2;
    } else {
      innerBox.size.height -= theme.edgeInset.height + theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2 + 2;
    }
    NSRect outerBox = preeditRect;
    outerBox.size.height -= MAX(0, theme.hilitedCornerRadius + theme.borderWidth);
    outerBox.size.width -= MAX(0, theme.hilitedCornerRadius + theme.borderWidth);
    outerBox.origin.x += MAX(0, theme.hilitedCornerRadius + theme.borderWidth) / 2;
    outerBox.origin.y += MAX(0, theme.hilitedCornerRadius + theme.borderWidth) / 2;
    
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:_highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
    
    NSMutableArray<NSValue *> *highlightedPreeditPoints;
    NSMutableArray<NSValue *> *highlightedPreeditPoints2;
    NSMutableSet<NSNumber *> *rightCorners;
    NSMutableSet<NSNumber *> *rightCorners2;
    [self linearMultilineForRect:bodyRect leadingRect:leadingRect trailingRect:trailingRect points1:&highlightedPreeditPoints points2:&highlightedPreeditPoints2 rightCorners:&rightCorners rightCorners2:&rightCorners2];
    
    expand(highlightedPreeditPoints, innerBox, outerBox);
    removeCorner(highlightedPreeditPoints, rightCorners, containingRect);
    highlightedPreeditPath = drawSmoothLines(highlightedPreeditPoints, rightCorners, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    if (highlightedPreeditPoints2.count > 0) {
      expand(highlightedPreeditPoints2, innerBox, outerBox);
      removeCorner(highlightedPreeditPoints2, rightCorners2, containingRect);
      CGPathRef highlightedPreeditPath2 = drawSmoothLines(highlightedPreeditPoints2, rightCorners2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
      CGPathAddPath(highlightedPreeditPath, NULL, highlightedPreeditPath2);
    }
  }

  [NSBezierPath setDefaultLineWidth:0];
  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), nil, theme.cornerRadius*0.3, theme.cornerRadius*1.4);
  _shape.path = CGPathCreateMutableCopy(backgroundPath);

  [self.layer setSublayers: NULL];
  CGMutablePathRef backPath = CGPathCreateMutableCopy(backgroundPath);
  if (!CGPathIsEmpty(preeditPath)) {
    CGPathAddPath(backPath, NULL, preeditPath);
  }
  CAShapeLayer *panelLayer = shapeFromPath(backPath);
  panelLayer.fillColor = theme.backgroundColor.CGColor;
  CAShapeLayer *panelLayerMask = shapeFromPath(backgroundPath);
  panelLayer.mask = panelLayerMask;
  [self.layer addSublayer: panelLayer];

  if (theme.preeditBackgroundColor && !CGPathIsEmpty(preeditPath)) {
    CAShapeLayer *layer = shapeFromPath(preeditPath);
    layer.fillColor = theme.preeditBackgroundColor.CGColor;
    CGMutablePathRef maskPath = CGPathCreateMutableCopy(backgroundPath);
    CAShapeLayer *mask = shapeFromPath(maskPath);
    layer.mask = mask;
    [panelLayer addSublayer: layer];
  }
  if (theme.borderWidth > 0 && theme.borderColor) {
    CAShapeLayer *borderLayer = shapeFromPath(backgroundPath);
    borderLayer.lineWidth = theme.borderWidth * 2;
    borderLayer.strokeColor = theme.borderColor.CGColor;
    borderLayer.fillColor = NULL;
    [panelLayer addSublayer: borderLayer];
  }
  if (theme.highlightedPreeditColor && !CGPathIsEmpty(highlightedPreeditPath)) {
    CAShapeLayer *layer = shapeFromPath(highlightedPreeditPath);
    layer.fillColor = theme.highlightedPreeditColor.CGColor;
    [panelLayer addSublayer: layer];
  }
  if (theme.highlightedBackColor && !CGPathIsEmpty(highlightedPath)) {
    CAShapeLayer *layer = shapeFromPath(highlightedPath);
    layer.fillColor = theme.highlightedBackColor.CGColor;
    [panelLayer addSublayer: layer];
  }
  [_textView setTextContainerInset:NSMakeSize(textFieldOrigin.x, textFieldOrigin.y)];
}

@end

@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;

  NSRange _preeditRange;
  NSRect _screenRect;
  CGFloat _maxHeight;

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
      NSFont *defaultFont = [NSFont systemFontOfSize:charFont.pointSize];
      [text addAttribute:NSFontAttributeName value:defaultFont range:currentFontRange];
    }
    i = currentFontRange.location + currentFontRange.length;
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
  theme.memorizeSize = YES;
  theme.candidateFormat = kDefaultCandidateFormat;

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];

  NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
  attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  attrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *highlightedAttrs = [[NSMutableDictionary alloc] init];
  highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedControlTextColor];
  highlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *labelAttrs = [attrs mutableCopy];
  NSMutableDictionary *labelHighlightedAttrs = [highlightedAttrs mutableCopy];

  NSMutableDictionary *commentAttrs = [[NSMutableDictionary alloc] init];
  commentAttrs[NSForegroundColorAttributeName] = secondaryTextColor;
  commentAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *commentHighlightedAttrs = [commentAttrs mutableCopy];

  NSMutableDictionary *preeditAttrs = [[NSMutableDictionary alloc] init];
  preeditAttrs[NSForegroundColorAttributeName] = secondaryTextColor;
  preeditAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSMutableDictionary *preeditHighlightedAttrs = [[NSMutableDictionary alloc] init];
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  preeditHighlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  NSParagraphStyle *paragraphStyle = [NSParagraphStyle defaultParagraphStyle];
  NSParagraphStyle *preeditParagraphStyle = [NSParagraphStyle defaultParagraphStyle];

  [theme          setAttrs:attrs
                labelAttrs:labelAttrs
          highlightedAttrs:highlightedAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs];
  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle];
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
    [contentView addSubview:_view.textView];
    
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

- (CGFloat)getMaxTextWidth:(SquirrelTheme *)theme {
  NSFont *currentFont = theme.attrs[NSFontAttributeName];
  CGFloat fontScale = currentFont.pointSize / 12;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + fontScale / 12);
  return theme.vertical
    ? NSHeight(_screenRect) * textWidthRatio - theme.edgeInset.height * 2
    : NSWidth(_screenRect) * textWidthRatio - theme.edgeInset.width * 2;
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
  CGFloat textWidth = [self getMaxTextWidth:theme];
  CGFloat maxTextHeight = theme.vertical ? _screenRect.size.width - theme.edgeInset.width * 2 : _screenRect.size.height - theme.edgeInset.height * 2;
  _view.textView.textContainer.containerSize = NSMakeSize(textWidth, maxTextHeight);

  NSRect windowRect;
  // in vertical mode, the width and height are interchanged
  NSRect contentRect = _view.contentRect;
  if (theme.memorizeSize && ((theme.vertical && NSMidY(_position) / NSHeight(_screenRect) < 0.5) ||
      (!theme.vertical && NSMinX(_position)+MAX(contentRect.size.width, _maxHeight)+theme.edgeInset.width*2 > NSMaxX(_screenRect)))) {
    if (contentRect.size.width >= _maxHeight) {
      _maxHeight = contentRect.size.width;
    } else {
      contentRect.size.width = _maxHeight;
      _view.textView.textContainer.containerSize = NSMakeSize(_maxHeight, maxTextHeight);
    }
  }

  if (theme.vertical) {
    windowRect.size = NSMakeSize(contentRect.size.height + theme.edgeInset.height * 2,
                                 contentRect.size.width + theme.edgeInset.width * 2);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMidY(_position) / NSHeight(_screenRect) >= 0.5) {
      windowRect.origin.y = NSMinY(_position) - kOffsetHeight - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + kOffsetHeight;
    }
    // Make the first candidate fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - windowRect.size.width - kOffsetHeight;
    if (_preeditRange.length > 0) {
      NSSize preeditSize = [_view contentRectForRange:_preeditRange].size;
      windowRect.origin.x += preeditSize.height + theme.edgeInset.width;
    }
  } else {
    windowRect.size = NSMakeSize(contentRect.size.width + theme.edgeInset.width * 2,
                                 contentRect.size.height + theme.edgeInset.height * 2);
    windowRect.origin = NSMakePoint(NSMinX(_position),
                                    NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
  }

  if (NSMaxX(windowRect) > NSMaxX(_screenRect)) {
    windowRect.origin.x = NSMaxX(_screenRect) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(_screenRect)) {
    windowRect.origin.x = NSMinX(_screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    if (theme.vertical) {
      windowRect.origin.y = NSMinY(_screenRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + kOffsetHeight;
    }
  }
  if (NSMaxY(windowRect) > NSMaxY(_screenRect)) {
    windowRect.origin.y = NSMaxY(_screenRect) - NSHeight(windowRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    windowRect.origin.y = NSMinY(_screenRect);
  }
  [self setFrame:windowRect display:YES];
  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    self.contentView.boundsRotation = -90;
    _view.textView.boundsRotation = 0;
    [self.contentView setBoundsOrigin:NSMakePoint(0, windowRect.size.width)];
  } else {
    self.contentView.boundsRotation = 0;
    _view.textView.boundsRotation = 0;
    [self.contentView setBoundsOrigin:NSMakePoint(0, 0)];
  }
  BOOL translucency = theme.translucency;
  [_view setFrame:self.contentView.bounds];
  [_view.textView setFrame:self.contentView.bounds];
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
        highlighted:(NSUInteger)index {
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
  [self getCurrentScreen];

  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  NSUInteger candidateStartPos = 0;
  _preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  // preedit
  if (preedit) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                 initWithString:[preedit substringToIndex:selRange.location].precomposedStringWithCanonicalMapping
                 attributes:theme.preeditAttrs]];
    }
    if (selRange.length > 0) {
      NSUInteger highlightedPreeditStart = line.length;
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[preedit substringWithRange:selRange].precomposedStringWithCanonicalMapping
                 attributes:theme.preeditHighlightedAttrs]];
      highlightedPreeditRange = NSMakeRange(highlightedPreeditStart, line.length - highlightedPreeditStart);
    }
    if (selRange.location + selRange.length < preedit.length) {
      [line
          appendAttributedString:
              [[NSAttributedString alloc]
                  initWithString:[preedit substringFromIndex:selRange.location +
                                                             selRange.length].precomposedStringWithCanonicalMapping
               attributes:theme.preeditAttrs]];
    }
    [text appendAttributedString:line];

    [text addAttribute:NSParagraphStyleAttributeName
                 value:theme.preeditParagraphStyle
                 range:NSMakeRange(0, text.length)];

    _preeditRange = NSMakeRange(0, text.length);
    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc]
                    initWithString:@"\n"
                        attributes:theme.preeditAttrs]];
    }
    candidateStartPos = text.length;
  }

  NSMutableArray<NSValue *> *candidateRanges = [[NSMutableArray alloc] init];
  // candidates
  NSUInteger i;
  for (i = 0; i < candidates.count; ++i) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    NSDictionary *attrs;
    NSDictionary *labelAttrs;
    NSDictionary *commentAttrs;
    if (i == index) {
      attrs = theme.highlightedAttrs;
      labelAttrs = theme.labelHighlightedAttrs;
      commentAttrs = theme.commentHighlightedAttrs;
    } else {
      attrs = theme.attrs;
      labelAttrs = theme.labelAttrs;
      commentAttrs = theme.commentAttrs;
    }

    CGFloat labelWidth = 0.0;

    if (theme.prefixLabelFormat != nil) {
      NSString *labelString;
      if (labels.count > 1 && i < labels.count) {
        NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        labelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        labelString = [NSString stringWithFormat:theme.prefixLabelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        labelString = [NSString stringWithFormat:labelFormat, i+1];
      }

      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString
                        attributes:labelAttrs]];
      // get the label size for indent
      if (!theme.linear) {
        NSMutableAttributedString *str = [line mutableCopy];
        if (theme.vertical) {
          [str addAttribute:NSVerticalGlyphFormAttributeName value:@(1) range:NSMakeRange(0, str.length)];
        }
        labelWidth = [str boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin].size.width;
      }
    }

    NSUInteger candidateStart = line.length;
    NSString *candidate = candidates[i];
    NSAttributedString *candidateAttributedString = [[NSAttributedString alloc]
                                                     initWithString:candidate.precomposedStringWithCanonicalMapping
                                                     attributes:attrs];
    
    [line appendAttributedString:candidateAttributedString];
    
    // Use left-to-right marks to prevent right-to-left text from changing the
    // layout of non-candidate text.
    [line addAttribute:NSWritingDirectionAttributeName value:@[@0] range:NSMakeRange(candidateStart, line.length-candidateStart)];

    if (theme.suffixLabelFormat != nil) {
      NSString *labelString;
      if (labels.count > 1 && i < labels.count) {
        NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
        labelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        char labelCharacter = [labels[0] characterAtIndex:i];
        labelString = [NSString stringWithFormat:theme.suffixLabelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%lu"];
        labelString = [NSString stringWithFormat:labelFormat, i+1];
      }
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:labelString
                        attributes:labelAttrs]];
    }

    if (i < comments.count && [comments[i] length] != 0) {
      NSString *comment = comments[i];
      NSAttributedString *commentAttributedString = [[NSAttributedString alloc]
                                                     initWithString:comment.precomposedStringWithCanonicalMapping
                                                     attributes:commentAttrs];
      
      NSString *commentSeparator = @" ";
      [line appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:commentSeparator
                                           attributes:commentAttrs]];
      [line appendAttributedString:commentAttributedString];
    }

    NSAttributedString *separator = [[NSMutableAttributedString alloc]
                                        initWithString:(theme.linear ? @"  " : @"\n")
                                            attributes:attrs];
    
    NSMutableAttributedString *str = [separator mutableCopy];
    if (theme.vertical) {
      [str addAttribute:NSVerticalGlyphFormAttributeName value:@(1) range:NSMakeRange(0, str.length)];
    }
    _view.seperatorWidth = [str boundingRectWithSize:NSZeroSize options:0].size.width;

    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    if (i == 0) {
      paragraphStyleCandidate.paragraphSpacingBefore = theme.preeditLinespace / 2 + theme.hilitedCornerRadius / 2;
    } else {
      [text appendAttributedString:separator];
    }
    if (theme.linear) {
      paragraphStyleCandidate.lineSpacing = theme.linespace;
    }
    paragraphStyleCandidate.headIndent = labelWidth;
    [line addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, line.length)];

    NSRange candidateRange = NSMakeRange(text.length, line.length);
    [candidateRanges addObject: [NSValue valueWithRange:candidateRange]];
    [text appendAttributedString:line];
  }

  // Fix font rendering
  fixDefaultFont(text);

  // text done!
  [_view.textView.textStorage setAttributedString:text];
  if (theme.vertical) {
    _view.textView.layoutOrientation = NSTextLayoutOrientationVertical;
  } else {
    _view.textView.layoutOrientation = NSTextLayoutOrientationHorizontal;
  }
  [_view drawViewWith:candidateRanges hilightedIndex:index preeditRange:_preeditRange highlightedPreeditRange:highlightedPreeditRange];
  [self show];
}

- (void)updateStatus:(NSString *)message {
  _statusMessage = message;
}

- (void)showStatus:(NSString *)message {
  SquirrelTheme *theme = _view.currentTheme;
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:message.precomposedStringWithCanonicalMapping attributes:theme.attrs];
  [text addAttribute:NSParagraphStyleAttributeName
               value:theme.paragraphStyle
               range:NSMakeRange(0, text.length)];
  fixDefaultFont(text);
  [_view.textView.textStorage setAttributedString:text];
  if (theme.vertical) {
    _view.textView.layoutOrientation = NSTextLayoutOrientationVertical;
  } else {
    _view.textView.layoutOrientation = NSTextLayoutOrientationHorizontal;
  }
  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  [_view drawViewWith:[[NSArray alloc] init] hilightedIndex:0 preeditRange:emptyRange highlightedPreeditRange:emptyRange];
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
  NSNumber *memorizeSizeConfig = [config getOptionalBool:@"style/memorize_size"];
  if (memorizeSizeConfig) {
    theme.memorizeSize = memorizeSizeConfig.boolValue;
  }
  
  NSString *candidateFormat = [config getString:@"style/candidate_format"];
  NSString *fontName = [config getString:@"style/font_face"];
  CGFloat fontSize = [config getDouble:@"style/font_point"];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  CGFloat labelFontSize = [config getDouble:@"style/label_font_point"];
  NSString *commentFontName = [config getString:@"style/comment_font_face"];
  CGFloat commentFontSize = [config getDouble:@"style/comment_font_point"];
  NSNumber *alphaValue = [config getOptionalDouble:@"style/alpha"];
  CGFloat alpha = alphaValue ? fmin(fmax(alphaValue.doubleValue, 0.0), 1.0) : 1.0;
  CGFloat cornerRadius = [config getDouble:@"style/corner_radius"];
  CGFloat hilitedCornerRadius = [config getDouble:@"style/hilited_corner_radius"];
  CGFloat borderHeight = [config getDouble:@"style/border_height"];
  CGFloat borderWidth = [config getDouble:@"style/border_width"];
  CGFloat lineSpacing = [config getDouble:@"style/line_spacing"];
  CGFloat spacing = [config getDouble:@"style/spacing"];
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
    candidateLabelColor =
        [config getColor:[prefix stringByAppendingString:@"/label_color"]];
    highlightedCandidateLabelColor =
        [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]];
    if (!highlightedCandidateLabelColor) {
      // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color'
      // are both valid
      highlightedCandidateLabelColor =
        [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]];
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
      fontSize = fontSizeOverridden.integerValue;
    }
    NSString *labelFontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
    if (labelFontNameOverridden) {
      labelFontName = labelFontNameOverridden;
    }
    NSNumber *labelFontSizeOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"]];
    if (labelFontSizeOverridden) {
      labelFontSize = labelFontSizeOverridden.integerValue;
    }
    NSString *commentFontNameOverridden =
        [config getString:[prefix stringByAppendingString:@"/comment_font_face"]];
    if (commentFontNameOverridden) {
      commentFontName = commentFontNameOverridden;
    }
    NSNumber *commentFontSizeOverridden =
        [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"]];
    if (commentFontSizeOverridden) {
      commentFontSize = commentFontSizeOverridden.integerValue;
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
  if (labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(labelFontName);
    if (labelFontDescriptor == nil) {
      labelFontDescriptor = fontDescriptor;
    }
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize];
    }
  }
  if (labelFont == nil) {
    if (fontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:fontDescriptor size:labelFontSize];
    } else {
      labelFont = [NSFont fontWithName:font.fontName size:labelFontSize];
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

  NSMutableParagraphStyle *paragraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.paragraphSpacing = lineSpacing / 2;
  paragraphStyle.paragraphSpacingBefore = lineSpacing / 2;

  NSMutableParagraphStyle *preeditParagraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.paragraphSpacing = spacing / 2 + hilitedCornerRadius / 2;

  NSMutableDictionary *attrs = [theme.attrs mutableCopy];
  NSMutableDictionary *highlightedAttrs = [theme.highlightedAttrs mutableCopy];
  NSMutableDictionary *labelAttrs = [theme.labelAttrs mutableCopy];
  NSMutableDictionary *labelHighlightedAttrs = [theme.labelHighlightedAttrs mutableCopy];
  NSMutableDictionary *commentAttrs = [theme.commentAttrs mutableCopy];
  NSMutableDictionary *commentHighlightedAttrs = [theme.commentHighlightedAttrs mutableCopy];
  NSMutableDictionary *preeditAttrs = [theme.preeditAttrs mutableCopy];
  NSMutableDictionary *preeditHighlightedAttrs = [theme.preeditHighlightedAttrs mutableCopy];

  attrs[NSFontAttributeName] = font;
  highlightedAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  commentHighlightedAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  preeditHighlightedAttrs[NSFontAttributeName] = font;
  attrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  highlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];

  backgroundColor = backgroundColor ? backgroundColor : [NSColor windowBackgroundColor];
  candidateTextColor = candidateTextColor ? candidateTextColor : [NSColor controlTextColor];
  candidateLabelColor = candidateLabelColor ? candidateLabelColor :
  isNative ? secondaryTextColor : blendColors(candidateTextColor, backgroundColor);
  highlightedCandidateTextColor = highlightedCandidateTextColor ? highlightedCandidateTextColor : [NSColor selectedControlTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? highlightedCandidateBackColor : [NSColor selectedTextBackgroundColor];
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? highlightedCandidateLabelColor :
  isNative ? secondaryTextColor : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? commentTextColor : secondaryTextColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? highlightedCommentTextColor : commentTextColor;
  textColor = textColor ? textColor : secondaryTextColor;
  highlightedTextColor = highlightedTextColor ? highlightedTextColor : [NSColor controlTextColor];

  attrs[NSForegroundColorAttributeName] = candidateTextColor;
  highlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateTextColor;
  labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
  labelHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateLabelColor;
  commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
  commentHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCommentTextColor;
  preeditAttrs[NSForegroundColorAttributeName] = textColor;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = highlightedTextColor;

  [theme          setAttrs:attrs
                labelAttrs:labelAttrs
          highlightedAttrs:highlightedAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs];

  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle];

  [theme setBackgroundColor:backgroundColor
      highlightedBackColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];

  NSSize edgeInset;
  if (vertical) {
    edgeInset = NSMakeSize(borderHeight + cornerRadius, borderWidth + cornerRadius);
  } else {
    edgeInset = NSMakeSize(borderWidth + cornerRadius, borderHeight + cornerRadius);
  }

  [theme setCornerRadius:cornerRadius
     hilitedCornerRadius:hilitedCornerRadius
               edgeInset:edgeInset
             borderWidth:MIN(borderHeight, borderWidth)
               linespace:lineSpacing
        preeditLinespace:spacing
                   alpha:alpha
            translucency:translucency
                  linear:linear
                vertical:vertical
           inlinePreedit:inlinePreedit
        inlineCandidate:inlineCandidate];

  theme.native = isNative;
  theme.candidateFormat = (candidateFormat ? candidateFormat : kDefaultCandidateFormat);
}
@end
