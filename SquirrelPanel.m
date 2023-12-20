#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOffsetHeight = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *kDefaultCandidateFormat = @"%c. %@";
static NSString *kTipSpecifier = @"%s";
static NSString *kFullWidthSpace = @"　";

@implementation NSBezierPath (BezierPathQuartzUtilities)

- (CGPathRef)quartzPath {
  if (@available(macOS 14.0, *)) {
    return self.CGPath;
  } else {
    // Need to begin a path here.
    CGPathRef immutablePath = NULL;
    // Then draw the path elements.
    NSInteger numElements = self.elementCount;
    if (numElements > 0) {
      CGMutablePathRef path = CGPathCreateMutable();
      NSPoint points[3];
      BOOL didClosePath = YES;
      for (NSInteger i = 0; i < numElements; i++) {
        switch ([self elementAtIndex:i associatedPoints:points]) {
          case NSBezierPathElementMoveTo:
            CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
            break;
          case NSBezierPathElementLineTo:
            CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
            didClosePath = NO;
            break;
          case NSBezierPathElementCurveTo:
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
          case NSBezierPathElementClosePath:
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

@end // NSBezierPath (BezierPathQuartzUtilities)


@implementation NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)

- (void)formatMarkDown {
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:
    @"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|<(b|strong|i|em|u|sup|sub|s)>)(.+?)(\\2|\\3(?=\\b)|<\\/\\4>)"
    options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
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
                    usingBlock:^(NSFont *value, NSRange range, BOOL *stop) {
        NSFont *font = [NSFont fontWithDescriptor:[value fontDescriptor] size:[value pointSize] * 7 / 12];
        [self addAttribute:NSFontAttributeName value:font range:range];
      }];
    } else if ([tag isEqualToString:@"~"] || [tag isEqualToString:@"<sub>"]) {
      [self subscriptRange:[result rangeAtIndex:5]];
      [self enumerateAttribute:NSFontAttributeName inRange:[result rangeAtIndex:5] options:0
                    usingBlock:^(NSFont *value, NSRange range, BOOL *stop) {
        NSFont *font = [NSFont fontWithDescriptor:[value fontDescriptor] size:[value pointSize] * 7 / 12];
        [self addAttribute:NSFontAttributeName value:font range:range];
      }];
    }
    [self deleteCharactersInRange:[result rangeAtIndex:6]];
    [self deleteCharactersInRange:[result rangeAtIndex:1]];
    offset -= [result rangeAtIndex:6].length + [result rangeAtIndex:1].length;
  }];
  if (offset != 0) { // repeat until no more nested markdown
    [self formatMarkDown];
  }
}

- (CGFloat)annotateRubyInRange:(NSRange)range
                verticalLayout:(BOOL)isVertical
                 maximumLength:(CGFloat)maxLength {
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:
                                @"(\uFFF9\\s*)(\\S+?)(\\s*\uFFFA(.+?)\uFFFB)" options:0 error:nil];
  CGFloat __block rubyLineHeight = 0.0;
  NSInteger __block offset = 0;
  [regex enumerateMatchesInString:self.mutableString options:0 range:range
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
    result = [result resultByAdjustingRangesWithOffset:offset];
    NSRange baseRange = [result rangeAtIndex:2];
    // no ruby annotation if the base string includes line breaks
    if ([self attributedSubstringFromRange:NSMakeRange(0, NSMaxRange(baseRange))].size.width > maxLength) {
      [self deleteCharactersInRange:NSMakeRange(NSMaxRange([result range]) - 1, 1)];
      [self deleteCharactersInRange:NSMakeRange([result rangeAtIndex:3].location, 1)];
      [self deleteCharactersInRange:NSMakeRange([result rangeAtIndex:1].location, 1)];
      offset -= 3;
    } else {
      // base string must use only one font so that all fall within one glyph run and the ruby annotation is aligned with no duplicates
      NSFont *baseFont = [self attribute:NSFontAttributeName atIndex:baseRange.location effectiveRange:NULL];
      baseFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)baseFont, (CFStringRef)self.string,
                                                         CFRangeMake((int)baseRange.location, (int)baseRange.length)));
      [self addAttribute:NSFontAttributeName value:baseFont range:baseRange];

      CGFloat rubyScale = 0.5;
      CFStringRef rubyString = (__bridge CFStringRef)[self.string substringWithRange:[result rangeAtIndex:4]];
      NSFont *rubyFont = [self attribute:NSFontAttributeName atIndex:[result rangeAtIndex:4].location effectiveRange:NULL];
      rubyFont = [NSFont fontWithDescriptor:rubyFont.fontDescriptor size:rubyFont.pointSize * rubyScale];
      rubyFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)rubyFont, rubyString,
                                                         CFRangeMake(0, CFStringGetLength(rubyString))));
      rubyLineHeight = MAX(rubyLineHeight, isVertical ? rubyFont.verticalFont.ascender - rubyFont.verticalFont.descender : rubyFont.ascender - rubyFont.descender);
      CGColorRef rubyColor = [[self attribute:NSForegroundColorAttributeName
                                      atIndex:[result rangeAtIndex:4].location effectiveRange:NULL] CGColor];
      CGFloat rubyBaselineOffset;
      if (@available(macOS 12.0, *)) {
        rubyBaselineOffset = isVertical ? rubyFont.verticalFont.ascender - rubyFont.verticalFont.descender : -rubyFont.descender;
      } else {
        rubyBaselineOffset = isVertical ? rubyFont.verticalFont.ascender : -rubyFont.descender;
      }
      CFTypeRef keys[] = {kCTFontAttributeName, kCTForegroundColorAttributeName,
        kCTBaselineOffsetAttributeName, kCTRubyAnnotationSizeFactorAttributeName,
        kCTRubyAnnotationScaleToFitAttributeName};
      CFTypeRef values[] = {(__bridge CTFontRef)rubyFont, rubyColor,
        CFNumberCreate(NULL, kCFNumberDoubleType, &rubyBaselineOffset),
        CFNumberCreate(NULL, kCFNumberDoubleType, &rubyScale), kCFBooleanFalse};
      CFDictionaryRef rubyAttrs = CFDictionaryCreate(NULL, keys, values, 5, &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
      CTRubyAnnotationRef rubyAnnotation = CTRubyAnnotationCreateWithAttributes(kCTRubyAlignmentDistributeSpace,
                                             kCTRubyOverhangAuto, kCTRubyPositionBefore, rubyString, rubyAttrs);

      [self deleteCharactersInRange:[result rangeAtIndex:3]];
      if (@available(macOS 12.0, *)) {
        [self addAttributes:@{CFBridgingRelease(kCTRubyAnnotationAttributeName): CFBridgingRelease(rubyAnnotation),
                              NSVerticalGlyphFormAttributeName: @(isVertical)} range:baseRange];
        [self deleteCharactersInRange:[result rangeAtIndex:1]];
        offset -= [result rangeAtIndex:3].length + [result rangeAtIndex:1].length;
      } else {
        // use U+008B as placeholder for line-forward spaces in case ruby is wider than base
        [self replaceCharactersInRange:NSMakeRange(NSMaxRange(baseRange), 0) withString:[NSString stringWithFormat:@"%C", 0x8B]];
        baseRange.length += 1;
        [self addAttributes:@{CFBridgingRelease(kCTRubyAnnotationAttributeName): CFBridgingRelease(rubyAnnotation),
                              NSVerticalGlyphFormAttributeName: @(isVertical)} range:baseRange];
        [self deleteCharactersInRange:[result rangeAtIndex:1]];
        offset -= [result rangeAtIndex:3].length - 1 + [result rangeAtIndex:1].length;
      }
    }
  }];
  return rubyLineHeight;
}

@end // NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)


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

@property(nonatomic, strong, readonly) NSAttributedString *separator;
@property(nonatomic, strong, readonly) NSAttributedString *symbolBackFill;
@property(nonatomic, strong, readonly) NSAttributedString *symbolBackStroke;
@property(nonatomic, strong, readonly) NSAttributedString *symbolForwardFill;
@property(nonatomic, strong, readonly) NSAttributedString *symbolForwardStroke;

@property(nonatomic, strong, readonly) NSString *selectKeys;
@property(nonatomic, strong, readonly) NSString *candidateFormat;
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

- (void)setSelectKeys:(NSString *)selectKeys
               labels:(NSArray<NSString *> *)labels
         directUpdate:(BOOL)update;

- (void)setCandidateFormat:(NSString *)candidateFormat;

- (void)updateCandidateFormats;

- (void)setStatusMessageType:(NSString *)statusMessageType;

- (void)setAnnotationHeight:(CGFloat)height;

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

  NSMutableDictionary *sepAttrs = [commentAttrs mutableCopy];
  sepAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  _separator = [[NSAttributedString alloc] initWithString:_linear ? (_tabled ? [kFullWidthSpace stringByAppendingString:@"\t"] : kFullWidthSpace) : @"\n" attributes:sepAttrs];

  NSMutableDictionary *symbolAttrs = [pagingAttrs mutableCopy];
  if (@available(macOS 12.0, *)) {
    NSTextAttachment *attmLeftFill = [[NSTextAttachment alloc] init];
    attmLeftFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.left.circle.fill" accessibilityDescription:nil];
    NSTextAttachment *attmLeftStroke = [[NSTextAttachment alloc] init];
    attmLeftStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.left.circle" accessibilityDescription:nil];
    NSTextAttachment *attmRightFill = [[NSTextAttachment alloc] init];
    attmRightFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.right.circle.fill" accessibilityDescription:nil];
    NSTextAttachment *attmRightStroke = [[NSTextAttachment alloc] init];
    attmRightStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.right.circle" accessibilityDescription:nil];
    NSTextAttachment *attmUpFill = [[NSTextAttachment alloc] init];
    attmUpFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.up.circle.fill" accessibilityDescription:nil];
    NSTextAttachment *attmUpStroke = [[NSTextAttachment alloc] init];
    attmUpStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.up.circle" accessibilityDescription:nil];
    NSTextAttachment *attmDownFill = [[NSTextAttachment alloc] init];
    attmDownFill.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.down.circle.fill" accessibilityDescription:nil];
    NSTextAttachment *attmDownStroke = [[NSTextAttachment alloc] init];
    attmDownStroke.image = [NSImage imageWithSystemSymbolName:@"arrowtriangle.down.circle" accessibilityDescription:nil];

    NSMutableDictionary *attrsBackFill = [symbolAttrs mutableCopy];
    attrsBackFill[NSAttachmentAttributeName] = _linear ? attmUpFill : attmLeftFill;
    _symbolBackFill = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsBackFill];
    NSMutableDictionary *attrsBackStroke = [symbolAttrs mutableCopy];
    attrsBackStroke[NSAttachmentAttributeName] = _linear ? attmUpStroke : attmLeftStroke;
    _symbolBackStroke = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsBackStroke];
    NSMutableDictionary *attrsForwardFill = [symbolAttrs mutableCopy];
    attrsForwardFill[NSAttachmentAttributeName] = _linear ? attmDownFill : attmRightFill;
    _symbolForwardFill = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsForwardFill];
    NSMutableDictionary *attrsForwardStroke = [symbolAttrs mutableCopy];
    attrsForwardStroke[NSAttachmentAttributeName] = _linear ? attmDownStroke : attmRightStroke;
    _symbolForwardStroke = [[NSAttributedString alloc] initWithString:@"\uFFFC" attributes:attrsForwardStroke];
  } else {
    NSFont *symbolFont = [NSFont fontWithDescriptor:[[NSFontDescriptor fontDescriptorWithName:@"AppleSymbols" size:0.0]
                          fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized]
                                                      size:[labelAttrs[NSFontAttributeName] pointSize]];
    if (_linear) {
      CGAffineTransform transform = CGAffineTransformMakeRotation(-M_PI_2);
      CTFontRef rotatedSymbolFont = CTFontCreateCopyWithSymbolicTraits((CTFontRef)symbolFont, symbolFont.pointSize, &transform, kCTFontTraitVertical, kCTFontTraitClassMask);
      symbolAttrs[NSFontAttributeName] = CFBridgingRelease(rotatedSymbolFont);
      symbolAttrs[NSBaselineOffsetAttributeName] = @([pagingAttrs[NSBaselineOffsetAttributeName] doubleValue] + symbolFont.ascender);
      symbolAttrs[CFBridgingRelease(kCTTrackingAttributeName)] = @(symbolFont.ascender);
    } else {
      symbolAttrs[NSFontAttributeName] = symbolFont;
      symbolAttrs[NSBaselineOffsetAttributeName] = @([pagingAttrs[NSBaselineOffsetAttributeName] doubleValue] - symbolFont.leading);
    }
    NSMutableDictionary *symbolAttrsBackFill = [symbolAttrs mutableCopy];
    NSMutableDictionary *symbolAttrsBackStroke = [symbolAttrs mutableCopy];
    NSMutableDictionary *symbolAttrsForwardFill = [symbolAttrs mutableCopy];
    NSMutableDictionary *symbolAttrsForwardStroke = [symbolAttrs mutableCopy];
    symbolAttrsBackFill[NSGlyphInfoAttributeName] = [NSGlyphInfo glyphInfoWithCGGlyph:0xE92 forFont:symbolFont baseString:@"◀"]; //gid4966
    symbolAttrsBackStroke[NSGlyphInfoAttributeName] = [NSGlyphInfo glyphInfoWithCGGlyph:0xE95 forFont:symbolFont baseString:@"◁"]; //gid4969
    symbolAttrsForwardFill[NSGlyphInfoAttributeName] = [NSGlyphInfo glyphInfoWithCGGlyph:0xE93 forFont:symbolFont baseString:@"▶"]; //gid4967
    symbolAttrsForwardStroke[NSGlyphInfoAttributeName] = [NSGlyphInfo glyphInfoWithCGGlyph:0xE94 forFont:symbolFont baseString:@"▷"]; //gid4968
    _symbolBackFill = [[NSAttributedString alloc] initWithString:@"◀" attributes:symbolAttrsBackFill];
    _symbolBackStroke = [[NSAttributedString alloc] initWithString:@"◁" attributes:symbolAttrsBackStroke];
    _symbolForwardFill = [[NSAttributedString alloc] initWithString:@"▶" attributes:symbolAttrsForwardFill];
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

- (void)setSelectKeys:(NSString *)selectKeys 
               labels:(NSArray<NSString *> *)labels
         directUpdate:(BOOL)update {
  _selectKeys = selectKeys;
  _labels = labels;
  if (update && _candidateFormat) {
    [self updateCandidateFormats];
  }
}

- (void)setCandidateFormat:(NSString *)candidateFormat {
  _candidateFormat = candidateFormat;
  [self updateCandidateFormats];
}

- (void)updateCandidateFormats {
  // validate candidate format: must have enumerator '%c' before candidate '%@'
  NSMutableString *candidateFormat = [_candidateFormat mutableCopy];
  if (![candidateFormat containsString:@"%@"]) {
    [candidateFormat appendString:@"%@"];
  }
  if (![candidateFormat containsString:@"%c"]) {
    [candidateFormat insertString:@"%c" atIndex:0];
  }
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@"];
  NSRange labelRange = [candidateFormat rangeOfString:@"%c"];
  if (labelRange.location > candidateRange.location) {
    [candidateFormat setString:kDefaultCandidateFormat];
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

- (void)setAnnotationHeight:(CGFloat)height {
  if (height > 0 && _linespace < height * 2) {
    _linespace = height * 2;
    NSMutableParagraphStyle *paragraphStyle = [_paragraphStyle mutableCopy];
    paragraphStyle.paragraphSpacingBefore = height;
    paragraphStyle.paragraphSpacing = height;
    _paragraphStyle = paragraphStyle;
  }
}

@end // SquirrelTheme


@interface SquirrelLayoutManager : NSLayoutManager <NSLayoutManagerDelegate>
@end

@implementation SquirrelLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange
                        atPoint:(NSPoint)origin {
  NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
  NSTextContainer *textContainer = [self textContainerForGlyphAtIndex:glyphRange.location effectiveRange:NULL withoutAdditionalLayout:YES];
  CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
  CGContextResetClip(context);
  [self.textStorage enumerateAttributesInRange:charRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                    usingBlock:^(NSDictionary<NSAttributedStringKey,id> *attrs, NSRange range, BOOL *stop) {
    NSRange glyRange = [self glyphRangeForCharacterRange:range actualCharacterRange:NULL];
    if (attrs[CFBridgingRelease(kCTRubyAnnotationAttributeName)]) {
      CGContextSaveGState(context);
      CGContextScaleCTM(context, 1.0, -1.0);
      NSUInteger glyphIndex = glyRange.location;
      NSRect lineRect = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:NULL withoutAdditionalLayout:YES];
      CTLineRef line = CTLineCreateWithAttributedString(
                         (CFAttributedStringRef)[self.textStorage attributedSubstringFromRange:range]);
      CFArrayRef runs = CTLineGetGlyphRuns(line);
      for (CFIndex i = 0; i < CFArrayGetCount(runs); ++i) {
        CGPoint position = [self locationForGlyphAtIndex:glyphIndex];
        CTRunRef run = CFArrayGetValueAtIndex(runs, i);
        CGAffineTransform matrix = CTRunGetTextMatrix(run);
        matrix.tx = origin.x + NSMinX(lineRect) + position.x;
        matrix.ty = - origin.y - NSMinY(lineRect) - position.y;
        CGContextSetTextMatrix(context, matrix);
        CTRunDraw(run, context, CFRangeMake(0, 0));
        glyphIndex += (NSUInteger)CTRunGetGlyphCount(run);
      }
      CGContextRestoreGState(context);
      CFRelease(line);
    } else {
      [super drawGlyphsForGlyphRange:glyRange atPoint:origin];
    }
  }];
  CGContextClipToRect(context, textContainer.textView.superview.bounds);
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager
                          shouldUseAction:(NSControlCharacterAction)action
               forControlCharacterAtIndex:(NSUInteger)charIndex {
  if ([layoutManager.textStorage.string characterAtIndex:charIndex] == 0x8B &&
      [layoutManager.textStorage attribute:CFBridgingRelease(kCTRubyAnnotationAttributeName) atIndex:charIndex effectiveRange:NULL]) {
    return NSControlCharacterActionWhitespace;
  } else {
    return action;
  }
}

- (NSRect)            layoutManager:(NSLayoutManager *)layoutManager
  boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex
                   forTextContainer:(NSTextContainer *)textContainer
               proposedLineFragment:(NSRect)proposedRect
                      glyphPosition:(NSPoint)glyphPosition
                     characterIndex:(NSUInteger)charIndex {
  CGFloat width = 0.0;
  if ([layoutManager.textStorage.string characterAtIndex:charIndex] == 0x8B) {
    NSRange rubyRange;
    id rubyAnnotation = [layoutManager.textStorage attribute:CFBridgingRelease(kCTRubyAnnotationAttributeName) atIndex:charIndex effectiveRange:&rubyRange];
    if (rubyAnnotation) {
      NSAttributedString *rubyString = [layoutManager.textStorage attributedSubstringFromRange:rubyRange];
      CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)rubyString);
      CGRect rubyRect = CTLineGetBoundsWithOptions(line, 0);
      CFRelease(line);
      NSSize baseSize = rubyString.size;
      width = MAX(0.0, rubyRect.size.width - baseSize.width);
    }
  }
  return NSMakeRect(glyphPosition.x, 0.0, width, glyphPosition.y);
}

@end // SquirrelLayoutManager


API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutFragment : NSTextLayoutFragment
@end

@implementation SquirrelTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point
          inContext:(CGContextRef)context {
  BOOL vertical = self.textLayoutManager.textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  NSArray<NSTextLineFragment *> *lineFragments = self.textLineFragments;
  for (NSTextLineFragment *lineFrag in lineFragments) {
    NSFont *refFont = [lineFrag.attributedString 
                       attribute:CFBridgingRelease(kCTBaselineReferenceInfoAttributeName) atIndex:0
                       effectiveRange:NULL][CFBridgingRelease(kCTBaselineReferenceFont)];
    CGPoint renderOrigin = CGPointMake(point.x + NSMinX(lineFrag.typographicBounds) + lineFrag.glyphOrigin.x,
                                       point.y + NSMidY(lineFrag.typographicBounds) - lineFrag.glyphOrigin.y +
                                         (vertical ? 0.0 : refFont.ascender / 2 + refFont.descender / 2));
    [lineFrag drawAtPoint:renderOrigin inContext:context];
  }
}

@end // SquirrelTextLayoutFragment


API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutManager : NSTextLayoutManager <NSTextLayoutManagerDelegate>
@end

@implementation SquirrelTextLayoutManager

- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager
              textLayoutFragmentForLocation:(id<NSTextLocation>)location
                              inTextElement:(NSTextElement *)textElement {
  return [[SquirrelTextLayoutFragment alloc] initWithTextElement:textElement range:textElement.elementRange];
}

@end // SquirrelTextLayoutManager


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
@property(nonatomic, readonly) SquirrelAppear appear;

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

- (SquirrelAppear)appear {
  if ([NSApp.effectiveAppearance bestMatchFromAppearancesWithNames:
       @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua) {
    return darkAppear;
  }
  return defaultAppear;
}

- (BOOL)allowsVibrancy {
  return YES;
}

- (SquirrelTheme *)selectTheme:(SquirrelAppear)appear {
  return appear == darkAppear ? _darkTheme : _defaultTheme;
}

- (SquirrelTheme *)currentTheme {
  return [self selectTheme:self.appear];
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
    SquirrelTextLayoutManager *textLayoutManager = [[SquirrelTextLayoutManager alloc] init];
    textLayoutManager.usesFontLeading = NO;
    textLayoutManager.delegate = textLayoutManager;
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
    SquirrelLayoutManager *layoutManager = [[SquirrelLayoutManager alloc] init];
    layoutManager.backgroundLayoutEnabled = YES;
    layoutManager.usesFontLeading = NO;
    layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
    layoutManager.delegate = layoutManager;
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
  _darkTheme = [[SquirrelTheme alloc] init];
  return self;
}

- (NSTextRange *)getTextRangeFromCharRange:(NSRange)charRange API_AVAILABLE(macos(12.0)) {
  if (charRange.location == NSNotFound) {
    return nil;
  } else {
    NSTextContentStorage *contentStorage = _textView.textContentStorage;
    id<NSTextLocation> startLocation = [contentStorage locationFromLocation:contentStorage.documentRange.location
                                                                 withOffset:(NSInteger)charRange.location];
    id<NSTextLocation> endLocation = [contentStorage locationFromLocation:startLocation
                                                               withOffset:(NSInteger)charRange.length];
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
    NSTextRange *textRange = [self getTextRangeFromCharRange:range];
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
- (void)multilineRectForRange:(NSRange)charRange 
                  leadingRect:(NSRectPointer)leadingRect
                     bodyRect:(NSRectPointer)bodyRect
                 trailingRect:(NSRectPointer)trailingRect {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromCharRange:charRange];
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
  NSRect textContainerRect = [self backingAlignedRect:NSInsetRect(backgroundRect, theme.edgeInset.width, theme.edgeInset.height)
                                options:NSAlignMinXOutward|NSAlignMinYOutward|NSAlignWidthNearest|NSAlignHeightNearest|NSAlignRectFlipped];

  NSRange visibleRange;
  if (@available(macOS 12.0, *)) {
    visibleRange = NSMakeRange(0, _textStorage.length);
  } else {
    NSRange containerGlyphRange = {NSNotFound, 0};
    [_textView.layoutManager textContainerForGlyphAtIndex:0 effectiveRange:&containerGlyphRange];
    visibleRange = [_textView.layoutManager characterRangeForGlyphRange:containerGlyphRange actualGlyphRange:NULL];
  }
  NSRange preeditRange = NSIntersectionRange(_preeditRange, visibleRange);
  NSRange candidateBlockRange = NSIntersectionRange(NSUnionRange(_candidateRanges.firstObject.rangeValue,
    theme.linear && _pagingRange.length > 0 ? _pagingRange : _candidateRanges.lastObject.rangeValue), visibleRange);
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
      candidateBlockRect.origin = textContainerRect.origin;
    }
  }
  if (pagingRange.length > 0) {
    pagingLineRect = [self contentRectForRange:pagingRange];
    if (!theme.linear) {
      pagingLineRect.origin.y -= theme.pagingParagraphStyle.paragraphSpacingBefore;
      pagingLineRect.size.height += theme.pagingParagraphStyle.paragraphSpacingBefore;
    }
  }

  [NSBezierPath setDefaultLineWidth:0];
  // Draw preedit Rect
  if (preeditRange.length > 0) {
    preeditRect.size.width = textContainerRect.size.width;
    preeditRect.origin = textContainerRect.origin;
    preeditRect = [self backingAlignedRect:preeditRect
                    options:NSAlignMinXOutward|NSAlignMinYOutward|NSAlignWidthNearest|NSAlignHeightNearest|NSAlignRectFlipped];
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
      leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(leadingRect, innerBox)
                      options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
      bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(bodyRect, innerBox)
                   options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
      trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : [self backingAlignedRect:NSIntersectionRect(trailingRect, innerBox)
                       options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
      NSArray<NSValue *> *highlightedPreeditPoints;
      NSArray<NSValue *> *highlightedPreeditPoints2;
      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) &&
          NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPreeditPoints = rectVertex(leadingRect);
        highlightedPreeditPoints2 = rectVertex(trailingRect);
      } else {
        highlightedPreeditPoints = multilineRectVertex(leadingRect, bodyRect, trailingRect);
      }
      highlightedPreeditPath = drawRoundedPolygon(highlightedPreeditPoints,
        MIN(theme.highlightedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight / 3));
      if (highlightedPreeditPoints2) {
        [highlightedPreeditPath appendBezierPath:drawRoundedPolygon(highlightedPreeditPoints2,
          MIN(theme.highlightedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight / 3))];
      }
    }
  }

  // Draw candidate Rect
  if (candidateBlockRange.length > 0) {
    candidateBlockRect.size.width = textContainerRect.size.width;
    candidateBlockRect.origin.x = textContainerRect.origin.x;
    candidateBlockRect = [self backingAlignedRect:NSIntersectionRect(candidateBlockRect, textContainerRect)
                            options:NSAlignMinXOutward|NSAlignMinYOutward|NSAlignWidthNearest|NSAlignHeightNearest|NSAlignRectFlipped];
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
        leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect : NSInsetRect(leadingRect, -theme.separatorWidth / 2, 0);
        bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect : NSInsetRect(bodyRect, -theme.separatorWidth / 2, 0);
        trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect : NSInsetRect(trailingRect, -theme.separatorWidth / 2, 0);
        if (!NSIsEmptyRect(leadingRect)) {
          leadingRect.origin.y -= theme.linespace / 2;
          leadingRect.size.height += theme.linespace / 2;
          leadingRect = [self backingAlignedRect:NSIntersectionRect(leadingRect, candidateBlockRect)
                                         options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
        }
        if (!NSIsEmptyRect(trailingRect)) {
          trailingRect.size.height += theme.linespace / 2;
          trailingRect =  [self backingAlignedRect:NSIntersectionRect(trailingRect, candidateBlockRect)
                                           options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
        }
        if (!NSIsEmptyRect(bodyRect)) {
          if (NSIsEmptyRect(leadingRect)) {
            bodyRect.origin.y -= theme.linespace / 2;
            bodyRect.size.height += theme.linespace / 2;
          }
          if (NSIsEmptyRect(trailingRect)) {
            bodyRect.size.height += theme.linespace / 2;
          }
          bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, candidateBlockRect)
                                      options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
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
            [candidateVertGridPath moveToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + theme.linespace / 2 + theme.paragraphStyle.maximumLineHeight - theme.highlightedCornerRadius / 2)];
            [candidateVertGridPath lineToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + theme.linespace / 2 + theme.highlightedCornerRadius / 2)];
            [candidateVertGridPath closePath];
          }
          CGFloat endEdge = NSMaxX(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          CGFloat tabPosition = ceil((endEdge - textContainerRect.origin.x) / tabInterval / 2) * tabInterval * 2 + textContainerRect.origin.x;
          if (i == _candidateRanges.count - 1 && pagingRange.length > 0 &&
              bottomEdge > NSMinY(pagingLineRect) && tabPosition > NSMinX(pagingLineRect)) {
            tabPosition -= tabInterval;
          }
          if (NSIsEmptyRect(trailingRect)) {
            bodyRect.size.width += tabPosition - endEdge;
            bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, candidateBlockRect)
                                        options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
          } else if (NSIsEmptyRect(bodyRect)) {
            trailingRect.size.width += tabPosition - endEdge;
            trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, candidateBlockRect)
                                            options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
          } else {
            bodyRect = NSMakeRect(NSMinX(candidateBlockRect), NSMinY(bodyRect),
                                  NSWidth(candidateBlockRect), NSHeight(bodyRect) + NSHeight(trailingRect));
            trailingRect = NSZeroRect;
            bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, candidateBlockRect)
                                        options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
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
        if (candidatePoints2) {
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
        candidateRect = [self backingAlignedRect:NSIntersectionRect(candidateRect, candidateBlockRect)
                          options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
        NSArray<NSValue *> *candidatePoints = rectVertex(candidateRect);
        NSBezierPath *candidatePath = drawRoundedPolygon(candidatePoints, theme.highlightedCornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
  }

  // Draw paging Rect
  if (pagingRange.length > 0) {
    NSRect pageDownRect = [self contentRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)];
    pageDownRect.size.width += theme.separatorWidth / 2;
    NSRect pageUpRect = [self contentRectForRange:NSMakeRange(pagingRange.location, 1)];
    pageUpRect.origin.x -= theme.separatorWidth / 2;
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    if (theme.linear) {
      pageDownRect = NSInsetRect(pageDownRect, 0.0, -theme.linespace / 2);
      pageUpRect = NSInsetRect(pageUpRect, 0.0, -theme.linespace / 2);
    }
    pageDownRect = [self backingAlignedRect:NSIntersectionRect(pageDownRect, candidateBlockRect)
                     options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
    pageUpRect = [self backingAlignedRect:NSIntersectionRect(pageUpRect, candidateBlockRect)
                   options:NSAlignAllEdgesOutward|NSAlignRectFlipped];
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
    borderPath.windingRule = NSWindingRuleEvenOdd;
  }

  // Set layers
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
      const CGAffineTransform rotate = CGAffineTransformMakeRotation(-M_PI_2);
      backgroundImageLayer.path = CFAutorelease(CGPathCreateCopyByTransformingPath([textContainerPath quartzPath], &rotate));
      backgroundImageLayer.fillColor = [theme.backgroundImage CGColor];
      [backgroundImageLayer setAffineTransform:CGAffineTransformInvert(rotate)];
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
      textContainerPath.windingRule = NSWindingRuleEvenOdd;
      backgroundLayer.path = [textContainerPath quartzPath];
      backgroundLayer.fillRule = kCAFillRuleEvenOdd;
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = [candidateBlockPath quartzPath];
      candidateLayer.fillColor = [theme.backgroundColor CGColor];
      candidateLayer.shadowOpacity = [theme.backgroundColor brightnessComponent];
      candidateLayer.shadowOffset = NSMakeSize(theme.preeditLinespace / 2, - theme.preeditLinespace / 2);
      [panelLayer addSublayer:candidateLayer];
    }
  }
  if (theme.translucency > 0) {
    panelLayer.opacity = (float)(1.0 - theme.translucency);
  }
  if (_highlightedIndex < _candidatePaths.count && theme.highlightedStripColor) {
    CAShapeLayer *highlightedLayer = [[CAShapeLayer alloc] init];
    highlightedPath = _candidatePaths[_highlightedIndex];
    highlightedLayer.path = [highlightedPath quartzPath];
    highlightedLayer.fillColor = [theme.highlightedStripColor CGColor];
    highlightedLayer.shadowOpacity = [theme.backgroundColor brightnessComponent];
    highlightedLayer.shadowOffset = NSMakeSize(theme.highlightedCornerRadius / 2, - theme.highlightedCornerRadius / 2);
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
      case NSPageUpFunctionKey:
        pagingLayer.path = [pageUpPath quartzPath];
        pagingLayer.fillColor = [[buttonColor colorWithSystemEffect:NSColorSystemEffectRollover] CGColor];
        break;
      case NSBeginFunctionKey:
        pagingLayer.path = [pageUpPath quartzPath];
        pagingLayer.fillColor = [[buttonColor colorWithSystemEffect:NSColorSystemEffectDisabled] CGColor];
        break;
      case NSPageDownFunctionKey:
        pagingLayer.path = [pageDownPath quartzPath];
        pagingLayer.fillColor = [[buttonColor colorWithSystemEffect:NSColorSystemEffectRollover] CGColor];
        break;
      case NSEndFunctionKey:
        pagingLayer.path = [pageDownPath quartzPath];
        pagingLayer.fillColor = [[buttonColor colorWithSystemEffect:NSColorSystemEffectDisabled] CGColor];
        break;
    }
    pagingLayer.mask = textContainerLayer;
    pagingLayer.shadowOpacity = [theme.backgroundColor brightnessComponent];
    pagingLayer.shadowOffset = NSMakeSize(theme.highlightedCornerRadius / 2, - theme.highlightedCornerRadius / 2);
    [self.layer addSublayer:pagingLayer];
  }
  if (theme.highlightedPreeditColor) {
    if (!highlightedPreeditPath.empty) {
      CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
      highlightedPreeditLayer.path = [highlightedPreeditPath quartzPath];
      highlightedPreeditLayer.fillColor = [theme.highlightedPreeditColor CGColor];
      highlightedPreeditLayer.mask = textContainerLayer;
      highlightedPreeditLayer.shadowOpacity = [theme.backgroundColor brightnessComponent];
      highlightedPreeditLayer.shadowOffset = NSMakeSize(theme.highlightedCornerRadius / 2, - theme.highlightedCornerRadius / 2);
      [self.layer addSublayer:highlightedPreeditLayer];
    }
  }
  if (theme.tabled) {
    CAShapeLayer *horzGridLayer = [[CAShapeLayer alloc] init];
    horzGridLayer.path = [candidateHorzGridPath quartzPath];
    horzGridLayer.strokeColor = [[theme.backgroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                                  ofColor:(self.appear == darkAppear ? [NSColor lightGrayColor] : [NSColor blackColor])] CGColor];
    horzGridLayer.lineWidth = theme.edgeInset.height / 2;
    horzGridLayer.lineCap = kCALineCapRound;
    [panelLayer addSublayer:horzGridLayer];
    CAShapeLayer *vertGridLayer = [[CAShapeLayer alloc] init];
    vertGridLayer.path = [candidateVertGridPath quartzPath];
    vertGridLayer.strokeColor = [[theme.backgroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction 
                                  ofColor:(self.appear == darkAppear ? [NSColor lightGrayColor] : [NSColor blackColor])] CGColor];
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

@end // SquirrelView


@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;

  NSSize _maxSize;
  CGFloat _textWidthLimit;

  NSUInteger _numCandidates;
  NSUInteger _index;
  NSUInteger _turnPage;
  BOOL _firstPage;
  BOOL _lastPage;

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

- (void)initializeUIStyleForAppearance:(SquirrelAppear)appear {
  SquirrelTheme *theme = [_view selectTheme:appear];

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
  labelAttrs[NSForegroundColorAttributeName] = [NSColor controlAccentColor];
  labelAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *labelHighlightedAttrs = [highlightedAttrs mutableCopy];
  labelHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor alternateSelectedControlTextColor];
  labelHighlightedAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *commentAttrs = [defaultAttrs mutableCopy];
  commentAttrs[NSForegroundColorAttributeName] = [NSColor secondaryLabelColor];
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
  pagingAttrs[NSForegroundColorAttributeName] = theme.linear ? [NSColor controlAccentColor] : [NSColor controlTextColor];

  NSMutableDictionary *pagingHighlightedAttrs = [defaultAttrs mutableCopy];
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = theme.linear
    ? [NSColor alternateSelectedControlTextColor] : [NSColor selectedMenuItemTextColor];

  if (@available(macOS 12.0, *)) {
    attrs[NSTrackingAttributeName] = @(1);
    highlightedAttrs[NSTrackingAttributeName] = @(1);
    commentAttrs[NSTrackingAttributeName] = @(1);
    commentHighlightedAttrs[NSTrackingAttributeName] = @(1);
    preeditAttrs[NSTrackingAttributeName] = @(1);
    preeditHighlightedAttrs[NSTrackingAttributeName] = @(1);
  } else {
    attrs[NSKernAttributeName] = @(1);
    highlightedAttrs[NSKernAttributeName] = @(1);
    commentAttrs[NSKernAttributeName] = @(1);
    commentHighlightedAttrs[NSKernAttributeName] = @(1);
    preeditAttrs[NSKernAttributeName] = @(1);
    preeditHighlightedAttrs[NSKernAttributeName] = @(1);
  }

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

  [theme setSelectKeys:@"12345" labels:@[@"１", @"２", @"３", @"４", @"５"] directUpdate:NO];
  [theme setCandidateFormat:kDefaultCandidateFormat];
}

- (instancetype)init {
  self = [super initWithContentRect:_position
                          styleMask:NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskBorderless | NSWindowStyleMaskHUDWindow | NSWindowStyleMaskUtilityWindow
                            backing:NSBackingStoreBuffered
                              defer:YES];

  if (self) {
    self.alphaValue = 1.0;
    self.hasShadow = NO;
    self.opaque = NO;
    self.displaysWhenScreenProfileChanges = YES;
    self.backgroundColor = [NSColor clearColor];
    NSView *contentView = [[NSView alloc] init];
    _view = [[SquirrelView alloc] initWithFrame:self.contentView.bounds];
    _back = [[NSVisualEffectView alloc] init];
    _back.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _back.material = NSVisualEffectMaterialHUDWindow;
    _back.state = NSVisualEffectStateActive;
    _back.wantsLayer = YES;
    _back.layer.mask = _view.shape;
    [contentView addSubview:_back];
    [contentView addSubview:_view];
    [contentView addSubview:_view.textView];

    self.contentView = contentView;
    [self initializeUIStyleForAppearance:defaultAppear];
    [self initializeUIStyleForAppearance:darkAppear];
    _maxSize = NSZeroSize;
    _initPosition = YES;
  }
  return self;
}

- (void)sendEvent:(NSEvent *)event {
  NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                            fromView:nil];
  NSUInteger cursorIndex = NSNotFound;
  switch (event.type) {
    case NSEventTypeLeftMouseUp:
      if (event.clickCount == 1 && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index) {
          [_inputController perform:kSELECT onIndex:(rimeIndex)cursorIndex];
        } else if (cursorIndex == _turnPage) {
          rimeIndex indexChar = cursorIndex == NSPageUpFunctionKey ? kPageUp :
                                (cursorIndex == NSPageDownFunctionKey ? kPageDown : kVoidSymbol);
          [_inputController perform:kSELECT onIndex:indexChar];
        }
      }
      break;
    case NSEventTypeRightMouseUp:
      if (event.clickCount == 1 && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _index) {
          [_inputController perform:kDELETE onIndex:(rimeIndex)cursorIndex];
        } else if (cursorIndex == _turnPage) {
          [_inputController perform:kSELECT onIndex:kEscape];
        }
      }
      break;
    case NSEventTypeMouseMoved:
      if ([_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex >= 0 && cursorIndex < _numCandidates && _index != cursorIndex) {
          _index = cursorIndex;
          [_inputController perform:kHILITE onIndex:(rimeIndex)cursorIndex];
        } else if ((cursorIndex == NSPageUpFunctionKey || cursorIndex == NSPageDownFunctionKey) && _turnPage != cursorIndex) {
          _turnPage = cursorIndex;
          if (_turnPage == NSPageUpFunctionKey) {
            [_view.textStorage addAttributes:_view.currentTheme.pagingHighlightedAttrs range:NSMakeRange(_view.pagingRange.location, 1)];
            [_view.textStorage addAttributes:_view.currentTheme.pagingAttrs range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
            cursorIndex = _firstPage ? NSBeginFunctionKey : NSPageUpFunctionKey;
          } else if (_turnPage == NSPageDownFunctionKey) {
            [_view.textStorage addAttributes:_view.currentTheme.pagingHighlightedAttrs range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
            [_view.textStorage addAttributes:_view.currentTheme.pagingAttrs range:NSMakeRange(_view.pagingRange.location, 1)];
            cursorIndex = _lastPage ? NSEndFunctionKey : NSPageDownFunctionKey;
          }
          [_view drawViewWithInsets:_view.insets
                    candidateRanges:_view.candidateRanges
                   highlightedIndex:_view.highlightedIndex
                       preeditRange:_view.preeditRange
            highlightedPreeditRange:_view.highlightedPreeditRange
                        pagingRange:_view.pagingRange
                       pagingButton:cursorIndex];
          [self show];
        }
      }
      break;
    case NSEventTypeLeftMouseDragged:
      _maxSize = NSZeroSize; // reset the remember_size references after moving the panel
      [self performWindowDragWithEvent:event];
      break;
    case NSEventTypeScrollWheel: {
      SquirrelTheme *theme = _view.currentTheme;
      CGFloat scrollThreshold = [theme.attrs[NSParagraphStyleAttributeName] maximumLineHeight] +
                                [theme.attrs[NSParagraphStyleAttributeName] lineSpacing];
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
          [_inputController perform:kSELECT onIndex:(theme.vertical ? kPageDown : kPageUp)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y > scrollThreshold) {
          [_inputController perform:kSELECT onIndex:kPageUp];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [_inputController perform:kSELECT onIndex:(theme.vertical ? kPageUp : kPageDown)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y < -scrollThreshold) {
          [_inputController perform:kSELECT onIndex:kPageDown];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        }
      }
    } break;
    default:
      [super sendEvent:event];
      break;
  }
}

- (void)getTextWidthLimit {
  NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
  SquirrelTheme *theme = _view.currentTheme;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit = (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio - theme.separatorWidth - theme.edgeInset.width * 2;
  if (theme.lineLength > 0) {
    _textWidthLimit = MIN(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabled) {
    CGFloat tabInterval = theme.separatorWidth * 2;
    _textWidthLimit = floor((_textWidthLimit + theme.separatorWidth) / tabInterval / 2) * tabInterval * 2 - theme.separatorWidth;
  }
  _view.textView.textContainer.size = NSMakeSize(_textWidthLimit, CGFLOAT_MAX);
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  NSAppearance *requestedAppearance = [NSAppearance appearanceNamed:
                                       (_view.appear == darkAppear ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua)];
  if (self.appearance != requestedAppearance) {
    self.appearance = requestedAppearance;
  }

  //Break line if the text is too long, based on screen size.
  SquirrelTheme *theme = _view.currentTheme;
  NSTextContainer *textContainer = _view.textView.textContainer;
  NSEdgeInsets insets = _view.insets;
  CGFloat textWidthRatio = MIN(1.0, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
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

  NSRect windowRect;
  if (_statusMessage != nil) { // following system UI, middle-align status message with cursor
    _initPosition = YES;
    if (theme.vertical) {
      windowRect.size.width = NSHeight(maxContentRect) + insets.top + insets.bottom;
      windowRect.size.height = NSWidth(maxContentRect) + insets.left + insets.right;
    } else {
      windowRect.size.width = NSWidth(maxContentRect) + insets.left + insets.right;
      windowRect.size.height = NSHeight(maxContentRect) + insets.top + insets.bottom;
    }
    if (sweepVertical) { // vertically centre-align (MidY) in screen coordinates
      windowRect.origin.x = NSMinX(_position) - kOffsetHeight - windowRect.size.width;
      windowRect.origin.y = NSMidY(_position) - windowRect.size.height / 2;
    } else { // horizontally centre-align (MidX) in screen coordinates
      windowRect.origin.x = NSMidX(_position) - windowRect.size.width / 2;
      windowRect.origin.y = NSMinY(_position) - kOffsetHeight - windowRect.size.height;
    }
  } else {
    if (theme.vertical) { // anchor is the top right corner in screen coordinates (MaxX, MaxY)
      windowRect = NSMakeRect(NSMaxX(self.frame) - NSHeight(maxContentRect) - insets.top - insets.bottom,
                              NSMaxY(self.frame) - NSWidth(maxContentRect) - insets.left - insets.right,
                              NSHeight(maxContentRect) + insets.top + insets.bottom,
                              NSWidth(maxContentRect) + insets.left + insets.right);
      _initPosition |= NSIntersectsRect(windowRect, _position);
      if (_initPosition) {
        // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
        if (NSMinY(_position) - NSMinY(screenRect) > NSHeight(screenRect) * textWidthRatio + kOffsetHeight) {
          windowRect.origin.y = NSMinY(_position) - (sweepVertical ? 0 : insets.left + kOffsetHeight) - NSWidth(maxContentRect) - insets.right;
        } else {
          windowRect.origin.y = NSMaxY(_position) + (sweepVertical ? 0 : kOffsetHeight);
        }
        // Make the right edge of candidate block fixed at the left of cursor
        windowRect.origin.x = NSMinX(_position) - (sweepVertical ? kOffsetHeight : 0) - NSHeight(maxContentRect) - insets.top - insets.bottom;
        if (!sweepVertical && _view.preeditRange.length > 0) {
          NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
          windowRect.origin.x += round(NSHeight(preeditRect) + [theme.preeditAttrs[NSFontAttributeName] descender] + insets.top);
        }
      }
    } else { // anchor is the top left corner in screen coordinates (MinX, MaxY)
      windowRect = NSMakeRect(NSMinX(self.frame),
                              NSMaxY(self.frame) - NSHeight(maxContentRect) - insets.top - insets.bottom,
                              NSWidth(maxContentRect) + insets.left + insets.right,
                              NSHeight(maxContentRect) + insets.top + insets.bottom);
      _initPosition |= NSIntersectsRect(windowRect, _position);
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
          windowRect.origin.x = NSMinX(_position) - insets.left;
          windowRect.origin.y = NSMinY(_position) - kOffsetHeight - NSHeight(windowRect);
        }
      }
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (_initPosition && sweepVertical ? MIN(NSMinX(_position) - kOffsetHeight, NSMaxX(screenRect)) : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = _initPosition && sweepVertical ? MAX(NSMaxX(_position) + kOffsetHeight, NSMinX(screenRect)) : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = _initPosition && !sweepVertical ? MAX(NSMaxY(_position) + kOffsetHeight, NSMinY(screenRect)) : NSMinY(screenRect);
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (_initPosition && !sweepVertical ? MIN(NSMinY(_position) - kOffsetHeight, NSMaxY(screenRect)) : NSMaxY(screenRect)) - NSHeight(windowRect);
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
    [self setFrame:[[NSScreen mainScreen] backingAlignedRect:windowRect options:NSAlignMaxXOutward | NSAlignMaxYInward | NSAlignWidthNearest | NSAlignHeightNearest] display:NO];
    [self.contentView setBoundsRotation:-90.0];
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    [self setFrame:[[NSScreen mainScreen] backingAlignedRect:windowRect options:NSAlignMinXInward | NSAlignMaxYInward | NSAlignWidthNearest | NSAlignHeightNearest] display:NO];
    [self.contentView setBoundsRotation:0.0];
    [self.contentView setBoundsOrigin:NSZeroPoint];
  }
  NSRect frameRect = self.contentView.bounds;
  NSRect textFrameRect = NSMakeRect(NSMinX(frameRect) + insets.left, NSMinY(frameRect) + insets.bottom,
                                    NSWidth(frameRect) - insets.left - insets.right,
                                    NSHeight(frameRect) - insets.top - insets.bottom);
  [_view.textView setBoundsRotation:0.0];
  [_view setBoundsOrigin:NSMakePoint(-insets.left, -insets.top)];
  [_view.textView setBoundsOrigin:NSZeroPoint];
  [_view setFrame:frameRect];
  [_view.textView setFrame:textFrameRect];

  if (theme.translucency > 0) {
    [_back setBoundsOrigin:NSMakePoint(-insets.left, -insets.top)];
    [_back setFrame:frameRect];
    [_back setAppearance:NSApp.effectiveAppearance];
    [_back setHidden:NO];
  } else {
    [_back setHidden:YES];
  }
  [self setAlphaValue:theme.alpha];
  [self display];
  [self orderFront:nil];
  // reset to initial position after showing status message
  _initPosition = _statusMessage != nil;
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

- (void)setLayoutForRange:(NSRange)charRange {
  BOOL verticalLayout = _view.currentTheme.vertical;
  NSFont *refFont = [_view.textStorage attribute:CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)
                                         atIndex:charRange.location
                                  effectiveRange:NULL][CFBridgingRelease(kCTBaselineReferenceFont)];
  if (@available(macOS 12.0, *)) {
    [_view.textStorage
     enumerateAttributesInRange:charRange
                        options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                     usingBlock:^(NSDictionary<NSAttributedStringKey,id> *attrs, NSRange range, BOOL *stop) {
      CGFloat baselineOffset = [attrs[NSBaselineOffsetAttributeName] doubleValue];
      NSFont *runFont =  attrs[NSFontAttributeName];
      NSInteger superscript = [attrs[NSSuperscriptAttributeName] integerValue];
      if ([runFont.fontName isEqualToString:@"AppleColorEmoji"]) {
        if (verticalLayout) {
          baselineOffset -= superscript * (runFont.ascender - runFont.descender) / 16;
        } else if (superscript == -1) {
          baselineOffset -= runFont.descender;
        } else if (superscript == 1) {
          baselineOffset -= runFont.underlinePosition;
        }
      } else if (superscript != 0) {
        baselineOffset -= runFont.descender;
      }
      [_view.textStorage addAttribute:NSBaselineOffsetAttributeName
                                value:@(baselineOffset) range:range];
    }];
  } else {
    NSParagraphStyle *style = [_view.textStorage attribute:NSParagraphStyleAttributeName
                                                   atIndex:charRange.location effectiveRange:NULL];
    CGFloat refFontHeight = refFont.ascender - refFont.descender;
    CGFloat lineHeight = MAX(style.lineHeightMultiple > 0 ? refFontHeight * style.lineHeightMultiple : refFontHeight,
                             style.minimumLineHeight);
    lineHeight = style.maximumLineHeight > 0 ? MIN(lineHeight, style.maximumLineHeight) : lineHeight;
    NSLayoutManager *layoutManager = _view.textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    [layoutManager enumerateLineFragmentsForGlyphRange:glyphRange
      usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer *textContainer, NSRange range, BOOL *stop) {
      CGFloat alignment = usedRect.origin.y - rect.origin.y + (verticalLayout ? lineHeight / 2 : refFont.ascender + lineHeight / 2 - refFontHeight / 2);
      // typesetting glyphs
      NSUInteger j = range.location;
      while (j < NSMaxRange(range)) {
        NSPoint runGlyphPosition = [layoutManager locationForGlyphAtIndex:j];
        NSUInteger runCharLocation = [layoutManager characterIndexForGlyphAtIndex:j];
        NSRange runRange = [layoutManager rangeOfNominallySpacedGlyphsContainingIndex:j];
        NSDictionary *attrs = [layoutManager.textStorage attributesAtIndex:runCharLocation effectiveRange:NULL];
        NSFont *runFont = attrs[NSFontAttributeName];
        NSFont *resizedRefFont = [NSFont fontWithDescriptor:refFont.fontDescriptor size:runFont.pointSize];
        NSString *baselineClass = attrs[CFBridgingRelease(kCTBaselineClassAttributeName)];
        NSNumber *baselineOffset = attrs[NSBaselineOffsetAttributeName];
        CGFloat offset = baselineOffset ? baselineOffset.doubleValue : 0.0;
        NSInteger superscript = [attrs[NSSuperscriptAttributeName] integerValue];
        if (verticalLayout) {
          NSNumber *verticalGlyph = attrs[NSVerticalGlyphFormAttributeName];
          if (verticalGlyph ? verticalGlyph.boolValue : YES) {
            runFont = runFont.verticalFont;
            resizedRefFont = resizedRefFont.verticalFont;
          }
        }
        if (superscript != 0) {
          offset += superscript == 1 ? refFont.ascender - resizedRefFont.ascender : refFont.descender - resizedRefFont.descender;
          if ([runFont.fontName isEqualToString:@"AppleColorEmoji"]) {
            offset -= (runFont.ascender - runFont.descender) / 16;
          }
        }
        if (verticalLayout) {
          if ([baselineClass isEqualToString:CFBridgingRelease(kCTBaselineClassRoman)] || !runFont.vertical) {
            runGlyphPosition.y = alignment - offset + resizedRefFont.xHeight / 2;
          } else {
            runGlyphPosition.y = alignment - offset + ([runFont.fontName isEqualToString:@"AppleColorEmoji"] && superscript == 0 ? (runFont.ascender - runFont.descender) / 16 : 0.0);
            runGlyphPosition.x += [runFont.fontName isEqualToString:@"AppleColorEmoji"] ? (runFont.ascender - runFont.descender) / 8 : 0.0;
          }
        } else {
          runGlyphPosition.y = alignment - offset + ([baselineClass isEqualToString:CFBridgingRelease(kCTBaselineClassIdeographicCentered)] ? runFont.xHeight / 2 - resizedRefFont.xHeight / 2 : 0.0);
        }
        [layoutManager setLocation:runGlyphPosition forStartOfGlyphRange:runRange];
        j = NSMaxRange(runRange);
      }
    }];
  }
}

- (BOOL)shouldBreakLineInsideRange:(NSRange)range {
  [_view.textStorage fixFontAttributeInRange:range];
  NSUInteger __block lineCount = 0;
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromCharRange:range];
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^BOOL(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      lineCount += 1 + (NSMaxX(segFrame) > _textWidthLimit);
      return YES;
    }];
  } else {
    NSRange glyphRange = [_view.textView.layoutManager glyphRangeForCharacterRange:range
                                                              actualCharacterRange:NULL];
    [_view.textView.layoutManager enumerateLineFragmentsForGlyphRange:glyphRange
      usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer *textContainer, NSRange lineRange, BOOL *stop) {
      lineCount  += 1 + (NSMaxX(usedRect) > self->_textWidthLimit);
    }];
  }
  return lineCount > 1;
}

- (BOOL)shouldUseTabsInRange:(NSRange)range maxLineLength:(CGFloat *)maxLineLength {
  [_view.textStorage fixFontAttributeInRange:range];
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromCharRange:range];
    CGFloat __block rangeEndEdge;
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      rangeEndEdge = NSMaxX(segFrame);
      return YES;
    }];
    [_view.textView.textLayoutManager ensureLayoutForRange:_view.textView.textContentStorage.documentRange];
    NSRect container = [_view.textView.textLayoutManager usageBoundsForTextContainer];
    *maxLineLength = MAX(MIN(_textWidthLimit, NSMaxX(container)), _maxSize.width);
    return *maxLineLength > rangeEndEdge;
  } else {
    NSUInteger glyphIndex = [_view.textView.layoutManager glyphIndexForCharacterAtIndex:range.location];
    CGFloat rangeEndEdge = NSMaxX([_view.textView.layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:NULL]);
    NSRect container = [_view.textView.layoutManager usedRectForTextContainer:_view.textView.textContainer];
    *maxLineLength = MAX(MIN(_textWidthLimit, NSMaxX(container)), _maxSize.width);
    return *maxLineLength > rangeEndEdge;
  }
}

- (CGFloat)getInlineOffsetAfterCharacterRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromCharRange:range];
    CGFloat __block offset;
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeStandard
                          options:NSTextLayoutManagerSegmentOptionsUpstreamAffinity
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, NSTextContainer *textContainer) {
      offset = NSMaxX(segFrame);
      return NO;
    }];
    return offset;
  } else {
    NSRange glyphRange = [_view.textView.layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
    NSRect boundingRect = [_view.textView.layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:_view.textView.textContainer];
    return NSMaxX(boundingRect);
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
           lastPage:(BOOL)lastPage {
  [self getTextWidthLimit];
  _numCandidates = candidates.count;
  _index = _numCandidates == 0 ? NSNotFound : index;
  _firstPage = pageNum == 0;
  _lastPage = lastPage;
  _turnPage = NSNotFound;
  if (_numCandidates > 0 || (preedit && preedit.length)) {
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
  _view.textView.layoutOrientation = theme.vertical ?
    NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;
  if (theme.lineLength > 0) {
    _maxSize.width = MIN(theme.lineLength, _textWidthLimit);
  }

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] init]];
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  NSMutableArray<NSValue *> *candidateRanges = [[NSMutableArray alloc] initWithCapacity:_numCandidates];
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
      [preeditLine addAttribute:NSVerticalGlyphFormAttributeName value:@NO
                          range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)), 1)];
    }
    preeditRange = NSMakeRange(0, preeditLine.length);
    [text appendAttributedString:preeditLine];

    if (_numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.preeditAttrs]];
    } else {
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
  for (NSUInteger idx = 0; idx < _numCandidates; ++idx) {
    // attributed labels are already included in candidateFormats
    NSMutableAttributedString *item = (idx == index) ? [theme.candidateHighlightedFormats[idx] mutableCopy] : [theme.candidateFormats[idx] mutableCopy];
    NSRange candidateRange = [item.string rangeOfString:@"%@"];
    // get the label size for indent
    CGFloat labelWidth = theme.linear ? 0.0 : ceil([item attributedSubstringFromRange:NSMakeRange(0, candidateRange.location)].size.width);

    [item replaceCharactersInRange:candidateRange withString:candidates[idx]];

    NSRange commentRange = [item.string rangeOfString:kTipSpecifier];
    if ([comments[idx] length] != 0) {
      [item replaceCharactersInRange:commentRange withString:[@" " stringByAppendingString:comments[idx]]];
    } else {
      [item deleteCharactersInRange:commentRange];
    }

    [item formatMarkDown];
    CGFloat annotationHeight = [item annotateRubyInRange:NSMakeRange(0, item.length) verticalLayout:theme.vertical maximumLength:_textWidthLimit];
    if (annotationHeight * 2 > theme.linespace) {
      [self setAnnotationHeight:annotationHeight];
      paragraphStyleCandidate = [theme.paragraphStyle copy];
      [text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(candidateBlockStart, text.length - candidateBlockStart) options:0
                    usingBlock:^(NSParagraphStyle *value, NSRange range, BOOL *stop) {
        NSMutableParagraphStyle *style = [value mutableCopy];
        style.paragraphSpacing = annotationHeight;
        style.paragraphSpacingBefore = annotationHeight;
        [text addAttribute:NSParagraphStyleAttributeName value:style range:range];
      }];
    }
    if ([comments[idx] length] != 0 && [item.string hasSuffix:@" "]) {
      [item deleteCharactersInRange:NSMakeRange(item.length - 1, 1)];
    }
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
      // separator: linear = "　"; tabled = "　\t"; stacked = "\n"
      NSMutableAttributedString *separator = [theme.separator mutableCopy];
      if (theme.tabled) { // fill gaps to make cells 2N-tab wide
        CGFloat widthInTabs = ([self getInlineOffsetAfterCharacterRange:candidateRanges.lastObject.rangeValue] + theme.separatorWidth) / tabInterval;
        NSUInteger numPaddingTabs = (NSUInteger)ceil(ceil(widthInTabs / 2) * 2 - widthInTabs) - 1;
        [separator replaceCharactersInRange:NSMakeRange(2, 0) withString:[@"\t" stringByPaddingToLength:numPaddingTabs withString:@"\t" startingAtIndex:0]];
      }
      [text appendAttributedString:separator];
      [text appendAttributedString:item];
      if (theme.linear && (ceil(item.size.width + theme.separatorWidth) > _textWidthLimit ||
          [self shouldBreakLineInsideRange:NSMakeRange(lineStart, text.length - lineStart)])) {
        [text replaceCharactersInRange:NSMakeRange(separatorStart + 1, separator.length - 1) withString:@"\n"];
        lineStart = separatorStart + 2;
      }
    } else { // at the start of a new line, no need to determine line break
      [text appendAttributedString:item];
    }
    // for linear layout, middle-truncate candidates that are longer than one line
    if (theme.linear && ceil(item.size.width + theme.separatorWidth) > _textWidthLimit) {
      if (idx < _numCandidates - 1 || theme.showPaging) {
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:theme.commentAttrs]];
      }
      NSMutableParagraphStyle *paragraphStyleTruncating = [paragraphStyleCandidate mutableCopy];
      paragraphStyleTruncating.lineBreakMode = NSLineBreakByTruncatingMiddle;
      [text addAttribute:NSParagraphStyleAttributeName value:paragraphStyleTruncating range:NSMakeRange(lineStart, item.length)];
      [candidateRanges addObject:[NSValue valueWithRange:NSMakeRange(lineStart, item.length)]];
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

    [text appendAttributedString:theme.separator];
    NSUInteger pagingStart = text.length;
    CGFloat maxLineLength;
    [text appendAttributedString:paging];
    if (theme.linear) {
      if ([self shouldBreakLineInsideRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 0) withString:@"\n"];
        lineStart = pagingStart;
        pagingStart += 1;
      }
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, paging.length) maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1) withString:@"\t"];
        paragraphStyleCandidate = [theme.paragraphStyle mutableCopy];
        paragraphStyleCandidate.tabStops = @[];
        CGFloat candidateEndPosition = ceil([self getInlineOffsetAfterCharacterRange:NSMakeRange(lineStart, pagingStart - 1 - lineStart)]);
        CGFloat textPostion = tabInterval;
        while (textPostion <= candidateEndPosition) {
          [paragraphStyleCandidate addTabStop:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                                                              location:textPostion options:@{}]];
          textPostion += tabInterval;
        }
        [paragraphStyleCandidate addTabStop:[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                            location:maxLineLength options:@{}]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleCandidate
                   range:NSMakeRange(lineStart, text.length - lineStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = [theme.pagingParagraphStyle mutableCopy];
      if ([self shouldUseTabsInRange:NSMakeRange(pagingStart, paging.length) maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1) withString:@"\t"];
        [text replaceCharactersInRange:NSMakeRange(pagingStart + paging.length - 2, 1) withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter
                                                                          location:maxLineLength / 2 options:@{}],
                                          [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                          location:maxLineLength options:@{}]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(pagingStart, paging.length)];
    }
    pagingRange = NSMakeRange(text.length - paging.length, paging.length);
  }

typesetter:
  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height + theme.linespace / 2,
                                         theme.edgeInset.width + theme.separatorWidth / 2,
                                         theme.edgeInset.height + theme.linespace / 2,
                                         theme.edgeInset.width + theme.separatorWidth / 2);
  if (preedit) {
    [self setLayoutForRange:preeditRange];
    insets.top = theme.edgeInset.height;
  }
  if (_numCandidates > 0) {
    NSRange candidateBlockRange = NSMakeRange(candidateBlockStart, (!theme.linear && pagingRange.length > 0 ? pagingRange.location : text.length) - candidateBlockStart);
    [self setLayoutForRange:candidateBlockRange];
    if (!theme.linear && pagingRange.length > 0) {
      [self setLayoutForRange:pagingRange];
      insets.bottom = theme.edgeInset.height;
    }
  } else {
    insets.bottom = theme.edgeInset.height;
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
               pagingButton:_turnPage];
  [self show];
}

- (void)updateStatusLong:(NSString *)messageLong 
             statusShort:(NSString *)messageShort {
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
  [self setLayoutForRange:NSMakeRange(0, text.length)];

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

static NSFont * getTallestFont(NSArray<NSFont *>*fonts, BOOL vertical) {
  NSFont *tallestFont;
  CGFloat maxHeight = 0.0;
  for (NSFont *font in fonts) {
    CGFloat fontHeight = getLineHeight(font, vertical);
    if (fontHeight > maxHeight) {
      tallestFont = font;
      maxHeight = fontHeight;
    }
  }
  return tallestFont;
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

- (void)setAnnotationHeight:(CGFloat)height {
  [[_view selectTheme:NO] setAnnotationHeight:height];
  [[_view selectTheme:YES] setAnnotationHeight:height];
}

- (void)loadLabelConfig:(SquirrelConfig *)config
           directUpdate:(BOOL)update {
  SquirrelTheme *theme = [_view selectTheme:defaultAppear];
  [SquirrelPanel updateTheme:theme withLabelConfig:config directUpdate:update];
  SquirrelTheme *darkTheme = [_view selectTheme:darkAppear];
  [SquirrelPanel updateTheme:darkTheme withLabelConfig:config directUpdate:update];
}

+ (void)updateTheme:(SquirrelTheme *)theme
    withLabelConfig:(SquirrelConfig *)config
       directUpdate:(BOOL)update {
  NSUInteger menuSize = (NSUInteger)[config getInt:@"menu/page_size"] ? : 5;
  NSMutableArray<NSString *> *labels = [[NSMutableArray alloc] initWithCapacity:menuSize];
  NSString *selectKeys = [config getString:@"menu/alternative_select_keys"];
  NSArray<NSString *> *selectLabels = [config getList:@"menu/alternative_select_labels"];
  if (selectLabels) {
    for (NSUInteger i = 0; i < menuSize; ++i) {
      labels[i] = selectLabels[i];
    }
  }
  if (selectKeys) {
    if (!selectLabels) {
      NSString *keyCaps = [[selectKeys uppercaseString]
                           stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [keyCaps substringWithRange:NSMakeRange(i, 1)];
      }
    }
  } else {
    selectKeys = [@"1234567890" substringToIndex:menuSize];
    if (!selectLabels) {
      NSString *numerals = [selectKeys stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [numerals substringWithRange:NSMakeRange(i, 1)];
      }
    }
  }
  [theme setSelectKeys:selectKeys labels:labels directUpdate:update];
}

- (void)loadConfig:(SquirrelConfig *)config
       forAppearance:(SquirrelAppear)appear {
  SquirrelTheme *theme = [_view selectTheme:appear];
  NSSet<NSString *> *styleOptions = [NSSet setWithArray:self.optionSwitcher.optionStates];
  [SquirrelPanel updateTheme:theme withConfig:config styleOptions:styleOptions forAppearance:appear];
}

+ (void)updateTheme:(SquirrelTheme *)theme
         withConfig:(SquirrelConfig *)config
       styleOptions:(NSSet<NSString *> *)styleOptions
      forAppearance:(SquirrelAppear)appear {
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
  if (appear == darkAppear) {
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
    config.colorSpace = [config getString:[prefix stringByAppendingString:@"/color_space"]] ? : config.colorSpace;
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
  NSString *labelString = [theme.labels componentsJoinedByString:@""];
  labelFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)labelFont, (CFStringRef)labelString, CFRangeMake(0, (int)labelString.length)));

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

  NSFont *zhFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)font, (CFStringRef)kFullWidthSpace, CFRangeMake(0, 1)));
  NSFont *zhCommentFont = CFBridgingRelease(CTFontCreateForString((CTFontRef)commentFont, (CFStringRef)kFullWidthSpace, CFRangeMake(0, 1)));
  NSFont *refFont = getTallestFont(@[zhFont, labelFont, zhCommentFont], vertical);
  labelAttrs[CFBridgingRelease(kCTBaselineClassAttributeName)] = CFBridgingRelease(kCTBaselineClassIdeographicCentered);
  labelHighlightedAttrs[CFBridgingRelease(kCTBaselineClassAttributeName)] = CFBridgingRelease(kCTBaselineClassIdeographicCentered);
  labelAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  labelHighlightedAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  attrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  highlightedAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  commentAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  commentHighlightedAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? refFont.verticalFont : refFont};
  preeditAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? zhFont.verticalFont : zhFont};
  preeditHighlightedAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? zhFont.verticalFont : zhFont};
  pagingAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): linear ? labelFont : pagingFont};
  statusAttrs[CFBridgingRelease(kCTBaselineReferenceInfoAttributeName)] = @{CFBridgingRelease(kCTBaselineReferenceFont): vertical ? zhCommentFont.verticalFont : zhCommentFont};

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
  if (theme.translucency > 0 && ABS(backgroundColor.brightnessComponent - (appear == darkAppear)) <= 0.4) {
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

  backgroundColor = backgroundColor ? : [NSColor controlBackgroundColor];
  borderColor = borderColor ? : isNative ? [NSColor gridColor] : nil;
  preeditBackgroundColor = preeditBackgroundColor ? : isNative ? [NSColor windowBackgroundColor] : nil;
  candidateTextColor = candidateTextColor ? : [NSColor controlTextColor];
  highlightedCandidateTextColor = highlightedCandidateTextColor ? : [NSColor selectedMenuItemTextColor];
  highlightedCandidateBackColor = highlightedCandidateBackColor ? : isNative ? [NSColor selectedContentBackgroundColor] : nil;
  candidateLabelColor = candidateLabelColor ? : isNative ? [NSColor controlAccentColor] : blendColors(highlightedCandidateBackColor, highlightedCandidateTextColor);
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? : isNative ? [NSColor alternateSelectedControlTextColor] : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? : [NSColor secondaryLabelColor];
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
               lineLength:lineLength.doubleValue > 0 ? MAX(lineLength.doubleValue, separatorWidth * 5) : 0.0
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

@end // SquirrelPanel
