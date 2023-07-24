#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in OS X v10.2 and later.
- (CGPathRef)quartzPath {
  if (@available(macOS 14.0, *)) {
    return self.CGPath;
  } else {
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
@property(nonatomic, readonly) CGFloat lineLength;
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
@property(nonatomic, strong, readonly) NSParagraphStyle *statusParagraphStyle;

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
             lineLength:(CGFloat)lineLength
             showPaging:(BOOL)showPaging
           rememberSize:(BOOL)rememberSize
                 linear:(BOOL)linear
               vertical:(BOOL)vertical
          inlinePreedit:(BOOL)inlinePreedit
        inlineCandidate:(BOOL)inlineCandidate;

- (void)         setAttrs:(NSMutableDictionary *)attrs
         highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
               labelAttrs:(NSMutableDictionary *)labelAttrs
    labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
             commentAttrs:(NSMutableDictionary *)commentAttrs
  commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
             preeditAttrs:(NSMutableDictionary *)preeditAttrs
  preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
              pagingAttrs:(NSMutableDictionary *)pagingAttrs
   pagingHighlightedAttrs:(NSMutableDictionary *)pagingHighlightedAttrs;

- (void)setParagraphStyle:(NSParagraphStyle *)paragraphStyle
    preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle
     pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle
     statusParagraphStyle:(NSParagraphStyle *)statusParagraphStyle;

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
  if ([type isEqualToString:@"long"] || [type isEqualToString:@"short"] || [type isEqualToString:@"mix"]) {
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
             lineLength:(CGFloat)lineLength
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
  _lineLength = lineLength;
  _showPaging = showPaging;
  _rememberSize = rememberSize;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
  _inlineCandidate = inlineCandidate;
}

- (void)         setAttrs:(NSMutableDictionary *)attrs
         highlightedAttrs:(NSMutableDictionary *)highlightedAttrs
               labelAttrs:(NSMutableDictionary *)labelAttrs
    labelHighlightedAttrs:(NSMutableDictionary *)labelHighlightedAttrs
             commentAttrs:(NSMutableDictionary *)commentAttrs
  commentHighlightedAttrs:(NSMutableDictionary *)commentHighlightedAttrs
             preeditAttrs:(NSMutableDictionary *)preeditAttrs
  preeditHighlightedAttrs:(NSMutableDictionary *)preeditHighlightedAttrs
              pagingAttrs:(NSMutableDictionary *)pagingAttrs
   pagingHighlightedAttrs:(NSMutableDictionary *)pagingHighlightedAttrs {
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

- (void)setParagraphStyle:(NSParagraphStyle *)paragraphStyle
    preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle
     pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle
     statusParagraphStyle:(NSParagraphStyle *)statusParagraphStyle {
  _paragraphStyle = paragraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
  _pagingParagraphStyle = pagingParagraphStyle;
  _statusParagraphStyle = statusParagraphStyle;
}

@end

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextView *textView;
@property(nonatomic, readonly) NSEdgeInsets insets;
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
@property(nonatomic, readonly) NSTextLayoutManager *layoutManager API_AVAILABLE(macos(12.0));
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, assign) CGFloat separatorWidth;
@property(nonatomic, readonly) CAShapeLayer *shape;
@property(nonatomic, getter = isFlipped, readonly) BOOL flipped;
@property(nonatomic, readonly) BOOL wantsUpdateLayer;

- (void) drawViewWithInsets:(NSEdgeInsets)insets
            candidateRanges:(NSArray<NSValue *> *)candidateRanges
           highlightedIndex:(NSUInteger)highlightedIndex
               preeditRange:(NSRange)preeditRange
    highlightedPreeditRange:(NSRange)highlightedPreeditRange
                pagingRange:(NSRange)pagingRange
               pagingButton:(NSUInteger)pagingButton;
- (NSRect)contentRectForRange:(NSRange)range;
- (NSRect)setLineRectForRange:(NSRange)charRange
                     atOrigin:(NSPoint *)origin
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

- (BOOL)wantsUpdateLayer {
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
    self.layer.geometryFlipped = YES;
    self.layer.masksToBounds = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
  }

  if (@available(macOS 12.0, *)) {
    _layoutManager = [[NSTextLayoutManager alloc] init];
    _layoutManager.usesFontLeading = NO;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    _layoutManager.textContainer = textContainer;
    NSTextContentStorage *textStorage = [[NSTextContentStorage alloc] init];
    [textStorage addTextLayoutManager:_layoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect
                                    textContainer:_layoutManager.textContainer];
  } else {
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    layoutManager.backgroundLayoutEnabled = YES;
    layoutManager.usesFontLeading = NO;
    layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithContainerSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    [layoutManager addTextContainer:textContainer];
    NSTextStorage *textStorage = [[NSTextStorage alloc] init];
    [textStorage addLayoutManager:layoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect
                                    textContainer:textContainer];
  }
  _textView.drawsBackground = NO;
  _textView.editable = NO;
  _textView.selectable = NO;
  _textView.wantsLayer = NO;

  _defaultTheme = [[SquirrelTheme alloc] init];
  _shape = [[CAShapeLayer alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
  }
  return self;
}

- (NSTextRange *)getTextRangeFromRange:(NSRange)range API_AVAILABLE(macos(12.0)) {
  if (range.location == NSNotFound) {
    return nil;
  } else {
    NSTextContentManager *contentManager = _layoutManager.textContentManager;
    id<NSTextLocation> startLocation = [contentManager locationFromLocation:contentManager.documentRange.location withOffset:range.location];
    id<NSTextLocation> endLocation = [contentManager locationFromLocation:startLocation withOffset:range.length];
    return [[NSTextRange alloc] initWithLocation:startLocation endLocation:endLocation];
  }
}

- (NSRect)setLineRectForRange:(NSRange)charRange
                     atOrigin:(NSPoint *)origin
            withReferenceFont:(NSFont *)refFont
               paragraphStyle:(NSParagraphStyle *)style {
  NSLayoutManager *layoutManager = _textView.layoutManager;
  NSTextContainer *textContainer = _textView.textContainer;
  NSTextStorage *textStorage = _textView.textStorage;

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
  BOOL verticalLayout = textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  CGFloat refFontHeight = refFont.ascender - refFont.descender;
  CGFloat refBaseline = refFont.ascender;
  CGFloat lineHeight = MAX(style.lineHeightMultiple > 0 ? refFontHeight * style.lineHeightMultiple : refFontHeight, style.minimumLineHeight);
  lineHeight = style.maximumLineHeight > 0 ? MIN(lineHeight, style.maximumLineHeight) : lineHeight;

  NSRect blockRect = NSZeroRect;
  NSUInteger i = glyphRange.location;
  NSRange lineRange = NSMakeRange(i, 0);
  while (i < NSMaxRange(glyphRange)) {
    // typsetting the line fragment
    NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:i effectiveRange:&lineRange];
    NSRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:i effectiveRange:NULL];
    NSRange lineCharRange = [layoutManager characterRangeForGlyphRange:lineRange actualGlyphRange:NULL];
    rect.origin.y = origin->y;
    usedRect.origin.y = origin->y;
    rect.size.height = lineHeight;
    usedRect.size.height = MAX(NSHeight(usedRect), lineHeight);
    CGFloat alignment = verticalLayout ? lineHeight / 2 : refBaseline + MAX(0.0, lineHeight - refFontHeight) / 2;
    if (style.lineSpacing > 0) {
      rect.size.height = lineHeight + style.lineSpacing;
      usedRect.size.height = MAX(NSHeight(usedRect), lineHeight + style.lineSpacing);
      alignment += style.lineSpacing / 2;
    }
    if (style.paragraphSpacing > 0 && NSMaxRange(lineCharRange) != textStorage.length &&
        [textStorage.string characterAtIndex:NSMaxRange(lineCharRange) - 1] == '\n') {
      rect.size.height += style.paragraphSpacing;
    }
    if (style.paragraphSpacingBefore > 0 && lineCharRange.location != 0 &&
        [textStorage.string characterAtIndex:lineCharRange.location - 1] == '\n') {
      rect.size.height += style.paragraphSpacingBefore;
      usedRect.origin.y += style.paragraphSpacingBefore;
      alignment += style.paragraphSpacingBefore;
    }
    [layoutManager setLineFragmentRect:rect forGlyphRange:lineRange usedRect:NSIntersectionRect(usedRect, rect)];
    blockRect = NSUnionRect(blockRect, rect);
    origin->y = NSMaxY(rect);

    // typesetting glyphs
    NSRange fontRunRange = NSMakeRange(NSNotFound, 0);
    NSUInteger j = lineRange.location;
    while (j < NSMaxRange(lineRange)) {
      NSPoint runGlyphPosition = [layoutManager locationForGlyphAtIndex:j];
      NSUInteger runCharLocation = [layoutManager characterIndexForGlyphAtIndex:j];
      NSFont *runFont = [textStorage attribute:NSFontAttributeName atIndex:runCharLocation effectiveRange:&fontRunRange];
      NSFont *resizedRefFont = [NSFont fontWithDescriptor:refFont.fontDescriptor size:runFont.pointSize];
      CGFloat baselineOffset = [[textStorage attribute:NSBaselineOffsetAttributeName atIndex:runCharLocation effectiveRange:NULL] doubleValue];
      NSRange fontRunGlyphRange = [layoutManager characterRangeForGlyphRange:fontRunRange actualGlyphRange:NULL];
      NSRange runRange = NSIntersectionRange(fontRunGlyphRange, [layoutManager rangeOfNominallySpacedGlyphsContainingIndex:j]);
      if (verticalLayout) {
        runFont = runFont.verticalFont;
        resizedRefFont = resizedRefFont.verticalFont;
      }
      CGFloat runBaseline = runFont.ascender;
      CGFloat runFontHeight = runFont.ascender - runFont.descender;
      CGFloat resizedRefFontHeight = resizedRefFont.ascender - resizedRefFont.descender;
      if (verticalLayout) {
        runGlyphPosition.y = alignment - baselineOffset + ceil(MAX(0.0, runFontHeight - resizedRefFontHeight)/4);
        if (runFont.isVertical) {
          runGlyphPosition.x += ceil(MAX(0.0, runFontHeight - resizedRefFontHeight)/2);
        } else {
          runGlyphPosition.y += runBaseline - runFontHeight/2;
        }
      } else {
        runGlyphPosition.y = alignment - baselineOffset;
      }
      [layoutManager setLocation:runGlyphPosition forStartOfGlyphRange:runRange];
      j = NSMaxRange(runRange);
    }
    i = NSMaxRange(lineRange);
  }
  return blockRect;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  if (@available(macOS 12.0, *)) {
    [_layoutManager ensureLayoutForRange:_layoutManager.textContentManager.documentRange];
    return NSInsetRect([_layoutManager usageBoundsForTextContainer],
                       -_textView.textContainer.lineFragmentPadding, 0);
  } else {
    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    return [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
  }
}

// Get the rectangle containing the range of text, will first convert to glyph or text range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromRange:range];
    __block NSRect contentRect = NSZeroRect;
    [_layoutManager enumerateTextSegmentsInRange:textRange
                                            type:NSTextLayoutManagerSegmentTypeStandard
                                         options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                      usingBlock:
     ^(NSTextRange *segmentRange, CGRect segmentRect, CGFloat baseline, NSTextContainer *textContainer) {
      contentRect = NSUnionRect(contentRect, segmentRect);
      return YES;
    }];
    return contentRect;
  } else {
    NSRange glyphRange = [_textView.layoutManager glyphRangeForCharacterRange:range
                                                         actualCharacterRange:NULL];
    NSRect rect = [_textView.layoutManager boundingRectForGlyphRange:glyphRange
                                                     inTextContainer:_textView.textContainer];
    NSRect firstLineRect = [_textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                                                         effectiveRange:NULL];
    NSRect finalLineRect = [_textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                                                                         effectiveRange:NULL];
    NSRect contentRect = NSMakeRect(NSMinX(rect), NSMinY(firstLineRect),
                                    NSWidth(rect), NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    return contentRect;
  }
}

// Will triger - (void)drawRect:(NSRect)dirtyRect
- (void) drawViewWithInsets:(NSEdgeInsets)insets
            candidateRanges:(NSArray<NSValue *> *)candidateRanges
           highlightedIndex:(NSUInteger)highlightedIndex
               preeditRange:(NSRange)preeditRange
    highlightedPreeditRange:(NSRange)highlightedPreeditRange
                pagingRange:(NSRange)pagingRange
               pagingButton:(NSUInteger)pagingButton {
  _insets = insets;
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

// Bezier cubic curve, which has continuous roundness
NSBezierPath * drawRoundedPolygon(NSArray<NSValue *> *vertex, CGFloat radius) {
  NSBezierPath *path = [NSBezierPath bezierPath];
  if (vertex.count < 1) {
    return path;
  }
  NSPoint previousPoint = vertex.lastObject.pointValue;
  NSPoint point = vertex.firstObject.pointValue;
  NSPoint nextPoint;
  NSPoint startPoint;
  NSPoint endPoint = previousPoint;
  CGFloat arcRadius;
  CGVector diff = CGVectorMake(point.x - previousPoint.x, point.y - previousPoint.y);
  if (ABS(diff.dx) >= ABS(diff.dy)) {
    endPoint.x += diff.dx / 2;
    endPoint.y = point.y;
  } else {
    endPoint.y += diff.dy / 2;
    endPoint.x = point.x;
  }
  [path moveToPoint:endPoint];
  for (NSUInteger i = 0; i < vertex.count; ++i) {
    startPoint = endPoint;
    point = vertex[i].pointValue;
    nextPoint = vertex[(i + 1) % vertex.count].pointValue;
    arcRadius = MIN(radius, MAX(ABS(point.x - startPoint.x), ABS(point.y - startPoint.y)));
    endPoint = point;
    diff = CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
    if (ABS(diff.dx) > ABS(diff.dy)) {
      endPoint.x += diff.dx / 2;
      arcRadius = MIN(arcRadius, ABS(diff.dx) / 2);
      endPoint.y = nextPoint.y;
      point.y = nextPoint.y;
    } else {
      endPoint.y += diff.dy / 2;
      arcRadius = MIN(arcRadius, ABS(diff.dy) / 2);
      endPoint.x = nextPoint.x;
      point.x = nextPoint.x;
    }
    [path appendBezierPathWithArcFromPoint:point toPoint:endPoint radius:arcRadius];
  }
  [path closePath];
  return path;
}

NSArray<NSValue *> * rectVertex(NSRect rect) {
  return @[@(rect.origin),
           @(NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y))];
}

BOOL nearEmptyRect(NSRect rect) {
  return rect.size.height * rect.size.width < 1;
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is the complete line fragment in the middle if the range spans no less than one full line
- (void)multilineRectForRange:(NSRange)charRange leadingRect:(NSRect *)leadingRect bodyRect:(NSRect *)bodyRect trailingRect:(NSRect *)trailingRect {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromRange:charRange];
    NSMutableArray<NSValue *> *lineRects = [[NSMutableArray alloc] init];
    [_layoutManager enumerateTextSegmentsInRange:textRange
                                            type:NSTextLayoutManagerSegmentTypeStandard
                                         options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                      usingBlock:
     ^(NSTextRange *segmentRange, CGRect segmentRect, CGFloat baseline, NSTextContainer *textContainer) {
      if (!nearEmptyRect(segmentRect)) {
        [lineRects addObject:[NSValue valueWithRect:segmentRect]];
      }
      return YES;
    }];
    if (lineRects.count == 1) {
      *bodyRect = lineRects[0].rectValue;
    } else {
      NSRect firstLineRect = lineRects.firstObject.rectValue;
      NSRect lastLineRect = lineRects.lastObject.rectValue;
      if (NSMaxX(lastLineRect) == NSMaxX(firstLineRect)) {
        if (NSMinX(firstLineRect) == NSMinX(lastLineRect)) {
          *bodyRect = NSUnionRect(firstLineRect, lastLineRect);
        } else {
          *leadingRect = firstLineRect;
          *bodyRect = NSUnionRect(lineRects[1].rectValue, lastLineRect);
        }
      } else {
        *trailingRect = lastLineRect;
        if (NSMinX(firstLineRect) == NSMinX(lastLineRect)) {
          *bodyRect = NSUnionRect(firstLineRect, lineRects[lineRects.count - 2].rectValue);
        } else {
          *leadingRect = firstLineRect;
          if (lineRects.count > 2) {
            *bodyRect = NSUnionRect(lineRects[1].rectValue, lineRects[lineRects.count - 2].rectValue);
          }
        }
      }
    }
  } else {
    NSLayoutManager *layoutManager = _textView.layoutManager;
    NSTextContainer *textContainer = _textView.textContainer;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
                                               actualCharacterRange:NULL];
    CGFloat startX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
    CGFloat endX = NSMaxX([layoutManager boundingRectForGlyphRange:NSMakeRange(NSMaxRange(glyphRange) - 1, 1)
                                                   inTextContainer:textContainer]);
    NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange
                                                   inTextContainer:textContainer];
    NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect leadingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                                                 effectiveRange:&leadingLineRange];
    if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
      *bodyRect = NSMakeRect(NSMinX(leadingLineRect) + startX,
                             NSMinY(leadingLineRect),
                             endX - startX, NSHeight(leadingLineRect));
    } else {
      CGFloat rightEdge = MAX(NSMaxX(leadingLineRect) - textContainer.lineFragmentPadding, NSMaxX(boundingRect));
      NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
      NSRect trailingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                                                                    effectiveRange:&trailingLineRange];
      CGFloat leftEdge = MIN(NSMinX(trailingLineRect) + textContainer.lineFragmentPadding, NSMinX(boundingRect));
      if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(leftEdge, NSMinY(leadingLineRect),
                                 rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startX, NSMinY(leadingLineRect),
                                    rightEdge - NSMinX(leadingLineRect) - startX, NSHeight(leadingLineRect));
          *bodyRect = NSMakeRect(leftEdge, NSMaxY(leadingLineRect),
                                 rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = NSMakeRect(leftEdge, NSMinY(trailingLineRect),
                                   NSMinX(trailingLineRect) + endX - leftEdge, NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(leftEdge, NSMinY(leadingLineRect),
                                 rightEdge - leftEdge, NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startX,
                                    NSMinY(leadingLineRect),
                                    rightEdge - NSMinX(leadingLineRect) - startX, NSHeight(leadingLineRect));
          if (trailingLineRange.location > NSMaxRange(leadingLineRange)) {
            *bodyRect = NSMakeRect(leftEdge, NSMaxY(leadingLineRect),
                                   rightEdge - leftEdge, NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
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
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], bodyVertex[1], bodyVertex[2], leadingVertex[3]];
  } else if (nearEmptyRect(leadingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], bodyVertex[3]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) &&
             nearEmptyRect(bodyRect) && NSMaxX(leadingRect) > NSMinX(trailingRect)) {
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], trailingVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3]];
  } else if (!nearEmptyRect(leadingRect) && !nearEmptyRect(trailingRect) && !nearEmptyRect(bodyRect)) {
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3]];
  } else {
    return @[];
  }
}

NSColor * hooverColor(NSColor *color, BOOL darkTheme) {
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  }
  if (darkTheme) {
    return [color highlightWithLevel:0.3];
  } else {
    return [color shadowWithLevel:0.3];
  }
}

NSColor * disabledColor(NSColor *color, BOOL darkTheme) {
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
- (void)updateLayer {
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *textContainerPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *candidateBlockPath;
  NSBezierPath *pageUpPath;
  NSBezierPath *pageDownPath;

  SquirrelTheme *theme = self.currentTheme;
  NSRect backgroundRect = self.bounds;
  NSRect textContainerRect = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);
  CGFloat linePadding = _textView.textContainer.lineFragmentPadding;

  NSRange visibleRange;
  if (@available(macOS 12.0, *)) {
    visibleRange = NSMakeRange(0, _textView.textContentStorage.textStorage.length);
  } else {
    NSRange containerGlyphRange = {NSNotFound, 0};
    [_textView.layoutManager textContainerForGlyphAtIndex:0 effectiveRange:&containerGlyphRange];
    visibleRange = [_textView.layoutManager characterRangeForGlyphRange:containerGlyphRange actualGlyphRange:NULL];
  }

  NSRange preeditRange = NSIntersectionRange(_preeditRange, visibleRange);
  NSRange candidateBlockRange = NSIntersectionRange(NSUnionRange(_candidateRanges.firstObject.rangeValue, theme.linear && _pagingRange.length > 0 ? _pagingRange : _candidateRanges.lastObject.rangeValue), visibleRange);
  NSRange pagingRange = NSIntersectionRange(_pagingRange, visibleRange);

  NSRect preeditRect = NSZeroRect;
  NSRect candidateBlockRect = NSZeroRect;
  NSRect pagingLineRect = NSZeroRect;
  NSRect statusRect = NSZeroRect;
  if (@available(macOS 12.0, *)) {
    if (preeditRange.length > 0) {
      preeditRect = [self contentRectForRange:preeditRange];
      if (candidateBlockRange.length > 0) {
        preeditRect.size.height += theme.preeditLinespace;
      }
    }
    if (candidateBlockRange.length > 0) {
      candidateBlockRect = NSInsetRect([self contentRectForRange:candidateBlockRange], 0.0, -theme.linespace / 2);
      if (preeditRange.length == 0) {
        candidateBlockRect.origin.y += theme.linespace / 2;
      }
    } else if (preeditRange.length == 0) { // status message
      statusRect = [self contentRectForRange:visibleRange];
    }
    if (!theme.linear && pagingRange.length > 0) {
      pagingLineRect = [self contentRectForRange:pagingRange];
      pagingLineRect.origin.y -= theme.pagingParagraphStyle.paragraphSpacingBefore;
      pagingLineRect.size.height += theme.pagingParagraphStyle.paragraphSpacingBefore;
    }
  } else {
    NSPoint lineOrigin = NSZeroPoint;
    if (preeditRange.length > 0) {
      NSFont *preeditRefFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, [theme.preeditAttrs[NSFontAttributeName] pointSize], (CFStringRef)@"zh"));
      preeditRect = [self setLineRectForRange:preeditRange
                                     atOrigin:&lineOrigin
                            withReferenceFont:(theme.vertical ? preeditRefFont.verticalFont : preeditRefFont)
                               paragraphStyle:theme.preeditParagraphStyle];
    }
    if (candidateBlockRange.length > 0) {
      CGFloat fontSize = MAX([theme.attrs[NSFontAttributeName] pointSize],
                             MAX([theme.commentAttrs[NSFontAttributeName] pointSize],
                                 [theme.labelAttrs[NSFontAttributeName] pointSize]));
      NSFont *refFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, fontSize, (CFStringRef)@"zh"));
      candidateBlockRect = [self setLineRectForRange:candidateBlockRange
                                            atOrigin:&lineOrigin
                                   withReferenceFont:(theme.vertical ? refFont.verticalFont : refFont)
                                      paragraphStyle:theme.paragraphStyle];
      if (preeditRange.length == 0) {
        candidateBlockRect.size.height += theme.linespace / 2;
      }
      if (theme.linear || pagingRange.length == 0) {
        candidateBlockRect.size.height += theme.linespace / 2;
      }
    } else if (preeditRange.length == 0) { // status message
      NSFont *statusRefFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, [theme.commentAttrs[NSFontAttributeName] pointSize], (CFStringRef)@"zh"));
      statusRect = [self setLineRectForRange:visibleRange
                                    atOrigin:&lineOrigin
                           withReferenceFont:(theme.vertical ? statusRefFont.verticalFont : statusRefFont)
                              paragraphStyle:theme.statusParagraphStyle];
    }
    if (!theme.linear && pagingRange.length > 0) {
      pagingLineRect = [self setLineRectForRange:pagingRange
                                        atOrigin:&lineOrigin
                               withReferenceFont:theme.pagingAttrs[NSFontAttributeName]
                                  paragraphStyle:theme.pagingParagraphStyle];
    }
  }

  [NSBezierPath setDefaultLineWidth:0];
  // Draw preedit Rect
  if (preeditRange.length > 0) {
    preeditRect.size.width = textContainerRect.size.width;
    preeditRect.origin = textContainerRect.origin;
    // Draw highlighted part of preedit text
    NSRange highlightedPreeditRange = NSIntersectionRange(_highlightedPreeditRange, visibleRange);
    if (highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
      NSRect innerBox = NSInsetRect(preeditRect, linePadding, 0);
      if (candidateBlockRange.length > 0) {
        innerBox.size.height -= theme.preeditLinespace;
      }
      NSRect leadingRect = NSZeroRect;
      NSRect bodyRect = NSZeroRect;
      NSRect trailingRect = NSZeroRect;
      [self multilineRectForRange:highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
      leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect
      : NSIntersectionRect(NSOffsetRect(leadingRect, textContainerRect.origin.x, textContainerRect.origin.y), innerBox);
      bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect
      : NSIntersectionRect(NSOffsetRect(bodyRect, textContainerRect.origin.x, textContainerRect.origin.y), innerBox);
      trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect
      : NSIntersectionRect(NSOffsetRect(trailingRect, textContainerRect.origin.x, textContainerRect.origin.y), innerBox);
      NSMutableArray<NSValue *> *highlightedPreeditPoints;
      NSMutableArray<NSValue *> *highlightedPreeditPoints2;
      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect)
          && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPreeditPoints = [rectVertex(leadingRect) mutableCopy];
        highlightedPreeditPoints2 = [rectVertex(trailingRect) mutableCopy];
      } else {
        highlightedPreeditPoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
      }
      highlightedPreeditPath = drawRoundedPolygon(highlightedPreeditPoints, MIN(theme.hilitedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight/3));
      if (highlightedPreeditPoints2.count > 0) {
        [highlightedPreeditPath appendBezierPath:drawRoundedPolygon(highlightedPreeditPoints2, MIN(theme.hilitedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight/3))];
      }
    }
  }

  // Draw candidate Rect
  if (candidateBlockRange.length > 0) {
    candidateBlockRect.size.width = textContainerRect.size.width;
    candidateBlockRect.origin.x = textContainerRect.origin.x;
    candidateBlockRect.origin.y += textContainerRect.origin.y;
    candidateBlockRect = NSIntersectionRect(candidateBlockRect, textContainerRect);
    candidateBlockPath = drawRoundedPolygon(rectVertex(candidateBlockRect), theme.hilitedCornerRadius);

    // Draw candidate highlight rect
    for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
      NSRange candidateRange = NSIntersectionRange([_candidateRanges[i] rangeValue], visibleRange);
      if (candidateRange.length == 0) {
        break;
      }
      if (theme.linear) {
        NSRect leadingRect = NSZeroRect;
        NSRect bodyRect = NSZeroRect;
        NSRect trailingRect = NSZeroRect;
        [self multilineRectForRange:candidateRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
        leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : NSInsetRect(NSOffsetRect(leadingRect, textContainerRect.origin.x, textContainerRect.origin.y), -MIN(_separatorWidth / 2, linePadding), 0);
        bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : NSInsetRect(NSOffsetRect(bodyRect, textContainerRect.origin.x, textContainerRect.origin.y), -MIN(_separatorWidth / 2, linePadding), 0);
        trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : NSInsetRect(NSOffsetRect(trailingRect, textContainerRect.origin.x, textContainerRect.origin.y), -MIN(_separatorWidth / 2, linePadding), 0);
        if (preeditRange.length == 0) {
          leadingRect.origin.y += theme.linespace / 2;
          bodyRect.origin.y += theme.linespace / 2;
          trailingRect.origin.y += theme.linespace / 2;
        }
        if (!NSIsEmptyRect(leadingRect)) {
          leadingRect.origin.y -= theme.linespace / 2;
          leadingRect.size.height += theme.linespace / 2;
          leadingRect = NSIntersectionRect(leadingRect, candidateBlockRect);
        }
        if (!NSIsEmptyRect(trailingRect)) {
          trailingRect.size.height += theme.linespace / 2;
          trailingRect = NSIntersectionRect(trailingRect, candidateBlockRect);
        }
        if (!NSIsEmptyRect(bodyRect)) {
          if (NSIsEmptyRect(leadingRect)) {
            bodyRect.origin.y -= theme.linespace / 2;
            bodyRect.size.height += theme.linespace / 2;
          }
          if (NSIsEmptyRect(trailingRect)) {
            bodyRect.size.height += theme.linespace / 2;
          }
          bodyRect = NSIntersectionRect(bodyRect, candidateBlockRect);
        }
        NSMutableArray<NSValue *> *candidatePoints;
        NSMutableArray<NSValue *> *candidatePoints2;
        // Handles the special case where containing boxes are separated
        if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) &&
            !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePoints = [rectVertex(leadingRect) mutableCopy];
          candidatePoints2 = [rectVertex(trailingRect) mutableCopy];
        } else {
          candidatePoints = [multilineRectVertex(leadingRect, bodyRect, trailingRect) mutableCopy];
        }
        NSBezierPath *candidatePath = drawRoundedPolygon(candidatePoints, theme.hilitedCornerRadius);
        if (candidatePoints2.count > 0) {
          [candidatePath appendBezierPath:drawRoundedPolygon(candidatePoints2, theme.hilitedCornerRadius)];
        }
        _candidatePaths[i] = candidatePath;
      } else {
        NSRect candidateRect = NSInsetRect([self contentRectForRange:candidateRange], 0.0, -theme.linespace / 2);
        candidateRect.size.width = textContainerRect.size.width;
        candidateRect.origin.x = textContainerRect.origin.x;
        candidateRect.origin.y += textContainerRect.origin.y;
        if (preeditRange.length == 0) {
          candidateRect.origin.y += theme.linespace / 2;
        }
        candidateRect = NSIntersectionRect(candidateRect, candidateBlockRect);
        NSMutableArray<NSValue *> *candidatePoints = [rectVertex(candidateRect) mutableCopy];
        NSBezierPath *candidatePath = drawRoundedPolygon(candidatePoints, theme.hilitedCornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
  }

  // Draw paging Rect
  if (pagingRange.length > 0) {
    CGFloat buttonPadding = theme.linear ? MIN(_separatorWidth / 2, linePadding) : linePadding;
    NSRect pageDownRect = NSOffsetRect([self contentRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)],
                                       textContainerRect.origin.x, textContainerRect.origin.y);
    pageDownRect.size.width += buttonPadding;
    NSRect pageUpRect = NSOffsetRect([self contentRectForRange:NSMakeRange(pagingRange.location, 1)],
                                     textContainerRect.origin.x, textContainerRect.origin.y);
    pageUpRect.origin.x -= buttonPadding;
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    if (theme.linear) {
      pageDownRect = NSInsetRect(pageDownRect, 0.0, -theme.linespace / 2);
      pageUpRect = NSInsetRect(pageUpRect, 0.0, -theme.linespace / 2);
    }
    if (preeditRange.length == 0) {
      pageDownRect = NSOffsetRect(pageDownRect, 0.0, theme.linespace / 2);
      pageUpRect = NSOffsetRect(pageUpRect, 0.0, theme.linespace / 2);
    }
    pageDownRect = NSIntersectionRect(pageDownRect, textContainerRect);
    pageUpRect = NSIntersectionRect(pageUpRect, textContainerRect);
    pageDownPath = drawRoundedPolygon(rectVertex(pageDownRect),
                                      MIN(theme.hilitedCornerRadius, MIN(NSWidth(pageDownRect), NSHeight(pageDownRect))/3));
    pageUpPath = drawRoundedPolygon(rectVertex(pageUpRect),
                                    MIN(theme.hilitedCornerRadius, MIN(NSWidth(pageUpRect), NSHeight(pageUpRect))/3));
    _pagingPaths[0] = pageUpPath;
    _pagingPaths[1] = pageDownPath;
  }

  // Draw borders
  backgroundPath = drawRoundedPolygon(rectVertex(backgroundRect),
                                      MIN(theme.cornerRadius, NSHeight(backgroundRect)/3));
  textContainerPath = drawRoundedPolygon(rectVertex(textContainerRect),
                                         MIN(theme.hilitedCornerRadius, NSHeight(textContainerRect)/3));
  if (theme.edgeInset.width > 0 || theme.edgeInset.height > 0) {
    borderPath = [backgroundPath copy];
    [borderPath appendBezierPath:textContainerPath];
    borderPath.windingRule = NSEvenOddWindingRule;
  }

  // set layers
  _shape.path = [backgroundPath quartzPath];
  _shape.fillColor = [[NSColor whiteColor] CGColor];
  _shape.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect)/3);
  CAShapeLayer *textContainerLayer = [[CAShapeLayer alloc] init];
  textContainerLayer.path = [textContainerPath quartzPath];
  textContainerLayer.fillColor = [[NSColor whiteColor] CGColor];
  textContainerLayer.cornerRadius = MIN(theme.hilitedCornerRadius, NSHeight(textContainerRect)/3);
  [self.layer setSublayers:NULL];
  self.layer.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect)/3);
  if (theme.backgroundImage) {
    CAShapeLayer *backgroundLayer = [[CAShapeLayer alloc] init];
    backgroundLayer.path = [backgroundPath quartzPath];
    backgroundLayer.fillColor = [theme.backgroundImage CGColor];
    backgroundLayer.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect)/3);
    [self.layer addSublayer:backgroundLayer];
  }
  CAShapeLayer *panelLayer = [[CAShapeLayer alloc] init];
  panelLayer.path = [textContainerPath quartzPath];
  panelLayer.fillColor = [theme.backgroundColor CGColor];
  [self.layer addSublayer:panelLayer];
  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0) {
      panelLayer.opacity = 1.0 - theme.translucency;
    }
  }
  if (theme.preeditBackgroundColor &&
      (preeditRange.length > 0 || !NSIsEmptyRect(pagingLineRect))) {
    panelLayer.fillColor = [theme.preeditBackgroundColor CGColor];
    if (![candidateBlockPath isEmpty]) {
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = [candidateBlockPath quartzPath];
      candidateLayer.fillColor = [theme.backgroundColor CGColor];
      [panelLayer addSublayer:candidateLayer];
    }
  }
  CIFilter *backColorFilter = [CIFilter filterWithName:@"CISourceATopCompositing"];
  panelLayer.compositingFilter = backColorFilter;
  if (_highlightedIndex < _candidatePaths.count && theme.highlightedStripColor) {
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
  if (pagingRange.length > 0 && buttonColor) {
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
    if (![highlightedPreeditPath isEmpty]) {
      CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
      highlightedPreeditLayer.path = [highlightedPreeditPath quartzPath];
      highlightedPreeditLayer.fillColor = [theme.highlightedPreeditColor CGColor];
      highlightedPreeditLayer.mask = textContainerLayer;
      [self.layer addSublayer:highlightedPreeditLayer];
    }
  }
  if (theme.borderColor && ![borderPath isEmpty]) {
    CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
    borderLayer.path = [borderPath quartzPath];
    borderLayer.fillColor = [theme.borderColor CGColor];
    borderLayer.fillRule = kCAFillRuleEvenOdd;
    [panelLayer addSublayer:borderLayer];
  }

  [_textView display];
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

  NSScreen *_screen;
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

- (BOOL)isFloatingPanel {
  return YES;
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

+ (NSColor *)secondaryTextColor {
  if (@available(macOS 10.10, *)) {
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
  NSFont *userFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFontOfSize:0.0].fontName)
                                           size:kDefaultFontSize];
  NSFont *userMonoFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName)
                                               size:kDefaultFontSize];
  NSFont *symbolFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0]
                                                   fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized]
                                             size:kDefaultFontSize];
  NSMutableDictionary *defaultAttrs = [[NSMutableDictionary alloc] init];

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
  preeditAttrs[NSLigatureAttributeName] = @(0);

  NSMutableDictionary *preeditHighlightedAttrs = [defaultAttrs mutableCopy];
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedTextColor];
  preeditHighlightedAttrs[NSFontAttributeName] = userFont;
  preeditHighlightedAttrs[NSLigatureAttributeName] = @(0);

  NSMutableDictionary *pagingAttrs = [defaultAttrs mutableCopy];
  pagingAttrs[NSForegroundColorAttributeName] = theme.linear ? accentColor : [NSColor controlTextColor];
  pagingAttrs[NSFontAttributeName] = symbolFont;

  NSMutableDictionary *pagingHighlightedAttrs = [defaultAttrs mutableCopy];
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = theme.linear ? [NSColor alternateSelectedControlTextColor] : [NSColor selectedMenuItemTextColor];
  pagingHighlightedAttrs[NSFontAttributeName] = symbolFont;

  NSMutableParagraphStyle *preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *pagingParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *statusParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  preeditParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
  preeditParagraphStyle.alignment = NSTextAlignmentLeft;
  paragraphStyle.alignment = NSTextAlignmentLeft;
  pagingParagraphStyle.alignment = NSTextAlignmentLeft;
  statusParagraphStyle.alignment = NSTextAlignmentLeft;

  // Use left-to-right marks to declare the default writing direction and prevent strong right-to-left
  // characters from setting the writing direction in case the label are direction-less symbols
  preeditParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  pagingParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;
  statusParagraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;

  [theme           setAttrs:attrs
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
      pagingParagraphStyle:pagingParagraphStyle
      statusParagraphStyle:statusParagraphStyle];
}

- (instancetype)init {
  self = [super initWithContentRect:_position
                          styleMask:NSWindowStyleMaskNonactivatingPanel|NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:YES];

  if (self) {
    self.alphaValue = 1.0;
    // _window.level = NSScreenSaverWindowLevel + 1;
    // ^ May fix visibility issue in fullscreen games.
    self.level = CGShieldingWindowLevel();
    self.hasShadow = NO;
    self.opaque = NO;
    self.displaysWhenScreenProfileChanges = YES;
    self.backgroundColor = [NSColor clearColor];
    NSView *contentView = [[NSView alloc] init];
    _view = [[SquirrelView alloc] initWithFrame:self.contentView.bounds];
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
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                                fromView:nil];
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
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                                fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if (_mouseDown && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index || cursorIndex == _turnPage) {
          [_inputController perform:kSELECT onIndex:cursorIndex];
        }
      }
      _mouseDown = NO;
    } break;
    case NSEventTypeRightMouseUp: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                                fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if (_mouseDown && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index && (cursorIndex >= 0 && cursorIndex < _candidates.count)) {
          [_inputController perform:kDELETE onIndex:cursorIndex];
        }
      }
      _mouseDown = NO;
    } break;
    case NSEventTypeMouseEntered: {
      self.acceptsMouseMovedEvents = YES;
    } break;
    case NSEventTypeMouseExited: {
      self.acceptsMouseMovedEvents = NO;
    } break;
    case NSEventTypeMouseMoved: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                                fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if ([_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex >= 0 && cursorIndex < _candidates.count && _index != cursorIndex) {
          [_inputController perform:kCHOOSE onIndex:cursorIndex];
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
          [_inputController perform:kSELECT onIndex:(_view.currentTheme.vertical ? NSPageDownFunctionKey : NSPageUpFunctionKey)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y > scrollThreshold) {
          [_inputController perform:kSELECT onIndex:NSPageUpFunctionKey];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [_inputController perform:kSELECT onIndex:(_view.currentTheme.vertical ? NSPageUpFunctionKey : NSPageDownFunctionKey)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y < -scrollThreshold) {
          [_inputController perform:kSELECT onIndex:NSPageDownFunctionKey];
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
  _screen = [NSScreen mainScreen];
  NSArray *screens = [NSScreen screens];
  for (NSUInteger i = 0; i < screens.count; ++i) {
    if (NSPointInRect(_position.origin, [screens[i] frame])) {
      _screen = screens[i];
      break;
    }
  }
}

- (void)getMaxTextWidth {
  SquirrelTheme *theme = _view.currentTheme;
  [self getCurrentScreen];
  NSRect screenRect = [_screen visibleFrame];
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _maxTextWidth = floor((theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio - (theme.hilitedCornerRadius + theme.edgeInset.width) * 2);
  if (theme.lineLength > 0) {
    _maxTextWidth = MIN(floor(theme.lineLength), _maxTextWidth);
  }
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
  NSTextContainer *textContainer = _view.textView.textContainer;
  CGFloat linePadding = textContainer.lineFragmentPadding;
  NSEdgeInsets insets = _view.insets;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = [_screen visibleFrame];
  CGFloat maxTextHeight = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * textWidthRatio - insets.top - insets.bottom;
  [textContainer setSize:NSMakeSize(_maxTextWidth + linePadding * 2, maxTextHeight)];

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  BOOL sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSRect contentRect = _view.contentRect;
  NSRect maxContentRect = NSInsetRect(contentRect, linePadding, 0);
  if (theme.lineLength > 0) { // fixed line length / text width
    if (_maxSize.width > 0) { // not applicable to status message where maxSize is set to 0
      maxContentRect.size.width = _maxTextWidth;
    }
  }
  if (theme.rememberSize) { // remember panel size (fix the top leading anchor of the panel in screen coordiantes)
    if ((theme.vertical ? (NSMinY(_position) - NSMinY(screenRect) <= NSHeight(screenRect) * textWidthRatio + kOffsetHeight)
         : (sweepVertical ? (NSMinX(_position) - NSMinX(screenRect) > NSWidth(screenRect) * textWidthRatio + kOffsetHeight)
            : (NSMinX(_position) + MAX(NSWidth(maxContentRect), _maxSize.width) + linePadding + insets.right > NSMaxX(screenRect)))) &&
        theme.lineLength == 0) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        maxContentRect.size.width = _maxSize.width;
        [textContainer setSize:NSMakeSize(_maxSize.width + linePadding * 2, maxTextHeight)];
      }
    }
    if (theme.vertical ? (NSMinX(_position) - NSMinX(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom + (sweepVertical ? kOffsetHeight : 0))
        : (NSMinY(_position) - NSMinY(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom + (sweepVertical ? 0 : kOffsetHeight))) {
      if (NSHeight(maxContentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(maxContentRect);
      } else {
        maxContentRect.size.height = _maxSize.height;
        [textContainer setSize:NSMakeSize(_maxTextWidth + linePadding * 2, _maxSize.height)];
      }
    }
  }

  NSRect windowRect;
  if (theme.vertical) {
    windowRect.size = NSMakeSize(NSHeight(maxContentRect) + insets.top + insets.bottom,
                                 NSWidth(maxContentRect) + linePadding * 2 + insets.left + insets.right);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMinY(_position) - NSMinY(screenRect) > NSHeight(screenRect) * textWidthRatio + kOffsetHeight) {
      windowRect.origin.y = NSMinY(_position) + (sweepVertical ? insets.left + linePadding : -kOffsetHeight) - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
    }
    // Make the right edge of candidate block fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
    if (!sweepVertical && _view.preeditRange.length > 0) {
      NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
      windowRect.origin.x += NSHeight(preeditRect) + insets.top;
    }
  } else {
    windowRect.size = NSMakeSize(NSWidth(maxContentRect) + linePadding * 2 + insets.left + insets.right,
                                 NSHeight(maxContentRect) + insets.top + insets.bottom);
    if (sweepVertical) {
      // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
      if (NSMinX(_position) - NSMinX(screenRect) > NSWidth(screenRect) * textWidthRatio + kOffsetHeight) {
        windowRect.origin.x = NSMinX(_position) - kOffsetHeight - NSWidth(windowRect);
      } else {
        windowRect.origin.x = NSMaxX(_position) + kOffsetHeight;
      }
      windowRect.origin.y = NSMinY(_position) - NSHeight(windowRect);
    } else {
      windowRect.origin = NSMakePoint(NSMinX(_position) - insets.left - linePadding,
                                      NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (sweepVertical ? NSMinX(_position) - kOffsetHeight : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = sweepVertical ? NSMaxX(_position) + kOffsetHeight : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = sweepVertical ? NSMinY(screenRect) : NSMaxY(_position) + kOffsetHeight;
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (sweepVertical ? NSMaxY(screenRect) : NSMinY(_position) - kOffsetHeight) - NSHeight(windowRect);
  }

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }

  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    [self setFrame:[_screen backingAlignedRect:windowRect options:NSAlignMaxXOutward|NSAlignMaxYInward|NSAlignWidthNearest|NSAlignHeightNearest] display:YES];
    [self.contentView setBoundsRotation:-90.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    [self setFrame:[_screen backingAlignedRect:windowRect options:NSAlignMinXInward|NSAlignMaxYInward|NSAlignWidthNearest|NSAlignHeightNearest] display:YES];
    [self.contentView setBoundsRotation:0.0];
    [self.contentView setBoundsOrigin:NSZeroPoint];
  }
  NSRect frameRect = [self.contentView backingAlignedRect:self.contentView.bounds
                                                  options:NSAlignMinXInward|NSAlignMaxYOutward|NSAlignWidthNearest|NSAlignHeightNearest];
  NSRect textFrameRect = NSMakeRect(NSMinX(frameRect) + insets.left, NSMinY(frameRect) + insets.bottom,
                                    NSWidth(frameRect) - insets.left - insets.right,
                                    NSHeight(frameRect) - insets.top - insets.bottom);
  if (@available(macOS 12.0, *)) {
    textFrameRect = NSInsetRect(textFrameRect, linePadding, 0);
  }
  [_view.textView setBoundsRotation:0.0];
  [_view setBoundsOrigin:NSZeroPoint];
  [_view.textView setBoundsOrigin:NSZeroPoint];
  [_view setFrame:frameRect];
  [_view.textView setFrame:textFrameRect];

  CGFloat translucency = theme.translucency;
  if (@available(macOS 10.14, *)) {
    if (translucency > 0) {
      [_back setFrame:frameRect];
      [_back setAppearance:NSApp.effectiveAppearance];
      [_back setHidden:NO];
    } else {
      [_back setHidden:YES];
    }
  }
  [self setAlphaValue:theme.alpha];
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

- (BOOL)shouldBreakLineWithRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromRange:range];
    NSUInteger __block lineCount = 0;
    [_view.layoutManager enumerateTextSegmentsInRange:textRange
                                                 type:NSTextLayoutManagerSegmentTypeStandard
                                              options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                           usingBlock:
     ^(NSTextRange *segmentRange, CGRect segmentFrame, CGFloat baselinePosition, NSTextContainer *textContainer) {
      ++lineCount;
      return YES;
    }];
    return lineCount > 1;
  } else {
    NSRange glyphRange = [_view.textView.layoutManager glyphRangeForCharacterRange:range
                                                              actualCharacterRange:NULL];
    NSUInteger loc = glyphRange.location;
    NSRange lineRange = NSMakeRange(loc, 0);
    NSUInteger lineCount = 0;
    while (loc < NSMaxRange(glyphRange)) {
      [_view.textView.layoutManager lineFragmentRectForGlyphAtIndex:loc
                                                     effectiveRange:&lineRange];
      ++lineCount;
      loc = NSMaxRange(lineRange);
    }
    return lineCount > 1;
  }
}

- (BOOL)shouldUseTabsInRange:(NSRange)range maxLineLength:(CGFloat *)maxLineLength{
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromRange:range];
    CGFloat __block rangeEdge;
    [_view.layoutManager enumerateTextSegmentsInRange:textRange
                                                 type:NSTextLayoutManagerSegmentTypeStandard
                                              options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                           usingBlock:
     ^(NSTextRange *segmentRange, CGRect segmentFrame, CGFloat baselinePosition, NSTextContainer *textContainer) {
      rangeEdge = NSMaxX(segmentFrame);
      return YES;
    }];
    NSRect container = [_view.layoutManager usageBoundsForTextContainer];
    *maxLineLength = MAX(MIN(_maxTextWidth, ceil(NSWidth(container))), _maxSize.width);
    return NSMinX(container) + *maxLineLength > rangeEdge;
  } else {
    NSUInteger glyphIndex = [_view.textView.layoutManager glyphIndexForCharacterAtIndex:range.location];
    CGFloat rangeEdge = NSMaxX([_view.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:NULL]);
    NSRect container = NSInsetRect([_view.textView.layoutManager usedRectForTextContainer:_view.textView.textContainer],
                                   _view.textView.textContainer.lineFragmentPadding, 0);
    *maxLineLength = MAX(MIN(_maxTextWidth, ceil(NSWidth(container))), _maxSize.width);
    return NSMinX(container) + *maxLineLength > rangeEdge;
  }
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

  if (numCandidates > 0 || (preedit && preedit.length)) {
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
  if (theme.lineLength > 0) {
    _maxSize.width = MIN(floor(theme.lineLength), _maxTextWidth);
  }
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height + theme.linespace / 2, theme.edgeInset.width,
                                         theme.edgeInset.height + theme.linespace / 2, theme.edgeInset.width);

  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];
  _view.textView.textContainer.lineFragmentPadding = theme.hilitedCornerRadius;
  NSTextStorage *text = _view.textView.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] init]];
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  // preedit
  if (preedit) {
    NSMutableAttributedString *preeditLine = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringToIndex:selRange.location]
                                               attributes:theme.preeditAttrs]];
    }
    if (selRange.length > 0) {
      NSUInteger highlightedPreeditStart = preeditLine.length;
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringWithRange:selRange]
                                               attributes:theme.preeditHighlightedAttrs]];
      highlightedPreeditRange = NSMakeRange(highlightedPreeditStart,
                                            preeditLine.length - highlightedPreeditStart);
    }
    if (NSMaxRange(selRange) < preedit.length) {
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringFromIndex:NSMaxRange(selRange)]
                                               attributes:theme.preeditAttrs]];
    }
    // force caret to be rendered horizontally in vertical layout
    if (caretPos != NSNotFound) {
      [preeditLine addAttribute:NSVerticalGlyphFormAttributeName
                          value:@NO
                          range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)), 1)];
    }
    [preeditLine addAttribute:NSParagraphStyleAttributeName
                        value:theme.preeditParagraphStyle
                        range:NSMakeRange(0, preeditLine.length)];

    preeditRange = NSMakeRange(0, preeditLine.length);
    [text appendAttributedString:preeditLine];
    if (numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.preeditAttrs]];
    } else {
      insets.bottom = theme.edgeInset.height;
    }
    insets.top = theme.edgeInset.height;
  }

  // separator
  NSMutableAttributedString *sep = [[NSMutableAttributedString alloc] initWithString:@"　" attributes:theme.attrs];
  [sep addAttribute:NSVerticalGlyphFormAttributeName
              value:@NO
              range:NSMakeRange(0, sep.length)];
  [sep fixAttributesInRange:NSMakeRange(0, sep.length)];
  CGFloat separatorWidth = theme.linear ? NSWidth([sep boundingRectWithSize:NSZeroSize options:0]) : 0.0;
  _view.separatorWidth = separatorWidth;

  // candidate items
  NSUInteger candidateBlockStart = text.length;
  NSMutableArray<NSValue *> *candidateRanges = [[NSMutableArray alloc] init];
  NSUInteger lineStart = text.length;
  NSRange separatorRange = NSMakeRange(NSNotFound, 0);
  for (NSUInteger i = 0; i < candidates.count; ++i) {
    NSMutableAttributedString *item = [[NSMutableAttributedString alloc] init];

    NSDictionary *attrs = (i == index) ? theme.highlightedAttrs : theme.attrs;
    NSDictionary *labelAttrs = (i == index) ? theme.labelHighlightedAttrs : theme.labelAttrs;
    NSDictionary *commentAttrs = (i == index) ? theme.commentHighlightedAttrs : theme.commentAttrs;
    CGFloat labelWidth = 0.0;

    if (theme.prefixLabelFormat != nil) {
      NSString *prefixLabelString;
      NSString *labelFormat = [theme.prefixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      if (labels.count > 1 && i < labels.count) {
        prefixLabelString = [NSString stringWithFormat:labelFormat, labels[i]];
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                                                      reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                                                      reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }

      [item appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:prefixLabelString
                                        attributes:labelAttrs]];
      if (!theme.linear) { // get the label size for indent
        labelWidth = NSWidth([item boundingRectWithSize:NSZeroSize options:0]);
      }
    }

    NSUInteger candidateStart = item.length;
    NSString *candidate = candidates[i];
    [item appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:candidate
                                      attributes:attrs]];
    // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
    [item addAttribute:NSWritingDirectionAttributeName
                 value:@[@0]
                 range:NSMakeRange(candidateStart, item.length - candidateStart)];

    if (i < comments.count && [comments[i] length] != 0) {
      [item appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:@" "
                                        attributes:commentAttrs]];
      NSString *comment = comments[i];
      [item appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:comment
                                        attributes:commentAttrs]];
    }

    if (theme.suffixLabelFormat != nil) {
      NSString *suffixLabelString;
      NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      if (labels.count > 1 && i < labels.count) {
        suffixLabelString = [NSString stringWithFormat:labelFormat, labels[i]];
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                                                      reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                                                      reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }
      [item appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:suffixLabelString
                                        attributes:labelAttrs]];
    }

    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    if (!theme.linear) {
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    [item addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, item.length)];
    // determine if the line is too wide and line break is needed, based on screen size.
    NSString *separatorString = theme.linear ? @"　" : @"\n";
    if (i > 0) {
      NSUInteger separatorStart = text.length;
      NSMutableAttributedString *separator = [[NSMutableAttributedString alloc]
                                              initWithString:separatorString
                                              attributes:theme.attrs];
      [separator addAttribute:NSVerticalGlyphFormAttributeName
                        value:@NO
                        range:NSMakeRange(0, separator.length)];
      separatorRange = NSMakeRange(separatorStart, separator.length);
      [text appendAttributedString:separator];
      [text appendAttributedString:item];
      if (theme.linear && [self shouldBreakLineWithRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        [text replaceCharactersInRange:separatorRange withString:@"\n"];
        lineStart = separatorStart + 1;
        separatorRange = NSMakeRange(NSNotFound, 0);
      }
    } else {
      [text appendAttributedString:item];
    }
    [candidateRanges addObject:[NSValue valueWithRange:NSMakeRange(text.length - item.length, item.length)]];
  }

  // paging indication
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);
  if (numCandidates > 0 && theme.showPaging) {
    NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] init];
    NSGlyphInfo *backFill = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4966"
                                                        forFont:theme.pagingAttrs[NSFontAttributeName]
                                                     baseString:@"◀"];
    NSGlyphInfo *backStroke = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4969"
                                                          forFont:theme.pagingAttrs[NSFontAttributeName]
                                                       baseString:@"◁"];
    NSMutableAttributedString *pageUpString = [[NSMutableAttributedString alloc]
                                               initWithString:(pageNum ? @"◀" : @"◁")
                                               attributes:(_turnPage == NSPageUpFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)];
    [pageUpString addAttribute:NSGlyphInfoAttributeName
                         value:(pageNum ? backFill : backStroke)
                         range:NSMakeRange(0, pageUpString.length)];
    [paging appendAttributedString:pageUpString];

    [paging appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:[NSString stringWithFormat:@" %lu ", pageNum + 1]
                                    attributes:theme.pagingAttrs]];

    NSGlyphInfo *forwardStroke = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4968"
                                                             forFont:theme.pagingAttrs[NSFontAttributeName]
                                                          baseString:@"▷"];
    NSGlyphInfo *forwardFill = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4967"
                                                           forFont:theme.pagingAttrs[NSFontAttributeName]
                                                        baseString:@"▶"];
    NSMutableAttributedString *pageDownString = [[NSMutableAttributedString alloc]
                                                 initWithString:(lastPage ? @"▷" : @"▶")
                                                 attributes:(_turnPage == NSPageDownFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)];
    [pageDownString addAttribute:NSGlyphInfoAttributeName
                           value:(lastPage ? forwardStroke : forwardFill)
                           range:NSMakeRange(0, pageDownString.length)];
    [paging appendAttributedString:pageDownString];

    [text appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:theme.linear ? @"　" : @"\n"
                                      attributes:theme.attrs]];
    NSUInteger pagingStart = text.length;
    CGFloat maxLineLength;
    if (theme.linear) {
      [text appendAttributedString:paging];
      if ([self shouldBreakLineWithRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        if (separatorRange.length > 0) {
          [text replaceCharactersInRange:separatorRange withString:@"\n"];
        } else {
          [text insertAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.attrs] atIndex:pagingStart-1];
          pagingStart += 1;
        }
      }
      NSMutableParagraphStyle *paragraphStylePaging = [theme.paragraphStyle mutableCopy];
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, text.length - pagingStart) maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart-1, 1) withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineLength]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(candidateBlockStart, text.length - candidateBlockStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, paging.length) maxLineLength:&maxLineLength]) {
        [paging replaceCharactersInRange:NSMakeRange(1, 1) withString:@"\t"];
        [paging replaceCharactersInRange:NSMakeRange(paging.length - 2, 1) withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSCenterTabStopType location:maxLineLength/2],
                                          [[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineLength]];
      }
      NSFont *pagingFont = theme.pagingAttrs[NSFontAttributeName];
      [paging addAttribute:NSParagraphStyleAttributeName
                     value:paragraphStylePaging
                     range:NSMakeRange(0, paging.length)];
      [text appendAttributedString:paging];
      insets.bottom = theme.edgeInset.height;
    }
    pagingRange = NSMakeRange(text.length - paging.length, paging.length);
  }

  // text done!
  [_view drawViewWithInsets:insets
            candidateRanges:candidateRanges
           highlightedIndex:index
               preeditRange:preeditRange
    highlightedPreeditRange:highlightedPreeditRange
                pagingRange:pagingRange
               pagingButton:turnPage];

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
  [self getMaxTextWidth];
  SquirrelTheme *theme = _view.currentTheme;
  _maxSize = NSZeroSize; // disable remember_size and fixed line_length for status messages
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height, theme.edgeInset.width,
                                         theme.edgeInset.height, theme.edgeInset.width);
  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];
  _view.textView.textContainer.lineFragmentPadding = theme.hilitedCornerRadius;

  NSTextStorage *text = _view.textView.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] init]];
  [text appendAttributedString:[[NSMutableAttributedString alloc] initWithString:message attributes:theme.commentAttrs]];
  [text addAttribute:NSParagraphStyleAttributeName
               value:theme.statusParagraphStyle
               range:NSMakeRange(0, text.length)];

  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  [_view drawViewWithInsets:insets
            candidateRanges:@[]
           highlightedIndex:NSNotFound
               preeditRange:NSMakeRange(NSNotFound, 0)
    highlightedPreeditRange:NSMakeRange(NSNotFound, 0)
                pagingRange:NSMakeRange(NSNotFound, 0)
               pagingButton:NSNotFound];
  [self show];
  _statusTimer = [NSTimer scheduledTimerWithTimeInterval:kShowStatusDuration
                                                  target:self
                                                selector:@selector(hideStatus:)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)hideStatus:(NSTimer *)timer {
  [self hide];
}

static inline NSColor * blendColors(NSColor *foregroundColor,
                                    NSColor *backgroundColor) {
  if (!backgroundColor) { // return foregroundColor;
    backgroundColor = [NSColor lightGrayColor];
  }
  return [[foregroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                                            ofColor:backgroundColor]
          colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static inline NSColor * inverseColor(NSColor *color) {
  if (color == nil) {
    return nil;
  } else {
    return [NSColor colorWithColorSpace:color.colorSpace
                                    hue:color.hueComponent
                             saturation:color.saturationComponent
                             brightness:1 - color.brightnessComponent
                                  alpha:color.alphaComponent];
  }
}

static NSFontDescriptor * getFontDescriptor(NSString *fullname) {
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
  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  CTFontRef systemFontRef = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 0.0, (CFStringRef)@"zh");
  NSFontDescriptor *systemFontDescriptor = CFBridgingRelease(CTFontCopyFontDescriptor(systemFontRef));
  CFRelease(systemFontRef);
  NSFontDescriptor *emojiFontDescriptor = [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
  NSArray *fallbackDescriptors = [[validFontDescriptors subarrayWithRange:NSMakeRange(1, validFontDescriptors.count - 1)]
                                  arrayByAddingObjectsFromArray:@[systemFontDescriptor, emojiFontDescriptor]];
  NSDictionary *attributes = @{NSFontCascadeListAttribute: fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static CGFloat getLineHeight(NSFont *font, BOOL vertical) {
  if (vertical) {
    font = font.verticalFont;
  }
  CGFloat lineHeight = ceil(font.ascender - font.descender);
  NSArray *fallbackList = [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor *fallback in fallbackList) {
    NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback size:font.pointSize];
    if (vertical) {
      fallbackFont = fallbackFont.verticalFont;
    }
    lineHeight = MAX(lineHeight, ceil(MIN(fallbackFont.ascender - fallbackFont.descender, NSHeight([fallbackFont boundingRectForFont]))));
  }
  return lineHeight;
}

static void updateCandidateListLayout(BOOL *isLinearCandidateList, SquirrelConfig *config, NSString *prefix) {
  NSString *candidateListLayout = [config getString:[prefix stringByAppendingString:@"/candidate_list_layout"]];
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
  NSString *textOrientation = [config getString:[prefix stringByAppendingString:@"/text_orientation"]];
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
  CGFloat fontSize = MAX([config getDouble:@"style/font_point"], 0.0);
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  CGFloat labelFontSize = MAX([config getDouble:@"style/label_font_point"], 0.0);
  NSString *commentFontName = [config getString:@"style/comment_font_face"];
  CGFloat commentFontSize = MAX([config getDouble:@"style/comment_font_point"], 0.0);
  CGFloat alpha = MIN(MAX([config getDouble:@"style/alpha"], 0.0), 1.0);
  CGFloat translucency = MIN(MAX([config getDouble:@"style/translucency"], 0.0), 1.0);
  CGFloat cornerRadius = MAX([config getDouble:@"style/corner_radius"], 0.0);
  CGFloat hilitedCornerRadius = MAX([config getDouble:@"style/hilited_corner_radius"], 0.0);
  CGFloat borderHeight = MAX([config getDouble:@"style/border_height"], 0.0);
  CGFloat borderWidth = MAX([config getDouble:@"style/border_width"], 0.0);
  CGFloat lineSpacing = MAX([config getDouble:@"style/line_spacing"], 0.0);
  CGFloat spacing = MAX([config getDouble:@"style/spacing"], 0.0);
  CGFloat baseOffset = [config getDouble:@"style/base_offset"];
  CGFloat lineLength = MAX([config getDouble:@"style/line_length"], 0.0);

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
      fontSize = MAX(fontSizeOverridden.doubleValue, 0.0);
    }
    NSString *labelFontNameOverridden = [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
    if (labelFontNameOverridden) {
      labelFontName = labelFontNameOverridden;
    }
    NSNumber *labelFontSizeOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"]];
    if (labelFontSizeOverridden) {
      labelFontSize = MAX(labelFontSizeOverridden.doubleValue, 0.0);
    }
    NSString *commentFontNameOverridden = [config getString:[prefix stringByAppendingString:@"/comment_font_face"]];
    if (commentFontNameOverridden) {
      commentFontName = commentFontNameOverridden;
    }
    NSNumber *commentFontSizeOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"]];
    if (commentFontSizeOverridden) {
      commentFontSize = MAX(commentFontSizeOverridden.doubleValue, 0.0);
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
      cornerRadius = MAX(cornerRadiusOverridden.doubleValue, 0.0);
    }
    NSNumber *hilitedCornerRadiusOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]];
    if (hilitedCornerRadiusOverridden) {
      hilitedCornerRadius = MAX(hilitedCornerRadiusOverridden.doubleValue, 0.0);
    }
    NSNumber *borderHeightOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]];
    if (borderHeightOverridden) {
      borderHeight = MAX(borderHeightOverridden.doubleValue, 0.0);
    }
    NSNumber *borderWidthOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]];
    if (borderWidthOverridden) {
      borderWidth = MAX(borderWidthOverridden.doubleValue, 0.0);
    }
    NSNumber *lineSpacingOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]];
    if (lineSpacingOverridden) {
      lineSpacing = MAX(lineSpacingOverridden.doubleValue, 0.0);
    }
    NSNumber *spacingOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]];
    if (spacingOverridden) {
      spacing = MAX(spacingOverridden.doubleValue, 0.0);
    }
    NSNumber *baseOffsetOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]];
    if (baseOffsetOverridden) {
      baseOffset = baseOffsetOverridden.doubleValue;
    }
    NSNumber *lineLengthOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_length"]];
    if (lineLengthOverridden) {
      lineLength = MAX(lineLengthOverridden.doubleValue, 0.0);
    }
  }

  fontSize = fontSize ? fontSize : kDefaultFontSize;
  labelFontSize = labelFontSize ? labelFontSize : fontSize;
  commentFontSize = commentFontSize ? commentFontSize : fontSize;

  NSFontDescriptor *fontDescriptor = getFontDescriptor(fontName);
  NSFont *font = [NSFont fontWithDescriptor:(fontDescriptor ? fontDescriptor : getFontDescriptor([NSFont userFontOfSize:0.0].fontName))
                                       size:fontSize];

  NSFontDescriptor *labelFontDescriptor = getFontDescriptor(labelFontName);
  NSFont *labelFont = labelFontDescriptor ? [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize]
    : (fontDescriptor ? [NSFont fontWithDescriptor:fontDescriptor size:labelFontSize]
       : [NSFont monospacedDigitSystemFontOfSize:labelFontSize weight:NSFontWeightRegular]);

  NSFontDescriptor *commentFontDescriptor = getFontDescriptor(commentFontName);
  NSFont *commentFont = [NSFont fontWithDescriptor:(commentFontDescriptor ? commentFontDescriptor : fontDescriptor)
                                              size:commentFontSize];

  NSFont *pagingFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0]
                                                   fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized]
                                             size:labelFontSize];

  CGFloat fontHeight = getLineHeight(font, vertical);
  CGFloat labelFontHeight = getLineHeight(labelFont, vertical);
  CGFloat commentFontHeight = getLineHeight(commentFont, vertical);
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
  pagingParagraphStyle.minimumLineHeight = ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.maximumLineHeight = ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.paragraphSpacingBefore = pagingFont.leading;

  NSMutableParagraphStyle *statusParagraphStyle = [theme.statusParagraphStyle mutableCopy];
  statusParagraphStyle.minimumLineHeight = commentFontHeight;
  statusParagraphStyle.maximumLineHeight = commentFontHeight;

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
  pagingAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);
  pagingHighlightedAttrs[NSBaselineOffsetAttributeName] = @(baseOffset);

  NSColor *secondaryTextColor = [[self class] secondaryTextColor];
  NSColor *accentColor = [[self class] accentColor];

  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0 &&
        ((backgroundColor.brightnessComponent >= 0.5 && isDark) ||
         (backgroundColor.brightnessComponent < 0.5 && !isDark))) {
      backgroundColor = inverseColor(backgroundColor);
      borderColor = inverseColor(borderColor);
      preeditBackgroundColor = inverseColor(preeditBackgroundColor);
      candidateTextColor = inverseColor(candidateTextColor);
      highlightedCandidateTextColor = [inverseColor(highlightedCandidateTextColor) highlightWithLevel:highlightedCandidateTextColor.brightnessComponent];
      highlightedCandidateBackColor = [inverseColor(highlightedCandidateBackColor) shadowWithLevel:1 - highlightedCandidateBackColor.brightnessComponent];
      candidateLabelColor = inverseColor(candidateLabelColor);
      highlightedCandidateLabelColor = [inverseColor(highlightedCandidateLabelColor) highlightWithLevel:highlightedCandidateLabelColor.brightnessComponent];
      commentTextColor = inverseColor(commentTextColor);
      highlightedCommentTextColor = [inverseColor(highlightedCommentTextColor) highlightWithLevel:highlightedCommentTextColor.brightnessComponent];
      textColor = inverseColor(textColor);
      highlightedTextColor = [inverseColor(highlightedTextColor) highlightWithLevel:highlightedTextColor.brightnessComponent];
      highlightedBackColor = [inverseColor(highlightedBackColor) shadowWithLevel:1 - highlightedBackColor.brightnessComponent];
    }
  }

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

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  pagingHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  [theme setStatusMessageType:statusMessageType];

  [theme           setAttrs:attrs
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
      pagingParagraphStyle:pagingParagraphStyle
      statusParagraphStyle:statusParagraphStyle];

  [theme setBackgroundColor:backgroundColor
            backgroundImage:backgroundImage
      highlightedStripColor:highlightedCandidateBackColor
    highlightedPreeditColor:highlightedBackColor
     preeditBackgroundColor:preeditBackgroundColor
                borderColor:borderColor];

  NSSize edgeInset = vertical ? NSMakeSize(borderHeight, borderWidth) : NSMakeSize(borderWidth, borderHeight);

  [theme setCornerRadius:MIN(cornerRadius, lineHeight/2)
     hilitedCornerRadius:MIN(hilitedCornerRadius, lineHeight/3)
               edgeInset:edgeInset
               linespace:lineSpacing
        preeditLinespace:spacing
                   alpha:(alpha == 0 ? 1.0 : alpha)
            translucency:translucency
              lineLength:lineLength
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
