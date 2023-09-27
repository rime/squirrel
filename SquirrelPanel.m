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
          case NSBezierPathElementQuadraticCurveTo:
            CGPathAddQuadCurveToPoint(path, NULL, points[0].x, points[0].y,
                                      points[1].x, points[1].y);
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

@implementation NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)

- (void)formatMarkDown {
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|<(b|strong|i|em|u|sup|sub|s)>)(.+?)(\\2|\\3(?=\\b)|<\\/\\4>)" options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
  NSInteger __block offset = 0;
  [regex enumerateMatchesInString:self.string options:0 range:NSMakeRange(0, self.length)
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
    result = [result resultByAdjustingRangesWithOffset:offset];
    NSString *tag = [self.string substringWithRange:[result rangeAtIndex:1]];
    if ([tag isEqualToString:@"**"] || [tag isEqualToString:@"__"] ||
        [tag isEqualToString:@"<b>"] || [tag isEqualToString:@"<strong>"]) {
      [self applyFontTraits:NSBoldFontMask range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"*"] || [tag isEqualToString:@"_"] ||
               [tag isEqualToString:@"<i>"] || [tag isEqualToString:@"<em>"]) {
      [self applyFontTraits:NSItalicFontMask range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"<u>"]) {
      [self addAttribute:NSUnderlineStyleAttributeName
                   value:@(NSUnderlineStyleSingle) range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"~~"] || [tag isEqualToString:@"<s>"]) {
      [self addAttribute:NSStrikethroughStyleAttributeName
                   value:@(NSUnderlineStyleSingle) range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"^"] || [tag isEqualToString:@"<sup>"]) {
      [self superscriptRange:[result rangeAtIndex:5]];
      [self enumerateAttribute:NSFontAttributeName inRange:[result rangeAtIndex:5] options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        NSFont *font = [[NSFontManager sharedFontManager] convertFont:value toSize:[value pointSize] * 7 / 12];
        [self addAttribute:NSFontAttributeName value:font range:range];
      }];
    } else if ([tag isEqualToString:@"~"] || [tag isEqualToString:@"<sub>"]) {
      [self subscriptRange:[result rangeAtIndex:5]];
      [self enumerateAttribute:NSFontAttributeName inRange:[result rangeAtIndex:5] options:0
                    usingBlock:^(id value, NSRange range, BOOL *stop) {
        NSFont *font = [[NSFontManager sharedFontManager] convertFont:value toSize:[value pointSize] * 7 / 12];
        [self addAttribute:NSFontAttributeName value:font range:range];
      }];
    }
    [self deleteCharactersInRange:[result rangeAtIndex:6]];
    [self deleteCharactersInRange:[result rangeAtIndex:1]];
    offset -= [result rangeAtIndex:6].length + [result rangeAtIndex:1].length;
  }];
  if (offset != 0) { // no match. text remain unchanged.
    [self formatMarkDown];
  }
}

@end

static const CGFloat kOffsetHeight = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c. %@";
static NSString *const kTipSpecifier = @"%s";
static NSString *const kFullWidthSpace = @"　";

@interface SquirrelTheme : NSObject

@property(nonatomic, strong, readonly) NSColor *backgroundColor;
@property(nonatomic, strong, readonly) NSColor *backgroundImage;
@property(nonatomic, strong, readonly) NSColor *highlightedStripColor;
@property(nonatomic, strong, readonly) NSColor *highlightedPreeditColor;
@property(nonatomic, strong, readonly) NSColor *preeditBackgroundColor;
@property(nonatomic, strong, readonly) NSColor *borderColor;

@property(nonatomic, readonly) CGFloat cornerRadius;
@property(nonatomic, readonly) CGFloat highlightedCornerRadius;
@property(nonatomic, readonly) CGFloat separatorWidth;
@property(nonatomic, readonly) NSSize edgeInset;
@property(nonatomic, readonly) CGFloat linespace;
@property(nonatomic, readonly) CGFloat preeditLinespace;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) CGFloat translucency;
@property(nonatomic, readonly) CGFloat lineLength;
@property(nonatomic, readonly) BOOL showPaging;
@property(nonatomic, readonly) BOOL rememberSize;
@property(nonatomic, readonly) BOOL tabled;
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
@property(nonatomic, strong, readonly) NSDictionary *statusAttrs;
@property(nonatomic, strong, readonly) NSParagraphStyle *paragraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *preeditParagraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *pagingParagraphStyle;
@property(nonatomic, strong, readonly) NSParagraphStyle *statusParagraphStyle;

@property(nonatomic, strong, readonly) NSAttributedString *symbolBackFill;
@property(nonatomic, strong, readonly) NSAttributedString *symbolBackStroke;
@property(nonatomic, strong, readonly) NSAttributedString *symbolForwardFill;
@property(nonatomic, strong, readonly) NSAttributedString *symbolForwardStroke;

@property(nonatomic, strong, readonly) NSArray<NSString *> *labels;
@property(nonatomic, strong, readonly) NSArray<NSAttributedString *> *candidateFormats;
@property(nonatomic, strong, readonly) NSArray<NSAttributedString *> *candidateHighlightedFormats;
@property(nonatomic, strong, readonly) NSString *statusMessageType;

- (void)setBackgroundColor:(NSColor *)backgroundColor
           backgroundImage:(NSColor *)backgroundImage
     highlightedStripColor:(NSColor *)highlightedStripColor
   highlightedPreeditColor:(NSColor *)highlightedPreeditColor
    preeditBackgroundColor:(NSColor *)preeditBackgroundColor
               borderColor:(NSColor *)borderColor;

- (void)  setCornerRadius:(CGFloat)cornerRadius
  highlightedCornerRadius:(CGFloat)highlightedCornerRadius
           separatorWidth:(CGFloat)separatorWidth
                edgeInset:(NSSize)edgeInset
                linespace:(CGFloat)linespace
         preeditLinespace:(CGFloat)preeditLinespace
                    alpha:(CGFloat)alpha
             translucency:(CGFloat)translucency
               lineLength:(CGFloat)lineLength
               showPaging:(BOOL)showPaging
             rememberSize:(BOOL)rememberSize
                   tabled:(BOOL)tabled
                   linear:(BOOL)linear
                 vertical:(BOOL)vertical
            inlinePreedit:(BOOL)inlinePreedit
          inlineCandidate:(BOOL)inlineCandidate;

- (void)         setAttrs:(NSDictionary *)attrs
         highlightedAttrs:(NSDictionary *)highlightedAttrs
               labelAttrs:(NSDictionary *)labelAttrs
    labelHighlightedAttrs:(NSDictionary *)labelHighlightedAttrs
             commentAttrs:(NSDictionary *)commentAttrs
  commentHighlightedAttrs:(NSDictionary *)commentHighlightedAttrs
             preeditAttrs:(NSDictionary *)preeditAttrs
  preeditHighlightedAttrs:(NSDictionary *)preeditHighlightedAttrs
              pagingAttrs:(NSDictionary *)pagingAttrs
   pagingHighlightedAttrs:(NSDictionary *)pagingHighlightedAttrs
              statusAttrs:(NSDictionary *)statusAttrs;

- (void)setParagraphStyle:(NSParagraphStyle *)paragraphStyle
    preeditParagraphStyle:(NSParagraphStyle *)preeditParagraphStyle
     pagingParagraphStyle:(NSParagraphStyle *)pagingParagraphStyle
     statusParagraphStyle:(NSParagraphStyle *)statusParagraphStyle;

- (void)setLabels:(NSArray<NSString *> *)labels;

- (void)setCandidateFormat:(NSString *)candidateFormat;

- (void)setStatusMessageType:(NSString *)statusMessageType;

@end

@implementation SquirrelTheme

static NSArray<NSAttributedString *> * formatLabels(NSAttributedString *format, NSArray<NSString *> *labels) {
  NSRange enumRange = NSMakeRange(0, 0);
  NSMutableArray<NSAttributedString *> *formatted = [[NSMutableArray alloc] initWithCapacity:labels.count];
  NSCharacterSet *labelCharacters = [NSCharacterSet characterSetWithCharactersInString:[labels componentsJoinedByString:@""]];
  if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xff10, 10)]
       isSupersetOfSet:labelCharacters]) { // ０１..９
    if ([format.string containsString:@"%c\u20dd"]) { // ①..⑨⓪
      enumRange = [format.string rangeOfString:@"%c\u20dd"];
      for (NSString *label in labels) {
        unichar chars[] = {[label characterAtIndex:0] == 0xff10 ? 0x24ea : [label characterAtIndex:0] - 0xff11 + 0x2460, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    } else if ([format.string containsString:@"(%c)"]) { // ⑴..⑼⑽
      enumRange = [format.string rangeOfString:@"(%c)"];
      for (NSString *label in labels) {
        unichar chars[] = {[label characterAtIndex:0] == 0xff10 ? 0x247d : [label characterAtIndex:0] - 0xff11 + 0x2474, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    } else if ([format.string containsString:@"%c."]) { // ⒈..⒐🄀
      enumRange = [format.string rangeOfString:@"%c."];
      for (NSString *label in labels) {
        if ([label characterAtIndex:0] == 0xff10) {
          unichar chars[] = {0xd83c, 0xdd00, 0x0};
          NSMutableAttributedString *newFormat = [format mutableCopy];
          [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:3]];
          [formatted addObject:[newFormat copy]];
        } else {
          unichar chars[] = {[label characterAtIndex:0] - 0xff11 + 0x2488, 0x0};
          NSMutableAttributedString *newFormat = [format mutableCopy];
          [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
          [formatted addObject:[newFormat copy]];
        }
      }
    } else if ([format.string containsString:@"%c,"]) { //🄂..🄊🄁
      enumRange = [format.string rangeOfString:@"%c,"];
      for (NSString *label in labels) {
        unichar chars[] = {0xd83c, [label characterAtIndex:0] - 0xff10 + 0xdd01, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    }
  } else if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xff21, 26)]
              isSupersetOfSet:labelCharacters]) { // Ａ..Ｚ
    if ([format.string containsString:@"%c\u20dd"]) { // Ⓐ..Ⓩ
      enumRange = [format.string rangeOfString:@"%c\u20dd"];
      for (NSString *label in labels) {
        unichar chars[] = {[label characterAtIndex:0] - 0xff21 + 0x24b6, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    } else if ([format.string containsString:@"(%c)"]) { // 🄐..🄩
      enumRange = [format.string rangeOfString:@"(%c)"];
      for (NSString *label in labels) {
        unichar chars[] = {0xd83c, [label characterAtIndex:0] - 0xff21 + 0xdd10, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    } else if ([format.string containsString:@"%c\u20de"]) { // 🄰..🅉
      enumRange = [format.string rangeOfString:@"%c\u20de"];
      for (NSString *label in labels) {
        unichar chars[] = {0xd83c, [label characterAtIndex:0] - 0xff21 + 0xdd30, 0x0};
        NSMutableAttributedString *newFormat = [format mutableCopy];
        [newFormat replaceCharactersInRange:enumRange withString:[NSString stringWithCharacters:chars length:2]];
        [formatted addObject:[newFormat copy]];
      }
    }
  }
  if (enumRange.length == 0) {
    enumRange = [format.string rangeOfString:@"%c"];
    for (NSString *label in labels) {
      NSMutableAttributedString *newFormat = [format mutableCopy];
      [newFormat replaceCharactersInRange:enumRange withString:label];
      [formatted addObject:[newFormat copy]];
    }
  }
  return [formatted copy];
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

- (void)  setCornerRadius:(CGFloat)cornerRadius
  highlightedCornerRadius:(CGFloat)highlightedCornerRadius
           separatorWidth:(CGFloat)separatorWidth
                edgeInset:(NSSize)edgeInset
                linespace:(CGFloat)linespace
         preeditLinespace:(CGFloat)preeditLinespace
                    alpha:(CGFloat)alpha
             translucency:(CGFloat)translucency
               lineLength:(CGFloat)lineLength
               showPaging:(BOOL)showPaging
             rememberSize:(BOOL)rememberSize
                   tabled:(BOOL)tabled
                   linear:(BOOL)linear
                 vertical:(BOOL)vertical
            inlinePreedit:(BOOL)inlinePreedit
          inlineCandidate:(BOOL)inlineCandidate {
  _cornerRadius = cornerRadius;
  _highlightedCornerRadius = highlightedCornerRadius;
  _separatorWidth = separatorWidth;
  _edgeInset = edgeInset;
  _linespace = linespace;
  _preeditLinespace = preeditLinespace;
  _alpha = alpha;
  _translucency = translucency;
  _lineLength = lineLength;
  _showPaging = showPaging;
  _rememberSize = rememberSize;
  _tabled = tabled;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
  _inlineCandidate = inlineCandidate;
}

- (void)         setAttrs:(NSDictionary *)attrs
         highlightedAttrs:(NSDictionary *)highlightedAttrs
               labelAttrs:(NSDictionary *)labelAttrs
    labelHighlightedAttrs:(NSDictionary *)labelHighlightedAttrs
             commentAttrs:(NSDictionary *)commentAttrs
  commentHighlightedAttrs:(NSDictionary *)commentHighlightedAttrs
             preeditAttrs:(NSDictionary *)preeditAttrs
  preeditHighlightedAttrs:(NSDictionary *)preeditHighlightedAttrs
              pagingAttrs:(NSDictionary *)pagingAttrs
   pagingHighlightedAttrs:(NSDictionary *)pagingHighlightedAttrs
              statusAttrs:(NSDictionary *)statusAttrs {
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
  _statusAttrs = statusAttrs;
  NSMutableDictionary *symbolAttrs = [pagingAttrs mutableCopy];
  if (@available(macOS 12.0, *)) {
    NSTextAttachment *attmBackFill = [[NSTextAttachment alloc] init];
    attmBackFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.backward.circle.fill" accessibilityDescription:nil];
    NSMutableDictionary *attrsBackFill = [symbolAttrs mutableCopy];
    attrsBackFill[NSAttachmentAttributeName] = attmBackFill;
    _symbolBackFill = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsBackFill];

    NSTextAttachment *attmBackStroke = [[NSTextAttachment alloc] init];
    attmBackStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.backward.circle" accessibilityDescription:nil];
    NSMutableDictionary *attrsBackStroke = [symbolAttrs mutableCopy];
    attrsBackStroke[NSAttachmentAttributeName] = attmBackStroke;
    _symbolBackStroke = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsBackStroke];

    NSTextAttachment *attmForwardFill = [[NSTextAttachment alloc] init];
    attmForwardFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.forward.circle.fill" accessibilityDescription:nil];
    NSMutableDictionary *attrsForwardFill = [symbolAttrs mutableCopy];
    attrsForwardFill[NSAttachmentAttributeName] = attmForwardFill;
    _symbolForwardFill = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsForwardFill];

    NSTextAttachment *attmForwardStroke = [[NSTextAttachment alloc] init];
    attmForwardStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.forward.circle" accessibilityDescription:nil];
    NSMutableDictionary *attrsForwardStroke = [symbolAttrs mutableCopy];
    attrsForwardStroke[NSAttachmentAttributeName] = attmForwardStroke;
    _symbolForwardStroke = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsForwardStroke];
  } else {
    NSFont *symbolFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0]
                          fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized]
                                                      size:[labelAttrs[NSFontAttributeName] pointSize]];
    symbolAttrs[NSFontAttributeName] = symbolFont;
    if (_vertical || !_linear) {
      symbolAttrs[NSBaselineOffsetAttributeName] = @([pagingAttrs[NSBaselineOffsetAttributeName] doubleValue] - symbolFont.leading);
    }

    NSMutableDictionary *symbolAttrsBackFill = [symbolAttrs mutableCopy];
    symbolAttrsBackFill[NSGlyphInfoAttributeName] =
      [NSGlyphInfo glyphInfoWithGlyphName:@"gid4966" forFont:symbolFont baseString:@"◀"];
    _symbolBackFill = [[NSAttributedString alloc] initWithString:@"◀" attributes:symbolAttrsBackFill];

    NSMutableDictionary *symbolAttrsBackStroke = [symbolAttrs mutableCopy];
    symbolAttrsBackStroke[NSGlyphInfoAttributeName] =
      [NSGlyphInfo glyphInfoWithGlyphName:@"gid4969" forFont:symbolFont baseString:@"◁"];
    _symbolBackStroke = [[NSAttributedString alloc] initWithString:@"◁" attributes:symbolAttrsBackStroke];

    NSMutableDictionary *symbolAttrsForwardFill = [symbolAttrs mutableCopy];
    symbolAttrsForwardFill[NSGlyphInfoAttributeName] =
      [NSGlyphInfo glyphInfoWithGlyphName:@"gid4967" forFont:symbolFont baseString:@"▶"];
    _symbolForwardFill = [[NSAttributedString alloc] initWithString:@"▶" attributes:symbolAttrsForwardFill];

    NSMutableDictionary *symbolAttrsForwardStroke = [symbolAttrs mutableCopy];
    symbolAttrsForwardStroke[NSGlyphInfoAttributeName] =
      [NSGlyphInfo glyphInfoWithGlyphName:@"gid4968" forFont:symbolFont baseString:@"▷"];
    _symbolForwardStroke = [[NSAttributedString alloc] initWithString:@"▷" attributes:symbolAttrsForwardStroke];
  }
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

- (void)setLabels:(NSArray<NSString *> *)labels {
  _labels = labels;
}

- (void)setCandidateFormat:(NSString *)candidateFormat {
  // validate candidate format: must have enumerator '%c' before candidate '%@'
  if (![candidateFormat containsString:@"%@"]) {
    candidateFormat = [candidateFormat stringByAppendingString:@"%@"];
  }
  if (![candidateFormat containsString:@"%c"]) {
    candidateFormat = [@"%c" stringByAppendingString:candidateFormat];
  }
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@"];
  NSRange labelRange = [candidateFormat rangeOfString:@"%c"];
  if (labelRange.location > candidateRange.location) {
    candidateFormat = kDefaultCandidateFormat;
    candidateRange = [candidateFormat rangeOfString:@"%@"];
  }
  labelRange = NSMakeRange(0, candidateRange.location);
  NSRange commentRange = NSMakeRange(NSMaxRange(candidateRange), candidateFormat.length - NSMaxRange(candidateRange));
  // parse markdown formats
  NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:candidateFormat];
  NSMutableAttributedString *highlightedFormat = [format mutableCopy];
  [format addAttributes:_labelAttrs range:labelRange];
  [highlightedFormat addAttributes:_labelHighlightedAttrs range:labelRange];
  [format addAttributes:_attrs range:candidateRange];
  [highlightedFormat addAttributes:_highlightedAttrs range:candidateRange];
  if (commentRange.length > 0) {
    [format addAttributes:_commentAttrs range:commentRange];
    [highlightedFormat addAttributes:_commentHighlightedAttrs range:commentRange];
  }
  [format formatMarkDown];
  [highlightedFormat formatMarkDown];
  // add placeholder for comment '%s'
  candidateRange = [format.string rangeOfString:@"%@"];
  commentRange = NSMakeRange(NSMaxRange(candidateRange), format.length - NSMaxRange(candidateRange));
  if (commentRange.length > 0) {
    [format replaceCharactersInRange:commentRange withString:[kTipSpecifier stringByAppendingString:[format.string substringWithRange:commentRange]]];
    [highlightedFormat replaceCharactersInRange:commentRange withString:[kTipSpecifier stringByAppendingString:[highlightedFormat.string substringWithRange:commentRange]]];
  } else {
    [format appendAttributedString:[[NSAttributedString alloc] initWithString:kTipSpecifier attributes:_commentAttrs]];
    [highlightedFormat appendAttributedString:[[NSAttributedString alloc] initWithString:kTipSpecifier attributes:_commentHighlightedAttrs]];
  }
  _candidateFormats = formatLabels(format, _labels);
  _candidateHighlightedFormats = formatLabels(highlightedFormat, _labels);
}

- (void)setStatusMessageType:(NSString *)type {
  if ([type isEqualToString:@"long"] || [type isEqualToString:@"short"] || [type isEqualToString:@"mix"]) {
    _statusMessageType = type;
  } else {
    _statusMessageType = @"mix";
  }
}

@end

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextView *textView;
@property(nonatomic, readonly) NSTextStorage *textStorage;
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
@property(nonatomic, readonly) CAShapeLayer *shape;
@property(nonatomic, readonly, strong) SquirrelTheme *currentTheme;
@property(nonatomic, readonly) BOOL isDark;

- (void)drawViewWithInsets:(NSEdgeInsets)insets
           candidateRanges:(NSArray<NSValue *> *)candidateRanges
          highlightedIndex:(NSUInteger)highlightedIndex
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

- (BOOL)allowsVibrancy {
  return YES;
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
    NSTextLayoutManager *textLayoutManager = [[NSTextLayoutManager alloc] init];
    textLayoutManager.usesFontLeading = NO;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    textContainer.lineFragmentPadding = 0;
    textLayoutManager.textContainer = textContainer;
    NSTextContentStorage *contentStorage = [[NSTextContentStorage alloc] init];
    [contentStorage addTextLayoutManager:textLayoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect
                                    textContainer:textLayoutManager.textContainer];
    _textStorage = _textView.textContentStorage.textStorage;
  } else {
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    layoutManager.backgroundLayoutEnabled = YES;
    layoutManager.usesFontLeading = NO;
    layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithContainerSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    textContainer.lineFragmentPadding = 0;
    [layoutManager addTextContainer:textContainer];
    _textStorage = [[NSTextStorage alloc] init];
    [_textStorage addLayoutManager:layoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect
                                    textContainer:textContainer];
  }
  _textView.drawsBackground = NO;
  _textView.editable = NO;
  _textView.selectable = NO;
  _textView.wantsLayer = NO;

  _shape = [[CAShapeLayer alloc] init];
  _defaultTheme = [[SquirrelTheme alloc] init];
  if (@available(macOS 10.14, *)) {
    _darkTheme = [[SquirrelTheme alloc] init];
  }
  return self;
}

- (NSTextRange *)getTextRangeFromRange:(NSRange)range API_AVAILABLE(macos(12.0)) {
  if (range.location == NSNotFound) {
    return nil;
  } else {
    NSTextContentStorage *contentStorage = _textView.textContentStorage;
    id<NSTextLocation> startLocation = [contentStorage locationFromLocation:contentStorage.documentRange.location withOffset:range.location];
    id<NSTextLocation> endLocation = [contentStorage locationFromLocation:startLocation withOffset:range.length];
    return [[NSTextRange alloc] initWithLocation:startLocation endLocation:endLocation];
  }
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  if (@available(macOS 12.0, *)) {
    [_textView.textLayoutManager ensureLayoutForRange:_textView.textContentStorage.documentRange];
    return [_textView.textLayoutManager usageBoundsForTextContainer];
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
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      contentRect = NSUnionRect(contentRect, segFrame);
      return YES;
    }];
    CGFloat lineSpacing = [[_textStorage attribute:NSParagraphStyleAttributeName
                                           atIndex:NSMaxRange(range) - 1
                                    effectiveRange:NULL] lineSpacing];
    contentRect.size.height += lineSpacing;
    return contentRect;
  } else {
    NSTextContainer *textContainer = _textView.textContainer;
    NSLayoutManager *layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range
                                               actualCharacterRange:NULL];
    NSRange firstLineRange = NSMakeRange(NSNotFound, 0);
    NSRect firstLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                                               effectiveRange:&firstLineRange];
    if (NSMaxRange(glyphRange) <= NSMaxRange(firstLineRange)) {
      CGFloat startX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
      CGFloat endX = NSMaxRange(glyphRange) < NSMaxRange(firstLineRange)
        ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x : NSWidth(firstLineRect);
      return NSMakeRect(NSMinX(firstLineRect) + startX, NSMinY(firstLineRect),
                        endX - startX, NSHeight(firstLineRect));
    } else {
      NSRect finalLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                                                                 effectiveRange:NULL];
      return NSMakeRect(NSMinX(firstLineRect), NSMinY(firstLineRect),
                        textContainer.size.width, NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    }
  }
}

// Will triger - (void)updateLayer
- (void)drawViewWithInsets:(NSEdgeInsets)insets
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
  _candidatePaths = [[NSMutableArray alloc] initWithCapacity:candidateRanges.count];
  _pagingPaths = [[NSMutableArray alloc] initWithCapacity:pagingRange.length > 0 ? 2 : 0];
  self.needsDisplay = YES;
}

// Bezier cubic curve, which has continuous roundness
static NSBezierPath * drawRoundedPolygon(NSArray<NSValue *> *vertex, CGFloat radius) {
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

static NSArray<NSValue *> * rectVertex(NSRect rect) {
  return @[@(rect.origin),
           @(NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y))];
}

static inline BOOL nearEmptyRect(NSRect rect) {
  return NSHeight(rect) * NSWidth(rect) < 1;
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is the complete line fragment in the middle if the range spans no less than one full line
- (void)multilineRectForRange:(NSRange)charRange leadingRect:(NSRectPointer)leadingRect bodyRect:(NSRectPointer)bodyRect trailingRect:(NSRectPointer)trailingRect {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromRange:charRange];
    CGFloat lineSpacing = [[_textStorage attribute:NSParagraphStyleAttributeName atIndex:charRange.location effectiveRange:NULL] lineSpacing];
    NSMutableArray<NSValue *> *lineRects = [[NSMutableArray alloc] initWithCapacity:2];
    NSMutableArray<NSTextRange *> *lineRanges = [[NSMutableArray alloc] initWithCapacity:2];
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsMiddleFragmentsExcluded
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      if (!nearEmptyRect(segFrame)) {
        segFrame.size.height += lineSpacing;
        [lineRects addObject:[NSValue valueWithRect:segFrame]];
        [lineRanges addObject:segRange];
      }
      return YES;
    }];
    if (lineRects.count == 1) {
      *bodyRect = lineRects[0].rectValue;
    } else {
      CGFloat containerWidth = _textView.textContainer.size.width;
      NSRect leadingLineRect = lineRects.firstObject.rectValue;
      leadingLineRect.size.width = containerWidth - NSMinX(leadingLineRect);
      NSRect trailingLineRect = lineRects.lastObject.rectValue;
      if (NSMaxX(trailingLineRect) == NSMaxX(leadingLineRect)) {
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect = NSUnionRect(leadingLineRect, trailingLineRect);
        } else {
          *leadingRect = leadingLineRect;
          *bodyRect = NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                                 NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = trailingLineRect;
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect = NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                                 NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = leadingLineRect;
          if (lineRanges.lastObject.location > lineRanges.firstObject.endLocation) {
            *bodyRect = NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                                   NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
    }
  } else {
    NSLayoutManager *layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
                                               actualCharacterRange:NULL];
    NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect leadingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                                                 effectiveRange:&leadingLineRange];
    CGFloat startX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
    if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
      CGFloat endX = NSMaxRange(glyphRange) < NSMaxRange(leadingLineRange)
        ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x : NSWidth(leadingLineRect);
      *bodyRect = NSMakeRect(startX, NSMinY(leadingLineRect),
                             endX - startX, NSHeight(leadingLineRect));
    } else {
      CGFloat containerWidth = _textView.textContainer.size.width;
      NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
      NSRect trailingLineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                                                                    effectiveRange:&trailingLineRange];
      CGFloat endX = NSMaxRange(glyphRange) < NSMaxRange(trailingLineRange)
        ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x : NSWidth(trailingLineRect);
      if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                                 NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(startX, NSMinY(leadingLineRect),
                                    containerWidth - startX, NSHeight(leadingLineRect));
          *bodyRect = NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                                 NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = NSMakeRect(0.0, NSMinY(trailingLineRect), endX,
                                   NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                                 NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(startX, NSMinY(leadingLineRect),
                                    containerWidth - startX, NSHeight(leadingLineRect));
          if (trailingLineRange.location > NSMaxRange(leadingLineRange)) {
            *bodyRect = NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                                   NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
    }
  }
}

// Based on the 3 boxes from multilineRectForRange, calculate the vertex of the polygon containing the text in range
static NSArray<NSValue *> * multilineRectVertex(NSRect leadingRect, NSRect bodyRect, NSRect trailingRect) {
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

static inline NSColor * hooverColor(NSColor *color, BOOL darkTheme) {
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  }
  if (darkTheme) {
    return [color highlightWithLevel:0.3];
  } else {
    return [color shadowWithLevel:0.3];
  }
}

static inline NSColor * disabledColor(NSColor *color, BOOL darkTheme) {
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
  NSBezierPath *candidateHorzGridPath;
  NSBezierPath *candidateVertGridPath;
  NSBezierPath *pageUpPath;
  NSBezierPath *pageDownPath;

  SquirrelTheme *theme = self.currentTheme;
  NSRect backgroundRect = self.bounds;
  NSRect textContainerRect = NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height);

  NSRange visibleRange;
  if (@available(macOS 12.0, *)) {
    visibleRange = NSMakeRange(0, _textStorage.length);
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
  }
  if (!theme.linear && pagingRange.length > 0) {
    pagingLineRect = [self contentRectForRange:pagingRange];
    pagingLineRect.origin.y -= theme.pagingParagraphStyle.paragraphSpacingBefore;
    pagingLineRect.size.height += theme.pagingParagraphStyle.paragraphSpacingBefore;
  }

  [NSBezierPath setDefaultLineWidth:0];
  // Draw preedit Rect
  if (preeditRange.length > 0) {
    preeditRect.size.width = textContainerRect.size.width;
    preeditRect.origin = textContainerRect.origin;
    // Draw highlighted part of preedit text
    NSRange highlightedPreeditRange = NSIntersectionRange(_highlightedPreeditRange, visibleRange);
    if (highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor != nil) {
      NSRect innerBox = NSInsetRect(preeditRect, theme.separatorWidth / 2, 0);
      if (candidateBlockRange.length > 0) {
        innerBox.size.height -= theme.preeditLinespace;
      }
      NSRect leadingRect = NSZeroRect;
      NSRect bodyRect = NSZeroRect;
      NSRect trailingRect = NSZeroRect;
      [self multilineRectForRange:highlightedPreeditRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
      leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect
        : NSIntersectionRect(NSOffsetRect(leadingRect, _insets.left, theme.edgeInset.height), innerBox);
      bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect
        : NSIntersectionRect(NSOffsetRect(bodyRect, _insets.left, theme.edgeInset.height), innerBox);
      trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect
        : NSIntersectionRect(NSOffsetRect(trailingRect, _insets.left, theme.edgeInset.height), innerBox);
      NSArray<NSValue *> *highlightedPreeditPoints;
      NSArray<NSValue *> *highlightedPreeditPoints2;
      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect)
          && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPreeditPoints = rectVertex(leadingRect);
        highlightedPreeditPoints2 = rectVertex(trailingRect);
      } else {
        highlightedPreeditPoints = multilineRectVertex(leadingRect, bodyRect, trailingRect);
      }
      highlightedPreeditPath = drawRoundedPolygon(highlightedPreeditPoints, MIN(theme.highlightedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight / 3));
      if (highlightedPreeditPoints2.count > 0) {
        [highlightedPreeditPath appendBezierPath:drawRoundedPolygon(highlightedPreeditPoints2, MIN(theme.highlightedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight / 3))];
      }
    }
  }

  // Draw candidate Rect
  if (candidateBlockRange.length > 0) {
    candidateBlockRect.size.width = textContainerRect.size.width;
    candidateBlockRect.origin.x = textContainerRect.origin.x;
    candidateBlockRect.origin.y += textContainerRect.origin.y;
    candidateBlockRect = NSIntersectionRect(candidateBlockRect, textContainerRect);
    candidateBlockPath = drawRoundedPolygon(rectVertex(candidateBlockRect), theme.highlightedCornerRadius);

    // Draw candidate highlight rect
    if (theme.linear) {
      CGFloat gridOriginY = NSMinY(candidateBlockRect);
      CGFloat tabInterval = theme.separatorWidth * 2;
      if (theme.tabled) {
        candidateHorzGridPath = [NSBezierPath bezierPath];
        candidateVertGridPath = [NSBezierPath bezierPath];
      }
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange([_candidateRanges[i] rangeValue], visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect leadingRect = NSZeroRect;
        NSRect bodyRect = NSZeroRect;
        NSRect trailingRect = NSZeroRect;
        [self multilineRectForRange:candidateRange leadingRect:&leadingRect bodyRect:&bodyRect trailingRect:&trailingRect];
        leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect
          : NSInsetRect(NSOffsetRect(leadingRect, _insets.left, theme.edgeInset.height), -theme.separatorWidth / 2, 0);
        bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect
          : NSInsetRect(NSOffsetRect(bodyRect, _insets.left, theme.edgeInset.height), -theme.separatorWidth / 2, 0);
        trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect
          : NSInsetRect(NSOffsetRect(trailingRect, _insets.left, theme.edgeInset.height), -theme.separatorWidth / 2, 0);
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
        if (theme.tabled) {
          CGFloat bottomEdge = NSMaxY(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          if (ABS(bottomEdge - gridOriginY) > 2 && ABS(bottomEdge - NSMaxY(candidateBlockRect)) > 2) { // horizontal border
            [candidateHorzGridPath moveToPoint:NSMakePoint(NSMinX(candidateBlockRect) + theme.separatorWidth / 2, bottomEdge)];
            [candidateHorzGridPath lineToPoint:NSMakePoint(NSMaxX(candidateBlockRect) - theme.separatorWidth / 2, bottomEdge)];
            [candidateHorzGridPath closePath];
            gridOriginY = bottomEdge;
          }
          CGPoint leadOrigin = (NSIsEmptyRect(leadingRect) ? bodyRect : leadingRect).origin;
          if (leadOrigin.x > NSMinX(candidateBlockRect) + theme.separatorWidth / 2) { // vertical bar
            [candidateVertGridPath moveToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + theme.linespace / 2 + theme.paragraphStyle.maximumLineHeight - theme.highlightedCornerRadius)];
            [candidateVertGridPath lineToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + theme.linespace / 2 + theme.highlightedCornerRadius)];
            [candidateVertGridPath closePath];
          }
          CGFloat tailEdge = NSMaxX(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          CGFloat tabPosition = pow(2, ceil(log2((tailEdge - leadOrigin.x) / tabInterval))) * tabInterval + leadOrigin.x;
          if (NSIsEmptyRect(trailingRect)) {
            bodyRect.size.width += tabPosition - tailEdge;
          } else if (NSIsEmptyRect(bodyRect)) {
            trailingRect.size.width += tabPosition - tailEdge;
          } else {
            bodyRect = NSMakeRect(NSMinX(candidateBlockRect), NSMinY(bodyRect), NSWidth(candidateBlockRect), NSHeight(bodyRect) + NSHeight(trailingRect));
            trailingRect = NSZeroRect;
          }
        }
        NSArray<NSValue *> *candidatePoints;
        NSArray<NSValue *> *candidatePoints2;
        // Handles the special case where containing boxes are separated
        if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) &&
            !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePoints = rectVertex(leadingRect);
          candidatePoints2 = rectVertex(trailingRect);
        } else {
          candidatePoints = multilineRectVertex(leadingRect, bodyRect, trailingRect);
        }
        NSBezierPath *candidatePath = drawRoundedPolygon(candidatePoints, theme.highlightedCornerRadius);
        if (candidatePoints2.count > 0) {
          [candidatePath appendBezierPath:drawRoundedPolygon(candidatePoints2, theme.highlightedCornerRadius)];
        }
        _candidatePaths[i] = candidatePath;
      }
    } else { // stacked layout
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange([_candidateRanges[i] rangeValue], visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect candidateRect = NSInsetRect([self contentRectForRange:candidateRange], 0.0, -theme.linespace / 2);
        candidateRect.size.width = textContainerRect.size.width;
        candidateRect.origin.x = textContainerRect.origin.x;
        candidateRect.origin.y += textContainerRect.origin.y;
        if (preeditRange.length == 0) {
          candidateRect.origin.y += theme.linespace / 2;
        }
        candidateRect = NSIntersectionRect(candidateRect, candidateBlockRect);
        NSArray<NSValue *> *candidatePoints = rectVertex(candidateRect);
        NSBezierPath *candidatePath = drawRoundedPolygon(candidatePoints, theme.highlightedCornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
  }

  // Draw paging Rect
  if (pagingRange.length > 0) {
    NSRect pageDownRect = NSOffsetRect([self contentRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)],
                                       _insets.left, theme.edgeInset.height);
    pageDownRect.size.width += theme.separatorWidth / 2;
    NSRect pageUpRect = NSOffsetRect([self contentRectForRange:NSMakeRange(pagingRange.location, 1)],
                                     _insets.left, theme.edgeInset.height);
    pageUpRect.origin.x -= theme.separatorWidth / 2;
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
      MIN(theme.highlightedCornerRadius, MIN(NSWidth(pageDownRect), NSHeight(pageDownRect)) / 3));
    pageUpPath = drawRoundedPolygon(rectVertex(pageUpRect),
      MIN(theme.highlightedCornerRadius, MIN(NSWidth(pageUpRect), NSHeight(pageUpRect)) / 3));
    _pagingPaths[0] = pageUpPath;
    _pagingPaths[1] = pageDownPath;
  }

  // Draw borders
  backgroundPath = drawRoundedPolygon(rectVertex(backgroundRect),
    MIN(theme.cornerRadius, NSHeight(backgroundRect) / 3));
  textContainerPath = drawRoundedPolygon(rectVertex(textContainerRect),
    MIN(theme.highlightedCornerRadius, NSHeight(textContainerRect) / 3));
  if (theme.edgeInset.width > 0 || theme.edgeInset.height > 0) {
    borderPath = [backgroundPath copy];
    [borderPath appendBezierPath:textContainerPath];
    borderPath.windingRule = NSEvenOddWindingRule;
  }

  // set layers
  _shape.path = [backgroundPath quartzPath];
  _shape.fillColor = [[NSColor whiteColor] CGColor];
  _shape.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect) / 3);
  CAShapeLayer *textContainerLayer = [[CAShapeLayer alloc] init];
  textContainerLayer.path = [textContainerPath quartzPath];
  textContainerLayer.fillColor = [[NSColor whiteColor] CGColor];
  textContainerLayer.cornerRadius = MIN(theme.highlightedCornerRadius, NSHeight(textContainerRect) / 3);
  [self.layer setSublayers:nil];
  self.layer.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect) / 3);
  CALayer *panelLayer = [[CALayer alloc] init];
  [self.layer addSublayer:panelLayer];
  if (theme.backgroundImage) {
    CAShapeLayer *backgroundImageLayer = [[CAShapeLayer alloc] init];
    if (theme.vertical) {
      const CGAffineTransform rotate = CGAffineTransformMakeRotation(-M_PI / 2);
      backgroundImageLayer.path = CFAutorelease(CGPathCreateCopyByTransformingPath([textContainerPath quartzPath], &rotate));
      backgroundImageLayer.fillColor = [theme.backgroundImage CGColor];
      [backgroundImageLayer setAffineTransform:CGAffineTransformMakeRotation(M_PI / 2)];
    } else {
      backgroundImageLayer.path = [textContainerPath quartzPath];
      backgroundImageLayer.fillColor = [theme.backgroundImage CGColor];
    }
    backgroundImageLayer.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect) / 3);
    [panelLayer addSublayer:backgroundImageLayer];
  }
  CAShapeLayer *backgroundLayer = [[CAShapeLayer alloc] init];
  backgroundLayer.path = [textContainerPath quartzPath];
  backgroundLayer.fillColor = [theme.backgroundColor CGColor];
  backgroundLayer.cornerRadius = MIN(theme.cornerRadius, NSHeight(backgroundRect) / 3);
  [panelLayer addSublayer:backgroundLayer];
  if (theme.preeditBackgroundColor &&
      (preeditRange.length > 0 || !NSIsEmptyRect(pagingLineRect))) {
    backgroundLayer.fillColor = [theme.preeditBackgroundColor CGColor];
    if (!candidateBlockPath.empty) {
      [textContainerPath appendBezierPath:candidateBlockPath];
      textContainerPath.windingRule = NSEvenOddWindingRule;
      backgroundLayer.path = [textContainerPath quartzPath];
      backgroundLayer.fillRule = kCAFillRuleEvenOdd;
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = [candidateBlockPath quartzPath];
      candidateLayer.fillColor = [theme.backgroundColor CGColor];
      [panelLayer addSublayer:candidateLayer];
    }
  }
  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0) {
      panelLayer.opacity = 1.0 - theme.translucency;
    }
  }
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
    if (!highlightedPreeditPath.empty) {
      CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
      highlightedPreeditLayer.path = [highlightedPreeditPath quartzPath];
      highlightedPreeditLayer.fillColor = [theme.highlightedPreeditColor CGColor];
      highlightedPreeditLayer.mask = textContainerLayer;
      [self.layer addSublayer:highlightedPreeditLayer];
    }
  }
  if (theme.tabled) {
    CAShapeLayer *horzGridLayer = [[CAShapeLayer alloc] init];
    horzGridLayer.path = [candidateHorzGridPath quartzPath];
    horzGridLayer.strokeColor = [[theme.backgroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction ofColor:(self.isDark ? [NSColor lightGrayColor] : [NSColor blackColor])] CGColor];
    horzGridLayer.lineWidth = theme.edgeInset.height / 2;
    horzGridLayer.lineCap = kCALineCapRound;
    [panelLayer addSublayer:horzGridLayer];
    CAShapeLayer *vertGridLayer = [[CAShapeLayer alloc] init];
    vertGridLayer.path = [candidateVertGridPath quartzPath];
    vertGridLayer.strokeColor = [[theme.backgroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction ofColor:(self.isDark ? [NSColor lightGrayColor] : [NSColor blackColor])] CGColor];
    vertGridLayer.lineWidth = theme.edgeInset.width / 2;
    vertGridLayer.lineCap = kCALineCapRound;
    [panelLayer addSublayer:vertGridLayer];
  }
  if (theme.borderColor && !borderPath.empty) {
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
  CGFloat _textWidthLimit;

  NSString *_preedit;
  NSRange _selRange;
  NSUInteger _caretPos;
  NSArray<NSString *> *_candidates;
  NSArray<NSString *> *_comments;
  NSUInteger _index;
  NSUInteger _pageNum;
  NSUInteger _turnPage;
  BOOL _lastPage;

  BOOL _mouseDown;
  NSPoint _scrollLocus;
  BOOL _initPosition;

  NSString *_statusMessage;
  NSTimer *_statusTimer;
}

- (BOOL)isFloatingPanel {
  return YES;
}

- (BOOL)linear {
  return _view.currentTheme.linear;
}

- (BOOL)tabled {
  return _view.currentTheme.tabled;
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
    return [NSColor colorForControlTint:[NSColor currentControlTint]];
  }
}

- (void)initializeUIStyleForDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];

  NSColor *secondaryTextColor = [SquirrelPanel secondaryTextColor];
  NSColor *accentColor = [SquirrelPanel accentColor];
  NSFont *userFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFontOfSize:0.0].fontName)
                                           size:kDefaultFontSize];
  NSFont *userMonoFont = [NSFont fontWithDescriptor:getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName)
                                               size:kDefaultFontSize];
  NSMutableDictionary *defaultAttrs = [[NSMutableDictionary alloc] init];
  // prevent mac terminal from hijacking non-alphabetic keys on non-inline mode
  defaultAttrs[IMKCandidatesSendServerKeyEventFirst] = @(YES);
  
  NSMutableDictionary *attrs = [defaultAttrs mutableCopy];
  attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  attrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *highlightedAttrs = [defaultAttrs mutableCopy];
  highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedMenuItemTextColor];
  highlightedAttrs[NSFontAttributeName] = userFont;
  // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
  attrs[NSWritingDirectionAttributeName] = @[@(0)];
  highlightedAttrs[NSWritingDirectionAttributeName] = @[@(0)];

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

  NSMutableDictionary *pagingHighlightedAttrs = [defaultAttrs mutableCopy];
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = theme.linear
    ? [NSColor alternateSelectedControlTextColor] : [NSColor selectedMenuItemTextColor];

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

  NSMutableDictionary *statusAttrs = [commentAttrs mutableCopy];
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  preeditHighlightedAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;

  [theme         setAttrs:attrs
         highlightedAttrs:highlightedAttrs
               labelAttrs:labelAttrs
    labelHighlightedAttrs:labelHighlightedAttrs
             commentAttrs:commentAttrs
  commentHighlightedAttrs:commentHighlightedAttrs
             preeditAttrs:preeditAttrs
  preeditHighlightedAttrs:preeditHighlightedAttrs
              pagingAttrs:pagingAttrs
   pagingHighlightedAttrs:pagingHighlightedAttrs
              statusAttrs:statusAttrs];

  [theme setParagraphStyle:paragraphStyle
     preeditParagraphStyle:preeditParagraphStyle
      pagingParagraphStyle:pagingParagraphStyle
      statusParagraphStyle:statusParagraphStyle];

  [theme setLabels:@[@"１", @"２", @"３", @"４", @"５", @"６", @"７", @"８", @"９", @"０"]];
  [theme setCandidateFormat:kDefaultCandidateFormat];
}

- (instancetype)init {
  self = [super initWithContentRect:_position
                          styleMask:NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:YES];

  if (self) {
    self.alphaValue = 1.0;
    self.level = kCGCursorWindowLevel - 10;
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
    _initPosition = YES;
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
          [self showPreedit:_preedit    selRange:_selRange caretPos:_caretPos
                 candidates:_candidates comments:_comments  highlighted:cursorIndex
                    pageNum:_pageNum    lastPage:_lastPage turnPage:NSNotFound update:NO];
        } else if ((cursorIndex == NSPageUpFunctionKey || cursorIndex == NSPageDownFunctionKey) && _turnPage != cursorIndex) {
          _turnPage = cursorIndex;
          [self showPreedit:_preedit    selRange:_selRange caretPos:_caretPos
                 candidates:_candidates comments:_comments  highlighted:_index
                    pageNum:_pageNum    lastPage:_lastPage turnPage:cursorIndex update:NO];
        }
      }
    } break;
    case NSEventTypeLeftMouseDragged: {
      _mouseDown = NO;
      _maxSize = NSZeroSize; // reset the remember_size references after moving the panel
      [self performWindowDragWithEvent:event];
    } break;
    case NSEventTypeScrollWheel: {
      SquirrelTheme *theme = _view.currentTheme;
      CGFloat scrollThreshold = [theme.attrs[NSParagraphStyleAttributeName] maximumLineHeight] + [theme.attrs[NSParagraphStyleAttributeName] lineSpacing];
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
          [_inputController perform:kSELECT onIndex:(theme.vertical ? NSPageDownFunctionKey : NSPageUpFunctionKey)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y > scrollThreshold) {
          [_inputController perform:kSELECT onIndex:NSPageUpFunctionKey];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [_inputController perform:kSELECT onIndex:(theme.vertical ? NSPageUpFunctionKey : NSPageDownFunctionKey)];
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
  _screen = [NSScreen mainScreen];
  NSArray<NSScreen *> *screens = [NSScreen screens];
  for (NSUInteger i = 0; i < screens.count; ++i) {
    if (NSPointInRect(_position.origin, [screens[i] frame])) {
      _screen = screens[i];
      return;
    }
  }
}

- (void)getTextWidthLimit {
  [self getCurrentScreen];
  NSRect screenRect = _screen.visibleFrame;
  SquirrelTheme *theme = _view.currentTheme;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit = (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio - theme.separatorWidth - theme.edgeInset.width * 2;
  if (theme.lineLength > 0) {
    _textWidthLimit = MIN(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabled) {
    CGFloat tabInterval = theme.separatorWidth * 2;
    _textWidthLimit = floor((_textWidthLimit + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
  }
  _view.textView.textContainer.size = NSMakeSize(_textWidthLimit, CGFLOAT_MAX);
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  if (@available(macOS 10.14, *)) {
    NSAppearance *requestedAppearance = [NSAppearance appearanceNamed:
      (_view.isDark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua)];
    if (self.appearance != requestedAppearance) {
      self.appearance = requestedAppearance;
    }
  }

  //Break line if the text is too long, based on screen size.
  SquirrelTheme *theme = _view.currentTheme;
  NSTextContainer *textContainer = _view.textView.textContainer;
  NSEdgeInsets insets = _view.insets;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = _screen.visibleFrame;
  CGFloat textHeightLimit = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * textWidthRatio - insets.top - insets.bottom;

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  BOOL sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSRect contentRect = _view.contentRect;
  NSRect maxContentRect = contentRect;
  if (theme.lineLength > 0) { // fixed line length (text width)
    if (_statusMessage == nil) { // not applicable to status message
      maxContentRect.size.width = _textWidthLimit;
    }
  }
  if (theme.rememberSize) { // remember panel size (fix the top leading anchor of the panel in screen coordiantes)
    if ((theme.vertical ? (NSMinY(_position) - NSMinY(screenRect) <= NSHeight(screenRect) * textWidthRatio + kOffsetHeight)
         : (sweepVertical ? (NSMinX(_position) - NSMinX(screenRect) > NSWidth(screenRect) * textWidthRatio + kOffsetHeight)
            : (NSMinX(_position) + MAX(NSWidth(maxContentRect), _maxSize.width) + insets.right > NSMaxX(screenRect)))) &&
        theme.lineLength == 0) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        maxContentRect.size.width = _maxSize.width;
        [textContainer setSize:NSMakeSize(_maxSize.width, textHeightLimit)];
      }
    }
    if (theme.vertical ? (NSMinX(_position) - NSMinX(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom + (sweepVertical ? kOffsetHeight : 0))
        : (NSMinY(_position) - NSMinY(screenRect) < MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom + (sweepVertical ? 0 : kOffsetHeight))) {
      if (NSHeight(maxContentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(maxContentRect);
      } else {
        maxContentRect.size.height = _maxSize.height;
      }
    }
  }

  _initPosition |= NSIntersectsRect(self.frame, _position);
  NSRect windowRect;
  if (theme.vertical) {
    windowRect.size = NSMakeSize(NSHeight(maxContentRect) + insets.top + insets.bottom,
                                 NSWidth(maxContentRect) + insets.left + insets.right);
    if (_initPosition ) {
      // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
      if (NSMinY(_position) - NSMinY(screenRect) > NSHeight(screenRect) * textWidthRatio + kOffsetHeight) {
        windowRect.origin.y = NSMinY(_position) + (sweepVertical ? insets.left : -kOffsetHeight) - NSHeight(windowRect);
      } else {
        windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
      }
      // Make the right edge of candidate block fixed at the left of cursor
      windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSWidth(windowRect);
      if (!sweepVertical && _view.preeditRange.length > 0) {
        NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
        windowRect.origin.x += round(NSHeight(preeditRect) + [theme.preeditAttrs[NSFontAttributeName] descender] + insets.top);
      }
    } else {
      windowRect.origin.x = NSMaxX(self.frame) - NSWidth(windowRect);
      windowRect.origin.y = NSMaxY(self.frame) - NSHeight(windowRect);
    }
  } else {
    windowRect.size = NSMakeSize(NSWidth(maxContentRect) + insets.left + insets.right,
                                 NSHeight(maxContentRect) + insets.top + insets.bottom);
    if (_initPosition) {
      if (sweepVertical) {
        // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
        if (NSMinX(_position) - NSMinX(screenRect) > NSWidth(screenRect) * textWidthRatio + kOffsetHeight) {
          windowRect.origin.x = NSMinX(_position) - kOffsetHeight - NSWidth(windowRect);
        } else {
          windowRect.origin.x = NSMaxX(_position) + kOffsetHeight;
        }
        windowRect.origin.y = NSMinY(_position) - NSHeight(windowRect);
      } else {
        windowRect.origin = NSMakePoint(NSMinX(_position) - insets.left,
                                        NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
      }
    } else {
      windowRect.origin = NSMakePoint(NSMinX(self.frame), NSMaxY(self.frame) - NSHeight(windowRect));
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (_initPosition && sweepVertical ? NSMinX(_position) - kOffsetHeight : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = _initPosition && sweepVertical ? NSMaxX(_position) + kOffsetHeight : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = _initPosition && !sweepVertical ? NSMaxY(_position) + kOffsetHeight : NSMinY(screenRect);
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (_initPosition && !sweepVertical ? NSMinY(_position) - kOffsetHeight : NSMaxY(screenRect)) - NSHeight(windowRect);
  }

  if (theme.vertical) {
    windowRect.origin.x += round(NSHeight(maxContentRect) - NSHeight(contentRect));
    windowRect.size.width -= round(NSHeight(maxContentRect) - NSHeight(contentRect));
  } else {
    windowRect.origin.y += round(NSHeight(maxContentRect) - NSHeight(contentRect));
    windowRect.size.height -= round(NSHeight(maxContentRect) - NSHeight(contentRect));
  }

  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    [self setFrame:[_screen backingAlignedRect:windowRect options:NSAlignMaxXOutward | NSAlignMaxYInward | NSAlignWidthNearest | NSAlignHeightNearest] display:YES];
    [self.contentView setBoundsRotation:-90.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    [self setFrame:[_screen backingAlignedRect:windowRect options:NSAlignMinXInward | NSAlignMaxYInward | NSAlignWidthNearest | NSAlignHeightNearest] display:YES];
    [self.contentView setBoundsRotation:0.0];
    [self.contentView setBoundsOrigin:NSZeroPoint];
  }
  NSRect frameRect = self.contentView.bounds;
  NSRect textFrameRect = NSMakeRect(NSMinX(frameRect) + insets.left, NSMinY(frameRect) + insets.bottom,
                                    NSWidth(frameRect) - insets.left - insets.right,
                                    NSHeight(frameRect) - insets.top - insets.bottom);
  [_view.textView setBoundsRotation:0.0];
  [_view setBoundsOrigin:NSZeroPoint];
  [_view.textView setBoundsOrigin:NSZeroPoint];
  [_view setFrame:frameRect];
  [_view.textView setFrame:textFrameRect];

  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0) {
      [_back setFrame:frameRect];
      [_back setAppearance:NSApp.effectiveAppearance];
      [_back setHidden:NO];
    } else {
      [_back setHidden:YES];
    }
  }
  [self setAlphaValue:theme.alpha];
  [self orderFront:nil];
  _initPosition = NO;
  // voila !
}

- (void)hide {
  if (_statusTimer) {
    [_statusTimer invalidate];
    _statusTimer = nil;
  }
  [self orderOut:nil];
  _maxSize = NSZeroSize;
  _initPosition = YES;
}

- (void)setLayoutForRange:(NSRange)charRange
        withReferenceFont:(NSFont *)refFont
           paragraphStyle:(NSParagraphStyle *)style {
  BOOL verticalLayout = _view.currentTheme.vertical;
  CGFloat refFontHeight = refFont.ascender - refFont.descender;
  CGFloat lineHeight = MAX(style.lineHeightMultiple > 0 ? refFontHeight * style.lineHeightMultiple : refFontHeight,
                           style.minimumLineHeight);
  lineHeight = style.maximumLineHeight > 0 ? MIN(lineHeight, style.maximumLineHeight) : lineHeight;
  if (@available(macOS 12.0, *)) {
    NSUInteger i = charRange.location;
    NSRange runRange = NSMakeRange(i, 0);
    while (i < NSMaxRange(charRange)) {
      NSDictionary *attrs = [_view.textStorage attributesAtIndex:i
                                           longestEffectiveRange:&runRange inRange:charRange];
      NSNumber *baselineOffset = attrs[NSBaselineOffsetAttributeName];
      CGFloat offset = (baselineOffset ? baselineOffset.doubleValue : 0.0) + lineHeight / 2 - refFontHeight / 2;
      NSNumber *superscript = attrs[NSSuperscriptAttributeName];
      if (superscript) {
        NSFont *runFont = verticalLayout ? [attrs[NSFontAttributeName] verticalFont] : attrs[NSFontAttributeName];
        offset += superscript.integerValue == 1 ? runFont.descender / 3 : runFont.ascender / 3;
      }
      [_view.textStorage addAttribute:NSBaselineOffsetAttributeName
                                value:@(offset) range:runRange];
      i = NSMaxRange(runRange);
    }
  } else {
    NSLayoutManager *layoutManager = _view.textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    NSUInteger i = glyphRange.location;
    NSRange lineRange = NSMakeRange(i, 0);
    while (i < NSMaxRange(glyphRange)) {
      NSRect rect = [layoutManager lineFragmentRectForGlyphAtIndex:i effectiveRange:&lineRange];
      NSRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:i effectiveRange:NULL];
      CGFloat alignment = usedRect.origin.y - rect.origin.y + (verticalLayout ? lineHeight / 2 : lineHeight / 2 + refFont.xHeight / 2);
      // typesetting glyphs
      NSUInteger j = lineRange.location;
      while (j < NSMaxRange(lineRange)) {
        NSPoint runGlyphPosition = [layoutManager locationForGlyphAtIndex:j];
        NSUInteger runCharLocation = [layoutManager characterIndexForGlyphAtIndex:j];
        NSRange runRange = [layoutManager rangeOfNominallySpacedGlyphsContainingIndex:j];
        NSDictionary *attrs = [_view.textStorage attributesAtIndex:runCharLocation effectiveRange:NULL];
        NSFont *runFont = attrs[NSFontAttributeName];
        NSFont *systemFont = [NSFont systemFontOfSize:runFont.pointSize];
        NSString *baselineClass = attrs[CFBridgingRelease(kCTBaselineClassAttributeName)];
        NSNumber *baselineOffset = attrs[NSBaselineOffsetAttributeName];
        CGFloat offset = baselineOffset ? baselineOffset.doubleValue : 0.0;
        NSNumber *superscript = attrs[NSSuperscriptAttributeName];
        if (verticalLayout) {
          NSNumber *verticalGlyph = attrs[NSVerticalGlyphFormAttributeName];
          if (verticalGlyph ? verticalGlyph.boolValue : YES) {
            runFont = runFont.verticalFont;
            systemFont = systemFont.verticalFont;
          }
        }
        CGFloat runFontHeight = runFont.ascender - runFont.descender;
        CGFloat systemFontHeight = systemFont.ascender - systemFont.descender;
        if (superscript) {
          offset += superscript.integerValue == 1 ? refFont.ascender / 3 : refFont.descender / 3;
        }
        if (verticalLayout) {
          if ([baselineClass isEqualToString:CFBridgingRelease(kCTBaselineClassRoman)] || !runFont.vertical) {
            runGlyphPosition.y = alignment - offset + refFont.xHeight / 2;
          } else {
            runGlyphPosition.y = alignment - offset + ([runFont.fontName isEqualToString:@"AppleColorEmoji"] ? (runFontHeight - systemFontHeight) / 3 : 0.0);
            runGlyphPosition.x += [runFont.fontName isEqualToString:@"AppleColorEmoji"] ? (runFontHeight - systemFontHeight) * 2 / 3 : 0.0;
          }
        } else {
          runGlyphPosition.y = alignment - offset + ([baselineClass isEqualToString:CFBridgingRelease(kCTBaselineClassIdeographicCentered)] ? runFont.xHeight / 2 - refFont.xHeight / 2 : 0.0);
        }
        [layoutManager setLocation:runGlyphPosition forStartOfGlyphRange:runRange];
        j = NSMaxRange(runRange);
      }
      i = NSMaxRange(lineRange);
    }
  }
}

- (BOOL)shouldBreakLineWithRange:(NSRange)range {
  [_view.textStorage fixFontAttributeInRange:range];
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromRange:range];
    NSUInteger __block lineCount = 0;
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
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
      [_view.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:loc
                                                         effectiveRange:&lineRange];
      ++lineCount;
      loc = NSMaxRange(lineRange);
    }
    return lineCount > 1;
  }
}

- (BOOL)shouldUseTabsInRange:(NSRange)range maxLineLength:(CGFloat *)maxLineLength {
  [_view.textStorage fixFontAttributeInRange:range];
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromRange:range];
    CGFloat __block rangeEdge;
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      rangeEdge = NSMaxX(segFrame);
      return YES;
    }];
    [_view.textView.textLayoutManager ensureLayoutForRange:_view.textView.textContentStorage.documentRange];
    NSRect container = [_view.textView.textLayoutManager usageBoundsForTextContainer];
    *maxLineLength = MAX(MIN(_textWidthLimit, NSWidth(container)), _maxSize.width);
    return NSMinX(container) + *maxLineLength > rangeEdge;
  } else {
    NSUInteger glyphIndex = [_view.textView.layoutManager glyphIndexForCharacterAtIndex:range.location];
    CGFloat rangeEdge = NSMaxX([_view.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:NULL]);
    NSRect container = [_view.textView.layoutManager usedRectForTextContainer:_view.textView.textContainer];
    *maxLineLength = MAX(MIN(_textWidthLimit, NSWidth(container)), _maxSize.width);
    return NSMinX(container) + *maxLineLength > rangeEdge;
  }
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray<NSString *> *)candidates
           comments:(NSArray<NSString *> *)comments
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
    _index = index;
    _pageNum = pageNum;
    _lastPage = lastPage;
  }

  [self getTextWidthLimit];
  NSUInteger numCandidates = candidates.count;
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

  if (numCandidates == 0) {
    _index = index = NSNotFound;
  }
  _turnPage = turnPage;
  if (_turnPage == NSPageUpFunctionKey) {
    turnPage = pageNum ? NSPageUpFunctionKey : NSBeginFunctionKey;
  } else if (_turnPage == NSPageDownFunctionKey) {
    turnPage = lastPage ? NSEndFunctionKey : NSPageDownFunctionKey;
  }

  SquirrelTheme *theme = _view.currentTheme;
  _view.textView.layoutOrientation = theme.vertical ?
    NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;
  if (theme.lineLength > 0) {
    _maxSize.width = MIN(theme.lineLength, _textWidthLimit);
  }
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height + theme.linespace / 2,
                                         theme.edgeInset.width + theme.separatorWidth / 2,
                                         theme.edgeInset.height + theme.linespace / 2,
                                         theme.edgeInset.width + theme.separatorWidth / 2);

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] init]];
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  NSMutableArray<NSValue *> *candidateRanges = [[NSMutableArray alloc] initWithCapacity:numCandidates];
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);
  NSMutableParagraphStyle *paragraphStyleCandidate;

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
      [preeditLine addAttributes:@{NSVerticalGlyphFormAttributeName: @NO}
                           range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)), 1)];
    }
    preeditRange = NSMakeRange(0, preeditLine.length);
    [text appendAttributedString:preeditLine];

    insets.top = theme.edgeInset.height;
    if (numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.preeditAttrs]];
    } else {
      insets.bottom = theme.edgeInset.height;
      goto typesetter;
    }
  }

  // candidate items
  NSUInteger candidateBlockStart = text.length;
  NSUInteger lineStart = text.length;
  if (theme.linear) {
    paragraphStyleCandidate = [theme.paragraphStyle copy];
  }
  CGFloat tabInterval = theme.separatorWidth * 2;
  for (NSUInteger idx = 0; idx < candidates.count; ++idx) {
    // attributed labels are already included in candidateFormats
    NSMutableAttributedString *item = (idx == index) ? [theme.candidateHighlightedFormats[idx] mutableCopy] : [theme.candidateFormats[idx] mutableCopy];
    NSRange candidateRange = [item.string rangeOfString:@"%@"];
    // get the label size for indent
    CGFloat labelWidth = theme.linear ? 0.0 : ceil([item attributedSubstringFromRange:NSMakeRange(0, candidateRange.location)].size.width);

    [item replaceCharactersInRange:candidateRange withString:candidates[idx]];

    NSRange commentRange = [item.string rangeOfString:kTipSpecifier];
    if (idx < comments.count && [comments[idx] length] != 0) {
      [item replaceCharactersInRange:commentRange withString:[@" " stringByAppendingString:comments[idx]]];
    } else {
      [item deleteCharactersInRange:commentRange];
    }

    [item formatMarkDown];
    if (!theme.linear) {
      paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    [item addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, item.length)];

    // determine if the line is too wide and line break is needed, based on screen size.
    if (lineStart != text.length) {
      NSUInteger separatorStart = text.length;
      NSMutableAttributedString *separator = [[NSMutableAttributedString alloc] initWithString:theme.linear ? (theme.tabled ? [kFullWidthSpace stringByAppendingString:@"\t"] : kFullWidthSpace) : @"\n" attributes:theme.commentAttrs];
      if (theme.tabled) {
        CGFloat widthInTabs = (ceil([text attributedSubstringFromRange:candidateRanges.lastObject.rangeValue].size.width) + theme.separatorWidth) / tabInterval;
        NSUInteger numPaddingTabs = pow(2, ceil(log2(widthInTabs))) - ceil(widthInTabs);
        [separator replaceCharactersInRange:NSMakeRange(2, 0) withString:[@"\t" stringByPaddingToLength:numPaddingTabs withString:@"\t" startingAtIndex:0]];
      }
      [separator addAttribute:NSVerticalGlyphFormAttributeName value:@(NO)
                        range:NSMakeRange(0, separator.length)];
      NSRange separatorRange = NSMakeRange(separatorStart, separator.length);
      [text appendAttributedString:separator];
      [text appendAttributedString:item];
      if (theme.linear && (ceil(item.size.width) > _textWidthLimit || [self shouldBreakLineWithRange:NSMakeRange(lineStart, text.length - lineStart)])) {
        [text replaceCharactersInRange:separatorRange withString:theme.tabled ? [kFullWidthSpace stringByAppendingString:@"\n"] : @"\n"];
        lineStart = separatorStart + (theme.tabled ? 2 : 1);
      }
    } else { // at the start of a new line, no need to determine line break
      [text appendAttributedString:item];
    }
    // for linear layout, middle-truncate candidates that are longer than one line
    if (theme.linear && ceil(item.size.width) > _textWidthLimit) {
      if (idx < numCandidates - 1 || theme.showPaging) {
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.commentAttrs]];
      }
      NSMutableParagraphStyle *paragraphStyleTruncating = [paragraphStyleCandidate mutableCopy];
      paragraphStyleTruncating.lineBreakMode = NSLineBreakByTruncatingMiddle;
      [text addAttribute:NSParagraphStyleAttributeName value:paragraphStyleTruncating range:NSMakeRange(lineStart, item.length)];
      [candidateRanges addObject:[NSValue valueWithRange:NSMakeRange(lineStart, text.length - lineStart - 1)]];
      lineStart = text.length;
    } else {
      [candidateRanges addObject:[NSValue valueWithRange:NSMakeRange(text.length - item.length, item.length)]];
    }
  }

  // paging indication
  if (theme.showPaging) {
    NSMutableAttributedString *paging = [[NSMutableAttributedString alloc]
                                         initWithAttributedString:(pageNum > 0 ? theme.symbolBackFill : theme.symbolBackStroke)];
    [paging appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:[NSString stringWithFormat:@" %lu ", pageNum + 1] attributes:theme.pagingAttrs]];
    [paging appendAttributedString:[[NSAttributedString alloc]
                                    initWithAttributedString:(lastPage ? theme.symbolForwardStroke : theme.symbolForwardFill)]];
    if (_turnPage == NSPageUpFunctionKey) {
      [paging addAttributes:theme.pagingHighlightedAttrs range:NSMakeRange(0, 1)];
    } else if (_turnPage == NSPageDownFunctionKey) {
      [paging addAttributes:theme.pagingHighlightedAttrs range:NSMakeRange(paging.length - 1, 1)];
    }

    [text appendAttributedString:[[NSAttributedString alloc] initWithString:theme.linear ? (theme.tabled ? [kFullWidthSpace stringByAppendingString:@"\t"] : kFullWidthSpace) : @"\n" attributes:theme.commentAttrs]];
    NSUInteger pagingStart = text.length;
    CGFloat maxLineLength;
    [text appendAttributedString:paging];
    if (theme.linear) {
      if ([self shouldBreakLineWithRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1) withString:theme.tabled ? @"\n\t" : [@"\n" stringByAppendingString:kFullWidthSpace]];
        lineStart = pagingStart;
        pagingStart += 1;
      }
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, paging.length) maxLineLength:&maxLineLength]) {
        paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
        if (theme.tabled) {
          maxLineLength = ceil(maxLineLength / tabInterval) * tabInterval - theme.separatorWidth;
        } else {
          [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1) withString:@"\t"];
        }
        CGFloat candidateEndPosition = ceil([text attributedSubstringFromRange:NSMakeRange(lineStart, pagingStart - 1 - lineStart)].size.width);
        NSMutableArray<NSTextTab *> *tabStops = [[NSMutableArray alloc] init];
        for (NSUInteger i = 1; tabInterval * i < candidateEndPosition; ++i) {
          [tabStops addObject:[[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabInterval * i]];
        }
        [tabStops addObject:[[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineLength]];
        paragraphStyleCandidate.tabStops = tabStops;
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleCandidate
                   range:NSMakeRange(lineStart, text.length - lineStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, paging.length) maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1) withString:@"\t"];
        [text replaceCharactersInRange:NSMakeRange(pagingStart + paging.length - 2, 1) withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithType:NSCenterTabStopType location:maxLineLength / 2],
                                          [[NSTextTab alloc] initWithType:NSRightTabStopType location:maxLineLength]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(pagingStart, paging.length)];
      insets.bottom = theme.edgeInset.height;
    }
    pagingRange = NSMakeRange(text.length - paging.length, paging.length);
  }

typesetter:
  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  if (preedit) {
    [self setLayoutForRange:preeditRange
          withReferenceFont:(theme.vertical ? [theme.preeditAttrs[NSFontAttributeName] verticalFont] : theme.preeditAttrs[NSFontAttributeName])
             paragraphStyle:theme.preeditParagraphStyle];
  }
  if (numCandidates > 0) {
    NSRange candidateBlockRange = NSMakeRange(candidateBlockStart, (!theme.linear && pagingRange.length > 0 ? pagingRange.location : text.length) - candidateBlockStart);
    [self setLayoutForRange:candidateBlockRange
          withReferenceFont:(theme.vertical ? [theme.attrs[NSFontAttributeName] verticalFont] : theme.attrs[NSFontAttributeName])
             paragraphStyle:theme.paragraphStyle];
    if (!theme.linear && pagingRange.length > 0) {
      [self setLayoutForRange:pagingRange
            withReferenceFont:theme.pagingAttrs[NSFontAttributeName]
               paragraphStyle:theme.pagingParagraphStyle];
    }
  }

  // text done!
  [self setAnimationBehavior:caretPos == NSNotFound ?
   NSWindowAnimationBehaviorUtilityWindow : NSWindowAnimationBehaviorDefault];
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
  SquirrelTheme *theme = _view.currentTheme;
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height, theme.edgeInset.width + theme.separatorWidth / 2,
                                         theme.edgeInset.height, theme.edgeInset.width + theme.separatorWidth / 2);
  _view.textView.layoutOrientation = theme.vertical ?
    NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] initWithString:message attributes:theme.statusAttrs]];

  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  [self setLayoutForRange:NSMakeRange(0, text.length)
        withReferenceFont:(theme.vertical ? [theme.statusAttrs[NSFontAttributeName] verticalFont] : theme.statusAttrs[NSFontAttributeName])
           paragraphStyle:theme.statusParagraphStyle];

  // disable remember_size and fixed line_length for status messages
  _initPosition = YES;
  _maxSize = NSZeroSize;
  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  [self setAnimationBehavior:NSWindowAnimationBehaviorUtilityWindow];
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
  NSArray<NSString *> *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray<NSFontDescriptor *> *validFontDescriptors = [[NSMutableArray alloc] initWithCapacity:fontNames.count];
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
  NSFontDescriptor *emojiFontDescriptor = [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
  NSArray<NSFontDescriptor *> *fallbackDescriptors =
    [[validFontDescriptors subarrayWithRange:NSMakeRange(1, validFontDescriptors.count - 1)]
     arrayByAddingObject:emojiFontDescriptor];
  NSDictionary *attributes = @{NSFontCascadeListAttribute: fallbackDescriptors};
  return [initialFontDescriptor fontDescriptorByAddingAttributes:attributes];
}

static CGFloat getLineHeight(NSFont *font, BOOL vertical) {
  if (vertical) {
    font = font.verticalFont;
  }
  CGFloat lineHeight = font.ascender - font.descender;
  NSArray<NSFontDescriptor *> *fallbackList = [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor *fallback in fallbackList) {
    NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback size:font.pointSize];
    if (vertical) {
      fallbackFont = fallbackFont.verticalFont;
    }
    lineHeight = MAX(lineHeight, fallbackFont.ascender - fallbackFont.descender);
  }
  return lineHeight;
}

static void updateCandidateListLayout(BOOL *isLinearCandidateList, BOOL *isTabledCandidateList, SquirrelConfig *config, NSString *prefix) {
  NSString *candidateListLayout = [config getString:[prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([candidateListLayout isEqualToString:@"stacked"]) {
    *isLinearCandidateList = NO;
    *isTabledCandidateList = NO;
  } else if ([candidateListLayout isEqualToString:@"linear"]) {
    *isLinearCandidateList = YES;
    *isTabledCandidateList = NO;
  } else if ([candidateListLayout isEqualToString:@"tabled"]) {
    // `tabled` is a derived layout of `linear`; tabled implies linear
    *isLinearCandidateList = YES;
    *isTabledCandidateList = YES;
  } else {
    // Deprecated. Not to be confused with text_orientation: horizontal
    NSNumber *horizontal = [config getOptionalBool:[prefix stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinearCandidateList = horizontal.boolValue;
      *isTabledCandidateList = NO;
    }
  }
}

static void updateTextOrientation(BOOL *isVerticalText, SquirrelConfig *config, NSString *prefix) {
  NSString *textOrientation = [config getString:[prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVerticalText = NO;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVerticalText = YES;
  } else {
    NSNumber *vertical = [config getOptionalBool:[prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVerticalText = vertical.boolValue;
    }
  }
}

- (void)loadLabelConfig:(SquirrelConfig *)config {
  SquirrelTheme *theme = [_view selectTheme:NO];
  [SquirrelPanel updateTheme:theme withLabelConfig:config];
  if (@available(macOS 10.14, *)) {
    SquirrelTheme *darkTheme = [_view selectTheme:YES];
    [SquirrelPanel updateTheme:darkTheme withLabelConfig:config];
  }
}

+ (void)updateTheme:(SquirrelTheme *)theme withLabelConfig:(SquirrelConfig *)config {
  int menuSize = [config getInt:@"menu/page_size"] ? : 5;
  NSMutableArray<NSString *> *labels = [[NSMutableArray alloc] initWithCapacity:menuSize];
  NSString *selectKeys = [config getString:@"menu/alternative_select_keys"];
  if (selectKeys) {
    NSString *keyCaps = [[selectKeys uppercaseString]
                         stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
    for (int i = 0; i < menuSize; ++i) {
      labels[i] = [keyCaps substringWithRange:NSMakeRange(i, 1)];
    }
  } else {
    NSArray<NSString *> *selectLabels = [config getList:@"menu/alternative_select_labels"];
    if (selectLabels) {
      for (int i = 0; i < menuSize; ++i) {
        labels[i] = selectLabels[i];
      }
    } else {
      NSString *numerals = @"１２３４５６７８９０";
      for (int i = 0; i < menuSize; ++i) {
        labels[i] = [numerals substringWithRange:NSMakeRange(i, 1)];
      }
    }
  }
  [theme setLabels:labels];
}

- (void)loadConfig:(SquirrelConfig *)config forDarkMode:(BOOL)isDark {
  SquirrelTheme *theme = [_view selectTheme:isDark];
  NSSet<NSString *> *styleOptions = [NSSet setWithArray:self.optionSwitcher.optionStates];
  [SquirrelPanel updateTheme:theme withConfig:config styleOptions:styleOptions forDarkMode:isDark];
}

+ (void)updateTheme:(SquirrelTheme *)theme withConfig:(SquirrelConfig *)config styleOptions:(NSSet<NSString *> *)styleOptions forDarkMode:(BOOL)isDark {
  // INTERFACE
  BOOL linear = NO;
  BOOL tabled = NO;
  BOOL vertical = NO;
  updateCandidateListLayout(&linear, &tabled, config, @"style");
  updateTextOrientation(&vertical, config, @"style");
  NSNumber *inlinePreedit = [config getOptionalBool:@"style/inline_preedit"];
  NSNumber *inlineCandidate = [config getOptionalBool:@"style/inline_candidate"];
  NSNumber *showPaging = [config getOptionalBool:@"style/show_paging"];
  NSNumber *rememberSize = [config getOptionalBool:@"style/remember_size"];
  NSString *statusMessageType = [config getString:@"style/status_message_type"];
  NSString *candidateFormat = [config getString:@"style/candidate_format"];
  // TYPOGRAPHY
  NSString *fontName = [config getString:@"style/font_face"];
  NSNumber *fontSize = [config getOptionalDouble:@"style/font_point"];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  NSNumber *labelFontSize = [config getOptionalDouble:@"style/label_font_point"];
  NSString *commentFontName = [config getString:@"style/comment_font_face"];
  NSNumber *commentFontSize = [config getOptionalDouble:@"style/comment_font_point"];
  NSNumber *alpha = [config getOptionalDouble:@"style/alpha"];
  NSNumber *translucency = [config getOptionalDouble:@"style/translucency"];
  NSNumber *cornerRadius = [config getOptionalDouble:@"style/corner_radius"];
  NSNumber *highlightedCornerRadius = [config getOptionalDouble:@"style/hilited_corner_radius"];
  NSNumber *borderHeight = [config getOptionalDouble:@"style/border_height"];
  NSNumber *borderWidth = [config getOptionalDouble:@"style/border_width"];
  NSNumber *lineSpacing = [config getOptionalDouble:@"style/line_spacing"];
  NSNumber *spacing = [config getOptionalDouble:@"style/spacing"];
  NSNumber *baseOffset = [config getOptionalDouble:@"style/base_offset"];
  NSNumber *lineLength = [config getOptionalDouble:@"style/line_length"];
  // CHROMATICS
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
    for (NSString *option in styleOptions) {
      if ((colorScheme = [config getString:[NSString stringWithFormat:@"style/%@/color_scheme_dark", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme_dark"];
  }
  if (!colorScheme) {
    for (NSString *option in styleOptions) {
      if ((colorScheme = [config getString:[NSString stringWithFormat:@"style/%@/color_scheme", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme"];
  }
  BOOL isNative = !colorScheme || [colorScheme isEqualToString:@"native"];
  NSArray<NSString *> *configPrefixes = isNative ? [@"style/" stringsByAppendingPaths:styleOptions.allObjects] :
    [[NSArray arrayWithObject:[@"preset_color_schemes/" stringByAppendingString:colorScheme]]
      arrayByAddingObjectsFromArray:[@"style/" stringsByAppendingPaths:styleOptions.allObjects]];

  // get color scheme and then check possible overrides from styleSwitcher
  for (NSString *prefix in configPrefixes) {
    // CHROMATICS override
    if (@available(macOS 10.12, *)) {
      config.colorSpace = [config getString:[prefix stringByAppendingString:@"/color_space"]] ? : config.colorSpace;
    }
    backgroundColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]] ? : backgroundColor;
    backgroundImage = [config getPattern:[prefix stringByAppendingString:@"/back_image"]] ? : backgroundImage;
    borderColor = [config getColor:[prefix stringByAppendingString:@"/border_color"]] ? : borderColor;
    preeditBackgroundColor = [config getColor:[prefix stringByAppendingString:@"/preedit_back_color"]] ? : preeditBackgroundColor;
    textColor = [config getColor:[prefix stringByAppendingString:@"/text_color"]] ? : textColor;
    highlightedTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_text_color"]] ? : highlightedTextColor;
    highlightedBackColor = [config getColor:[prefix stringByAppendingString:@"/hilited_back_color"]] ? : highlightedBackColor;
    candidateTextColor = [config getColor:[prefix stringByAppendingString:@"/candidate_text_color"]] ? : candidateTextColor;
    highlightedCandidateTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_text_color"]] ? : highlightedCandidateTextColor;
    highlightedCandidateBackColor = [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_back_color"]] ? : highlightedCandidateBackColor;
    commentTextColor = [config getColor:[prefix stringByAppendingString:@"/comment_text_color"]] ? : commentTextColor;
    highlightedCommentTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_comment_text_color"]] ? : highlightedCommentTextColor;
    candidateLabelColor = [config getColor:[prefix stringByAppendingString:@"/label_color"]] ? : candidateLabelColor;
    // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color' are both valid
    highlightedCandidateLabelColor = [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]] ? :
      [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]] ? : highlightedCandidateLabelColor;

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style' section
    // INTERFACE override
    updateCandidateListLayout(&linear, &tabled, config, prefix);
    updateTextOrientation(&vertical, config, prefix);
    inlinePreedit = [config getOptionalBool:[prefix stringByAppendingString:@"/inline_preedit"]] ? : inlinePreedit;
    inlineCandidate = [config getOptionalBool:[prefix stringByAppendingString:@"/inline_candidate"]] ? : inlineCandidate;
    showPaging = [config getOptionalBool:[prefix stringByAppendingString:@"/show_paging"]] ? : showPaging;
    rememberSize = [config getOptionalBool:[prefix stringByAppendingString:@"/remember_size"]] ? : rememberSize;
    statusMessageType = [config getString:[prefix stringByAppendingString:@"style/status_message_type"]] ? : statusMessageType;
    candidateFormat = [config getString:[prefix stringByAppendingString:@"/candidate_format"]] ? : candidateFormat;
    // TYPOGRAPHY override
    fontName = [config getString:[prefix stringByAppendingString:@"/font_face"]] ? : fontName;
    fontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/font_point"]] ? : fontSize;
    labelFontName = [config getString:[prefix stringByAppendingString:@"/label_font_face"]] ? : labelFontName;
    labelFontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"]] ? : labelFontSize;
    commentFontName = [config getString:[prefix stringByAppendingString:@"/comment_font_face"]] ? : commentFontName;
    commentFontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"]] ? : commentFontSize;
    alpha = [config getOptionalDouble:[prefix stringByAppendingString:@"/alpha"]] ? : alpha;
    translucency = [config getOptionalDouble:[prefix stringByAppendingString:@"/translucency"]] ? : translucency;
    cornerRadius = [config getOptionalDouble:[prefix stringByAppendingString:@"/corner_radius"]] ? : cornerRadius;
    highlightedCornerRadius = [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]] ? : highlightedCornerRadius;
    borderHeight = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]] ? : borderHeight;
    borderWidth = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]] ? : borderWidth;
    lineSpacing = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]] ? : lineSpacing;
    spacing = [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]] ? : spacing;
    baseOffset = [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]] ? : baseOffset;
    lineLength = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_length"]] ? : lineLength;
  }

  // TYPOGRAPHY refinement
  fontSize = fontSize ? : @(kDefaultFontSize);
  labelFontSize = labelFontSize ? : fontSize;
  commentFontSize = commentFontSize ? : fontSize;
  NSDictionary *monoDigitAttrs = @{NSFontFeatureSettingsAttribute:
                                   @[@{NSFontFeatureTypeIdentifierKey: @(kNumberSpacingType),
                                       NSFontFeatureSelectorIdentifierKey: @(kMonospacedNumbersSelector)},
                                     @{NSFontFeatureTypeIdentifierKey: @(kTextSpacingType),
                                       NSFontFeatureSelectorIdentifierKey: @(kHalfWidthTextSelector)}] };

  NSFontDescriptor *fontDescriptor = getFontDescriptor(fontName);
  NSFont *font = [NSFont fontWithDescriptor:(fontDescriptor ? : getFontDescriptor([NSFont userFontOfSize:0].fontName))
                                       size:MAX(fontSize.doubleValue, 0)];

  NSFontDescriptor *labelFontDescriptor = [(getFontDescriptor(labelFontName) ? : fontDescriptor)
                                           fontDescriptorByAddingAttributes:monoDigitAttrs];
  NSFont *labelFont = labelFontDescriptor ? [NSFont fontWithDescriptor:labelFontDescriptor size:MAX(labelFontSize.doubleValue, 0)]
    : [NSFont monospacedDigitSystemFontOfSize:MAX(labelFontSize.doubleValue, 0) weight:NSFontWeightRegular];

  NSFontDescriptor *commentFontDescriptor = getFontDescriptor(commentFontName);
  NSFont *commentFont = [NSFont fontWithDescriptor:(commentFontDescriptor ? : fontDescriptor)
                                              size:MAX(commentFontSize.doubleValue, 0)];

  NSFont *pagingFont;
  if (@available(macOS 12.0, *)) {
    pagingFont = [NSFont monospacedDigitSystemFontOfSize:MAX(labelFontSize.doubleValue, 0) weight:NSFontWeightRegular];
  } else {
    pagingFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0]
                                             fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized]
                                       size:MAX(labelFontSize.doubleValue, 0)];
  }

  CGFloat fontHeight = getLineHeight(font, vertical);
  CGFloat labelFontHeight = getLineHeight(labelFont, vertical);
  CGFloat commentFontHeight = getLineHeight(commentFont, vertical);
  CGFloat lineHeight = MAX(fontHeight, MAX(labelFontHeight, commentFontHeight));
  CGFloat separatorWidth = ceil([[NSAttributedString alloc] initWithString:kFullWidthSpace
                                   attributes:@{NSFontAttributeName: commentFont}].size.width);

  NSMutableParagraphStyle *preeditParagraphStyle = [theme.preeditParagraphStyle mutableCopy];
  preeditParagraphStyle.minimumLineHeight = fontHeight;
  preeditParagraphStyle.maximumLineHeight = fontHeight;
  preeditParagraphStyle.paragraphSpacing = MAX(spacing.doubleValue, 0);

  NSMutableParagraphStyle *paragraphStyle = [theme.paragraphStyle mutableCopy];
  paragraphStyle.minimumLineHeight = lineHeight;
  paragraphStyle.maximumLineHeight = lineHeight;
  paragraphStyle.paragraphSpacing = MAX(lineSpacing.doubleValue / 2, 0);
  paragraphStyle.paragraphSpacingBefore = MAX(lineSpacing.doubleValue / 2, 0);
  paragraphStyle.tabStops = @[];
  paragraphStyle.defaultTabInterval = separatorWidth * 2;

  NSMutableParagraphStyle *pagingParagraphStyle = [theme.pagingParagraphStyle mutableCopy];
  pagingParagraphStyle.minimumLineHeight = pagingFont.ascender - pagingFont.descender;
  pagingParagraphStyle.maximumLineHeight = pagingFont.ascender - pagingFont.descender;

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
  NSMutableDictionary *statusAttrs = [theme.statusAttrs mutableCopy];

  attrs[NSFontAttributeName] = font;
  highlightedAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  commentHighlightedAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  preeditHighlightedAttrs[NSFontAttributeName] = font;
  pagingAttrs[NSFontAttributeName] = linear ? labelFont : pagingFont;
  statusAttrs[NSFontAttributeName] = commentFont;

  NSFont *refFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)font, (CFStringRef)kFullWidthSpace, CFRangeMake(0, 1)));
  labelAttrs[CFBridgingRelease(kCTBaselineClassAttributeName)] = CFBridgingRelease(kCTBaselineClassIdeographicCentered);
  labelHighlightedAttrs[CFBridgingRelease(kCTBaselineClassAttributeName)] = CFBridgingRelease(kCTBaselineClassIdeographicCentered);
  labelAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): refFont};
  labelHighlightedAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): refFont};

  attrs[NSBaselineOffsetAttributeName] = baseOffset;
  highlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  labelAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  commentAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  preeditAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  pagingAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  statusAttrs[NSBaselineOffsetAttributeName] = baseOffset;

  preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  preeditHighlightedAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  // CHROMATICS refinement
  NSColor *secondaryTextColor = [SquirrelPanel secondaryTextColor];
  NSColor *accentColor = [SquirrelPanel accentColor];

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

  backgroundColor = backgroundColor ? : [NSColor controlBackgroundColor];
  borderColor = borderColor ? : isNative ? [NSColor gridColor] : nil;
  preeditBackgroundColor = preeditBackgroundColor ? : isNative ? [NSColor windowBackgroundColor] : nil;
  candidateTextColor = candidateTextColor ? : [NSColor controlTextColor];
  highlightedCandidateTextColor = highlightedCandidateTextColor ? : [NSColor selectedMenuItemTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? : isNative ? [NSColor alternateSelectedControlColor] : nil;
  candidateLabelColor = candidateLabelColor ? : isNative ? accentColor : blendColors(highlightedCandidateBackColor, highlightedCandidateTextColor);
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? : isNative ? [NSColor alternateSelectedControlTextColor] : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? : secondaryTextColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? : [NSColor alternateSelectedControlTextColor];
  textColor = textColor ? textColor : [NSColor textColor];
  highlightedTextColor = highlightedTextColor ? : [NSColor selectedTextColor];
  highlightedBackColor = highlightedBackColor ? : isNative ? [NSColor selectedTextBackgroundColor] : nil;

  attrs[NSForegroundColorAttributeName] = candidateTextColor;
  highlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateTextColor;
  labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
  labelHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCandidateLabelColor;
  commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
  commentHighlightedAttrs[NSForegroundColorAttributeName] = highlightedCommentTextColor;
  preeditAttrs[NSForegroundColorAttributeName] = textColor;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = highlightedTextColor;
  pagingAttrs[NSForegroundColorAttributeName] = linear ? candidateLabelColor : textColor;
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = linear ? highlightedCandidateLabelColor : highlightedTextColor;
  statusAttrs[NSForegroundColorAttributeName] = commentTextColor;

  NSSize edgeInset = vertical ? NSMakeSize(MAX(borderHeight.doubleValue, 0), MAX(borderWidth.doubleValue, 0)) :
    NSMakeSize(MAX(borderWidth.doubleValue, 0), MAX(borderHeight.doubleValue, 0));

  [theme  setCornerRadius:MIN(cornerRadius.doubleValue, lineHeight / 2)
  highlightedCornerRadius:MIN(highlightedCornerRadius.doubleValue, lineHeight / 3)
           separatorWidth:separatorWidth
                edgeInset:edgeInset
                linespace:MAX(lineSpacing.doubleValue, 0)
         preeditLinespace:MAX(spacing.doubleValue, 0)
                    alpha:(alpha ? MIN(MAX(alpha.doubleValue, 0.0), 1.0) : 1.0)
             translucency:(translucency ? MIN(MAX(translucency.doubleValue, 0.0), 1.0) : 0.0)
               lineLength:lineLength.doubleValue ? MAX(lineLength.doubleValue, separatorWidth * 5) : 0.0
               showPaging:showPaging.boolValue
             rememberSize:rememberSize.boolValue
                   tabled:tabled
                   linear:linear
                 vertical:vertical
            inlinePreedit:inlinePreedit.boolValue
          inlineCandidate:inlineCandidate.boolValue];

  [theme         setAttrs:attrs
         highlightedAttrs:highlightedAttrs
               labelAttrs:labelAttrs
    labelHighlightedAttrs:labelHighlightedAttrs
             commentAttrs:commentAttrs
  commentHighlightedAttrs:commentHighlightedAttrs
             preeditAttrs:preeditAttrs
  preeditHighlightedAttrs:preeditHighlightedAttrs
              pagingAttrs:pagingAttrs
   pagingHighlightedAttrs:pagingHighlightedAttrs
              statusAttrs:statusAttrs];

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

  [theme setCandidateFormat:candidateFormat ? : kDefaultCandidateFormat];
  [theme setStatusMessageType:statusMessageType];
}

@end
