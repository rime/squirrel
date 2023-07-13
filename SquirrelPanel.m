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
      pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle
      statusParagraphStyle:(NSParagraphStyle *)statusParagraphStyle{
  _paragraphStyle = paragraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
  _pagingParagraphStyle = pagingParagraphStyle;
  _statusParagraphStyle = statusParagraphStyle;
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
@property(nonatomic, readonly) NSTextLayoutManager *layoutManager API_AVAILABLE(macos(12.0));
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, assign) CGFloat seperatorWidth;
@property(nonatomic, readonly) CAShapeLayer *shape;
@property(nonatomic, getter=isFlipped, readonly) BOOL flipped;
@property(nonatomic, readonly) BOOL wantsUpdateLayer;

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
    self.layer.masksToBounds = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    self.layerContentsPlacement = NSViewLayerContentsPlacementBottomLeft;
  }

  if (@available(macOS 12.0, *)) {
    _layoutManager = [[NSTextLayoutManager alloc] init];
    _layoutManager.usesFontLeading = NO;
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    _layoutManager.textContainer = textContainer;
    NSTextContentStorage *textStorage = [[NSTextContentStorage alloc] init];
    [textStorage addTextLayoutManager:_layoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect textContainer:_layoutManager.textContainer];
    _textView.drawsBackground = NO;
    _textView.editable = NO;
    _textView.selectable = NO;
    _textView.wantsLayer = NO;
  } else {
    _textView = [[NSTextView alloc] initWithFrame:frameRect];
    _textView.drawsBackground = NO;
    _textView.editable = NO;
    _textView.selectable = NO;
    _textView.wantsLayer = NO;
    _textView.layoutManager.backgroundLayoutEnabled = YES;
    _textView.layoutManager.usesFontLeading = NO;
    _textView.layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    [_textView replaceTextContainer:textContainer];
  }
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
    NSTextContentManager *contentManager = self.layoutManager.textContentManager;
    id<NSTextLocation> startLocation = [contentManager locationFromLocation:contentManager.documentRange.location withOffset:range.location];
    id<NSTextLocation> endLocation = [contentManager locationFromLocation:startLocation withOffset:range.length];
    return [[NSTextRange alloc] initWithLocation:startLocation endLocation:endLocation];
  }
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
  CGFloat refFontHeight = refFont.ascender - refFont.descender;
  CGFloat refBaseline = refFont.ascender;
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
    CGFloat alignment = verticalLayout ? lineHeight/2 : refBaseline + MAX(0.0, lineHeight - refFontHeight)/2;
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
    blockRect = NSUnionRect(blockRect, rect);
    usedRect = NSIntersectionRect(usedRect, rect);
    rect = [self.textView backingAlignedRect:rect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    usedRect = [self.textView backingAlignedRect:usedRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    [layoutManager setLineFragmentRect:rect forGlyphRange:lineRange usedRect:usedRect];

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
      CGFloat runBaseline = runFont.ascender;
      CGFloat runFontHeight = runFont.ascender - runFont.descender;
      CGFloat resizedRefFontHeight = resizedRefFont.ascender - resizedRefFont.descender;
      if (verticalLayout) {
        runGlyphPosition.y = alignment - baselineOffset + MAX(0.0, runFontHeight - resizedRefFontHeight)/2;
        if (runFont.isVertical) {
          runGlyphPosition.x += MAX(0.0, runFontHeight - resizedRefFontHeight)/2;
        } else {
          runGlyphPosition.y += runBaseline - runFontHeight/2;
        }
      } else {
        runGlyphPosition.y = alignment - baselineOffset;
      }
      NSRect lineDrawnRect = [self.textView backingAlignedRect:NSMakeRect(rect.origin.x, rect.origin.y, runGlyphPosition.x, runGlyphPosition.y) options:(NSAlignAllEdgesInward|NSAlignRectFlipped)];
      [layoutManager setLocation:NSMakePoint(NSWidth(lineDrawnRect), NSHeight(lineDrawnRect)) forStartOfGlyphRange:runRange];
      j = NSMaxRange(runRange);
    }
    i = NSMaxRange(lineRange);
  }
  return blockRect;
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  NSRect contentRect;
  if (@available(macOS 12.0, *)) {
    [self.layoutManager ensureLayoutForRange:self.layoutManager.textContentManager.documentRange];
    contentRect = [self.layoutManager usageBoundsForTextContainer];
  } else {
    [self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
    contentRect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
  }
  if (_candidateRanges.count > 0) {
    if (_preeditRange.length == 0) {
      contentRect.origin.y -= self.currentTheme.linespace/2;
      contentRect.size.height += self.currentTheme.linespace/2;
    }
    if (self.currentTheme.linear || _pagingRange.length == 0) {
      contentRect.size.height += self.currentTheme.linespace/2;
    }
  }
  return contentRect;
}

// Get the rectangle containing the range of text, will first convert to glyph or text range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromRange:range];
    __block NSRect contentRect = NSZeroRect;
    [self.layoutManager enumerateTextSegmentsInRange:textRange type:NSTextLayoutManagerSegmentTypeStandard options:NSTextLayoutManagerSegmentOptionsRangeNotRequired usingBlock:^(NSTextRange *segmentRange, CGRect segmentRect, CGFloat baseline, NSTextContainer *textContainer) {
      contentRect = NSUnionRect(contentRect, segmentRect);
      return YES;
    }];
    return contentRect;
  } else {
    NSRange glyphRange = [self.textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
    NSRect rect = [self.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:self.textView.textContainer];
    NSRect firstLineRect = [self.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location effectiveRange:NULL];
    NSRect finalLineRect = [self.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:NULL];
    NSRect contentRect = NSMakeRect(NSMinX(rect), NSMinY(firstLineRect), NSWidth(rect), NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    return contentRect;
  }
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
  NSPoint previousPoint = vertex[vertex.count-1].pointValue;
  NSPoint point = vertex[0].pointValue;
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
    previousPoint = vertex[(vertex.count+i-1)%vertex.count].pointValue;
    point = vertex[i].pointValue;
    nextPoint = vertex[(i+1)%vertex.count].pointValue;
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

BOOL nearEmptyRect(NSRect rect) {
  return rect.size.height * rect.size.width < 1;
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is the complete line fragment in the middle if the range spans no less than one full line
- (void)multilineRectForRange:(NSRange)charRange leadingRect:(NSRect *)leadingRect bodyRect:(NSRect *)bodyRect trailingRect:(NSRect *)trailingRect {
  NSSize edgeInset = self.currentTheme.edgeInset;
  *leadingRect = NSZeroRect;
  *bodyRect = NSZeroRect;
  *trailingRect = NSZeroRect;
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromRange:charRange];
    NSMutableArray<NSValue *> *lineRects = [[NSMutableArray alloc] init];
    [self.layoutManager enumerateTextSegmentsInRange:textRange type:NSTextLayoutManagerSegmentTypeStandard options:NSTextLayoutManagerSegmentOptionsRangeNotRequired usingBlock:^(NSTextRange *segmentRange, CGRect segmentRect, CGFloat baseline, NSTextContainer *textContainer) {
      if (!nearEmptyRect(segmentRect)) {
        [lineRects addObject:[NSValue valueWithRect:NSOffsetRect(segmentRect, edgeInset.width, edgeInset.height)]];
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
          *bodyRect = NSUnionRect(firstLineRect, lineRects[lineRects.count-2].rectValue);
        } else {
          *leadingRect = firstLineRect;
          if (lineRects.count > 2) {
            *bodyRect = NSUnionRect(lineRects[1].rectValue, lineRects[lineRects.count-2].rectValue);
          }
        }
      }
    }
  } else {
    NSLayoutManager *layoutManager = self.textView.layoutManager;
    NSTextContainer *textContainer = self.textView.textContainer;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    CGFloat startX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
    CGFloat endX = NSMaxX([layoutManager boundingRectForGlyphRange:NSMakeRange(NSMaxRange(glyphRange)-1, 1) inTextContainer:textContainer]);
    NSRect boundingRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
    NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect leadingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location effectiveRange:&leadingLineRange withoutAdditionalLayout:YES];
    if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
      *bodyRect = NSMakeRect(NSMinX(leadingLineRect) + startX + edgeInset.width,
                             NSMinY(leadingLineRect) + edgeInset.height,
                             endX - startX, NSHeight(leadingLineRect));
    } else {
      CGFloat rightEdge = MAX(NSMaxX(leadingLineRect) - self.currentTheme.hilitedCornerRadius, NSMaxX(boundingRect));
      NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
      NSRect trailingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange)-1 effectiveRange:&trailingLineRange withoutAdditionalLayout:YES];
      CGFloat leftEdge = MIN(NSMinX(trailingLineRect) + self.currentTheme.hilitedCornerRadius, NSMinX(boundingRect));
      if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(leadingLineRect) + edgeInset.height,
                                 rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startX + edgeInset.width,
                                    NSMinY(leadingLineRect) + edgeInset.height,
                                    rightEdge - NSMinX(leadingLineRect) - startX, NSHeight(leadingLineRect));
          *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMaxY(leadingLineRect) + edgeInset.height,
                                 rightEdge - leftEdge, NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(trailingLineRect) + edgeInset.height,
                                   NSMinX(trailingLineRect) + endX - leftEdge, NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMinY(leadingLineRect) + edgeInset.height,
                                 rightEdge - leftEdge, NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(NSMinX(leadingLineRect) + startX + edgeInset.width,
                                    NSMinY(leadingLineRect) + edgeInset.height,
                                    rightEdge - NSMinX(leadingLineRect) - startX, NSHeight(leadingLineRect));
          NSRange bodyLineRange = NSMakeRange(NSMaxRange(leadingLineRange), trailingLineRange.location-NSMaxRange(leadingLineRange));
          if (bodyLineRange.length > 0) {
            *bodyRect = NSMakeRect(leftEdge + edgeInset.width, NSMaxY(leadingLineRect) + edgeInset.height,
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
  NSPoint lineOrigin = NSZeroPoint;

  NSRect backgroundRect = self.bounds;
  NSRect textContainerRect = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);
  NSRect preeditRect = NSZeroRect;
  NSRect candidateBlockRect = NSZeroRect;
  NSRect pagingLineRect = NSZeroRect;

  if (@available(macOS 12.0, *)) {
    if (_preeditRange.length > 0) {
      preeditRect = [self contentRectForRange:_preeditRange];
      preeditRect.size.height += theme.preeditLinespace;
      preeditRect.origin = lineOrigin;
      lineOrigin.y = NSMaxY(preeditRect);
    }
    if (_candidateRanges.count > 0) {
      NSRange candidateBlockRange = NSUnionRange(_candidateRanges.firstObject.rangeValue, theme.linear && _pagingRange.length > 0 ? _pagingRange : _candidateRanges.lastObject.rangeValue);
      candidateBlockRect = NSInsetRect([self contentRectForRange:candidateBlockRange], 0.0, -theme.linespace/2);
      candidateBlockRect.origin = lineOrigin;
      lineOrigin.y = NSMaxY(candidateBlockRect);
    }
    if (!theme.linear && _pagingRange.length > 0) {
      pagingLineRect = [self contentRectForRange:_pagingRange];
      pagingLineRect.origin = lineOrigin;
      lineOrigin.y = NSMaxY(pagingLineRect);
    }
  } else {
    // perform typesetting to get vertically centered layout and get the block rect
    if (_preeditRange.length > 0) {
      NSFont *preeditRefFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, [theme.preeditAttrs[NSFontAttributeName] pointSize], (CFStringRef) @"zh"));
      preeditRect = [self setLineRectForRange:_preeditRange atOrigin:lineOrigin withReferenceFont:(theme.vertical ? preeditRefFont.verticalFont : preeditRefFont) paragraphStyle:theme.preeditParagraphStyle];
      lineOrigin.y = NSMaxY(preeditRect);
    }
    if (_candidateRanges.count > 0) {
      CGFloat fontSize = MAX([theme.attrs[NSFontAttributeName] pointSize], MAX([theme.commentAttrs[NSFontAttributeName] pointSize], [theme.labelAttrs[NSFontAttributeName] pointSize]));
      NSFont *refFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, fontSize, (CFStringRef) @"zh"));
      NSRange candidateBlockRange = NSUnionRange(_candidateRanges.firstObject.rangeValue, theme.linear && _pagingRange.length > 0 ? _pagingRange : _candidateRanges.lastObject.rangeValue);
      candidateBlockRect = [self setLineRectForRange:candidateBlockRange atOrigin:lineOrigin withReferenceFont:(theme.vertical ? refFont.verticalFont : refFont) paragraphStyle:theme.paragraphStyle];
      lineOrigin.y = NSMaxY(candidateBlockRect);
    } else if (_preeditRange.length == 0) { // status message
      NSFont *statusRefFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, [theme.commentAttrs[NSFontAttributeName] pointSize], (CFStringRef) @"zh"));
      candidateBlockRect = [self setLineRectForRange:NSMakeRange(0, self.textView.textStorage.length) atOrigin:lineOrigin withReferenceFont:(theme.vertical ? statusRefFont.verticalFont : statusRefFont) paragraphStyle:theme.statusParagraphStyle];
      lineOrigin.y = NSMaxY(candidateBlockRect);
    }
    if (!theme.linear && _pagingRange.length > 0) {
      pagingLineRect = [self setLineRectForRange:_pagingRange atOrigin:lineOrigin withReferenceFont:theme.pagingAttrs[NSFontAttributeName] paragraphStyle:theme.pagingParagraphStyle];
      lineOrigin.y = NSMaxY(pagingLineRect);
    }
  }
  if (_candidateRanges.count > 0) {
    if (_preeditRange.length == 0) {
      candidateBlockRect.origin.y -= theme.linespace/2;
      candidateBlockRect.size.height += theme.linespace/2;
    }
    if (theme.linear || _pagingRange.length == 0) {
      candidateBlockRect.size.height += theme.linespace/2;
    }
  }

  [NSBezierPath setDefaultLineWidth:0];
  // Draw preedit Rect
  if (_preeditRange.length > 0) {
    preeditRect.size.width = textContainerRect.size.width;
    preeditRect.origin = textContainerRect.origin;
  }

  // Draw candidate Rect
  if (_candidateRanges.count > 0) {
    candidateBlockRect.size.width = textContainerRect.size.width;
    candidateBlockRect.origin.x = textContainerRect.origin.x;
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
        if (@available(macOS 12.0, *)) {
          if (_preeditRange.length == 0) {
            leadingRect.origin.y += theme.linespace/2;
            bodyRect.origin.y += theme.linespace/2;
            trailingRect.origin.y += theme.linespace/2;
          }
        }
        if (!NSIsEmptyRect(leadingRect)) {
          leadingRect.origin.y -= theme.linespace/2;
          leadingRect.size.height += theme.linespace/2;
          leadingRect = [self backingAlignedRect:leadingRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
        }
        if (!NSIsEmptyRect(trailingRect)) {
          trailingRect.size.height += theme.linespace/2;
          trailingRect = [self backingAlignedRect:trailingRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
        }
        if (!NSIsEmptyRect(bodyRect)) {
          if (NSIsEmptyRect(leadingRect)) {
            bodyRect.origin.y -= theme.linespace/2;
            bodyRect.size.height += theme.linespace/2;
          }
          if (NSIsEmptyRect(trailingRect)) {
            bodyRect.size.height += theme.linespace/2;
          }
          bodyRect = [self backingAlignedRect:bodyRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
        }
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
        NSRect candidateRect = NSInsetRect([self contentRectForRange:candidateRange], 0.0, -theme.linespace/2);
        candidateRect.size.width = textContainerRect.size.width;
        candidateRect.origin.x = textContainerRect.origin.x;
        candidateRect.origin.y += theme.edgeInset.height;
        if (@available(macOS 12.0, *)) {
          if (_preeditRange.length == 0) {
            candidateRect = NSOffsetRect(candidateRect, 0.0, theme.linespace/2);
          }
        }
        candidateRect = [self backingAlignedRect:candidateRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
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
    leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(leadingRect, innerBox) options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(bodyRect, innerBox) options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(trailingRect, innerBox) options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
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
    NSRect pageDownRect = NSOffsetRect([self contentRectForRange:NSMakeRange(NSMaxRange(_pagingRange)-1, 1)], theme.edgeInset.width, theme.edgeInset.height);
    pageDownRect.size.width += buttonPadding;
    NSRect pageUpRect = NSOffsetRect([self contentRectForRange:NSMakeRange(_pagingRange.location, 1)], theme.edgeInset.width, theme.edgeInset.height);
    pageUpRect.origin.x -= buttonPadding;
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    if (theme.linear) {
      pageDownRect = NSInsetRect(pageDownRect, 0.0, -theme.linespace/2);
      pageUpRect = NSInsetRect(pageUpRect, 0.0, -theme.linespace/2);
    }
    if (@available(macOS 12.0, *)) {
      if (_preeditRange.length == 0) {
        pageDownRect = NSOffsetRect(pageDownRect, 0.0, theme.linespace/2);
        pageUpRect = NSOffsetRect(pageUpRect, 0.0, theme.linespace/2);
      }
    }
    pageDownRect = [self backingAlignedRect:pageDownRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    pageUpRect = [self backingAlignedRect:pageUpRect options:(NSAlignAllEdgesOutward|NSAlignRectFlipped)];
    pageDownPath = drawSmoothLines(rectVertex(pageDownRect), 0.06*NSHeight(pageDownRect), 0.28*NSWidth(pageDownRect));
    pageUpPath = drawSmoothLines(rectVertex(pageUpRect), 0.06*NSHeight(pageUpRect), 0.28*NSWidth(pageUpRect));
    _pagingPaths[0] = pageUpPath;
    _pagingPaths[1] = pageDownPath;
  }

  // Draw borders
  backgroundPath = drawSmoothLines(rectVertex(backgroundRect), 0.3*theme.cornerRadius, 1.4*theme.cornerRadius);
  textContainerPath = drawSmoothLines(rectVertex(textContainerRect), 0.3*theme.hilitedCornerRadius, 1.4*theme.hilitedCornerRadius);
  if (theme.edgeInset.width > 0 || theme.edgeInset.height > 0) {
    borderPath = [backgroundPath copy];
    [borderPath appendBezierPath:textContainerPath];
    borderPath.windingRule = NSEvenOddWindingRule;
  }

  // set layers
  _shape.path = [backgroundPath quartzPath];
  _shape.fillColor = [[NSColor whiteColor] CGColor];
  _shape.cornerRadius = theme.cornerRadius;
  CAShapeLayer *textContainerLayer = [[CAShapeLayer alloc] init];
  textContainerLayer.path = [textContainerPath quartzPath];
  textContainerLayer.fillColor = [[NSColor whiteColor] CGColor];
  textContainerLayer.cornerRadius = theme.hilitedCornerRadius;
  [self.layer setSublayers:NULL];
  self.layer.cornerRadius = theme.cornerRadius;
  if (theme.backgroundImage) {
    CAShapeLayer *backgroundLayer = [[CAShapeLayer alloc] init];
    backgroundLayer.path = [backgroundPath quartzPath];
    backgroundLayer.fillColor = [theme.backgroundImage CGColor];
    backgroundLayer.cornerRadius = theme.cornerRadius;
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
      (_preeditRange.length > 0 || !NSIsEmptyRect(pagingLineRect))) {
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
  if (theme.borderColor && ![borderPath isEmpty]) {
    CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
    borderLayer.path = [borderPath quartzPath];
    borderLayer.fillColor = [theme.borderColor CGColor];
    borderLayer.fillRule = kCAFillRuleEvenOdd;
    [panelLayer addSublayer:borderLayer];
  }
  [self.textView setTextContainerInset:theme.edgeInset];
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
  NSFont *userFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFontOfSize:0.0].fontName) size:kDefaultFontSize];
  NSFont *userMonoFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName) size:kDefaultFontSize];
  NSFont *symbolFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0] fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized] size:kDefaultFontSize];
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
  pagingHighlightedAttrs[NSForegroundColorAttributeName] =  theme.linear ? [NSColor alternateSelectedControlTextColor] : [NSColor selectedMenuItemTextColor];
  pagingHighlightedAttrs[NSFontAttributeName] = symbolFont;

  NSMutableParagraphStyle *preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *pagingParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  NSMutableParagraphStyle *statusParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  preeditParagraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
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
      pagingParagraphStyle:pagingParagraphStyle
      statusParagraphStyle:statusParagraphStyle];
}

- (instancetype)init {
  self = [super initWithContentRect:_position
                          styleMask:(NSWindowStyleMaskNonactivatingPanel|NSWindowStyleMaskBorderless)
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    self.alphaValue = 1.0;
    // _window.level = NSScreenSaverWindowLevel + 1;
    // ^ May fix visibility issue in fullscreen games.
    self.level = CGShieldingWindowLevel();
    self.hasShadow = YES;
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

- (BOOL)isOpaque {
  return NO;
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
        }
      }
      _mouseDown = NO;
    } break;
    case NSEventTypeRightMouseUp: {
      NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream fromView:nil];
      NSUInteger cursorIndex = NSNotFound;
      if (_mouseDown && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index && (cursorIndex >= 0 && cursorIndex < _candidates.count)) {
          [self.inputController perform:kDELETE onIndex:cursorIndex];
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
  _maxTextWidth = (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio - (theme.hilitedCornerRadius + theme.edgeInset.width) * 2;
  if (theme.lineLength > 0) {
    _maxTextWidth = MIN(theme.lineLength, _maxTextWidth);
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
  NSTextContainer *textContainer;
  if (@available(macOS 12.0, *)) {
    textContainer = _view.layoutManager.textContainer;
  } else {
    textContainer = _view.textView.textContainer;
  }
  [textContainer setLineFragmentPadding:theme.hilitedCornerRadius];
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = [_screen visibleFrame];
  CGFloat maxTextHeight = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * textWidthRatio - theme.edgeInset.height * 2;
  [textContainer setSize:NSMakeSize(_maxTextWidth + theme.hilitedCornerRadius * 2, maxTextHeight)];

  BOOL sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSRect contentRect = _view.contentRect;
  NSRect maxContentRect = NSInsetRect(contentRect, theme.hilitedCornerRadius, 0);
  if (theme.lineLength > 0) { // fixed line length / text width
    if (_maxSize.width > 0) { // only applicable to non-status
      maxContentRect.size.width = _maxTextWidth;
    }
  }
  if (theme.rememberSize) { // remember panel size (fix the top leading anchor of the panel in screen coordiantes)
    if ((theme.vertical ? (NSMinY(_position) - NSMinY(screenRect) <= NSHeight(screenRect) * textWidthRatio + kOffsetHeight) :
         (sweepVertical ? (NSMinX(_position) - NSMinX(screenRect) >  NSWidth(screenRect) * textWidthRatio + kOffsetHeight) :
          (NSMinX(_position) + MAX(NSWidth(maxContentRect), _maxSize.width) + theme.hilitedCornerRadius + theme.edgeInset.width > NSMaxX(screenRect)))) &&
        theme.lineLength == 0) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        maxContentRect.size.width = _maxSize.width;
        [textContainer setSize:NSMakeSize(_maxSize.width + theme.hilitedCornerRadius * 2, maxTextHeight)];
      }
    }
    if (theme.vertical ? (NSMinX(_position) - NSMinX(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + theme.edgeInset.height * 2 + (sweepVertical ? kOffsetHeight : 0)) :
        (NSMinY(_position) - NSMinY(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + theme.edgeInset.height * 2 + (sweepVertical ? 0 : kOffsetHeight))) {
      if (NSHeight(maxContentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(maxContentRect);
      } else {
        maxContentRect.size.height = _maxSize.height;
        [textContainer setSize:NSMakeSize(_maxTextWidth + theme.hilitedCornerRadius * 2, _maxSize.height)];
      }
    }
  }

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  NSRect windowRect;
  if (theme.vertical) {
    windowRect.size = NSMakeSize(NSHeight(maxContentRect) + theme.edgeInset.height * 2,
                                 NSWidth(maxContentRect) + (theme.edgeInset.width + theme.hilitedCornerRadius) * 2);
    // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
    if (NSMinY(_position) - NSMinY(screenRect) > NSHeight(screenRect) * textWidthRatio + kOffsetHeight) {
      windowRect.origin.y = NSMinY(_position) + (sweepVertical ? theme.edgeInset.width+theme.hilitedCornerRadius : -kOffsetHeight) - NSHeight(windowRect);
    } else {
      windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
    }
    // Make the right edge of candidate block fixed at the left of cursor
    windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
    if (!sweepVertical && _view.preeditRange.length > 0) {
      NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
      windowRect.origin.x += NSHeight(preeditRect) + theme.edgeInset.height;
    }
  } else {
    windowRect.size = NSMakeSize(NSWidth(maxContentRect) + (theme.edgeInset.width + theme.hilitedCornerRadius) * 2,
                                 NSHeight(maxContentRect) + theme.edgeInset.height * 2);
    if (sweepVertical) {
      // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
      if (NSMinX(_position) - NSMinX(screenRect) > NSWidth(screenRect) * textWidthRatio + kOffsetHeight) {
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

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (sweepVertical ? NSMinX(_position)-kOffsetHeight : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = sweepVertical ? NSMaxX(_position)+kOffsetHeight : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = sweepVertical ? NSMinY(screenRect) : NSMaxY(_position)+kOffsetHeight;
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (sweepVertical ? NSMaxY(screenRect) : NSMinY(_position)-kOffsetHeight) - NSHeight(windowRect);
  }

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }
  [self setFrame:[_screen backingAlignedRect:windowRect
                                     options:NSAlignAllEdgesOutward] display:YES];
  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    [self.contentView setBoundsRotation:-90.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    [self.contentView setBoundsRotation:0.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, 0.0)];
  }
  [_view.textView setBoundsRotation:0.0];
  if (@available(macOS 12.0, *)) {
    NSPoint textViewOrigin = _view.layoutManager.usageBoundsForTextContainer.origin;
    if (_view.candidateRanges.count > 0 && _view.preeditRange.length == 0) {
      textViewOrigin.y += theme.linespace / 2;
    }
    [_view.textView setBoundsOrigin:textViewOrigin];
  } else {
    [_view.textView setBoundsOrigin:_view.textView.textContainerOrigin];
  }
  NSRect boundsRect = [self backingAlignedRect:self.contentView.bounds
                                       options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
  [_view setFrame:boundsRect];
  [_view.textView setFrame:boundsRect];

  CGFloat translucency = theme.translucency;
  if (@available(macOS 10.14, *)) {
    if (translucency > 0) {
      [_back setFrame:boundsRect];
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

static CGFloat stringWidth(NSAttributedString *string, BOOL vertical){
  NSTextStorage *textStorage = [[NSTextStorage alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [textContainer setLineFragmentPadding:0.0];
  NSTextView *textView = textContainer.textView;
  [textView setLayoutOrientation:vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];
  [textStorage setAttributedString:string];
  [layoutManager ensureLayoutForTextContainer:textContainer];
  return NSWidth([layoutManager usedRectForTextContainer:textContainer]);
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
    _maxSize.width = MIN(theme.lineLength, _maxTextWidth);
  }

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
      highlightedPreeditRange = NSMakeRange(text.length + highlightedPreeditStart,
                                            preeditLine.length - highlightedPreeditStart);
    }
    if (NSMaxRange(selRange) < preedit.length) {
      [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:[preedit substringFromIndex:NSMaxRange(selRange)].precomposedStringWithCanonicalMapping
                                           attributes:theme.preeditAttrs]];
    }
    // force caret to be rendered horizontally in vertical layout
    if (caretPos != NSNotFound) {
      [preeditLine addAttribute:NSVerticalGlyphFormAttributeName
                          value:@NO
                          range:NSMakeRange(caretPos, 1)];
    }
    [preeditLine addAttribute:NSParagraphStyleAttributeName
                        value:theme.preeditParagraphStyle
                        range:NSMakeRange(0, preeditLine.length)];

    preeditRange = NSMakeRange(text.length, preeditLine.length);
    [text appendAttributedString:preeditLine];
    preeditWidth = stringWidth(preeditLine, theme.vertical);
    if (numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.preeditAttrs]];
    }
  }

  // prepare paging and separator for width calculation but no insertion yet
  NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] init];
  NSGlyphInfo *backFilled = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4966"
                                                        forFont:theme.pagingAttrs[NSFontAttributeName]
                                                     baseString:@"◀"];
  NSGlyphInfo *backOutline = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4969"
                                                         forFont:theme.pagingAttrs[NSFontAttributeName]
                                                      baseString:@"◁"];
  NSMutableAttributedString *pageUpString = [[NSMutableAttributedString alloc]
                                             initWithString:(pageNum ? @"◀" : @"◁")
                                             attributes:(_turnPage == NSPageUpFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)];
  [pageUpString addAttribute:NSGlyphInfoAttributeName
                       value:(pageNum ? backFilled : backOutline)
                       range:NSMakeRange(0, pageUpString.length)];
  [paging appendAttributedString:pageUpString];

  [paging appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:[NSString stringWithFormat:@" %lu ", pageNum+1]
                                  attributes:theme.pagingAttrs]];

  NSGlyphInfo *forwardOutline = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4968"
                                                            forFont:theme.pagingAttrs[NSFontAttributeName] baseString:@"▷"];
  NSGlyphInfo *forwardFilled = [NSGlyphInfo glyphInfoWithGlyphName:@"gid4967"
                                                           forFont:theme.pagingAttrs[NSFontAttributeName] baseString:@"▶"];
  NSMutableAttributedString *pageDownString = [[NSMutableAttributedString alloc]
                                               initWithString:(lastPage ? @"▷" : @"▶")
                                               attributes:(_turnPage == NSPageDownFunctionKey ? theme.pagingHighlightedAttrs : theme.pagingAttrs)];
  [pageDownString addAttribute:NSGlyphInfoAttributeName
                         value:(lastPage ? forwardOutline : forwardFilled)
                         range:NSMakeRange(0, pageDownString.length)];
  [paging appendAttributedString:pageDownString];
  CGFloat pagingWidth = theme.showPaging ? stringWidth(paging, theme.vertical) : 0.0;

  NSMutableAttributedString *sep = [[NSMutableAttributedString alloc] initWithString:@"  " attributes:theme.attrs];
  [sep addAttribute:NSVerticalGlyphFormAttributeName
              value:@NO
              range:NSMakeRange(0, sep.length)];
  CGFloat separatorWidth = theme.linear ? stringWidth(sep, theme.vertical) : 0.0;
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
        prefixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        prefixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }

      [line appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:prefixLabelString
                                    attributes:labelAttrs]];
      if (!theme.linear) { // get the label size for indent
        labelWidth = stringWidth(line, theme.vertical);
      }
    }

    NSUInteger candidateStart = line.length;
    NSString *candidate = candidates[i];
    [line appendAttributedString:[[NSAttributedString alloc] initWithString:candidate.precomposedStringWithCanonicalMapping
                                                                 attributes:attrs]];
    // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
    [line addAttribute:NSWritingDirectionAttributeName
                 value:@[@0]
                 range:NSMakeRange(candidateStart, line.length-candidateStart)];

    if (i < comments.count && [comments[i] length] != 0) {
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:@" "
                                                                   attributes:commentAttrs]];
      NSString *comment = comments[i];
      [line appendAttributedString:[[NSAttributedString alloc] initWithString:comment.precomposedStringWithCanonicalMapping
                                                                   attributes:commentAttrs]];
    }

    if (theme.suffixLabelFormat != nil) {
      NSString *suffixLabelString;
      NSString *labelFormat = [theme.suffixLabelFormat stringByReplacingOccurrencesOfString:@"%c" withString:@"%@"];
      if (labels.count > 1 && i < labels.count) {
        suffixLabelString = [NSString stringWithFormat:labelFormat, labels[i]].precomposedStringWithCanonicalMapping;
      } else if (labels.count == 1 && i < [labels[0] length]) {
        // custom: A. B. C...
        NSString *labelCharacter = [[labels[0] substringWithRange:NSMakeRange(i, 1)]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      } else {
        // default: 1. 2. 3...
        NSString *labelCharacter = [[NSString stringWithFormat:@"%lu", (i + 1) % 10]
                                    stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
        suffixLabelString = [NSString stringWithFormat:labelFormat, labelCharacter];
      }
      [line appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:suffixLabelString
                                    attributes:labelAttrs]];
    }

    NSMutableParagraphStyle *paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
    // determine if the line is too wide and line break is needed, based on screen size.
    NSString *separtatorString = @"\n";
    CGFloat candidateWidth = stringWidth(line, theme.vertical);

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
    NSMutableAttributedString *separator = [[NSMutableAttributedString alloc]
                                            initWithString:separtatorString
                                            attributes:theme.attrs];
    [separator addAttribute:NSVerticalGlyphFormAttributeName
                      value:@NO
                      range:NSMakeRange(0, separator.length)];

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
  if (numCandidates > 0 && theme.showPaging) {
    [text appendAttributedString:[[NSAttributedString alloc]
                                  initWithString:theme.linear ? (useTab ? @"\t" : @"  ") : @"\n"
                                  attributes:theme.attrs]];
    NSUInteger pagingStart = text.length;
    if (theme.linear) {
      [text appendAttributedString:paging];
      NSMutableParagraphStyle *paragraphStylePaging = [theme.paragraphStyle mutableCopy];
      paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSRightTabStopType
                                                               location:maxLineWidth]];
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(candidateBlockStart, text.length-candidateBlockStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      if (useTab) {
        [paging replaceCharactersInRange:NSMakeRange(1, 1) withString:@"\t"];
        [paging replaceCharactersInRange:NSMakeRange(paging.length-2, 1) withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSCenterTabStopType
                                                                 location:maxLineWidth/2],
                                          [[NSTextTab alloc] initWithType:NSRightTabStopType
                                                                 location:maxLineWidth]];
      }
      [paging addAttribute:NSParagraphStyleAttributeName
                     value:paragraphStylePaging
                     range:NSMakeRange(0, paging.length)];
      [text appendAttributedString:paging];
    }
    pagingRange = NSMakeRange(pagingStart, paging.length);
  }

  [_view.textView.textStorage setAttributedString:text];
  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];

  // text done!
  [_view     drawViewWith:candidateRanges
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
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
                                     initWithString:message.precomposedStringWithCanonicalMapping
                                     attributes:theme.commentAttrs];
  [text addAttribute:NSParagraphStyleAttributeName
               value:theme.statusParagraphStyle
               range:NSMakeRange(0, text.length)];

  [_view.textView.textStorage setAttributedString:text];
  [_view.textView setLayoutOrientation:theme.vertical ? NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal];

  _maxSize = NSZeroSize; // disable remember_size and fixed line_length for status messages
  NSRange emptyRange = NSMakeRange(NSNotFound, 0);
  [_view     drawViewWith:@[]
         highlightedIndex:NSNotFound
             preeditRange:emptyRange
  highlightedPreeditRange:emptyRange
              pagingRange:emptyRange
             pagingButton:NSNotFound];
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
  return [[foregroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                                            ofColor:backgroundColor]
          colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static inline NSColor *inverseColor(NSColor *color) {
  if (color == nil) {
    return nil;
  } else {
    return [NSColor colorWithColorSpace:color.colorSpace
                                    hue:color.hueComponent
                             saturation:color.saturationComponent
                             brightness:1-color.brightnessComponent
                                  alpha:color.alphaComponent];
  }
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
  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  CTFontRef systemFontRef = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, 0.0, (CFStringRef) @"zh");
  NSFontDescriptor *systemFontDescriptor = CFBridgingRelease(CTFontCopyFontDescriptor(systemFontRef));
  CFRelease(systemFontRef);
  NSFontDescriptor *emojiFontDescriptor = [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
  NSArray *fallbackDescriptors = [[validFontDescriptors subarrayWithRange:NSMakeRange(1, validFontDescriptors.count-1)] arrayByAddingObjectsFromArray:@[systemFontDescriptor, emojiFontDescriptor]];
  NSDictionary *attributes = @{NSFontCascadeListAttribute:fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static CGFloat getLineHeight(NSFont *font, BOOL vertical) {
  if (vertical) {
    font = font.verticalFont;
  }
  CGFloat lineHeight = font.ascender - font.descender;
  if (@available(macOS 12.0, *)) {
    return lineHeight;
  } else {
    NSArray *fallbackList = [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
    for (NSFontDescriptor *fallback in fallbackList) {
      NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback size:font.pointSize];
      if (vertical) {
        fallbackFont = fallbackFont.verticalFont;
      }
      lineHeight = MAX(lineHeight, fallbackFont.ascender - fallbackFont.descender);
    }
    return lineHeight;
  }
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
    NSNumber *lineLengthOverridden = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_length"]];
    if (lineLengthOverridden) {
      lineLength = MAX(lineLengthOverridden.doubleValue, 0.0);
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
  pagingParagraphStyle.minimumLineHeight = pagingFont.ascender - pagingFont.descender;
  pagingParagraphStyle.maximumLineHeight = pagingFont.ascender - pagingFont.descender;
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
      borderColor = inverseColor(borderColor) ;
      preeditBackgroundColor = inverseColor(preeditBackgroundColor);
      candidateTextColor = inverseColor(candidateTextColor);
      highlightedCandidateTextColor = [inverseColor(highlightedCandidateTextColor) highlightWithLevel:highlightedCandidateTextColor.brightnessComponent];
      highlightedCandidateBackColor = [inverseColor(highlightedCandidateBackColor) shadowWithLevel:1-highlightedCandidateBackColor.brightnessComponent];
      candidateLabelColor = inverseColor(candidateLabelColor);
      highlightedCandidateLabelColor = [inverseColor(highlightedCandidateLabelColor) highlightWithLevel:highlightedCandidateLabelColor.brightnessComponent];
      commentTextColor = inverseColor(commentTextColor);
      highlightedCommentTextColor = [inverseColor(highlightedCommentTextColor) highlightWithLevel:highlightedCommentTextColor.brightnessComponent];
      textColor = inverseColor(textColor);
      highlightedTextColor = [inverseColor(highlightedTextColor) highlightWithLevel:highlightedTextColor.brightnessComponent];
      highlightedBackColor = [inverseColor(highlightedBackColor) shadowWithLevel:1-highlightedBackColor.brightnessComponent];
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
      pagingParagraphStyle:pagingParagraphStyle
      statusParagraphStyle:statusParagraphStyle];

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
