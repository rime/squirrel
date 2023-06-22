#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath {
  // Need to begin a path here.
  CGPathRef immutablePath = NULL;
  // Then draw the path elements.
  NSUInteger numElements = self.elementCount;
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
    immutablePath = CFAutorelease(CGPathCreateCopy(path));
    CGPathRelease(path);
  }
  return immutablePath;
}
@end

static const CGFloat kOffsetHeight = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c %@";

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
@property(nonatomic, readonly) CGFloat linespace;
@property(nonatomic, readonly) CGFloat preeditLinespace;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) CGFloat translucency;
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
@property(nonatomic, strong, readonly) NSDictionary *pagingHighlightedAttrs;
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
              linespace:(CGFloat)linespace
       preeditLinespace:(CGFloat)preeditLinespace
                  alpha:(CGFloat)alpha
           translucency:(CGFloat)translucency
             showPaging:(BOOL)showPaging
           rememberSize:(BOOL)rememberSize
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate;

- (void)       setAttrs:(NSMutableDictionary *)attrs
       highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
             labelAttrs:(NSMutableDictionary *)labelAttrs
  labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
           commentAttrs:(NSMutableDictionary *)commentAttrs
commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
           preeditAttrs:(NSMutableDictionary *)preeditAttrs
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
            pagingAttrs:(NSMutableDictionary *)pagingAttrs
 pagingHighlightedAttrs:(NSMutableDictionary *)pagingHighlightedAttrs;

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
              linespace:(CGFloat)linespace
       preeditLinespace:(CGFloat)preeditLinespace
                  alpha:(CGFloat)alpha
           translucency:(CGFloat)translucency
             showPaging:(BOOL)showPaging
           rememberSize:(BOOL)rememberSize
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate {
  _cornerRadius = cornerRadius;
  _hilitedCornerRadius = hilitedCornerRadius;
  _edgeInset = edgeInset;
  _linespace = linespace;
  _preeditLinespace = preeditLinespace;
  _alpha = alpha;
  _translucency = translucency;
  _showPaging = showPaging;
  _rememberSize = rememberSize;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
  _inlineCandidate = inlineCandidate;
}

- (void)       setAttrs:(NSMutableDictionary *)attrs
       highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
             labelAttrs:(NSMutableDictionary *)labelAttrs
  labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
           commentAttrs:(NSMutableDictionary *)commentAttrs
commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
           preeditAttrs:(NSMutableDictionary *)preeditAttrs
preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
            pagingAttrs:(NSMutableDictionary *)pagingAttrs
 pagingHighlightedAttrs:(NSMutableDictionary *)pagingHighlightedAttrs{
  _attrs = attrs;
  _highlightedAttrs = highlightedAttrs;
  _labelAttrs = labelAttrs;
  _labelHighlightedAttrs = labelHighlightedAttrs;
  _commentAttrs = commentAttrs;
  _commentHighlightedAttrs = commentHighlightedAttrs;
  _preeditAttrs = preeditAttrs;
  _preeditHighlightedAttrs = preeditHighlightedAttrs;
  _pagingAttrs = pagingAttrs;
  _pagingHighlightedAttrs = pagingHighlightedAttrs;
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
@property(nonatomic, readonly) NSUInteger highlightedIndex;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) NSMutableArray<NSBezierPath *> *candidatePaths;
@property(nonatomic, readonly) NSMutableArray<NSBezierPath *> *pagingPaths;
@property(nonatomic, readonly) NSUInteger pagingButton;
@property(nonatomic, readonly) BOOL isDark;
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, assign) CGFloat seperatorWidth;
@property(nonatomic, readonly) CAShapeLayer *shape;

- (BOOL)isFlipped;
@property (NS_NONATOMIC_IOSONLY, getter=isFlipped, readonly) BOOL flipped;
- (void)     drawViewWith:(NSArray<NSValue *> *)candidateRanges
         highlightedIndex:(NSUInteger)highlightedIndex
             preeditRange:(NSRange)preeditRange
  highlightedPreeditRange:(NSRange)highlightedPreeditRange
              pagingRange:(NSRange)pagingRange
             pagingButton:(NSUInteger)pagingButton;
- (NSRect)contentRectForRange:(NSRange)range;
- (NSRect)setLineRectForRange:(NSRange)charRange
                     atOrigin:(NSPoint)origin
            withReferenceFont:(NSFont *)refFont
               paragraphStyle:(NSParagraphStyle *)style;
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
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
  }
  _textView = [[NSTextView alloc] initWithFrame:frameRect];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSZeroSize];
  _textView.drawsBackground = NO;
  _textView.editable = NO;
  _textView.selectable = NO;
  _textView.wantsLayer = NO;
  [_textView replaceTextContainer:textContainer];
  _textView.layoutManager.backgroundLayoutEnabled = YES;
  _textView.layoutManager.usesFontLeading = NO;
  _textView.layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
  _defaultTheme = [[SquirrelTheme alloc] init];
  _shape = [[CAShapeLayer alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
  }
  return self;
}

- (NSRect)setLineRectForRange:(NSRange)charRange
                     atOrigin:(NSPoint)origin
            withReferenceFont:(NSFont *)refFont
               paragraphStyle:(NSParagraphStyle *)style {
  NSLayoutManager *layoutManager = self.textView.layoutManager;
  NSTextContainer *textContainer = self.textView.textContainer;
  NSTextStorage *textStorage = self.textView.textStorage;

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  NSRect blockRect = NSMakeRect(origin.x, origin.y, 0, 0);
  BOOL verticalLayout = textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  CGFloat refFontHeight = [layoutManager defaultLineHeightForFont:refFont];
  CGFloat refBaseline = [layoutManager defaultBaselineOffsetForFont:refFont];
  CGFloat lineHeight = MAX(style.lineHeightMultiple > 0 ? refFontHeight * style.lineHeightMultiple : refFontHeight, style.minimumLineHeight);
  lineHeight = style.maximumLineHeight > 0 ? MIN(lineHeight, style.maximumLineHeight) : lineHeight;

  NSUInteger i = glyphRange.location;
  NSRange lineRange = NSMakeRange(i, 0);
  while (i < NSMaxRange(glyphRange)) {
    // typsetting the line fragment
    NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:i effectiveRange:&lineRange];
    NSRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:i effectiveRange:NULL];
    NSRange lineCharRange = [layoutManager characterRangeForGlyphRange:lineRange actualGlyphRange:NULL];
    rect.origin.y = NSMaxY(blockRect);
    usedRect.origin.y = NSMaxY(blockRect);
    CGFloat alignment = verticalLayout ? lineHeight/2 : refBaseline;
    rect.size.height = lineHeight;
    usedRect.size.height = MAX(NSHeight(usedRect), lineHeight);
    if (style.lineSpacing > 0) {
      rect.size.height = lineHeight + style.lineSpacing;
      usedRect.size.height = MAX(NSHeight(usedRect), lineHeight + style.lineSpacing);
      alignment += style.lineSpacing/2;
    }
    if (style.paragraphSpacing > 0 && [textStorage.string characterAtIndex:NSMaxRange(lineCharRange)-1] == '\n') {
      rect.size.height += style.paragraphSpacing;
    }
    if (style.paragraphSpacingBefore > 0 && (lineCharRange.location == 0 ||
         [textStorage.string characterAtIndex:lineCharRange.location-1] == '\n')) {
      rect.size.height += style.paragraphSpacingBefore;
      usedRect.origin.y += style.paragraphSpacingBefore;
      alignment += style.paragraphSpacingBefore;
    }
    [layoutManager setLineFragmentRect:rect forGlyphRange:lineRange usedRect:NSIntersectionRect(usedRect, rect)];

    // typesetting glyphs
    NSRange fontRunRange = NSMakeRange(NSNotFound, 0);
    NSUInteger j = lineRange.location;
    while (j < NSMaxRange(lineRange)) {
      NSPoint runGlyphPosition = [layoutManager locationForGlyphAtIndex:j];
      NSUInteger runCharLocation = [layoutManager characterIndexForGlyphAtIndex:j];
      NSFont *runFont = [textStorage attribute:NSFontAttributeName atIndex:runCharLocation effectiveRange:&fontRunRange];
      NSFont *resizedRefFont = [NSFont fontWithDescriptor:refFont.fontDescriptor size:runFont.pointSize];
      CGFloat baselineOffset = [[textStorage attribute:NSBaselineOffsetAttributeName atIndex:runCharLocation effectiveRange:NULL] doubleValue];
      NSRange runRange = NSIntersectionRange(fontRunRange, [layoutManager rangeOfNominallySpacedGlyphsContainingIndex:j]);
      if (verticalLayout) {
        runFont = runFont.verticalFont;
        resizedRefFont = resizedRefFont.verticalFont;
      }
      CGFloat runBaseline = [layoutManager defaultBaselineOffsetForFont:runFont];
      CGFloat runFontHeight = [layoutManager defaultLineHeightForFont:runFont];
      CGFloat resizedRefFontHeight = [layoutManager defaultLineHeightForFont:resizedRefFont];
      CGFloat resizedRefBaseline = [layoutManager defaultBaselineOffsetForFont:resizedRefFont];
      CGFloat runFontOvershoot = MAX(0.0, runFontHeight - runBaseline - resizedRefFontHeight + resizedRefBaseline)/2;
      runGlyphPosition.y = alignment - baselineOffset + MAX(0.0, runFontHeight - resizedRefFontHeight)/2;
      if (verticalLayout) {
        if (runFont.verticalFont.isVertical) {
          runGlyphPosition.x += runFontOvershoot;
        } else {
          runGlyphPosition.y += runBaseline - runFontHeight/2;
        }
      }
      [layoutManager setLocation:runGlyphPosition forStartOfGlyphRange:runRange];
      j = NSMaxRange(runRange);
    }
    blockRect = NSUnionRect(blockRect, rect);
    i = NSMaxRange(lineRange);
  }
  return blockRect;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  [self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
  NSRect rect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
  NSRect extraLineRect = [self.textView.layoutManager extraLineFragmentRect];
  rect.size.height -= NSHeight(extraLineRect);
  return rect;
}

// Get the rectangle containing the range of text, will first convert to glyph range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  NSSize edgeInset = self.currentTheme.edgeInset;
  NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRect rect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
  NSRect firstLineRect = [self.textView.layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location effectiveRange:NULL];
  NSRect finalLineRect = [self.textView.layoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:NULL];
  return NSMakeRect(NSMinX(rect) + edgeInset.width, NSMinY(firstLineRect) + edgeInset.height,
                    NSWidth(rect), NSMaxY(finalLineRect) - NSMinY(firstLineRect));
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void)     drawViewWith:(NSArray<NSValue *>*)candidateRanges
         highlightedIndex:(NSUInteger)highlightedIndex
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
  _candidatePaths = [NSMutableArray arrayWithCapacity:candidateRanges.count];
  _pagingPaths = [NSMutableArray arrayWithCapacity:pagingRange.length > 0 ? 2 : 0];
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
  for (NSUInteger i = 0; i < vertex.count; ++i) {
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
           @(NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y))];
}

void xyTranslation(NSMutableArray<NSValue *> *shape, CGFloat dx, CGFloat dy) {
  for (NSUInteger i = 0; i < shape.count; ++i) {
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
  NSLayoutManager *layoutManager = self.textView.layoutManager;
  NSTextContainer *textContainer = self.textView.textContainer;
  NSSize edgeInset = self.currentTheme.edgeInset;
  *leadingRect = NSZeroRect;
  *bodyRect = NSZeroRect;
  *trailingRect = NSZeroRect;
  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  NSPoint startPoint = [layoutManager locationForGlyphAtIndex:glyphRange.location];
  NSPoint endPoint = [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)];
  NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
  NSRect leadingLineRect = [layoutManager lineFragmentRectForGlyphAtIndex:glyphRange.location effectiveRange:&leadingLineRange withoutAdditionalLayout:YES];
  if (NSMaxRange(leadingLineRange) > NSMaxRange(glyphRange)) {
    *bodyRect = NSMakeRect(NSMinX(leadingLineRect) + startPoint.x + edgeInset.width,
                           NSMinY(leadingLineRect) + edgeInset.height,
                           endPoint.x - startPoint.x, NSHeight(leadingLineRect));
  } else {
    CGFloat rightEdge = MAX(NSMaxX(leadingLineRect) - self.currentTheme.hilitedCornerRadius, NSMaxX(boundingRect));
    NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect trailingLineRect = [layoutManager lineFragmentRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:&trailingLineRange withoutAdditionalLayout:YES];
    CGFloat leftEdge = MIN(NSMinX(trailingLineRect) + self.currentTheme.hilitedCornerRadius, NSMinX(boundingRect));
    if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
      if (glyphRange.location == leadingLineRange.location) {
        *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(leadingLineRect) + edgeInset.height,
                               rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
      } else {
        *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startPoint.x + edgeInset.width,
                                  NSMinY(leadingLineRect) + edgeInset.height,
                                  rightEdge - NSMinX(leadingLineRect) - startPoint.x, NSHeight(leadingLineRect));
        *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMaxY(leadingLineRect) + edgeInset.height,
                               rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
      }
    } else {
      *trailingRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(trailingLineRect) + edgeInset.height,
                                 NSMinX(trailingLineRect) + endPoint.x - leftEdge, NSHeight(trailingLineRect));
      if (glyphRange.location == leadingLineRange.location) {
        *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(leadingLineRect) + edgeInset.height,
                               rightEdge - leftEdge, NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
      } else {
        *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startPoint.x + edgeInset.width,
                                  NSMinY(leadingLineRect) + edgeInset.height,
                                  rightEdge - NSMinX(leadingLineRect) - startPoint.x, NSHeight(leadingLineRect));
        NSRange bodyLineRange = NSMakeRange(NSMaxRange(leadingLineRange), trailingLineRange.location-NSMaxRange(leadingLineRange));
        if (bodyLineRange.length > 0) {
          *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMaxY(leadingLineRect) + edgeInset.height,
                                 rightEdge - leftEdge, NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      }
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

NSColor *hooverColor(NSColor *color, BOOL darkTheme) {
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  }
  if (darkTheme) {
    return [color highlightWithLevel:0.3];
  } else {
    return [color shadowWithLevel:0.3];
  }
}

NSColor *disabledColor(NSColor *color, BOOL darkTheme) {
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectDisabled];
  }
  if (darkTheme) {
    return [color shadowWithLevel:0.3];
  } else {
    return [color highlightWithLevel:0.3];
  }
}

// All draws happen here
- (void)drawRect:(NSRect)dirtyRect {
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *textContainerPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *candidateBlockPath;
  NSBezierPath *pageUpPath;
  NSBezierPath *pageDownPath;
  SquirrelTheme *theme = self.currentTheme;

  [NSBezierPath setDefaultLineWidth:0];

  NSRect backgroundRect = dirtyRect;
  NSRect textContainer = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);

  // perform typesetting to get vertically centered layout and get the block rect
  NSPoint lineOrigin = NSZeroPoint;
  NSRect preeditRect = NSZeroRect;
  if (_preeditRange.length > 0) {
    NSFont *preeditRefFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, [theme.preeditAttrs[NSFontAttributeName] pointSize], (CFStringRef) @"zh"));
    preeditRect = [self setLineRectForRange:_preeditRange atOrigin:lineOrigin withReferenceFont:(theme.vertical ? preeditRefFont.verticalFont : preeditRefFont) paragraphStyle:theme.preeditParagraphStyle];
    lineOrigin.y = NSMaxY(preeditRect);
  }
  NSRect candidateBlockRect = NSZeroRect;
  if (_candidateRanges.count > 0) {
    CGFloat fontSize = MAX([theme.attrs[NSFontAttributeName] pointSize], MAX([theme.commentAttrs[NSFontAttributeName] pointSize], [theme.labelAttrs[NSFontAttributeName] pointSize]));
    NSFont *refFont =  CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, fontSize, (CFStringRef) @"zh"));
    NSRange candidateBlockRange = NSUnionRange(_candidateRanges[0].rangeValue, theme.linear && _pagingRange.length >0 ? _pagingRange : _candidateRanges[_candidateRanges.count-1].rangeValue);
    candidateBlockRect = [self setLineRectForRange:candidateBlockRange atOrigin:lineOrigin withReferenceFont:(theme.vertical ? refFont.verticalFont : refFont) paragraphStyle:theme.paragraphStyle];
    lineOrigin.y = NSMaxY(candidateBlockRect);
  }
  NSRect pagingLineRect = NSZeroRect;
  if (!theme.linear && _pagingRange.length > 0) {
    pagingLineRect = [self setLineRectForRange:_pagingRange atOrigin:lineOrigin withReferenceFont:theme.pagingAttrs[NSFontAttributeName] paragraphStyle:theme.pagingParagraphStyle];
    lineOrigin.y = NSMaxY(pagingLineRect);
  }
  [self.textView.layoutManager setExtraLineFragmentRect:NSMakeRect(lineOrigin.x, lineOrigin.y, NSWidth(textContainer), NSHeight(textContainer)) usedRect:NSMakeRect(lineOrigin.x, lineOrigin.y, theme.hilitedCornerRadius*2, theme.paragraphStyle.minimumLineHeight) textContainer:self.textView.textContainer];

  // Draw preedit Rect
  if (_preeditRange.length > 0) {
    preeditRect.size.width = textContainer.size.width;
    preeditRect.origin = textContainer.origin;
  }

  // Draw candidate Rect
  if (_candidateRanges.count > 0) {
    candidateBlockRect.size.width = textContainer.size.width;
    candidateBlockRect.origin.x = textContainer.origin.x;
    candidateBlockRect.origin.y += theme.edgeInset.height;
    if (theme.preeditBackgroundColor != nil) {
      candidateBlockPath = drawSmoothLines(rectVertex(candidateBlockRect), 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    }

    // Draw candidate highlight rect
    if (theme.linear) {
      CGFloat highlightPadding = MIN(_seperatorWidth/2, theme.hilitedCornerRadius);
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = _candidateRanges[i].rangeValue;
        NSRect leadingRect;
        NSRect bodyRect;
        NSRect trailingRect;
        [self multilineRectForRange:candidateRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
        leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : NSInsetRect(leadingRect, -highlightPadding, 0);
        bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : NSInsetRect(bodyRect, -highlightPadding, 0);
        trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : NSInsetRect(trailingRect, -highlightPadding, 0);
        NSMutableArray<NSValue *> *candidatePoints;
        NSMutableArray<NSValue *> *candidatePoints2;
        // Handles the special case where containing boxes are separated
        if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePoints = [rectVertex(leadingRect) mutableCopy];
          candidatePoints2 = [rectVertex(trailingRect) mutableCopy];
        } else {
          candidatePoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
        }
        NSBezierPath *candidatePath = drawSmoothLines(candidatePoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
        if (candidatePoints2.count > 0) {
          [candidatePath appendBezierPath:drawSmoothLines(candidatePoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius)];
        }
        _candidatePaths[i] = candidatePath;
      }
    } else {
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = _candidateRanges[i].rangeValue;
        NSRect candidateRect = [self contentRectForRange:candidateRange];
        candidateRect.size.width = textContainer.size.width;
        candidateRect.origin.x = textContainer.origin.x;
        NSMutableArray<NSValue *> *candidatePoints = [rectVertex(candidateRect) mutableCopy];
        NSBezierPath *candidatePath = drawSmoothLines(candidatePoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
  }

  // Draw highlighted part of preedit text
  if (_highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
    NSRect innerBox = NSInsetRect(preeditRect, theme.hilitedCornerRadius, 0);
    innerBox.size.height -= theme.preeditLinespace;
    NSRect leadingRect;
    NSRect bodyRect;
    NSRect trailingRect;
    [self multilineRectForRange:_highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
    leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : NSIntersectionRect(leadingRect, innerBox);
    bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : NSIntersectionRect(bodyRect, innerBox);
    trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : NSIntersectionRect(trailingRect, innerBox);
    NSMutableArray<NSValue *> *highlightedPreeditPoints;
    NSMutableArray<NSValue *> *highlightedPreeditPoints2;
    // Handles the special case where containing boxes are separated
    if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
      highlightedPreeditPoints = [rectVertex(leadingRect) mutableCopy];
      highlightedPreeditPoints2 = [rectVertex(trailingRect) mutableCopy];
    } else {
      highlightedPreeditPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
    }
    highlightedPreeditPath = drawSmoothLines(highlightedPreeditPoints, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
    if (highlightedPreeditPoints2.count > 0) {
      [highlightedPreeditPath appendBezierPath:drawSmoothLines(highlightedPreeditPoints2, 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius)];
    }
  }

  // Draw paging Rect
  if (_pagingRange.length > 0) {
    CGFloat buttonPadding = theme.linear ? MIN(_seperatorWidth/2, theme.hilitedCornerRadius) : theme.hilitedCornerRadius;
    NSRect pageDownRect = [self contentRectForRange:NSMakeRange(NSMaxRange(_pagingRange)-1, 1)];
    pageDownRect.size.width += buttonPadding;
    pageDownPath = drawSmoothLines(rectVertex(pageDownRect), 0.06*NSHeight(pageDownRect), 0.28*NSWidth(pageDownRect));
    NSRect pageUpRect = [self contentRectForRange:NSMakeRange(_pagingRange.location, 1)];
    pageUpRect.origin.x -= buttonPadding;
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    pageUpPath = drawSmoothLines(rectVertex(pageUpRect), 0.06*NSHeight(pageUpRect), 0.28*NSWidth(pageUpRect));
    _pagingPaths[0] = pageUpPath;
    _pagingPaths[1] = pageDownPath;
  }

  // Draw borders
  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), 0.3*theme.cornerRadius, 1.4*theme.cornerRadius);
  textContainerPath = drawSmoothLines(rectVertex(textContainer), 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
  if (theme.edgeInset.width > 0 || theme.edgeInset.height > 0) {
    borderPath = [backgroundPath copy];
    [borderPath appendBezierPath:textContainerPath];
    borderPath.windingRule = NSEvenOddWindingRule;
  }

  // set layers]
  _shape.path = [backgroundPath quartzPath];
  _shape.fillColor = [[NSColor whiteColor] CGColor];
  CAShapeLayer *textContainerLayer = [[CAShapeLayer alloc] init];
  textContainerLayer.path = [textContainerPath quartzPath];
  textContainerLayer.fillColor = [[NSColor whiteColor] CGColor];
  [self.layer setSublayers: NULL];
  CAShapeLayer *panelLayer = [[CAShapeLayer alloc] init];
  if (theme.backgroundImage) {
    panelLayer.backgroundColor = [theme.backgroundImage CGColor];
  }
  panelLayer.path = [textContainerPath quartzPath];
  panelLayer.fillColor = [theme.backgroundColor CGColor];
  [self.layer addSublayer:panelLayer];
  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0) {
      panelLayer.opacity = 1.0 - theme.translucency;
    }
  }
  if (theme.preeditBackgroundColor &&
      (_preeditRange.length > 0 || !NSIsEmptyRect(pagingLineRect))) {
    panelLayer.fillColor = [theme.preeditBackgroundColor CGColor];
    if (![candidateBlockPath isEmpty]) {
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = [candidateBlockPath quartzPath];
      candidateLayer.fillColor = [theme.backgroundColor CGColor];
      [panelLayer addSublayer:candidateLayer];
    }
  }
  if (theme.borderColor && ![borderPath isEmpty]) {
    CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
    borderLayer.path = [borderPath quartzPath];
    borderLayer.fillColor = [theme.borderColor CGColor];
    borderLayer.fillRule = kCAFillRuleEvenOdd;
    [panelLayer addSublayer:borderLayer];
  }
  CIFilter *backColorFilter = [CIFilter filterWithName:@"CISourceATopCompositing"];
  panelLayer.compositingFilter = backColorFilter;
  if (_highlightedIndex != NSNotFound && theme.highlightedStripColor) {
    CAShapeLayer *highlightedLayer = [[CAShapeLayer alloc] init];
    highlightedPath = _candidatePaths[_highlightedIndex];
    highlightedLayer.path = [highlightedPath quartzPath];
    highlightedLayer.fillColor = [theme.highlightedStripColor CGColor];
    CAShapeLayer *candidateMaskLayer = [[CAShapeLayer alloc] init];
    candidateMaskLayer.path = [candidateBlockPath quartzPath];
    candidateMaskLayer.fillColor = [[NSColor whiteColor] CGColor];
    highlightedLayer.mask = candidateMaskLayer;
    [self.layer addSublayer:highlightedLayer];
  }
  NSColor *buttonColor = theme.linear ? theme.highlightedStripColor : theme.highlightedPreeditColor;
  if (_pagingRange.length > 0 && buttonColor) {
    CAShapeLayer *pagingLayer = [[CAShapeLayer alloc] init];
    switch (_pagingButton) {
      case NSPageUpFunctionKey: {
        pagingLayer.path = [pageUpPath quartzPath];
        pagingLayer.fillColor = [hooverColor(buttonColor, self.isDark) CGColor];
      } break;
      case NSBeginFunctionKey: {
        pagingLayer.path = [pageUpPath quartzPath];
        pagingLayer.fillColor = [disabledColor(buttonColor, self.isDark) CGColor];
      } break;
      case NSPageDownFunctionKey: {
        pagingLayer.path = [pageDownPath quartzPath];
        pagingLayer.fillColor = [hooverColor(buttonColor, self.isDark) CGColor];
      } break;
      case NSEndFunctionKey: {
        pagingLayer.path = [pageDownPath quartzPath];
        pagingLayer.fillColor = [disabledColor(buttonColor, self.isDark) CGColor];
      } break;
    }
    pagingLayer.mask = textContainerLayer;
    [self.layer addSublayer:pagingLayer];
  }
  if (theme.highlightedPreeditColor) {
    if(![highlightedPreeditPath isEmpty]) {
      CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
      highlightedPreeditLayer.path = [highlightedPreeditPath quartzPath];
      highlightedPreeditLayer.fillColor = [theme.highlightedPreeditColor CGColor];
      highlightedPreeditLayer.mask = textContainerLayer;
      [self.layer addSublayer:highlightedPreeditLayer];
    }
  }
  [self.textView setTextContainerInset:theme.edgeInset];
  // get sharp emojis on non-retina screens
  [self.textView.layer setContentsScale:self.window.backingScaleFactor*3];
}

- (BOOL)convertClickSpot:(NSPoint)spot toIndex:(NSUInteger *)index {
  if (NSPointInRect(spot, self.bounds)) {
    if (_pagingPaths.count > 0) {
      if ([_pagingPaths[0] containsPoint:spot]) {
        *index = NSPageUpFunctionKey; // borrow function-key unicode for readability
        return YES;
      }
      if ([_pagingPaths[1] containsPoint:spot]) {
        *index = NSPageDownFunctionKey; // borrow function-key unicode for readability
        return YES;
      }
    }
    for (NSUInteger i = 0; i < _candidatePaths.count; ++i) {
      if ([_candidatePaths[i] containsPoint:spot]) {
        *index = i;
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
  NSSize _maxSize;
  CGFloat _maxTextWidth;

  NSString *_preedit;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray *_candidates;
  NSArray *_comments;
  NSArray *_labels;
  NSUInteger _index;
  NSUInteger _pageNum;
  NSUInteger _turnPage;
  BOOL _lastPage;
  BOOL _mouseDown;
  NSPoint _scrollLocus;
  
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

+ (NSColor *)secondaryTextColor {
  if(@available(macOS 10.10, *)) {
    return [NSColor secondaryLabelColor];
  } else {
    return [NSColor disabledControlTextColor];
  }
}

+ (NSColor *)accentColor {
  if (@available(macOS 10.14, *)) {
    return [NSColor controlAccentColor];
  } else {
    return [NSColor colorForControlTint:[[self class] currentControlTint]];
  }
}

- (void)initializeUIStyleForDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];
  theme.native = YES;
  theme.candidateFormat = kDefaultCandidateFormat;

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];
  NSColor *accentColor = [[self class] accentColor];
  NSFont *userFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFontOfSize:0.0].fontName) size:kDefaultFontSize];
  NSFont *userMonoFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName) size:kDefaultFontSize];
  NSFont *symbolFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0] fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized] size:kDefaultFontSize];

  NSMutableDictionary *defaultAttrs = [[NSMutableDictionary alloc] init];
  defaultAttrs[NSLigatureAttributeName] = [NSNumber numberWithInt:0];
  defaultAttrs[NSVerticalGlyphFormAttributeName] = [NSNumber numberWithBool:theme.vertical];

  NSMutableDictionary *attrs = [defaultAttrs mutableCopy];
  attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  attrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *highlightedAttrs = [defaultAttrs mutableCopy];
  highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedMenuItemTextColor];
  highlightedAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *labelAttrs = [attrs mutableCopy];
  labelAttrs[NSForegroundColorAttributeName] = accentColor;
  labelAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *labelHighlightedAttrs = [highlightedAttrs mutableCopy];
  labelHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor alternateSelectedControlTextColor];
  labelHighlightedAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *commentAttrs = [defaultAttrs mutableCopy];
  commentAttrs[NSForegroundColorAttributeName] = secondaryTextColor;
  commentAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *commentHighlightedAttrs = [defaultAttrs mutableCopy];
  commentHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor alternateSelectedControlTextColor];
  commentHighlightedAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *preeditAttrs = [defaultAttrs mutableCopy];
  preeditAttrs[NSForegroundColorAttributeName] = [NSColor textColor];
  preeditAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *preeditHighlightedAttrs = [defaultAttrs mutableCopy];
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedTextColor];
  preeditHighlightedAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *pagingAttrs = [defaultAttrs mutableCopy];
  pagingAttrs[NSForegroundColorAttributeName] = theme.linear ? accentColor : [NSColor controlTextColor];
  pagingAttrs[NSFontAttributeName] = symbolFont;

  NSMutableDictionary *pagingHighlightedAttrs = [defaultAttrs mutableCopy];
  pagingHighlightedAttrs[NSForegroundColorAttributeName] =  theme.linear ? [NSColor alternateSelectedControlTextColor] : [NSColor selectedMenuItemTextColor];
  pagingHighlightedAttrs[NSFontAttributeName] = symbolFont;

  NSMutableParagraphStyle *preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *pagingParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  preeditParagraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
  preeditParagraphStyle.alignment = NSTextAlignmentLeft;
  paragraphStyle.alignment = NSTextAlignmentLeft;
  pagingParagraphStyle.alignment = NSTextAlignmentLeft;
  // Use left-to-right marks to declare the default writing direction and prevent strong right-to-left
  // characters from setting the writing direction in case the label are direction-less symbols
  preeditParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  pagingParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;

  [theme          setAttrs:attrs
          highlightedAttrs:highlightedAttrs
                labelAttrs:labelAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs
               pagingAttrs:pagingAttrs
    pagingHighlightedAttrs:pagingHighlightedAttrs];
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
    _maxSize = NSZeroSize;
  }
  return self;
}

- (void)sendEvent:(NSEvent *)event {
  switch (event.type) {
    case NSEventTypeLeftMouseDown:
    case NSEventTypeRightMouseDown: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if ([_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if ((cursorIndex >= 0 && cursorIndex < _candidates.count) ||
            cursorIndex == NSPageUpFunctionKey || cursorIndex == NSPageDownFunctionKey) {
          _index = cursorIndex;
          _mouseDown = YES;
        }
      }
    } break;
    case NSEventTypeLeftMouseUp: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if (_mouseDown && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index || cursorIndex == _turnPage) {
          [self.inputController perform:kSELECT onIndex:cursorIndex];
          _mouseDown = NO;
        }
      }
    } break;
    case NSEventTypeRightMouseUp: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if (_mouseDown && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index && (cursorIndex >= 0 && cursorIndex < _candidates.count)) {
          [self.inputController perform:kDELETE onIndex:cursorIndex];
          _mouseDown = NO;
        }
      }
    } break;
    case NSEventTypeMouseEntered: {
      self.acceptsMouseMovedEvents = YES;
    } break;
    case NSEventTypeMouseExited: {
      self.acceptsMouseMovedEvents = NO;
    } break;
    case NSEventTypeMouseMoved: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if ([_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex >= 0 && cursorIndex < _candidates.count && _index != cursorIndex) {
          [self.inputController perform:kCHOOSE onIndex:cursorIndex];
          _index = cursorIndex;
          [self showPreedit:_preedit selRange:_selRange caretPos:_caretPos candidates:_candidates comments:_comments labels:_labels highlighted:cursorIndex pageNum:_pageNum lastPage:_lastPage turnPage:NSNotFound update:NO];
        } else if ((cursorIndex == NSPageUpFunctionKey || cursorIndex == NSPageDownFunctionKey) && _turnPage != cursorIndex) {
          _turnPage = cursorIndex;
          [self showPreedit:_preedit selRange:_selRange caretPos:_caretPos candidates:_candidates comments:_comments labels:_labels highlighted:_index pageNum:_pageNum lastPage:_lastPage turnPage:cursorIndex update:NO];
        }
      }
    } break;
    case NSEventTypeLeftMouseDragged: {
      _mouseDown = NO;
      [self performWindowDragWithEvent:event];
    } break;
    case NSEventTypeScrollWheel: {
      CGFloat scrollThreshold = [_view.currentTheme.attrs[NSParagraphStyleAttributeName] minimumLineHeight];
      if (event.phase == NSEventPhaseBegan) {
        _scrollLocus = NSZeroPoint;
      } else if ((event.phase == NSEventPhaseNone || event.momentumPhase == NSEventPhaseNone) &&
                 _scrollLocus.x != NSNotFound && _scrollLocus.y != NSNotFound) {
        // determine scrolling direction by confining to sectors within ±30º of any axis
        if (ABS(event.scrollingDeltaX) > ABS(event.scrollingDeltaY) * sqrt(3)) {
          _scrollLocus.x += event.scrollingDeltaX * (event.hasPreciseScrollingDeltas ? 1 : 10);
        } else if (ABS(event.scrollingDeltaY) > ABS(event.scrollingDeltaX) * sqrt(3)) {
          _scrollLocus.y += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 10);
        }
        // compare accumulated locus length against threshold and limit paging to max once
        if (_scrollLocus.x > scrollThreshold) {
          [self.inputController perform:kSELECT onIndex:(_view.currentTheme.vertical ? NSPageDownFunctionKey : NSPageUpFunctionKey)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y > scrollThreshold) {
          [self.inputController perform:kSELECT onIndex:NSPageUpFunctionKey];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [self.inputController perform:kSELECT onIndex:(_view.currentTheme.vertical ? NSPageUpFunctionKey : NSPageDownFunctionKey)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y < -scrollThreshold) {
          [self.inputController perform:kSELECT onIndex:NSPageDownFunctionKey];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
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
  NSScreen *currentScreen = [NSScreen mainScreen];
  _screenRect = currentScreen.visibleFrame;
  NSArray *screens = [NSScreen screens];
  for (NSUInteger i = 0; i < screens.count; ++i) {
    if (NSPointInRect(_position.origin, [screens[i] frame])) {
      _screenRect = [screens[i] visibleFrame];
      break;
    }
  }
}

- (void)getMaxTextWidth {
  SquirrelTheme *theme = _view.currentTheme;
  [self getCurrentScreen];
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _maxTextWidth = (theme.vertical ? NSHeight(_screenRect) : NSWidth(_screenRect)) * textWidthRatio - (theme.hilitedCornerRadius + theme.edgeInset.width) * 2;
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  SquirrelTheme *theme = _view.currentTheme;

  if (@available(macOS 10.14, *)) {
    NSAppearance *requestedAppearance = theme.native ? nil : [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    if (self.appearance != requestedAppearance) {
      self.appearance = requestedAppearance;
    }
  }

  //Break line if the text is too long, based on screen size.
  _view.textView.textContainer.lineFragmentPadding = theme.hilitedCornerRadius;
  CGFloat textWidth = _view.textView.textStorage.size.width;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  CGFloat maxTextHeight = (theme.vertical ? NSWidth(_screenRect) : NSHeight(_screenRect)) - theme.edgeInset.height * 2;
  if (textWidth > _maxTextWidth) {
    textWidth = _maxTextWidth;
  }
  _view.textView.textContainer.size = NSMakeSize(textWidth + theme.hilitedCornerRadius * 2, maxTextHeight);

  bool sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSRect contentRect = NSInsetRect(_view.contentRect, theme.hilitedCornerRadius, 0);
  NSRect maxContentRect = contentRect;
  // remember panel size (fix the top leading anchor of the panel in screen coordiantes)
  if (theme.rememberSize) {
    if (theme.vertical ? (NSMinY(_position) / NSHeight(_screenRect) <= textWidthRatio) :
        (sweepVertical ? (NSMinX(_position) / NSWidth(_screenRect) > textWidthRatio) :
         (NSMinX(_position) + MAX(NSWidth(maxContentRect), _maxSize.width) + theme.hilitedCornerRadius + theme.edgeInset.width > NSMaxX(_screenRect)))) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        maxContentRect.size.width = _maxSize.width;
        _view.textView.textContainer.size = NSMakeSize(_maxSize.width + theme.hilitedCornerRadius * 2, maxTextHeight);
      }
    }
    if (theme.vertical ? (NSMinX(_position) < MAX(NSHeight(maxContentRect), _maxSize.height) + theme.edgeInset.height * 2 + (sweepVertical ? kOffsetHeight : 0)) :
        (NSMinY(_position) < MAX(NSHeight(maxContentRect), _maxSize.height) + theme.edgeInset.height * 2 + (sweepVertical ? 0 : kOffsetHeight))) {
      if (NSHeight(maxContentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(maxContentRect);
      } else {
        maxContentRect.size.height = _maxSize.height;
      }
    }
  }

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  NSRect windowRect;
  if (theme.vertical) {
    windowRect.size = NSMakeSize(NSHeight(maxContentRect) + theme.edgeInset.height * 2,
                                 NSWidth(maxContentRect) + (theme.edgeInset.width + theme.hilitedCornerRadius) * 2);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMinY(_position) / NSHeight(_screenRect) > textWidthRatio) {
      windowRect.origin.y = NSMinY(_position) + (sweepVertical ? theme.edgeInset.width+theme.hilitedCornerRadius : -kOffsetHeight) - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
    }
    // Make the right edge of candidate block fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
    if (!sweepVertical && _view.preeditRange.length > 0) {
      NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
      windowRect.origin.x += NSHeight(preeditRect) + theme.edgeInset.height - theme.preeditLinespace;
    }
  } else {
    windowRect.size = NSMakeSize(NSWidth(maxContentRect) + (theme.edgeInset.width + theme.hilitedCornerRadius) * 2,
                                 NSHeight(maxContentRect) + theme.edgeInset.height * 2);
    if (sweepVertical) {
      // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
      if (NSMinX(_position) / NSWidth(_screenRect) > textWidthRatio) {
        windowRect.origin.x = NSMinX(_position) - kOffsetHeight - NSWidth(windowRect);
      } else {
        windowRect.origin.x = NSMaxX(_position) + kOffsetHeight;
      }
      windowRect.origin.y = NSMinY(_position) - NSHeight(windowRect);
    } else {
      windowRect.origin = NSMakePoint(NSMinX(_position) - theme.edgeInset.width - theme.hilitedCornerRadius,
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

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }
  [self setFrame:NSIntegralRectWithOptions(windowRect, NSAlignAllEdgesOutward) display:YES];
  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    [self.contentView setBoundsRotation:-90.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    [self.contentView setBoundsRotation:0.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, 0.0)];
  }
  [_view.textView setBoundsRotation:0.0];
  [_view.textView setBoundsOrigin:_view.textView.textContainerOrigin];
  [_view setFrame:self.contentView.bounds];
  [_view.textView setFrame:self.contentView.bounds];

  CGFloat translucency = theme.translucency;
  if (@available(macOS 10.14, *)) {
    if (translucency > 0) {
      [_back setFrame:self.contentView.bounds];
      [_back setAppearance:NSApp.effectiveAppearance];
      [_back setHidden:NO];
    } else {
      [_back setHidden:YES];
    }
  }
  [self setAlphaValue:theme.alpha];
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
  _maxSize = NSZeroSize;
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

  _turnPage = turnPage;
  if (_turnPage == NSPageUpFunctionKey) {
    turnPage = pageNum ? NSPageUpFunctionKey : NSBeginFunctionKey;
  } else if (_turnPage == NSPageDownFunctionKey) {
    turnPage = lastPage ? NSEndFunctionKey : NSPageDownFunctionKey;
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
  [self getMaxTextWidth];

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

    [preeditLine addAttribute:NSParagraphStyleAttributeName
                        value:theme.preeditParagraphStyle
                        range:NSMakeRange(0, preeditLine.length)];

    [text appendAttributedString:preeditLine];
    preeditRange = NSMakeRange(0, text.length);
    preeditWidth = NSWidth([preeditLine boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.preeditAttrs]];
    }
  }

  // prepare paging and separator for width calculation but no insertion yet
  NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] initWithString:@"" attributes:theme.pagingAttrs];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:(theme.vertical ? (pageNum ? @"▲" : @"△") : (pageNum ? @"◀" : @"◁"))
                                                                 attributes:(_turnPage == NSPageUpFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)]];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu", pageNum+1]
                                                                 attributes:theme.pagingAttrs]];
  [paging appendAttributedString:[[NSAttributedString alloc] initWithString:(theme.vertical ? (lastPage ? @"▽" : @"▼") : (lastPage ? @"▷" : @"▶"))
                                                                 attributes:(_turnPage == NSPageDownFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)]];

  CGFloat pagingWidth = theme.showPaging ? NSWidth([paging boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]) : 0;
  CGFloat separatorWidth = theme.linear ? NSWidth([[[NSAttributedString alloc] initWithString:@"  " attributes:theme.attrs] boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]) : 0;
  _view.seperatorWidth = separatorWidth;
  CGFloat lineWidth = 0.0 - separatorWidth;
  CGFloat maxLineWidth = MIN(preeditWidth, _maxTextWidth);
  BOOL useTab = NO;

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
      NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      if (labels.count > 1 && i < labels.count) {
        prefixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCompatibilityMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }

      [line appendAttributedString:[[NSAttributedString alloc] initWithString:prefixLabelString attributes:labelAttrs]];
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
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:comment.precomposedStringWithCompatibilityMapping
                                                                   attributes:commentAttrs]];
    }

    if (theme.suffixLabelFormat != nil) {
      NSString *suffixLabelString;
      NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      if (labels.count > 1 && i < labels.count) {
        suffixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10] stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:suffixLabelString attributes:labelAttrs]];
    }

    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    // determine if the line is too wide and line break is needed, based on screen size.
    NSString *separtatorString = @"\n";
    CGFloat candidateWidth = NSWidth([line boundingRectWithSize:NSZeroSize options:NSStringDrawingUsesLineFragmentOrigin]);
    if (theme.linear) {
      if (i == numCandidates-1) {
        candidateWidth += separatorWidth + pagingWidth;
      }
      if (lineWidth + separatorWidth + candidateWidth > _maxTextWidth) {
        separtatorString = @"\n";
        maxLineWidth = MAX(maxLineWidth, MIN(lineWidth, _maxTextWidth));
        lineWidth = candidateWidth;
      } else {
        separtatorString = @"  ";
        lineWidth += separatorWidth + candidateWidth;
      }
    } else { // stacked candidates
      maxLineWidth = MAX(maxLineWidth, MIN(candidateWidth, _maxTextWidth));
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    if (i == numCandidates-1 && theme.showPaging) {
      maxLineWidth = MAX(maxLineWidth, _maxSize.width);
      useTab = !((theme.linear ? lineWidth : pagingWidth) >= maxLineWidth);
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
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:theme.linear ? (useTab ? @"\t" : @"  ") : @"\n" attributes:theme.attrs]];
    NSUInteger pagingStart = text.length;
    if (theme.linear) {
      [text appendAttributedString:paging];
      NSMutableParagraphStyle *paragraphStylePaging = [theme.paragraphStyle mutableCopy];
      paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineWidth]];
      [text addAttribute:NSParagraphStyleAttributeName value:paragraphStylePaging range:NSMakeRange(candidateBlockStart, text.length-candidateBlockStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      if (useTab) {
        [paging insertAttributedString:[[NSAttributedString alloc] initWithString:@"\t" attributes:theme.pagingAttrs] atIndex:paging.length-1];
        [paging insertAttributedString:[[NSAttributedString alloc] initWithString:@"\t" attributes:theme.pagingAttrs] atIndex:1];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSCenterTabStopType location:maxLineWidth/2],
                                          [[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineWidth]];
      }
      [paging addAttribute:NSParagraphStyleAttributeName value:paragraphStylePaging range:NSMakeRange(0, paging.length)];
      [text appendAttributedString:paging];
    }
    pagingRange = NSMakeRange(pagingStart, paging.length);
  }

  // extra line fragment will not actually be drawn but ensures the spacing after the last line
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.attrs]];

  [text fixAttributesInRange:NSMakeRange(0, text.length)];
  [_view.textView.textStorage setAttributedString:text];
  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];

  // text done!
  [_view drawViewWith:candidateRanges highlightedIndex:index preeditRange:preeditRange highlightedPreeditRange:highlightedPreeditRange pagingRange:pagingRange pagingButton:turnPage];

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

  [text fixAttributesInRange:NSMakeRange(0, text.length)];
  [_view.textView.textStorage setAttributedString:text];
  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];

  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  _maxSize = NSZeroSize; // disable remember_size for status messages
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
      NSFontDescriptor *fontDescriptor = [NSFontDescriptor fontDescriptorWithName:fontName size:0.0];
      NSFontDescriptor *UIFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized];
      [validFontDescriptors addObject:([NSFont fontWithDescriptor:UIFontDescriptor size:0.0] != nil ? UIFontDescriptor : fontDescriptor)];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  }
  CTFontRef systemFontRef = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 0.0, (CFStringRef) @"zh");
  NSFontDescriptor *systemFontDescriptor = CFBridgingRelease(CTFontCopyFontDescriptor(systemFontRef));
  CFRelease(systemFontRef);
  NSFontDescriptor *emojiFontDescriptor = [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];

  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  NSArray *fallbackDescriptors = [[validFontDescriptors subarrayWithRange:NSMakeRange(1, validFontDescriptors.count-1)] arrayByAddingObjectsFromArray:@[systemFontDescriptor, emojiFontDescriptor]];
  NSDictionary *attributes = @{NSFontCascadeListAttribute:fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static CGFloat getLineHeight(NSFont *font) {
  CGFloat lineHeight = font.ascender - font.descender;
  NSArray *fallbackList = [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor *fallback in fallbackList) {
    NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback size:font.pointSize];
    lineHeight = MAX(lineHeight, fallbackFont.ascender - fallbackFont.descender);
  }
  return lineHeight;
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

- (void)loadConfig:(SquirrelConfig *)config forDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];
  [[self class] updateTheme:theme withConfig:config forDarkMode:isDark];
}

+ (void)updateTheme:(SquirrelTheme *)theme withConfig:(SquirrelConfig *)config forDarkMode:(BOOL)isDark {
  BOOL linear = NO;
  BOOL vertical = NO;
  updateCandidateListLayout(&linear, config, @"style");
  updateTextOrientation(&vertical, config, @"style");
  BOOL inlinePreedit = [config getBool:@"style/inline_preedit"];
  BOOL inlineCandidate = [config getBool:@"style/inline_candidate"];
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
  CGFloat alpha = MIN(MAX([config getDouble:@"style/alpha"], 0.0), 1.0);
  CGFloat translucency = MIN(MAX([config getDouble:@"style/translucency"], 0.0), 1.0);
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
    backgroundImage = [config getPattern:[prefix stringByAppendingString:@"/back_image"]];
    borderColor = [config getColor:[prefix stringByAppendingString:@"/border_color"]];
    preeditBackgroundColor = [config getColor:[prefix stringByAppendingString:@"/preedit_back_color"]];
    textColor = [config getColor:[prefix stringByAppendingString:@"/text_color"]];
    highlightedTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_text_color"]];
    if (highlightedTextColor == nil) {
      highlightedTextColor = textColor;
    }
    highlightedBackColor = [config getColor:[prefix stringByAppendingString:@"/hilited_back_color"]];
    candidateTextColor = [config getColor:[prefix stringByAppendingString:@"/candidate_text_color"]];
    if (candidateTextColor == nil) {
      // in non-inline mode, 'text_color' is for rendering preedit text.
      // if not otherwise specified, candidate text is also rendered in this color.
      candidateTextColor = textColor;
    }
    highlightedCandidateTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_text_color"]];
    if (highlightedCandidateTextColor == nil) {
      highlightedCandidateTextColor = highlightedTextColor;
    }
    highlightedCandidateBackColor = [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_back_color"]];
    if (highlightedCandidateBackColor == nil) {
      highlightedCandidateBackColor = highlightedBackColor;
    }
    commentTextColor = [config getColor:[prefix stringByAppendingString:@"/comment_text_color"]];
    highlightedCommentTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_comment_text_color"]];

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style' section

    updateCandidateListLayout(&linear, config, prefix);
    updateTextOrientation(&vertical, config, prefix);

    NSNumber *inlinePreeditOverridden = [config getOptionalBool:[prefix stringByAppendingString:@"/inline_preedit"]];
    if (inlinePreeditOverridden) {
      inlinePreedit = inlinePreeditOverridden.boolValue;
    }
    NSNumber *inlineCandidateOverridden = [config getOptionalBool:[prefix stringByAppendingString:@"/inline_candidate"]];
    if (inlineCandidateOverridden) {
      inlineCandidate = inlineCandidateOverridden.boolValue;
    }
    NSNumber *showPagingOverridden = [config getOptionalBool:[prefix stringByAppendingString:@"/show_paging"]];
    if (showPagingOverridden) {
      showPaging = showPagingOverridden.boolValue;
    }
    NSString *candidateFormatOverridden = [config getString:[prefix stringByAppendingString:@"/candidate_format"]];
    if (candidateFormatOverridden) {
      candidateFormat = candidateFormatOverridden;
    }
    NSString *fontNameOverridden = [config getString:[prefix stringByAppendingString:@"/font_face"]];
    if (fontNameOverridden) {
      fontName = fontNameOverridden;
    }
    NSNumber *fontSizeOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/font_point"]];
    if (fontSizeOverridden) {
      fontSize = fontSizeOverridden.doubleValue;
    }
    NSString *labelFontNameOverridden = [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
    if (labelFontNameOverridden) {
      labelFontName = labelFontNameOverridden;
    }
    NSNumber *labelFontSizeOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"]];
    if (labelFontSizeOverridden) {
      labelFontSize = labelFontSizeOverridden.doubleValue;
    }
    NSString *commentFontNameOverridden = [config getString:[prefix stringByAppendingString:@"/comment_font_face"]];
    if (commentFontNameOverridden) {
      commentFontName = commentFontNameOverridden;
    }
    NSNumber *commentFontSizeOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"]];
    if (commentFontSizeOverridden) {
      commentFontSize = commentFontSizeOverridden.doubleValue;
    }
    NSColor *candidateLabelColorOverridden = [config getColor:[prefix stringByAppendingString:@"/label_color"]];
    if (candidateLabelColorOverridden) {
      candidateLabelColor = candidateLabelColorOverridden;
    }
    NSColor *highlightedCandidateLabelColorOverridden = [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]];
    if (highlightedCandidateLabelColorOverridden == nil) {
      // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color' are both valid
      highlightedCandidateLabelColorOverridden = [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]];
    }
    if (highlightedCandidateLabelColorOverridden) {
      highlightedCandidateLabelColor = highlightedCandidateLabelColorOverridden;
    }
    NSNumber *alphaOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/alpha"]];
    if (alphaOverridden) {
      alpha = MIN(MAX(alphaOverridden.doubleValue, 0.0), 1.0);
    }
    NSNumber *translucencyOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/translucency"]];
    if (translucencyOverridden) {
      translucency = MIN(MAX(translucencyOverridden.doubleValue, 0.0), 1.0);
    }
    NSNumber *cornerRadiusOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/corner_radius"]];
    if (cornerRadiusOverridden) {
      cornerRadius = cornerRadiusOverridden.doubleValue;
    }
    NSNumber *hilitedCornerRadiusOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]];
    if (hilitedCornerRadiusOverridden) {
      hilitedCornerRadius = hilitedCornerRadiusOverridden.doubleValue;
    }
    NSNumber *borderHeightOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]];
    if (borderHeightOverridden) {
      borderHeight = borderHeightOverridden.doubleValue;
    }
    NSNumber *borderWidthOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]];
    if (borderWidthOverridden) {
      borderWidth = borderWidthOverridden.doubleValue;
    }
    NSNumber *lineSpacingOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]];
    if (lineSpacingOverridden) {
      lineSpacing = lineSpacingOverridden.doubleValue;
    }
    NSNumber *spacingOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]];
    if (spacingOverridden) {
      spacing = spacingOverridden.doubleValue;
    }
    NSNumber *baseOffsetOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]];
    if (baseOffsetOverridden) {
      baseOffset = baseOffsetOverridden.doubleValue;
    }
  }

  fontSize = fontSize ? fontSize : kDefaultFontSize;
  labelFontSize = labelFontSize ? labelFontSize : fontSize;
  commentFontSize = commentFontSize ? commentFontSize : fontSize;

  NSFontDescriptor *fontDescriptor = getFontDescriptor(fontName);
  NSFont *font = [NSFont fontWithDescriptor:(fontDescriptor ? fontDescriptor : getFontDescriptor([NSFont userFontOfSize:0.0].fontName)) size:fontSize];

  NSFontDescriptor *labelFontDescriptor = getFontDescriptor(labelFontName);
  NSFont *labelFont = labelFontDescriptor ? [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize] : (fontDescriptor ? [NSFont fontWithDescriptor:fontDescriptor size:labelFontSize] : [NSFont monospacedDigitSystemFontOfSize:labelFontSize weight:NSFontWeightRegular]);

  NSFontDescriptor *commentFontDescriptor = getFontDescriptor(commentFontName);
  NSFont *commentFont = [NSFont fontWithDescriptor:(commentFontDescriptor ? commentFontDescriptor : fontDescriptor) size:commentFontSize];

  NSFont *pagingFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0] fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized] size:labelFontSize];

  CGFloat fontHeight = getLineHeight(font);
  CGFloat labelFontHeight = getLineHeight(labelFont);
  CGFloat commentFontHeight = getLineHeight(commentFont);
  CGFloat lineHeight = MAX(fontHeight, MAX(labelFontHeight, commentFontHeight));

  NSMutableParagraphStyle *preeditParagraphStyle = [theme.preeditParagraphStyle mutableCopy];
  preeditParagraphStyle.minimumLineHeight = fontHeight;
  preeditParagraphStyle.maximumLineHeight = fontHeight;
  preeditParagraphStyle.paragraphSpacing = spacing;

  NSMutableParagraphStyle *paragraphStyle = [theme.paragraphStyle mutableCopy];
  paragraphStyle.minimumLineHeight = lineHeight;
  paragraphStyle.maximumLineHeight = lineHeight;
  paragraphStyle.paragraphSpacing = lineSpacing / 2;
  paragraphStyle.paragraphSpacingBefore = lineSpacing / 2;

  NSMutableParagraphStyle *pagingParagraphStyle = [theme.pagingParagraphStyle mutableCopy];
  pagingParagraphStyle.minimumLineHeight = pagingFont.ascender - pagingFont.descender;
  pagingParagraphStyle.maximumLineHeight = pagingFont.ascender - pagingFont.descender;

  NSMutableDictionary *attrs = [theme.attrs mutableCopy];
  NSMutableDictionary *highlightedAttrs = [theme.highlightedAttrs mutableCopy];
  NSMutableDictionary *labelAttrs = [theme.labelAttrs mutableCopy];
  NSMutableDictionary *labelHighlightedAttrs = [theme.labelHighlightedAttrs mutableCopy];
  NSMutableDictionary *commentAttrs = [theme.commentAttrs mutableCopy];
  NSMutableDictionary *commentHighlightedAttrs = [theme.commentHighlightedAttrs mutableCopy];
  NSMutableDictionary *preeditAttrs = [theme.preeditAttrs mutableCopy];
  NSMutableDictionary *preeditHighlightedAttrs = [theme.preeditHighlightedAttrs mutableCopy];
  NSMutableDictionary *pagingAttrs = [theme.pagingAttrs mutableCopy];
  NSMutableDictionary *pagingHighlightedAttrs = [theme.pagingHighlightedAttrs mutableCopy];

  attrs[NSFontAttributeName] = font;
  highlightedAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  commentHighlightedAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  preeditHighlightedAttrs[NSFontAttributeName] = font;
  pagingAttrs[NSFontAttributeName] = pagingFont;
  pagingHighlightedAttrs[NSFontAttributeName] = pagingFont;

  attrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  highlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  pagingAttrs[NSBaselineOffsetAttributeName] = @(baseOffset - (linear ? 0.0 : labelFontSize * 0.1));
  pagingHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset - (linear ? 0.0 : labelFontSize * 0.1));

  preeditAttrs[NSLigatureAttributeName] = @0;
  preeditHighlightedAttrs[NSLigatureAttributeName] = @0;

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];
  NSColor *accentColor = [[self class] accentColor];

  backgroundColor = backgroundColor ? backgroundColor : [NSColor controlBackgroundColor];
  borderColor = borderColor ? borderColor : isNative ? [NSColor gridColor] : nil;
  preeditBackgroundColor = preeditBackgroundColor ? preeditBackgroundColor : isNative ? [NSColor windowBackgroundColor] : nil;
  candidateTextColor = candidateTextColor ? candidateTextColor : [NSColor controlTextColor];
  highlightedCandidateTextColor = highlightedCandidateTextColor ? highlightedCandidateTextColor : [NSColor selectedMenuItemTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? highlightedCandidateBackColor : isNative ? [NSColor alternateSelectedControlColor] : nil;
  candidateLabelColor = candidateLabelColor ? candidateLabelColor : isNative ? accentColor : blendColors(highlightedCandidateBackColor, highlightedCandidateTextColor);
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? highlightedCandidateLabelColor : isNative ? [NSColor alternateSelectedControlTextColor] : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? commentTextColor : secondaryTextColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? highlightedCommentTextColor : [NSColor alternateSelectedControlTextColor];
  textColor = textColor ? textColor : [NSColor textColor];
  highlightedTextColor = highlightedTextColor ? highlightedTextColor : [NSColor selectedTextColor];
  highlightedBackColor = highlightedBackColor ? highlightedBackColor : isNative ? [NSColor selectedTextBackgroundColor] : nil;

  attrs[NSForegroundColorAttributeName] = candidateTextColor;
  highlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateTextColor;
  labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
  labelHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateLabelColor;
  commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
  commentHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCommentTextColor;
  preeditAttrs[NSForegroundColorAttributeName] = textColor;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = highlightedTextColor;
  pagingAttrs[NSForegroundColorAttributeName] = linear ? candidateLabelColor : candidateTextColor;
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = linear ? highlightedCandidateLabelColor : highlightedCandidateTextColor;

  attrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  highlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  commentAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  commentHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  preeditAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  preeditHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);

  [theme setStatusMessageType:statusMessageType];

  [theme          setAttrs:attrs
          highlightedAttrs:highlightedAttrs
                labelAttrs:labelAttrs
     labelHighlightedAttrs:labelHighlightedAttrs
              commentAttrs:commentAttrs
   commentHighlightedAttrs:commentHighlightedAttrs
              preeditAttrs:preeditAttrs
   preeditHighlightedAttrs:preeditHighlightedAttrs
               pagingAttrs:pagingAttrs
    pagingHighlightedAttrs:pagingHighlightedAttrs];

  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle
      pagingParagraphStyle:pagingParagraphStyle];

  [theme setBackgroundColor:backgroundColor
            backgroundImage:backgroundImage
      highlightedStripColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];

  NSSize edgeInset = vertical ? NSMakeSize(borderHeight, borderWidth) : NSMakeSize(borderWidth, borderHeight);

  [theme setCornerRadius:cornerRadius
     hilitedCornerRadius:MIN(hilitedCornerRadius, lineHeight/2)
               edgeInset:edgeInset
               linespace:lineSpacing
        preeditLinespace:spacing
                   alpha:(alpha == 0 ? 1.0 : alpha)
            translucency:translucency
              showPaging:showPaging
            rememberSize:rememberSize
                  linear:linear
                vertical:vertical
           inlinePreedit:inlinePreedit
         inlineCandidate:inlineCandidate];

  theme.native = isNative;
  theme.candidateFormat = candidateFormat ? candidateFormat : kDefaultCandidateFormat;
}

@end
