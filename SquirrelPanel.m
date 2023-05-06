#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath {
  // Need to begin a path here.
  CGPathRef immutablePath = NULL;
  // Then draw the path elements.
  NSUInteger numElements = [self elementCount];
  if (numElements > 0) {
    CGMutablePathRef path = CGPathCreateMutable();
    NSPoint points[3];
    BOOL didClosePath = YES;
    for (NSUInteger i = 0; i < numElements; i++) {
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
@property(nonatomic, strong, readonly) NSColor *backgroundImage;
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
@property(nonatomic, readonly) CGFloat scaleFactor;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) BOOL translucency;
@property(nonatomic, readonly) BOOL showPaging;
@property(nonatomic, readonly) BOOL rememberSize;
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

@property(nonatomic, strong, readonly) NSString *prefixLabelFormat;
@property(nonatomic, strong, readonly) NSString *suffixLabelFormat;
@property(nonatomic, strong, readonly) NSString *statusMessageType;

- (void)setCandidateFormat:(NSString *)candidateFormat;
- (void)setStatusMessageType:(NSString *)statusMessageType;

- (void)setBackgroundColor:(NSColor *)backgroundColor
           backgroundImage:(NSColor *)backgroundImage
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
            scaleFactor:(CGFloat)scaleFactor
                  alpha:(CGFloat)alpha
           translucency:(BOOL)translucency
             showPaging:(BOOL)showPaging
           rememberSize:(BOOL)rememberSize
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

- (void)setStatusMessageType:(NSString *)type {
  if ([type isEqualToString: @"long"] || [type isEqualToString: @"short"] || [type isEqualToString: @"mix"]) {
    _statusMessageType = type;
  } else {
    _statusMessageType = @"mix";
  }
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
           backgroundImage:(NSColor *)backgroundImage
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor {
  _backgroundColor = backgroundColor;
  _backgroundImage = backgroundImage;
  _highlightedStripColor = highlightedStripColor;
  _highlightedPreeditColor = highlightedPreeditColor;
  _preeditBackgroundColor = preeditBackgroundColor;
  _borderColor = borderColor;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
    hilitedCornerRadius:(CGFloat)hilitedCornerRadius
              edgeInset:(NSSize)edgeInset
            borderWidth:(CGFloat)borderWidth
              linespace:(CGFloat)linespace
       preeditLinespace:(CGFloat)preeditLinespace
            scaleFactor:(CGFloat)scaleFactor
                  alpha:(CGFloat)alpha
           translucency:(BOOL)translucency
             showPaging:(BOOL)showPaging
           rememberSize:(BOOL)rememberSize
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate {
  _cornerRadius = cornerRadius;
  _hilitedCornerRadius = hilitedCornerRadius;
  _edgeInset = edgeInset;
  _borderWidth = borderWidth;
  _linespace = linespace;
  _scaleFactor = scaleFactor;
  _alpha = alpha;
  _translucency = translucency;
  _showPaging = showPaging;
  _rememberSize = rememberSize;
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
@property(nonatomic, readonly) NSArray<NSValue *> *candidateRanges;
@property(nonatomic, readonly) NSInteger highlightedIndex;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) NSMutableArray<NSBezierPath *> *candidatePaths;
@property(nonatomic, readonly) NSMutableArray<NSValue *> *pagingRects;
@property(nonatomic, readonly) NSUInteger pagingButton;
@property(nonatomic, readonly) BOOL isDark;
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, readonly) CAShapeLayer *shape;

- (BOOL)isFlipped;
@property (NS_NONATOMIC_IOSONLY, getter=isFlipped, readonly) BOOL flipped;
- (void)     drawViewWith:(NSArray<NSValue *> *)candidateRanges
         highlightedIndex:(NSInteger)highlightedIndex
             preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange
              pagingRange:(NSRange)pagingRange
             pagingButton:(NSUInteger)pagingButton;
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
  _textView.layoutManager.usesFontLeading = NO;
  _textView.layoutManager.typesetterBehavior = NSTypesetterBehavior_10_4;
  _defaultTheme = [[SquirrelTheme alloc] init];
  _candidatePaths = [NSMutableArray arrayWithCapacity:_candidateRanges.count];
  _pagingRects = [NSMutableArray arrayWithCapacity:2];
  _shape = [[CAShapeLayer alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
  }
  return self;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
  NSRange glyphRange = [_textView.layoutManager glyphRangeForTextContainer:_textView.textContainer];
  NSRect rect = [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
  NSRect finalLineRect = [_textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:NULL withoutAdditionalLayout:YES];
  // integral the size of the window rect to avoid pixel jumping
  CGFloat scaleFactor = self.currentTheme.scaleFactor;
  rect.size.height = round((NSMaxY(finalLineRect) - rect.origin.y) / scaleFactor) * scaleFactor;
  rect.size.width = round(rect.size.width / scaleFactor) * scaleFactor;;
  return rect;
}

// Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_textView.textContainer];
  return rect;
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void)     drawViewWith:(NSArray<NSValue *>*)candidateRanges
         highlightedIndex:(NSInteger)highlightedIndex
             preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange
              pagingRange:(NSRange)pagingRange
             pagingButton:(NSUInteger)pagingButton {
  _candidateRanges = candidateRanges;
  _highlightedIndex = highlightedIndex;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  _pagingRange = pagingRange;
  _pagingButton = pagingButton;
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
  CGVector diff = CGVectorMake(point.x - previousPoint.x, point.y - previousPoint.y);
  if (ABS(diff.dx) >= ABS(diff.dy)) {
    target.x += sign(diff.dx/beta)*beta;
  } else {
    target.y += sign(diff.dy/beta)*beta;
  }
  [path moveToPoint:target];
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
    previousPoint = (vertex[(vertex.count+i-1)%vertex.count]).pointValue;
    point = (vertex[i]).pointValue;
    nextPoint = (vertex[(i+1)%vertex.count]).pointValue;
    target = point;
    control1 = point;
    diff = CGVectorMake(point.x - previousPoint.x, point.y - previousPoint.y);
    if (ABS(diff.dx) >= ABS(diff.dy)) {
      target.x -= sign(diff.dx/beta)*beta;
      control1.x -= sign(diff.dx/beta)*alpha;
    } else {
      target.y -= sign(diff.dy/beta)*beta;
      control1.y -= sign(diff.dy/beta)*alpha;
    }
    [path lineToPoint:target];
    target = point;
    control2 = point;
    diff = CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
    if (ABS(diff.dx) > ABS(diff.dy)) {
      control2.x += sign(diff.dx/beta)*alpha;
      target.x += sign(diff.dx/beta)*beta;
    } else {
      control2.y += sign(diff.dy/beta)*alpha;
      target.y += sign(diff.dy/beta)*beta;
    }
    [path curveToPoint:target controlPoint1:control1 controlPoint2:control2];
  }
  [path closePath];
  return path;
}

NSArray<NSValue *> *rectVertex(NSRect rect) {
  return @[@(rect.origin),
           @(NSMakePoint(rect.origin.x, rect.origin.y+rect.size.height)),
           @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y+rect.size.height)),
           @(NSMakePoint(rect.origin.x+rect.size.width, rect.origin.y))];
}

void xyTranslation(NSMutableArray<NSValue *> *shape, CGFloat dx, CGFloat dy) {
  for (NSUInteger i = 0; i < shape.count; i += 1) {
    NSPoint point = (shape[i]).pointValue;
    point.x += dx;
    point.y += dy;
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
  NSSize edgeInset = self.currentTheme.edgeInset;
  *leadingRect = NSZeroRect;
  *bodyRect = NSZeroRect;
  *trailingRect = NSZeroRect;
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  NSPoint startPoint = [layoutManager locationForGlyphAtIndex:glyphRange.location];
  NSPoint endPoint = [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)];
  NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
  NSRect leadingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location effectiveRange:&leadingLineRange];
  if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
    *bodyRect = NSMakeRect(NSMinX(leadingLineRect)+startPoint.x+edgeInset.width, NSMinY(leadingLineRect)+edgeInset.height, endPoint.x-startPoint.x, NSHeight(leadingLineRect));
  } else {
    *leadingRect = NSMakeRect(NSMinX(leadingLineRect)+startPoint.x+edgeInset.width, NSMinY(leadingLineRect)+edgeInset.height, NSWidth(leadingLineRect)-startPoint.x, NSHeight(leadingLineRect));
    NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect trailingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:&trailingLineRange];
    *trailingRect = NSMakeRect(NSMinX(trailingLineRect)+edgeInset.width, NSMinY(trailingLineRect)+edgeInset.height, endPoint.x, NSHeight(trailingLineRect));
    NSRange bodyLineRange = NSMakeRange(NSMaxRange(leadingLineRange), trailingLineRange.location-NSMaxRange(leadingLineRange));
    if (bodyLineRange.length > 0) {
      *bodyRect = NSMakeRect(NSMinX(trailingLineRect)+edgeInset.width, NSMaxY(leadingLineRect)+edgeInset.height, NSMaxX(leadingLineRect)-NSMinX(trailingLineRect), NSMinY(trailingLineRect)-NSMaxY(leadingLineRect));
    }
  }
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
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], bodyVertex[1], bodyVertex[2], leadingVertex[3]];
  } else if (nearEmptyRect(leadingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], bodyVertex[3]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && nearEmptyRect(bodyRect) && NSMaxX(leadingRect)>NSMinX(trailingRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], trailingVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> * leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> * bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> * trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3]];
  } else {
    return @[];
  }
}

// If the point is outside the innerBox, will extend to reach the outerBox
void expand(NSMutableArray<NSValue *> *vertex, NSRect innerBorder, NSRect outerBorder) {
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
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

// If the point is outside the boundBox, will shrink to the border of boundBox
void shrink(NSMutableArray<NSValue *> *vertex, NSRect boundBox) {
  for (NSUInteger i = 0; i < vertex.count; i += 1) {
    NSPoint point = [vertex[i] pointValue];
    if (point.x < NSMinX(boundBox)) {
      point.x = NSMinX(boundBox);
    }
    if (point.y < NSMinY(boundBox)) {
      point.y = NSMinY(boundBox);
    }
    if (point.x > NSMaxX(boundBox)) {
      point.x = NSMaxX(boundBox);
    }
    if (point.y > NSMaxY(boundBox)) {
      point.y = NSMaxY(boundBox);
    }
    [vertex replaceObjectAtIndex:i withObject:@(point)];
  }
}

// All draws happen here
- (void)drawRect:(NSRect)dirtyRect {
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *nonCandidateBlockPath;
  NSBezierPath *candidateBlockPath;
  NSBezierPath *pageUpPath;
  NSBezierPath *pageDownPath;
  SquirrelTheme *theme = self.currentTheme;

  [NSBezierPath setDefaultLineWidth:0];
  NSRect backgroundRect = dirtyRect;
  NSRect textField = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);
  
  // Draw preedit Rect
  NSRect preeditRect = NSZeroRect;
  if (_preeditRange.length > 0) {
    preeditRect = [self contentRectForRange:_preeditRange];
    preeditRect.size.width = backgroundRect.size.width;
    preeditRect.size.height += theme.edgeInset.height + theme.preeditLinespace/2.0;
    preeditRect.origin = backgroundRect.origin;
    if (_highlightedIndex == NSNotFound) {
      preeditRect.size.height += theme.edgeInset.height - theme.preeditLinespace/2.0;
    }
  }

  // Draw paging Rect
  NSRect pagingRect = NSZeroRect;
  if (_pagingRange.length > 0) {
    if (!theme.linear) {
      pagingRect = [self contentRectForRange:_pagingRange];
      pagingRect.size.width = backgroundRect.size.width;
      pagingRect.size.height += theme.edgeInset.height;
      pagingRect.origin.x = backgroundRect.origin.x;
      pagingRect.origin.y += theme.edgeInset.height;
    }
    NSRect pageUpRect = [self contentRectForRange:NSMakeRange(_pagingRange.location, 2)];
    pageUpRect.origin.y += theme.edgeInset.height;
    pageUpRect.origin.x += theme.edgeInset.width;
    _pagingRects[0] = [NSValue valueWithRect:pageUpRect];
    NSRect pageDownRect = [self contentRectForRange:NSMakeRange(NSMaxRange(_pagingRange)-2, 2)];
    pageDownRect.origin.y += theme.edgeInset.height;
    pageDownRect.origin.x += theme.edgeInset.width;
    _pagingRects[1] = [NSValue valueWithRect:pageDownRect];
    if (theme.highlightedPreeditColor != nil) {
      pageUpPath = [NSBezierPath bezierPathWithRoundedRect:pageUpRect xRadius:pageUpRect.size.height * 0.2 yRadius:pageUpRect.size.width * 0.2];
      pageDownPath = [NSBezierPath bezierPathWithRoundedRect:pageDownRect xRadius:pageDownRect.size.height * 0.2 yRadius:pageDownRect.size.width * 0.2];
    }
  }

  // Draw candidate Rect
  if (_highlightedIndex != NSNotFound) {
    NSRect outerBox = NSInsetRect(backgroundRect, theme.edgeInset.width, 0);
    outerBox.size.height -= preeditRect.size.height + pagingRect.size.height;
    outerBox.origin.y += preeditRect.size.height;
    if (_preeditRange.length == 0) {
      outerBox.size.height -= theme.edgeInset.height;
      outerBox.origin.y += theme.edgeInset.height;
    }
    if (_pagingRange.length == 0 || theme.linear) {
      outerBox.size.height -= theme.edgeInset.height;
    }
    NSRect innerBox = NSInsetRect(outerBox, 0, theme.linespace/2.0);
    if (theme.preeditBackgroundColor != nil) {
      candidateBlockPath = drawSmoothLines(rectVertex(outerBox), 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    }

    if (theme.linear) {
      for (NSUInteger i = 0; i < _candidateRanges.count; i += 1) {
        NSRange candidateRange = _candidateRanges[i].rangeValue;
        NSRect leadingRect;
        NSRect bodyRect;
        NSRect trailingRect;
        [self multilineRectForRange:candidateRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

        NSMutableArray<NSValue *> *candidatePoints;
        NSMutableArray<NSValue *> *candidatePoints2;
        // Handles the special case where containing boxes are separated
        if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePoints = [rectVertex(leadingRect) copy];
          candidatePoints2 = [rectVertex(trailingRect) copy];
        } else {
          candidatePoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) copy];
        }

        NSBezierPath *candidatePath = drawSmoothLines(candidatePoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
        if (candidatePoints2.count > 0) {
          [candidatePath appendBezierPath:drawSmoothLines(candidatePoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius)];
        }
        _candidatePaths[i] = candidatePath;
      }
    } else {
      for (NSUInteger i = 0; i < _candidateRanges.count; i += 1) {
        NSRange candidateRange = _candidateRanges[i].rangeValue;
        NSRect candidateRect = [self contentRectForRange:candidateRange];
        candidateRect.size.width = textField.size.width;
        candidateRect.origin.x = textField.origin.x;
        candidateRect.origin.y += theme.edgeInset.height;
        NSMutableArray<NSValue *> *candidatePoints = [rectVertex(candidateRect) mutableCopy];
        expand(candidatePoints, innerBox, outerBox);

        NSBezierPath *candidatePath = drawSmoothLines(candidatePoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
    if (theme.highlightedStripColor != nil) {
      highlightedPath = _candidatePaths[_highlightedIndex];
    }
  }

  // Draw highlighted part of preedit text
  if (_highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
    NSRect innerBox = NSInsetRect(preeditRect, theme.edgeInset.width, theme.edgeInset.height);
    if (_highlightedIndex != NSNotFound) {
      innerBox.size.height -= theme.preeditLinespace/2.0 - theme.edgeInset.height;
    }
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:_highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];

    NSMutableArray<NSValue *> *highlightedPreeditPoints;
    NSMutableArray<NSValue *> *highlightedPreeditPoints2;
    // Handles the special case where containing boxes are separated
    if (nearEmptyRect(bodyRect) && !nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
      highlightedPreeditPoints = [rectVertex(leadingRect) mutableCopy];
      highlightedPreeditPoints2 = [rectVertex(trailingRect) mutableCopy];
    } else {
      highlightedPreeditPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
    }
    shrink(highlightedPreeditPoints, innerBox);
    highlightedPreeditPath = drawSmoothLines(highlightedPreeditPoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    if (highlightedPreeditPoints2.count > 0) {
      shrink(highlightedPreeditPoints2, innerBox);
      [highlightedPreeditPath appendBezierPath:drawSmoothLines(highlightedPreeditPoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius)];
    }
  }

  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), 0.3*theme.cornerRadius, 1.4*theme.cornerRadius);
  _shape.path = [backgroundPath quartzPath];

  NSRect borderRect = NSInsetRect(backgroundRect, theme.edgeInset.width/2 - theme.borderWidth/2, theme.edgeInset.height/2 - theme.borderWidth/2);
  borderPath = drawSmoothLines(rectVertex(borderRect), 0.3*theme.cornerRadius, 1.4*theme.cornerRadius);
  borderPath.lineWidth = theme.borderWidth;

  // set layers
  [self.layer setSublayers: NULL];
  CAShapeLayer *maskLayer = [CAShapeLayer layer];
  maskLayer.path = [backgroundPath quartzPath];
  if (theme.backgroundImage) {
    self.layer.backgroundColor = [theme.backgroundImage CGColor];
  }
  CAShapeLayer *panelLayer = [CAShapeLayer layer];
  panelLayer.path = [backgroundPath quartzPath];
  panelLayer.fillColor = [theme.backgroundColor CGColor];
  [self.layer addSublayer:panelLayer];
  if (theme.preeditBackgroundColor &&
      (_preeditRange.length > 0 || _highlightedIndex != NSNotFound)) {
    if (_highlightedIndex != NSNotFound && theme.highlightedStripColor) {
      CAShapeLayer *highlightedLayer = [CAShapeLayer layer];
      highlightedLayer.path = [highlightedPath quartzPath];
      highlightedLayer.fillColor = [theme.highlightedStripColor CGColor];
      [panelLayer addSublayer:highlightedLayer];
    }
    nonCandidateBlockPath = [backgroundPath copy];
    if (![candidateBlockPath isEmpty]) {
      [nonCandidateBlockPath appendBezierPath:candidateBlockPath];
      [nonCandidateBlockPath setWindingRule:NSEvenOddWindingRule];
    }
    CAShapeLayer *nonCandidateLayer = [CAShapeLayer layer];
    nonCandidateLayer.path = [nonCandidateBlockPath quartzPath];
    nonCandidateLayer.fillRule = kCAFillRuleEvenOdd;
    nonCandidateLayer.fillColor = [theme.preeditBackgroundColor CGColor];
    [panelLayer addSublayer:nonCandidateLayer];
  }
  if (theme.highlightedPreeditColor) {
    if (_pagingRange.length > 0) {
      CAShapeLayer *pageUpLayer = [CAShapeLayer layer];
      pageUpLayer.path = [pageUpPath quartzPath];
      pageUpLayer.fillColor = nil;
      CAShapeLayer *pageDownLayer = [CAShapeLayer layer];
      pageDownLayer.path = [pageDownPath quartzPath];
      pageDownLayer.fillColor = nil;
      if (_pagingButton == NSPageUpFunctionKey) {
        pageUpLayer.fillColor = [[theme.highlightedPreeditColor colorWithSystemEffect:NSColorSystemEffectRollover] CGColor];
      } if (_pagingButton == NSBeginFunctionKey) {
        pageUpLayer.fillColor = [[theme.highlightedPreeditColor colorWithSystemEffect:NSColorSystemEffectDisabled] CGColor];
      } else if (_pagingButton == NSPageDownFunctionKey) {
        pageDownLayer.fillColor = [[theme.highlightedPreeditColor colorWithSystemEffect:NSColorSystemEffectRollover] CGColor];
      } else if (_pagingButton == NSEndFunctionKey) {
        pageDownLayer.fillColor = [[theme.highlightedPreeditColor colorWithSystemEffect:NSColorSystemEffectDisabled] CGColor];
      }
      [panelLayer addSublayer:pageUpLayer];
      [panelLayer addSublayer:pageDownLayer];
    }
    if(![highlightedPreeditPath isEmpty]) {
      CAShapeLayer *highlightedPreeditLayer = [CAShapeLayer layer];
      highlightedPreeditLayer.path = [highlightedPreeditPath quartzPath];
      highlightedPreeditLayer.fillColor = [theme.highlightedPreeditColor CGColor];
      [panelLayer addSublayer:highlightedPreeditLayer];
    }
  }
  if (theme.borderColor && (theme.borderWidth > 0)) {
    CAShapeLayer *borderLayer = [CAShapeLayer layer];
    borderLayer.path = [borderPath quartzPath];
    borderLayer.lineWidth = theme.borderWidth;
    borderLayer.fillColor = nil;
    borderLayer.strokeColor = [theme.borderColor CGColor];
    borderLayer.mask = maskLayer;
    [panelLayer addSublayer:borderLayer];
  }

  [_textView setTextContainerInset:theme.edgeInset];
  [self.layer setShouldRasterize:YES];
  [self.layer setRasterizationScale:theme.scaleFactor];
}

- (BOOL)clickAtPoint:(NSPoint)_point index:(NSInteger *)_index {
  if (CGPathContainsPoint(_shape.path, NULL, _point, NO)) {
    if (_pagingRects[0] != nil && NSPointInRect(_point, _pagingRects[0].rectValue)) {
      *_index = NSPageUpFunctionKey;
      return YES;
    } else if (_pagingRects[1] != nil && NSPointInRect(_point, _pagingRects[1].rectValue)) {
      *_index = NSPageDownFunctionKey;
      return YES;
    }
    for (NSUInteger i = 0; i < _candidatePaths.count; i++) {
      if ([_candidatePaths[i] containsPoint:_point]) {
        *_index = i;
        return YES;
      }
    }
  }
  return NO;
}

@end

@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;

  NSRect _screenRect;
  CGFloat _maxHeight;
  CGFloat _maxTextWidth;

  NSString *_preedit;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray *_candidates;
  NSArray *_comments;
  NSArray *_labels;
  NSUInteger _index;
  NSUInteger _pageNum;
  NSInteger _turnPage;
  BOOL _lastPage;
  NSUInteger _cursorIndex;
  
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

- (BOOL)showPaging {
  return _view.currentTheme.showPaging;
}

- (BOOL)rememberSize {
  return _view.currentTheme.rememberSize;
}

void fixDefaultFont(NSMutableAttributedString *text) {
  [text fixFontAttributeInRange:NSMakeRange(0, text.length)];
  NSRange currentFontRange = NSMakeRange(NSNotFound, 0);
  NSUInteger i = 0;
  while (i < text.length) {
    NSFont *charFont = [text attribute:NSFontAttributeName atIndex:i effectiveRange:&currentFontRange];
    if ([charFont.fontName isEqualToString:@"AppleColorEmoji"]) {
      NSFont *defaultFont = [NSFont systemFontOfSize:charFont.pointSize];
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
  pagingAttrs[NSFontAttributeName] = [NSFont fontWithName:@"AppleSymbols" size:kDefaultFontSize];

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
                          styleMask:(NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskBorderless)
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

- (NSPoint)mousePosition {
  NSPoint point = NSEvent.mouseLocation;
  point = [self convertPointFromScreen:point];
  return [_view convertPoint:point fromView:nil];
}

- (void)sendEvent:(NSEvent *)event {
  switch (event.type) {
    case NSEventTypeLeftMouseDown:
    case NSEventTypeRightMouseDown: {
      NSPoint point = [self mousePosition];
      NSInteger index = NSNotFound;
      if ([_view clickAtPoint:point index:&index]) {
        if ((index >= 0 && index < _candidates.count) ||
            index == NSPageUpFunctionKey || index == NSPageDownFunctionKey) {
          _index = index;
        }
      }
    } break;
    case NSEventTypeLeftMouseUp: {
      NSPoint point = [self mousePosition];
      NSInteger index = NSNotFound;
      if ([_view clickAtPoint:point index:&index]) {
        if (((index >= 0 && index < _candidates.count) || index == NSPageUpFunctionKey ||
             index == NSPageDownFunctionKey) && index == _index) {
          [_inputController actionWithCandidate:index];
        }
      }
    } break;
    case NSEventTypeRightMouseUp: {
      NSPoint point = [self mousePosition];
      NSInteger index = NSNotFound;
      if ([_view clickAtPoint:point index:&index]) {
        if ((index >= 0 && index < _candidates.count) && index == _index) {
          [_inputController actionWithCandidate:-1-index]; // negative index for deletion
        }
      }
    } break;
    case NSEventTypeMouseEntered: {
      self.acceptsMouseMovedEvents = YES;
    } break;
    case NSEventTypeMouseExited: {
      self.acceptsMouseMovedEvents = NO;
      if (_cursorIndex != _index) {
        [self showPreedit:_preedit selRange:_selRange caretPos:_caretPos candidates:_candidates comments:_comments labels:_labels
              highlighted:_index pageNum:_pageNum lastPage:_lastPage turnPage:NSNotFound update:NO];
      }
    } break;
    case NSEventTypeMouseMoved: {
      NSPoint point = [self mousePosition];
      NSInteger index = NSNotFound;
      if ([_view clickAtPoint: point index:&index]) {
        if (index >= 0 && index < _candidates.count && _cursorIndex != index) {
          [self showPreedit:_preedit selRange:_selRange caretPos:_caretPos candidates:_candidates comments:_comments labels:_labels
                highlighted:index pageNum:_pageNum lastPage:_lastPage turnPage:NSNotFound update:NO];
        } else if (index == NSPageUpFunctionKey || index == NSPageDownFunctionKey ||
                   index == NSBeginFunctionKey || index == NSEndFunctionKey) { // borrow corresponding unicodes for readability
          [self showPreedit:_preedit selRange:_selRange caretPos:_caretPos candidates:_candidates comments:_comments labels:_labels
                highlighted:_index pageNum:_pageNum lastPage:_lastPage turnPage:index update:NO];
        }
      }
    } break;
    default:
      break;
  }
  [super sendEvent:event];
}

- (void)getCurrentScreen {
  // get current screen
  _screenRect = [NSScreen mainScreen].frame;
  NSArray *screens = [NSScreen screens];
  for (NSUInteger i = 0; i < screens.count; ++i) {
    NSRect rect = [screens[i] frame];
    if (NSPointInRect(_position.origin, rect)) {
      _screenRect = rect;
      break;
    }
  }
}

// Get the window size, its bounds (insetRect) will be the dirtyRect in SquirrelView.drawRect
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
  CGFloat fontScale = currentFont.pointSize / 12.0 / theme.scaleFactor;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + fontScale / 12.0);
  _maxTextWidth = theme.vertical
  ? NSHeight(_screenRect) * textWidthRatio * theme.scaleFactor - theme.edgeInset.height * 2
  : NSWidth(_screenRect) * textWidthRatio * theme.scaleFactor - theme.edgeInset.width * 2;
  CGFloat maxTextHeight = theme.vertical
  ? NSWidth(_screenRect) * theme.scaleFactor - theme.edgeInset.width * 2
  : NSHeight(_screenRect) * theme.scaleFactor - theme.edgeInset.height * 2;
  if (textWidth > _maxTextWidth) {
    textWidth = _maxTextWidth;
  }
  _view.textView.textContainer.containerSize = NSMakeSize(textWidth, maxTextHeight);

  // in vertical mode, the width and height are interchanged
  NSRect contentRect = _view.contentRect;
  if (theme.rememberSize && (theme.vertical ? (NSMinY(_position) / NSHeight(_screenRect) <= textWidthRatio) :
      ((NSMinX(_position) + (MAX(contentRect.size.width, _maxHeight)+theme.edgeInset.width*2)/theme.scaleFactor > NSMaxX(_screenRect))))) {
    if (contentRect.size.width >= _maxHeight) {
      _maxHeight = contentRect.size.width;
    } else {
      contentRect.size.width = _maxHeight;
      _view.textView.textContainer.containerSize = NSMakeSize(_maxHeight, maxTextHeight);
    }
  }

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  NSRect windowRect;
  bool sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSSize scaledRectSize = NSMakeSize(contentRect.size.width + theme.edgeInset.width * 2,
                                     contentRect.size.height + theme.edgeInset.height * 2);
  if (theme.vertical) {
    windowRect.size = NSMakeSize(scaledRectSize.height / theme.scaleFactor, scaledRectSize.width / theme.scaleFactor);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMinY(_position) / NSHeight(_screenRect) > textWidthRatio) {
      windowRect.origin.y = NSMinY(_position) + (sweepVertical ? theme.edgeInset.width / theme.scaleFactor : -kOffsetHeight) - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
    }
    // Make the right edge of candidate block fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
    if (!sweepVertical && _view.preeditRange.length > 0) {
      CGFloat preeditHeight = NSHeight([_view contentRectForRange:_view.preeditRange]);
      windowRect.origin.x += (preeditHeight + theme.edgeInset.height) / theme.scaleFactor;
    }
  } else {
    windowRect.size = NSMakeSize(scaledRectSize.width / theme.scaleFactor, scaledRectSize.height / theme.scaleFactor);
    if (sweepVertical) {
      // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
      if (NSMinX(_position) / NSWidth(_screenRect) > textWidthRatio) {
        windowRect.origin.x = NSMinX(_position) - kOffsetHeight - NSWidth(windowRect);
      } else {
        windowRect.origin.x = NSMaxX(_position) + kOffsetHeight + theme.edgeInset.width / theme.scaleFactor;
      }
      windowRect.origin.y = NSMinY(_position) - NSHeight(windowRect);
    } else {
      windowRect.origin = NSMakePoint(NSMinX(_position) - theme.edgeInset.width / theme.scaleFactor,
                                      NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(_screenRect)) {
    windowRect.origin.x = (sweepVertical ? NSMinX(_position)-kOffsetHeight : NSMaxX(_screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(_screenRect)) {
    windowRect.origin.x = sweepVertical ? NSMaxX(_position)+kOffsetHeight : NSMinX(_screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(_screenRect)) {
    windowRect.origin.y = sweepVertical ? NSMinY(_screenRect) : NSMaxY(_position)+kOffsetHeight;
  }
  if (NSMaxY(windowRect) > NSMaxY(_screenRect)) {
    windowRect.origin.y = (sweepVertical ? NSMaxY(_screenRect) : NSMinY(_position)-kOffsetHeight) - NSHeight(windowRect);
  }

  [self setFrame:windowRect display:YES];
  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    self.contentView.boundsRotation = -90.0;
    [self.contentView setBoundsSize:NSMakeSize(scaledRectSize.height, scaledRectSize.width)];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, windowRect.size.width)];
  } else {
    self.contentView.boundsRotation = 0.0;
    [self.contentView setBoundsSize:NSMakeSize(scaledRectSize.width, scaledRectSize.height)];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, 0.0)];
  }

  [_view setFrame:self.contentView.bounds];
  [_view.textView setFrame:self.contentView.bounds];
  _view.textView.boundsRotation = 0.0;
  [_view.textView setBoundsOrigin:NSMakePoint(0.0, 0.0)];
  BOOL translucency = theme.translucency;
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
           lastPage:(BOOL)lastPage
           turnPage:(NSUInteger)turnPage
             update:(BOOL)update {
  if (update) {
    _preedit = preedit;
    _selRange = selRange;
    _caretPos = caretPos;
    _candidates = candidates;
    _comments = comments;
    _labels = labels;
    _index = index;
    _pageNum = pageNum;
    _lastPage = lastPage;
  }
  NSUInteger numCandidates = candidates.count;
  if (numCandidates == 0) {
    _index = index = NSNotFound;
  }
  _cursorIndex = index;

  if (turnPage == NSPageUpFunctionKey || turnPage == NSBeginFunctionKey) {
    _turnPage = pageNum ? NSPageUpFunctionKey : NSBeginFunctionKey;
  } else if (turnPage == NSPageDownFunctionKey || turnPage == NSEndFunctionKey) {
    _turnPage = lastPage ? NSEndFunctionKey : NSPageDownFunctionKey;
  } else {
    _turnPage = NSNotFound;
  }

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
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  CGFloat preeditWidth = 0.0;
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
    [preeditLine addAttribute:NSParagraphStyleAttributeName
                        value:theme.preeditParagraphStyle
                        range:NSMakeRange(0, preeditLine.length)];

    [text appendAttributedString:preeditLine];
    preeditRange = NSMakeRange(0, text.length);
    preeditWidth = NSWidth([preeditLine boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                   attributes:theme.preeditAttrs]];
    }
  }

  // prepare paging and separator for width calculation but no insertion yet
  NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] initWithString:@""
                                                                             attributes:theme.pagingAttrs];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:(pageNum ? @"◀\ufe0e" : @"◁\ufe0e").precomposedStringWithCanonicalMapping
                                                                 attributes:theme.pagingAttrs]];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:theme.linear ? @" %lu " : @"\t%lu\t", pageNum+1]
                                                                 attributes:theme.pagingAttrs]];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:(lastPage ? @"▷\ufe0e" : @"▶\ufe0e").precomposedStringWithCanonicalMapping
                                                                 attributes:theme.pagingAttrs]];
  fixDefaultFont(paging);
  CGFloat pagingWidth = theme.showPaging ? NSMaxX([paging boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]) : 0;

  CGFloat separatorWidth = theme.linear ? NSMaxX([[[NSAttributedString alloc] initWithString:@"  " attributes:theme.attrs] boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]) : 0;
  CGFloat lineWidth = 0.0 - separatorWidth;
  CGFloat maxLineWidth = MIN(preeditWidth, _maxTextWidth);
  BOOL multiLine = NO;

  // candidates
  NSUInteger candidateBlockStart = text.length;
  NSMutableArray<NSValue *> *candidateRanges = [[NSMutableArray alloc] init];
  for (NSUInteger i = 0; i < candidates.count; ++i) {
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
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:suffixLabelString
                                                                   attributes:attrs]];
    }

    fixDefaultFont(line);
    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    // determine if the line is too wide and line break is needed, based on screen size.
    NSString *separtatorString = @"\u2029";
    CGFloat candidateWidth = NSWidth([line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
    if (theme.linear) {
      if (i == numCandidates-1) {
        candidateWidth += separatorWidth + pagingWidth;
      }
      if (lineWidth + separatorWidth + candidateWidth > _maxTextWidth) {
        separtatorString = @"\u2028";
        multiLine = YES;
        maxLineWidth = MAX(maxLineWidth, lineWidth);
        lineWidth = candidateWidth;
      } else {
        separtatorString = @"  ";
        lineWidth += separatorWidth + candidateWidth;
      }
    } else {
      maxLineWidth = MAX(maxLineWidth, MIN(candidateWidth, _maxTextWidth));
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    NSAttributedString *separator = [[NSAttributedString alloc] initWithString:separtatorString attributes:theme.attrs];

    if (i > 0) {
      [text appendAttributedString:separator];
    }
    [line addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, line.length)];
    [candidateRanges addObject:[NSValue valueWithRange:NSMakeRange(text.length, line.length)]];
    [text appendAttributedString:line];
  }

  // paging indication
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);
  if (numCandidates && theme.showPaging) {
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:theme.linear ? (multiLine ? @"\t" : @"  ") : @"\n" attributes:theme.attrs]];
    pagingRange = NSMakeRange(text.length, paging.length);
    if (theme.rememberSize) {
      maxLineWidth = MAX(maxLineWidth, _maxHeight);
    }
    if (theme.linear) {
      [text appendAttributedString:paging];
      NSMutableParagraphStyle *paragraphStylePaging = [theme.paragraphStyle mutableCopy];
      paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineWidth]];
      [text addAttribute:NSParagraphStyleAttributeName value:paragraphStylePaging range:NSMakeRange(candidateBlockStart, text.length-candidateBlockStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSCenterTabStopType location:maxLineWidth/2],
                                        [[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineWidth]];
      [paging addAttribute:NSParagraphStyleAttributeName value:paragraphStylePaging range:NSMakeRange(0, paging.length)];
      [text appendAttributedString:paging];
    }
  }

  // extra line fragment will not actually be drawn but ensures the spacing after the last line
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.attrs]];

  [text fixAttributesInRange:NSMakeRange(0, text.length)];
  [_view.textView.textStorage setAttributedString:text];
  _view.textView.layoutOrientation = theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  // text done!
  [_view drawViewWith:candidateRanges highlightedIndex:index preeditRange:preeditRange highlightedPreeditRange:highlightedPreeditRange pagingRange:pagingRange pagingButton:_turnPage];

  [self show];
}

- (void)updateStatusLong:(NSString *)messageLong statusShort:(NSString *)messageShort {
  SquirrelTheme *theme = _view.currentTheme;
  if ([theme.statusMessageType isEqualToString:@"mix"]) {
    if (messageShort) {
      _statusMessage = messageShort;
    } else {
      _statusMessage = messageLong;
    }
  } else if ([theme.statusMessageType isEqualToString:@"long"]) {
    _statusMessage = messageLong;
  } else if ([theme.statusMessageType isEqualToString:@"short"]) {
    if (messageShort) {
      _statusMessage = messageShort;
    } else if (messageLong) {
      _statusMessage = [messageLong substringWithRange:[messageLong rangeOfComposedCharacterSequenceAtIndex:0]];
    }
  }
}

- (void)showStatus:(NSString *)message {
  SquirrelTheme *theme = _view.currentTheme;
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:message.precomposedStringWithCanonicalMapping attributes:theme.commentAttrs];
  [text addAttribute:NSKernAttributeName value:@(0) range:NSMakeRange(0, text.length)];
  fixDefaultFont(text);

  [text fixAttributesInRange:NSMakeRange(0, text.length)];
  [_view.textView.textStorage setAttributedString:text];
  _view.textView.layoutOrientation = theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  [_view drawViewWith:@[] highlightedIndex:NSNotFound preeditRange:emptyRange highlightedPreeditRange:emptyRange pagingRange:emptyRange pagingButton:NSNotFound];
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
  if (!backgroundColor) { // return foregroundColor;
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
      [validFontDescriptors addObject:[NSFontDescriptor fontDescriptorWithName:fontName size:0.0]];
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
  BOOL showPaging = [config getBool:@"style/show_paging"];
  BOOL rememberSize = [config getBool:@"style/remember_size"];
  NSString *statusMessageType = [config getString:@"style/status_message_type"];
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
  CGFloat lineSpacing = [config getDouble:@"style/line_spacing"];
  CGFloat spacing = [config getDouble:@"style/spacing"];
  CGFloat baseOffset = [config getDouble:@"style/base_offset"];

  NSColor *backgroundColor;
  NSColor *backgroundImage;
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
    backgroundImage = [config getImage:[prefix stringByAppendingString:@"/back_image"]];
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
    NSNumber *showPagingOverridden =
        [config getOptionalBool:[prefix stringByAppendingString:@"/show_paging"]];
    if (showPagingOverridden) {
      showPaging = showPagingOverridden.boolValue;
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
  CGFloat scaleFactor = MAX(1.0, kDefaultFontSize/fontSize);
  NSFontDescriptor *fontDescriptor = nil;
  NSFont *font = nil;
  if (fontName != nil) {
    fontDescriptor = getFontDescriptor(fontName);
    if (fontDescriptor != nil) {
      font = [NSFont fontWithDescriptor:fontDescriptor size:fontSize * scaleFactor];
    }
  }
  if (font == nil) { // use default font
    font = [NSFont userFontOfSize:fontSize * scaleFactor];
  }
  NSFontDescriptor *labelFontDescriptor = nil;
  NSFont *labelFont = nil;
  if (labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(labelFontName);
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize * scaleFactor];
    }
  }
  if (labelFont == nil) {
    labelFont = [NSFont monospacedDigitSystemFontOfSize:labelFontSize * scaleFactor weight:NSFontWeightRegular];
  }
  NSFontDescriptor *commentFontDescriptor = nil;
  NSFont *commentFont = nil;
  if (commentFontName != nil) {
    commentFontDescriptor = getFontDescriptor(commentFontName);
    if (commentFontDescriptor == nil) {
      commentFontDescriptor = fontDescriptor;
    }
    if (commentFontDescriptor != nil) {
      commentFont = [NSFont fontWithDescriptor:commentFontDescriptor size:commentFontSize * scaleFactor];
    }
  }
  if (commentFont == nil) {
    if (fontDescriptor != nil) {
      commentFont = [NSFont fontWithDescriptor:fontDescriptor size:commentFontSize * scaleFactor];
    } else {
      commentFont = [NSFont fontWithName:font.fontName size:commentFontSize * scaleFactor];
    }
  }
  NSFont *pagingFont = [NSFont fontWithName:@"AppleSymbols" size:labelFontSize * scaleFactor];

  CGFloat fontLineHeight = MAX(font.ascender - font.descender, [NSFont systemFontOfSize:fontSize].ascender - [NSFont systemFontOfSize:fontSize].descender);
  CGFloat commentLineHeight = MAX(commentFont.ascender - commentFont.descender, [NSFont systemFontOfSize:commentFontSize].ascender - [NSFont systemFontOfSize:commentFontSize].descender);
  CGFloat labelLineHeight = MAX(labelFont.ascender - labelFont.descender, [NSFont systemFontOfSize:labelFontSize].ascender - [NSFont systemFontOfSize:labelFontSize].descender);
  CGFloat lineHeight = MAX(fontLineHeight, MAX(commentLineHeight, labelLineHeight));

  NSMutableParagraphStyle *preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.alignment = NSTextAlignmentLeft;
  preeditParagraphStyle.minimumLineHeight = fontLineHeight;
  preeditParagraphStyle.paragraphSpacing = spacing/2.0 * scaleFactor;

  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.alignment = NSTextAlignmentLeft;
  paragraphStyle.minimumLineHeight = lineHeight + lineSpacing/2.0 * scaleFactor;
  paragraphStyle.lineSpacing = lineSpacing/2.0 * scaleFactor;

  NSMutableParagraphStyle *pagingParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  pagingParagraphStyle.alignment = NSTextAlignmentLeft;

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
  attrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  highlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  labelAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  commentAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  preeditAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor);
  pagingAttrs[NSBaselineOffsetAttributeName] = @(baseOffset * scaleFactor - ceil(labelFontSize/5.0));

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
  labelAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  highlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  commentAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  commentHighlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  preeditAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  preeditHighlightedAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;
  pagingAttrs[NSVerticalGlyphFormAttributeName] = vertical ? @YES : @NO;

  [theme setStatusMessageType:statusMessageType];

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
            backgroundImage:backgroundImage
      highlightedStripColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];

  borderHeight = MAX(borderHeight, cornerRadius - cornerRadius / sqrt(2)) * scaleFactor;
  borderWidth = MAX(borderWidth, cornerRadius - cornerRadius / sqrt(2)) * scaleFactor;
  NSSize edgeInset = vertical ? NSMakeSize(borderHeight, borderWidth) : NSMakeSize(borderWidth, borderHeight);

  [theme setCornerRadius:cornerRadius * scaleFactor
     hilitedCornerRadius:hilitedCornerRadius * scaleFactor
               edgeInset:edgeInset
             borderWidth:MAX(borderHeight, borderWidth)
               linespace:lineSpacing * scaleFactor
        preeditLinespace:spacing * scaleFactor
             scaleFactor:scaleFactor
                   alpha:(alpha == 0 ? 1.0 : alpha)
            translucency:translucency
              showPaging:showPaging
            rememberSize:rememberSize
                  linear:linear
                vertical:vertical
           inlinePreedit:inlinePreedit
         inlineCandidate:inlineCandidate];

  theme.native = isNative;
  theme.candidateFormat = (candidateFormat ? candidateFormat : kDefaultCandidateFormat);
}

@end
