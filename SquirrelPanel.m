#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOffsetGap = 5;
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

- (void)superscriptRange:(NSRange)range {
  [self enumerateAttribute:NSFontAttributeName inRange:range
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(NSFont *value, NSRange range, BOOL *stop) {
    NSFont *font = [NSFont fontWithDescriptor:value.fontDescriptor
                                         size:floor(value.pointSize * 0.55)];
    [self addAttributes:@{  NSFontAttributeName : font,
      (NSString *)kCTBaselineClassAttributeName : (NSString *)kCTBaselineClassIdeographicHigh,
                     NSSuperscriptAttributeName : @(1)}
                  range:range];
  }];
}

- (void)subscriptRange:(NSRange)range {
  [self enumerateAttribute:NSFontAttributeName inRange:range
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(NSFont *value, NSRange range, BOOL *stop) {
    NSFont *font = [NSFont fontWithDescriptor:value.fontDescriptor
                                         size:floor(value.pointSize * 0.55)];
    [self addAttributes:@{  NSFontAttributeName : font,
      (NSString *)kCTBaselineClassAttributeName : (NSString *)kCTBaselineClassIdeographicLow,
                     NSSuperscriptAttributeName : @(-1)}
                  range:range];
  }];
}

- (void)formatMarkDown {
  NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:
    @"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|<(b|strong|i|em|u|sup|sub|s)>)(.+?)(\\2|\\3(?=\\b)|<\\/\\4>)"
    options:NSRegularExpressionUseUnicodeWordBoundaries error:nil];
  NSInteger __block offset = 0;
  [regex enumerateMatchesInString:self.string options:0
                            range:NSMakeRange(0, self.length)
                       usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
    result = [result resultByAdjustingRangesWithOffset:offset];
    NSString *tag = [self.string substringWithRange:[result rangeAtIndex:1]];
    if ([tag isEqualToString:@"**"] || [tag isEqualToString:@"__"] ||
        [tag isEqualToString:@"<b>"] || [tag isEqualToString:@"<strong>"]) {
      [self applyFontTraits:NSBoldFontMask
                      range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"*"] || [tag isEqualToString:@"_"] ||
               [tag isEqualToString:@"<i>"] || [tag isEqualToString:@"<em>"]) {
      [self applyFontTraits:NSItalicFontMask 
                      range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"<u>"]) {
      [self addAttribute:NSUnderlineStyleAttributeName
                   value:@(NSUnderlineStyleSingle)
                   range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"~~"] || [tag isEqualToString:@"<s>"]) {
      [self addAttribute:NSStrikethroughStyleAttributeName
                   value:@(NSUnderlineStyleSingle) 
                   range:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"^"] || [tag isEqualToString:@"<sup>"]) {
      [self superscriptRange:[result rangeAtIndex:5]];
    } else if ([tag isEqualToString:@"~"] || [tag isEqualToString:@"<sub>"]) {
      [self subscriptRange:[result rangeAtIndex:5]];
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
           verticalOrientation:(BOOL)isVertical
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
      [self deleteCharactersInRange:NSMakeRange(NSMaxRange(result.range) - 1, 1)];
      [self deleteCharactersInRange:NSMakeRange([result rangeAtIndex:3].location, 1)];
      [self deleteCharactersInRange:NSMakeRange([result rangeAtIndex:1].location, 1)];
      offset -= 3;
    } else {
      // base string must use only one font so that all fall within one glyph run and the ruby annotation is aligned with no duplicates
      NSFont *baseFont = [self attribute:NSFontAttributeName
                                 atIndex:baseRange.location
                          effectiveRange:NULL];
      baseFont = CFBridgingRelease(CTFontCreateForStringWithLanguage((CTFontRef)baseFont, (CFStringRef)self.string,
                                    CFRangeMake((CFIndex)baseRange.location, (CFIndex)baseRange.length), CFSTR("zh")));
      [self addAttribute:NSFontAttributeName value:baseFont range:baseRange];

      CGFloat rubyScale = 0.5;
      CFStringRef rubyString = (__bridge CFStringRef)[self.string substringWithRange:[result rangeAtIndex:4]];
      NSFont *rubyFont = [self attribute:NSFontAttributeName
                                 atIndex:[result rangeAtIndex:4].location 
                          effectiveRange:NULL];
      rubyFont = [NSFont fontWithDescriptor:rubyFont.fontDescriptor
                                       size:rubyFont.pointSize * rubyScale];
      rubyFont = CFBridgingRelease(CTFontCreateForStringWithLanguage((CTFontRef)rubyFont, rubyString,
                                   CFRangeMake(0, CFStringGetLength(rubyString)), CFSTR("zh")));
      rubyLineHeight = MAX(rubyLineHeight, isVertical ? rubyFont.verticalFont.ascender - rubyFont.verticalFont.descender
                                                      : rubyFont.ascender - rubyFont.descender);
      CGColorRef rubyColor = [[self attribute:NSForegroundColorAttributeName
                                      atIndex:[result rangeAtIndex:4].location
                               effectiveRange:NULL] CGColor];
      CFTypeRef keys[] = {kCTFontAttributeName, kCTForegroundColorAttributeName,
                          kCTBaselineClassAttributeName, kCTRubyAnnotationSizeFactorAttributeName,
                          kCTRubyAnnotationScaleToFitAttributeName};
      CFTypeRef values[] = {(__bridge CTFontRef)rubyFont, rubyColor, kCTBaselineClassIdeographicHigh,
                            CFNumberCreate(NULL, kCFNumberDoubleType, &rubyScale), kCFBooleanFalse};
      CFDictionaryRef rubyAttrs = CFDictionaryCreate(NULL, keys, values, 5, &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
      CTRubyAnnotationRef rubyAnnotation = CTRubyAnnotationCreateWithAttributes(kCTRubyAlignmentDistributeSpace,
                                             kCTRubyOverhangNone, kCTRubyPositionBefore, rubyString, rubyAttrs);

      [self deleteCharactersInRange:[result rangeAtIndex:3]];
      if (@available(macOS 12.0, *)) {
        [self addAttributes:@{(NSString *)kCTRubyAnnotationAttributeName : CFBridgingRelease(rubyAnnotation),
                                        NSVerticalGlyphFormAttributeName : @(isVertical)}
                      range:baseRange];
        [self deleteCharactersInRange:[result rangeAtIndex:1]];
        offset -= [result rangeAtIndex:3].length + [result rangeAtIndex:1].length;
      } else {
        // use U+008B as placeholder for line-forward spaces in case ruby is wider than base
        [self replaceCharactersInRange:NSMakeRange(NSMaxRange(baseRange), 0)
                            withString:[NSString stringWithFormat:@"%C", 0x8B]];
        baseRange.length += 1;
        [self addAttributes:@{(NSString *)kCTRubyAnnotationAttributeName : CFBridgingRelease(rubyAnnotation),
                                        NSVerticalGlyphFormAttributeName : @(isVertical)}
                      range:baseRange];
        [self deleteCharactersInRange:[result rangeAtIndex:1]];
        offset -= [result rangeAtIndex:3].length - 1 + [result rangeAtIndex:1].length;
      }
    }
  }];
  if (offset == 0) {
    [self.mutableString replaceOccurrencesOfString:@"[\uFFF9-\uFFFB]"
                                        withString:@""
                                           options:NSRegularExpressionSearch
                                             range:range];
  }
  return ceil(rubyLineHeight);
}

@end // NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)


@implementation NSColorSpace (labColorSpace)

+ (NSColorSpace *)labColorSpace {
  CGFloat whitePoint[3] = {0.950489, 1.0, 1.088840};
  CGFloat blackPoint[3] = {0.0, 0.0, 0.0};
  CGFloat range[4] = {-127.0, 127.0, -127.0, 127.0};
  CGColorSpaceRef colorSpaceLab = CGColorSpaceCreateLab(whitePoint, blackPoint, range);
  NSColorSpace *labColorSpace = [[NSColorSpace alloc] initWithCGColorSpace:colorSpaceLab];
  CGColorSpaceRelease(colorSpaceLab);
  return labColorSpace;
}

@end // NSColorSpace (labColorSpace)


@implementation NSColor (colorWithLabColorSpace)

+ (NSColor *)colorWithLabLuminance:(CGFloat)luminance
                                 a:(CGFloat)a
                                 b:(CGFloat)b
                             alpha:(CGFloat)alpha {
  luminance = MAX(MIN(luminance, 100.0), 0.0);
  a = MAX(MIN(a, 127.0), -127.0);
  b = MAX(MIN(b, 127.0), -127.0);
  alpha = MAX(MIN(alpha, 1.0), 0.0);
  CGFloat components[4] = {luminance, a, b, alpha};
  return [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                           components:components count:4];
}

- (void)getLuminance:(CGFloat *)luminance
                   a:(CGFloat *)a
                   b:(CGFloat *)b
               alpha:(CGFloat *)alpha {
  NSColor *labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  *luminance = components[0] / 100.0;
  *a = components[1] / 127.0; // green-red
  *b = components[2] / 127.0; // blue-yellow
  *alpha = components[3];
}

- (CGFloat)luminanceComponent {
  NSColor *labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  return components[0] / 100.0;
}

- (NSColor *)invertLuminanceWithAdjustment:(NSInteger)sign {
  if (self == nil) {
    return nil;
  }
  NSColor *labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  BOOL isDark = components[0] < 60;
  if (sign > 0) {
    components[0] = isDark ? 100.0 - components[0] * 2.0 / 3.0 : 150.0 - components[0] * 1.5;
  } else if (sign < 0) {
    components[0] = isDark ? 80.0 - components[0] / 3.0 : 135.0 - components[0] * 1.25;
  } else {
    components[0] = isDark ? 90.0 - components[0] / 2.0 : 120.0 - components[0];
  }
  NSColor *invertedColor = [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                                             components:components count:4];
  return [invertedColor colorUsingColorSpace:self.colorSpace];
}

@end // NSColor (colorWithLabColorSpace)

#pragma mark - Color scheme and other user configurations

@interface SquirrelTheme : NSObject

@property(nonatomic, strong, readonly) NSColor *backgroundColor;
@property(nonatomic, strong, readonly) NSImage *backgroundImage;
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
@property(nonatomic, strong, readonly) NSAttributedString *symbolDeleteFill;
@property(nonatomic, strong, readonly) NSAttributedString *symbolDeleteStroke;

@property(nonatomic, strong, readonly) NSString *selectKeys;
@property(nonatomic, strong, readonly) NSString *candidateFormat;
@property(nonatomic, strong, readonly) NSArray<NSString *> *labels;
@property(nonatomic, strong, readonly) NSArray<NSAttributedString *> *candidateFormats;
@property(nonatomic, strong, readonly) NSArray<NSAttributedString *> *candidateHighlightedFormats;
@property(nonatomic, strong, readonly) NSString *statusMessageType;

- (void)setBackgroundColor:(NSColor *)backgroundColor
           backgroundImage:(NSImage *)backgroundImage
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

static NSArray<NSAttributedString *> * formatLabels(NSAttributedString *format,
                                                    NSArray<NSString *> *labels) {
  NSRange enumRange = NSMakeRange(0, 0);
  NSMutableArray<NSAttributedString *> *formatted =
    [[NSMutableArray alloc] initWithCapacity:labels.count];
  NSCharacterSet *labelCharacters = [NSCharacterSet characterSetWithCharactersInString:
                                       [labels componentsJoinedByString:@""]];
  if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF10, 10)]
       isSupersetOfSet:labelCharacters]) { // ０１..９
    if ([format.string containsString:@"%c\u20E3"]) { // 1⃣..9⃣0⃣
      enumRange = [format.string rangeOfString:@"%c\u20E3"];
      for (NSString *label in labels) {
        const unichar chars[] = {[label characterAtIndex:0] - 0xFF10 + 0x0030, 0xFE0E, 0x20E3, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"%c\u20DD"]) { // ①..⑨⓪
      enumRange = [format.string rangeOfString:@"%c\u20DD"];
      for (NSString *label in labels) {
        const unichar chars[] = {[label characterAtIndex:0] == 0xFF10 ? 0x24EA :
                                 [label characterAtIndex:0] - 0xFF11 + 0x2460, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange 
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"(%c)"]) { // ⑴..⑼⑽
      enumRange = [format.string rangeOfString:@"(%c)"];
      for (NSString *label in labels) {
        const unichar chars[] = {[label characterAtIndex:0] == 0xFF10 ? 0x247D :
                                 [label characterAtIndex:0] - 0xFF11 + 0x2474, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"%c."]) { // ⒈..⒐🄀
      enumRange = [format.string rangeOfString:@"%c."];
      for (NSString *label in labels) {
        const unichar chars[] = {[label characterAtIndex:0] == 0xFF10 ? 0xD83C :
                                 [label characterAtIndex:0] - 0xFF11 + 0x2488,
                                 [label characterAtIndex:0] == 0xFF10 ? 0xDD00 : 0x0, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"%c,"]) { // 🄂..🄊🄁
      enumRange = [format.string rangeOfString:@"%c,"];
      for (NSString *label in labels) {
        const unichar chars[] = {0xD83C, [label characterAtIndex:0] - 0xFF10 + 0xDD01, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    }
  } else if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF21, 26)]
              isSupersetOfSet:labelCharacters]) { // Ａ..Ｚ
    if ([format.string containsString:@"%c\u20DD"]) { // Ⓐ..Ⓩ
      enumRange = [format.string rangeOfString:@"%c\u20DD"];
      for (NSString *label in labels) {
        const unichar chars[] = {[label characterAtIndex:0] - 0xFF21 + 0x24B6, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange 
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"(%c)"]) { // 🄐..🄩
      enumRange = [format.string rangeOfString:@"(%c)"];
      for (NSString *label in labels) {
        const unichar chars[] = {0xD83C, [label characterAtIndex:0] - 0xFF21 + 0xDD10, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    } else if ([format.string containsString:@"%c\u20DE"]) { // 🄰..🅉
      enumRange = [format.string rangeOfString:@"%c\u20DE"];
      for (NSString *label in labels) {
        const unichar chars[] = {0xD83C, [label characterAtIndex:0] - 0xFF21 + 0xDD30, 0x0};
        NSMutableAttributedString *newFormat = format.mutableCopy;
        [newFormat replaceCharactersInRange:enumRange 
                                 withString:[NSString stringWithFormat:@"%S", chars]];
        [formatted addObject:newFormat];
      }
    }
  }
  if (enumRange.length == 0) {
    enumRange = [format.string rangeOfString:@"%c"];
    for (NSString *label in labels) {
      NSMutableAttributedString *newFormat = format.mutableCopy;
      [newFormat replaceCharactersInRange:enumRange withString:label];
      [formatted addObject:newFormat];
    }
  }
  return formatted;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor
           backgroundImage:(NSImage *)backgroundImage
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

  NSMutableDictionary *sepAttrs = commentAttrs.mutableCopy;
  sepAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  sepAttrs[NSKernAttributeName] = @(0.0);
  _separator = [[NSAttributedString alloc] initWithString:_linear ?
                (_tabled ? [kFullWidthSpace stringByAppendingString:@"\t"] : kFullWidthSpace) : @"\n"
                                               attributes:sepAttrs];

  // Symbols for function buttons
  NSTextAttachment *attmLeftFill = [[NSTextAttachment alloc] init];
  attmLeftFill.image = [NSImage imageNamed:@"Symbols/chevron.left.circle.fill"];
  NSTextAttachment *attmUpFill = [[NSTextAttachment alloc] init];
  attmUpFill.image = [NSImage imageNamed:@"Symbols/chevron.up.circle.fill"];
  NSMutableDictionary *attrsBackFill = pagingAttrs.mutableCopy;
  attrsBackFill[NSAttachmentAttributeName] = _linear ? attmUpFill : attmLeftFill;
  _symbolBackFill = [[NSAttributedString alloc] 
                     initWithString:@"\uFFFC" attributes:attrsBackFill];

  NSTextAttachment *attmLeftStroke = [[NSTextAttachment alloc] init];
  attmLeftStroke.image = [NSImage imageNamed:@"Symbols/chevron.left.circle"];
  NSTextAttachment *attmUpStroke = [[NSTextAttachment alloc] init];
  attmUpStroke.image = [NSImage imageNamed:@"Symbols/chevron.up.circle"];
  NSMutableDictionary *attrsBackStroke = pagingAttrs.mutableCopy;
  attrsBackStroke[NSAttachmentAttributeName] = _linear ? attmUpStroke : attmLeftStroke;
  _symbolBackStroke = [[NSAttributedString alloc] 
                       initWithString:@"\uFFFC" attributes:attrsBackStroke];

  NSTextAttachment *attmRightFill = [[NSTextAttachment alloc] init];
  attmRightFill.image = [NSImage imageNamed:@"Symbols/chevron.right.circle.fill"];
  NSTextAttachment *attmDownFill = [[NSTextAttachment alloc] init];
  attmDownFill.image = [NSImage imageNamed:@"Symbols/chevron.down.circle.fill"];
  NSMutableDictionary *attrsForwardFill = pagingAttrs.mutableCopy;
  attrsForwardFill[NSAttachmentAttributeName] = _linear ? attmDownFill : attmRightFill;
  _symbolForwardFill = [[NSAttributedString alloc]
                        initWithString:@"\uFFFC" attributes:attrsForwardFill];

  NSTextAttachment *attmRightStroke = [[NSTextAttachment alloc] init];
  attmRightStroke.image = [NSImage imageNamed:@"Symbols/chevron.right.circle"];
  NSTextAttachment *attmDownStroke = [[NSTextAttachment alloc] init];
  attmDownStroke.image = [NSImage imageNamed:@"Symbols/chevron.down.circle"];
  NSMutableDictionary *attrsForwardStroke = pagingAttrs.mutableCopy;
  attrsForwardStroke[NSAttachmentAttributeName] = _linear ? attmDownStroke : attmRightStroke;
  _symbolForwardStroke = [[NSAttributedString alloc] 
                          initWithString:@"\uFFFC" attributes:attrsForwardStroke];

  NSTextAttachment *attmDeleteFill = [[NSTextAttachment alloc] init];
  attmDeleteFill.image = [NSImage imageNamed:@"Symbols/delete.backward.fill"];
  NSMutableDictionary *attrsDeleteFill = preeditAttrs.mutableCopy;
  attrsDeleteFill[NSAttachmentAttributeName] = attmDeleteFill;
  attrsDeleteFill[NSVerticalGlyphFormAttributeName] = @(NO);
  attrsDeleteFill[NSKernAttributeName] = @(0.0);
  _symbolDeleteFill = [[NSAttributedString alloc]
                       initWithString:@"\uFFFC" attributes:attrsDeleteFill];

  NSTextAttachment *attmDeleteStroke = [[NSTextAttachment alloc] init];
  attmDeleteStroke.image = [NSImage imageNamed:@"Symbols/delete.backward"];
  NSMutableDictionary *attrsDeleteStroke = preeditAttrs.mutableCopy;
  attrsDeleteStroke[NSAttachmentAttributeName] = attmDeleteStroke;
  attrsDeleteStroke[NSVerticalGlyphFormAttributeName] = @(NO);
  attrsDeleteStroke[NSKernAttributeName] = @(0.0);
  _symbolDeleteStroke = [[NSAttributedString alloc]
                         initWithString:@"\uFFFC" attributes:attrsDeleteStroke];
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
  NSMutableString *candidateFormat = _candidateFormat.mutableCopy;
  if (![candidateFormat containsString:@"%@"]) {
    [candidateFormat appendString:@"%@"];
  }
  NSRange labelRange = [candidateFormat rangeOfString:@"%c" options:NSLiteralSearch];
  if (labelRange.length == 0) {
    [candidateFormat insertString:@"%c" atIndex:0];
  }
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@"];
  if (labelRange.location > candidateRange.location) {
    [candidateFormat setString:kDefaultCandidateFormat];
    candidateRange = [candidateFormat rangeOfString:@"%@"];
  }
  labelRange = NSMakeRange(0, candidateRange.location);
  NSRange commentRange = NSMakeRange(NSMaxRange(candidateRange),
                                     candidateFormat.length - NSMaxRange(candidateRange));
  // parse markdown formats
  NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:candidateFormat];
  NSMutableAttributedString *highlightedFormat = format.mutableCopy;
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
  commentRange = NSMakeRange(NSMaxRange(candidateRange),
                             format.length - NSMaxRange(candidateRange));
  if (commentRange.length > 0) {
    [format replaceCharactersInRange:commentRange withString:
       [kTipSpecifier stringByAppendingString:[format.string substringWithRange:commentRange]]];
    [highlightedFormat replaceCharactersInRange:commentRange withString:
       [kTipSpecifier stringByAppendingString:[highlightedFormat.string substringWithRange:commentRange]]];
  } else {
    [format appendAttributedString:[[NSAttributedString alloc] initWithString:
                                    kTipSpecifier attributes:_commentAttrs]];
    [highlightedFormat appendAttributedString:[[NSAttributedString alloc] initWithString:
                                               kTipSpecifier attributes:_commentHighlightedAttrs]];
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
    NSMutableParagraphStyle *paragraphStyle = _paragraphStyle.mutableCopy;
    paragraphStyle.paragraphSpacingBefore = height;
    paragraphStyle.paragraphSpacing = height;
    _paragraphStyle = paragraphStyle;
  }
}

@end // SquirrelTheme

#pragma mark - Typesetting extensions for TextKit 1 (macOS 11 or lower)

@interface SquirrelLayoutManager : NSLayoutManager <NSLayoutManagerDelegate>
@end

@implementation SquirrelLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange
                        atPoint:(NSPoint)origin {
  NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
  NSTextContainer *textContainer = [self textContainerForGlyphAtIndex:glyphRange.location
                                                       effectiveRange:NULL withoutAdditionalLayout:YES];
  BOOL verticalOrientation = textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  CGContextRef context = NSGraphicsContext.currentContext.CGContext;
  CGContextResetClip(context);
  [self.textStorage 
   enumerateAttributesInRange:charRange
   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
   usingBlock:^(NSDictionary<NSAttributedStringKey,id> *attrs, NSRange range, BOOL *stop) {
    NSRange glyRange = [self glyphRangeForCharacterRange:range
                                    actualCharacterRange:NULL];
    NSRect lineRect = [self lineFragmentRectForGlyphAtIndex:glyRange.location
                                             effectiveRange:NULL 
                                    withoutAdditionalLayout:YES];
    CGContextSaveGState(context);
    if (attrs[(NSString *)kCTRubyAnnotationAttributeName]) {
      CGContextScaleCTM(context, 1.0, -1.0);
      NSUInteger glyphIndex = glyRange.location;
      CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)
                         [self.textStorage attributedSubstringFromRange:range]);
      CFArrayRef runs = CTLineGetGlyphRuns(line);
      for (CFIndex i = 0; i < CFArrayGetCount(runs); ++i) {
        CGPoint position = [self locationForGlyphAtIndex:glyphIndex];
        NSPoint backingTextPosition = [textContainer.textView convertPointToBacking:
                                       NSMakePoint(lineRect.origin.x + position.x, 
                                                   lineRect.origin.y + position.y)];
        NSPoint textPosition = [textContainer.textView convertPointFromBacking:
                                NSMakePoint(round(backingTextPosition.x),
                                            round(backingTextPosition.y))];
        CTRunRef run = CFArrayGetValueAtIndex(runs, i);
        CGAffineTransform matrix = CTRunGetTextMatrix(run);
        matrix.tx = textPosition.x;
        matrix.ty = -textPosition.y;
        CGContextSetTextMatrix(context, matrix);
        CTRunDraw(run, context, CFRangeMake(0, 0));
        glyphIndex += (NSUInteger)CTRunGetGlyphCount(run);
      }
      CFRelease(line);
    } else {
      NSPoint position = [self locationForGlyphAtIndex:glyRange.location];
      position.x += origin.x + lineRect.origin.x;
      position.y += origin.y + lineRect.origin.y;
      CGContextSetTextPosition(context, position.x, position.y);
      NSFont *runFont = attrs[NSFontAttributeName];
      NSPoint glyphOffset = NSZeroPoint;
      if (verticalOrientation && runFont.pointSize < 24 &&
          [runFont.fontName isEqualToString:@"AppleColorEmoji"]) {
        NSInteger superscript = [attrs[NSSuperscriptAttributeName] integerValue];
        glyphOffset.x = runFont.capHeight - runFont.pointSize;
        glyphOffset.y = (runFont.capHeight - runFont.pointSize) * 
                        (superscript == 0 ? 0.5 : (superscript == 1 ? 1.0 / 0.55 - 0.55 : 0.0));
      }
      NSPoint backingGlyphOrigin = [textContainer.textView convertPointToBacking:
                                    NSMakePoint(position.x + glyphOffset.x, 
                                                position.y + glyphOffset.y)];
      NSPoint glyphOrigin = [textContainer.textView convertPointFromBacking:
                             NSMakePoint(round(backingGlyphOrigin.x),
                                         round(backingGlyphOrigin.y))];
      [super drawGlyphsForGlyphRange:glyRange
                             atPoint:NSMakePoint(glyphOrigin.x - position.x, 
                                                 glyphOrigin.y - position.y)];
    }
    CGContextRestoreGState(context);
  }];
  CGContextClipToRect(context, textContainer.textView.superview.bounds);
}

- (BOOL)      layoutManager:(NSLayoutManager *)layoutManager
  shouldSetLineFragmentRect:(inout NSRect *)lineFragmentRect
       lineFragmentUsedRect:(inout NSRect *)lineFragmentUsedRect
             baselineOffset:(inout CGFloat *)baselineOffset 
            inTextContainer:(NSTextContainer *)textContainer
              forGlyphRange:(NSRange)glyphRange {
  BOOL verticalOrientation = textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange 
                                                actualGlyphRange:NULL];
  NSParagraphStyle *style = [layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                                         atIndex:charRange.location 
                                                  effectiveRange:NULL];
  NSFont *refFont = [layoutManager.textStorage attribute:(NSString *)kCTBaselineReferenceInfoAttributeName
                                                 atIndex:charRange.location
                                          effectiveRange:NULL][(NSString *)kCTBaselineReferenceFont];
  CGFloat refFontHeight = refFont.ascender - refFont.descender;
  CGFloat lineHeight = MAX(style.lineHeightMultiple > 0 ? refFontHeight * style.lineHeightMultiple : refFontHeight,
                           style.minimumLineHeight);
  lineHeight = style.maximumLineHeight > 0 ? MIN(lineHeight, style.maximumLineHeight) : lineHeight;
  *lineFragmentRect = [textContainer.textView backingAlignedRect:*lineFragmentRect
                                                         options:NSAlignAllEdgesNearest];
  *lineFragmentUsedRect = [textContainer.textView backingAlignedRect:*lineFragmentUsedRect
                                                             options:NSAlignAllEdgesNearest];
  NSRect lineFragmentAscentRect = *lineFragmentRect;
  lineFragmentAscentRect.size.height = lineFragmentUsedRect->origin.y - lineFragmentRect->origin.y +
      (verticalOrientation ? lineHeight / 2 : refFont.ascender + lineHeight / 2 - refFontHeight / 2);
  lineFragmentAscentRect = [textContainer.textView backingAlignedRect:lineFragmentAscentRect
                                                              options:NSAlignAllEdgesNearest];
  *baselineOffset = lineFragmentAscentRect.size.height;
  return YES;
}

- (BOOL)                        layoutManager:(NSLayoutManager *)layoutManager
  shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex {
  return charIndex <= 1 || [layoutManager.textStorage.string characterAtIndex:charIndex - 1] != '\t';
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager
                          shouldUseAction:(NSControlCharacterAction)action
               forControlCharacterAtIndex:(NSUInteger)charIndex {
  if ([layoutManager.textStorage.string characterAtIndex:charIndex] == 0x8B &&
      [layoutManager.textStorage attribute:(NSString *)kCTRubyAnnotationAttributeName
                                   atIndex:charIndex 
                            effectiveRange:NULL]) {
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
    id rubyAnnotation = [layoutManager.textStorage attribute:(NSString *)kCTRubyAnnotationAttributeName
                                                     atIndex:charIndex 
                                              effectiveRange:&rubyRange];
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

#pragma mark - Typesetting extensions for TextKit 2 (macOS 12 or lower)

API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutFragment : NSTextLayoutFragment
@end

@implementation SquirrelTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point
          inContext:(CGContextRef)context {
  BOOL verticalOrientation = self.textLayoutManager.textContainer.layoutOrientation == NSTextLayoutOrientationVertical;
  for (NSTextLineFragment *lineFrag in self.textLineFragments) {
    CGContextSaveGState(context);
    NSFont *refFont = [lineFrag.attributedString attribute:(NSString *)kCTBaselineReferenceInfoAttributeName
                                                   atIndex:lineFrag.characterRange.location
                                            effectiveRange:NULL][(NSString *)kCTBaselineReferenceFont];
    CGPoint renderOrigin = CGPointMake(NSMinX(lineFrag.typographicBounds) + lineFrag.glyphOrigin.x,
                                       NSMidY(lineFrag.typographicBounds) - lineFrag.glyphOrigin.y +
                                       (verticalOrientation ? 0.0 : refFont.ascender / 2 + refFont.descender / 2));
    CGPoint deviceRenderOrigin = CGContextConvertPointToDeviceSpace(context, renderOrigin);
    renderOrigin = CGContextConvertPointToUserSpace(context, CGPointMake(round(deviceRenderOrigin.x), round(deviceRenderOrigin.y)));
    [lineFrag drawAtPoint:renderOrigin inContext:context];
    CGContextRestoreGState(context);
  }
}

@end // SquirrelTextLayoutFragment


API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutManager : NSTextLayoutManager <NSTextLayoutManagerDelegate>
@end

@implementation SquirrelTextLayoutManager

- (BOOL)      textLayoutManager:(NSTextLayoutManager *)textLayoutManager
  shouldBreakLineBeforeLocation:(id<NSTextLocation>)location
                    hyphenating:(BOOL)hyphenating {
  NSTextContentStorage *contentStorage = textLayoutManager.textContainer.textView.textContentStorage;
  NSInteger charIndex = [contentStorage offsetFromLocation:contentStorage.documentRange.location 
                                                toLocation:location];
  return charIndex <= 1 || [contentStorage.textStorage.string characterAtIndex:(NSUInteger)charIndex - 1] != '\t';
}

- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager
              textLayoutFragmentForLocation:(id<NSTextLocation>)location
                              inTextElement:(NSTextElement *)textElement {
  return [[SquirrelTextLayoutFragment alloc] initWithTextElement:textElement
            range:[[NSTextRange alloc] initWithLocation:location
                                            endLocation:textElement.elementRange.endLocation]];
}

@end // SquirrelTextLayoutManager

#pragma mark - View behind text, containing drawings of backgrounds and highlights

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSTextView *textView;
@property(nonatomic, readonly) NSTextStorage *textStorage;
@property(nonatomic, readonly, strong) SquirrelTheme *currentTheme;
@property(nonatomic, readonly) CAShapeLayer *shape;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) SquirrelAppear appear;
@property(nonatomic, readonly) NSEdgeInsets alignmentRectInsets;
@property(nonatomic, readonly) NSArray<NSValue *> *candidateRanges;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) NSUInteger highlightedIndex;
@property(nonatomic, readonly) rimeIndex functionButton;
@property(nonatomic, readonly) NSBezierPath *deleteBackPath;
@property(nonatomic, readonly) NSMutableArray<NSBezierPath *> *candidatePaths;
@property(nonatomic, readonly) NSMutableArray<NSBezierPath *> *pagingPaths;

- (NSTextRange *)getTextRangeFromCharRange:(NSRange)charRange API_AVAILABLE(macos(12.0));

- (NSRange)getCharRangeFromTextRange:(NSTextRange *)textRange API_AVAILABLE(macos(12.0));

- (NSRect)contentRectForRange:(NSRange)range;

- (void)drawViewWithInsets:(NSEdgeInsets)alignmentRectInsets
           candidateRanges:(NSArray<NSValue *> *)candidateRanges
          highlightedIndex:(NSUInteger)highlightedIndex
              preeditRange:(NSRange)preeditRange
   highlightedPreeditRange:(NSRange)highlightedPreeditRange
               pagingRange:(NSRange)pagingRange;

- (void)highlightFunctionButton:(rimeIndex)functionButton;

- (BOOL)convertClickSpot:(NSPoint)spot
                 toIndex:(NSUInteger *)index;

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
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
  }

  if (@available(macOS 12.0, *)) {
    SquirrelTextLayoutManager *textLayoutManager = [[SquirrelTextLayoutManager alloc] init];
    textLayoutManager.usesFontLeading = NO;
    textLayoutManager.usesHyphenation = NO;
    textLayoutManager.delegate = textLayoutManager;
    NSTextContainer *textContainer = [[NSTextContainer alloc]
                                      initWithSize:NSMakeSize(NSViewWidthSizable, CGFLOAT_MAX)];
    textContainer.lineFragmentPadding = 0;
    textLayoutManager.textContainer = textContainer;
    NSTextContentStorage *contentStorage = [[NSTextContentStorage alloc] init];
    [contentStorage addTextLayoutManager:textLayoutManager];
    _textView = [[NSTextView alloc] initWithFrame:frameRect
                                    textContainer:textContainer];
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
    id<NSTextLocation> startLocation =
      [contentStorage locationFromLocation:contentStorage.documentRange.location
                                withOffset:(NSInteger)charRange.location];
    id<NSTextLocation> endLocation =
      [contentStorage locationFromLocation:startLocation
                                withOffset:(NSInteger)charRange.length];
    return [[NSTextRange alloc] initWithLocation:startLocation
                                     endLocation:endLocation];
  }
}

- (NSRange)getCharRangeFromTextRange:(NSTextRange *)textRange API_AVAILABLE(macos(12.0)) {
  if (textRange == nil) {
    return NSMakeRange(NSNotFound, 0);
  } else {
    NSTextContentStorage *contentStorage = _textView.textContentStorage;
    NSInteger location = [contentStorage offsetFromLocation:contentStorage.documentRange.location
                                                 toLocation:textRange.location];
    NSInteger length = [contentStorage offsetFromLocation:textRange.location 
                                               toLocation:textRange.endLocation];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
  }
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  if (@available(macOS 12.0, *)) {
    [_textView.textLayoutManager ensureLayoutForRange:_textView.textContentStorage.documentRange];
    return _textView.textLayoutManager.usageBoundsForTextContainer;
  } else {
    [_textView.layoutManager ensureLayoutForTextContainer:_textView.textContainer];
    return [_textView.layoutManager usedRectForTextContainer:_textView.textContainer];
  }
}

// Get the rectangle containing the range of text, will first convert to glyph or text range, expensive to calculate
- (NSRect)contentRectForRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromCharRange:range];
    NSRect __block contentRect = NSZeroRect;
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeHighlight
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline,
                                    NSTextContainer *textContainer) {
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
- (void)drawViewWithInsets:(NSEdgeInsets)alignmentRectInsets
           candidateRanges:(NSArray<NSValue *> *)candidateRanges
          highlightedIndex:(NSUInteger)highlightedIndex
              preeditRange:(NSRange)preeditRange
   highlightedPreeditRange:(NSRange)highlightedPreeditRange
               pagingRange:(NSRange)pagingRange {
  _alignmentRectInsets = alignmentRectInsets;
  _candidateRanges = candidateRanges;
  _highlightedIndex = highlightedIndex;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  _pagingRange = pagingRange;
  _deleteBackPath = preeditRange.length > 0 ? [NSBezierPath bezierPath] : nil;
  _candidatePaths = [[NSMutableArray alloc] initWithCapacity:candidateRanges.count];
  _pagingPaths = [[NSMutableArray alloc] initWithCapacity:pagingRange.length > 0 ? 2 : 0];
  _functionButton = kVoidSymbol;
  // invalidate Rect beyond bound of textview to clear any out-of-bound drawing from last round
  [self setNeedsDisplayInRect:self.bounds];
  [self.textView setNeedsDisplayInRect:self.bounds];
}

- (void)highlightFunctionButton:(rimeIndex)functionButton {
  _functionButton = functionButton;
  if (_deleteBackPath && !_deleteBackPath.empty) {
    [self setNeedsDisplayInRect:_deleteBackPath.bounds];
    [self.textView setNeedsDisplayInRect:_deleteBackPath.bounds];
  }
  if (_pagingPaths.count > 0) {
    [self setNeedsDisplayInRect:_pagingPaths[0].bounds];
    [self setNeedsDisplayInRect:_pagingPaths[1].bounds];
    [self.textView setNeedsDisplayInRect:_pagingPaths[0].bounds];
    [self.textView setNeedsDisplayInRect:_pagingPaths[1].bounds];
  }
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

static inline NSArray<NSValue *> * rectVertex(NSRect rect) {
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
    NSMutableArray<NSValue *> *lineRects = [[NSMutableArray alloc] init];
    NSMutableArray<NSTextRange *> *lineRanges = [[NSMutableArray alloc] init];
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeHighlight
                          options:NSTextLayoutManagerSegmentOptionsNone
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline,
                                    NSTextContainer *textContainer) {
      if (!nearEmptyRect(segFrame)) {
        NSRect lastSegFrame = lineRects.count > 0 ? lineRects.lastObject.rectValue : NSZeroRect;
        if (NSMinY(segFrame) < NSMaxY(lastSegFrame)) {
          segFrame = NSUnionRect(segFrame, lastSegFrame);
          lineRects[lineRects.count - 1] = [NSValue valueWithRect:segFrame];
          segRange = [segRange textRangeByFormingUnionWithTextRange:lineRanges.lastObject];
          lineRanges[lineRanges.count - 1] = segRange;
        } else {
          [lineRects addObject:[NSValue valueWithRect:segFrame]];
          [lineRanges addObject:segRange];
        }
      }
      return YES;
    }];
    if (lineRects.count == 1) {
      *bodyRect = lineRects[0].rectValue;
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
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
      CGFloat endX = NSMaxRange(glyphRange) < NSMaxRange(leadingLineRange) ?
        [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x : NSWidth(leadingLineRect);
      *bodyRect = NSMakeRect(startX, NSMinY(leadingLineRect),
                             endX - startX, NSHeight(leadingLineRect));
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
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
  if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && NSIsEmptyRect(trailingRect)) {
    return rectVertex(leadingRect);
  } else if (NSIsEmptyRect(bodyRect) && NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect)) {
    return rectVertex(trailingRect);
  } else if (NSIsEmptyRect(leadingRect) && NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    return rectVertex(bodyRect);
  } else if (NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], bodyVertex[1], bodyVertex[2], leadingVertex[3]];
  } else if (NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], trailingVertex[1], trailingVertex[2], trailingVertex[3], bodyVertex[2], bodyVertex[3]];
  } else if (!NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) &&
             NSIsEmptyRect(bodyRect) && NSMinX(leadingRect) <= NSMaxX(trailingRect)) {
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], trailingVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3]];
  } else if (!NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray<NSValue *> *leadingVertex = rectVertex(leadingRect);
    NSArray<NSValue *> *bodyVertex = rectVertex(bodyRect);
    NSArray<NSValue *> *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3]];
  } else {
    return @[];
  }
}

static inline NSColor * hooverColor(NSColor *color, SquirrelAppear appear) {
  if (color == nil) {
    return nil;
  }
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  } else {
    return appear == darkAppear ? [color highlightWithLevel:0.3] : [color shadowWithLevel:0.3];
  }
}

static inline NSColor * disabledColor(NSColor *color, SquirrelAppear appear) {
  if (color == nil) {
    return nil;
  }
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectDisabled];
  } else {
    return appear == darkAppear ? [color shadowWithLevel:0.3] : [color highlightWithLevel:0.3];
  }
}

- (CAShapeLayer *)getFunctionButtonLayer {
  SquirrelTheme *theme = self.currentTheme;
  NSColor *buttonColor;
  NSBezierPath *buttonPath;
  switch (_functionButton) {
    case kPageUp:
      buttonColor = hooverColor(theme.linear ? theme.highlightedStripColor 
                                             : theme.highlightedPreeditColor, self.appear);
      buttonPath = _pagingPaths[0];
      break;
    case kHome:
      buttonColor = disabledColor(theme.linear ? theme.highlightedStripColor 
                                               : theme.highlightedPreeditColor, self.appear);
      buttonPath = _pagingPaths[0];
      break;
    case kPageDown:
      buttonColor = hooverColor(theme.linear ? theme.highlightedStripColor 
                                             : theme.highlightedPreeditColor, self.appear);
      buttonPath = _pagingPaths[1];
      break;
    case kEnd:
      buttonColor = disabledColor(theme.linear ? theme.highlightedStripColor 
                                               : theme.highlightedPreeditColor, self.appear);
      buttonPath = _pagingPaths[1];
      break;
    case kBackSpace:
      buttonColor = hooverColor(theme.highlightedPreeditColor, self.appear);
      buttonPath = _deleteBackPath;
      break;
    case kEscape:
      buttonColor = disabledColor(theme.highlightedPreeditColor, self.appear);
      buttonPath= _deleteBackPath;
      break;
    default:
      return nil;
      break;
  }
  if (!buttonPath.empty && buttonColor) {
    CAShapeLayer *functionButtonLayer = [[CAShapeLayer alloc] init];
    functionButtonLayer.path = buttonPath.quartzPath;
    functionButtonLayer.fillColor = buttonColor.CGColor;
    return functionButtonLayer;
  }
  return nil;
}

// All draws happen here
- (void)updateLayer {
  NSBezierPath *panelPath;
  NSBezierPath *backgroundPath;
  NSBezierPath *borderPath;
  NSBezierPath *highlightedPath;
  NSBezierPath *highlightedPreeditPath;
  NSBezierPath *candidateBlockPath;
  NSBezierPath *gridPath;

  SquirrelTheme *theme = self.currentTheme;
  NSRect panelRect = self.bounds;
  NSRect backgroundRect = [self backingAlignedRect:NSInsetRect(panelRect, theme.edgeInset.width, theme.edgeInset.height)
                                           options:NSAlignAllEdgesNearest];

  NSRange visibleRange;
  if (@available(macOS 12.0, *)) {
    visibleRange = [self getCharRangeFromTextRange:
                    _textView.textLayoutManager.textViewportLayoutController.viewportRange];
  } else {
    NSRange containerGlyphRange = NSMakeRange(NSNotFound, 0);
    [_textView.layoutManager textContainerForGlyphAtIndex:0
                                           effectiveRange:&containerGlyphRange];
    visibleRange = [_textView.layoutManager characterRangeForGlyphRange:containerGlyphRange
                                                       actualGlyphRange:NULL];
  }
  NSRange preeditRange = NSIntersectionRange(_preeditRange, visibleRange);
  NSRange candidateBlockRange = NSIntersectionRange(NSUnionRange(_candidateRanges.firstObject.rangeValue,
    theme.linear && _pagingRange.length > 0 ? _pagingRange : _candidateRanges.lastObject.rangeValue), visibleRange);
  NSRange pagingRange = NSIntersectionRange(_pagingRange, visibleRange);

  // Draw preedit Rect
  NSRect preeditRect = NSZeroRect;
  if (preeditRange.length > 0) {
    preeditRect = [self contentRectForRange:preeditRange];
    preeditRect.size.width = backgroundRect.size.width;
    preeditRect.origin = backgroundRect.origin;
    if (candidateBlockRange.length > 0) {
      preeditRect.size.height += theme.preeditLinespace;
    }
    preeditRect = [self backingAlignedRect:preeditRect
                                   options:NSAlignAllEdgesNearest];

    // Draw highlighted part of preedit text
    NSRange highlightedPreeditRange = NSIntersectionRange(_highlightedPreeditRange, visibleRange);
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius, theme.preeditParagraphStyle.maximumLineHeight / 3);
    if (highlightedPreeditRange.length > 0 && theme.highlightedPreeditColor) {
      CGFloat kerning = [theme.preeditAttrs[NSKernAttributeName] doubleValue];
      NSRect innerBox = NSMakeRect(preeditRect.origin.x + ceil(theme.separatorWidth * 0.5) - ceil(kerning * 0.5), preeditRect.origin.y,
                                   preeditRect.size.width - theme.separatorWidth + kerning, preeditRect.size.height);
      if (candidateBlockRange.length > 0) {
        innerBox.size.height -= theme.preeditLinespace;
      }
      innerBox = [self backingAlignedRect:innerBox options:NSAlignAllEdgesNearest];
      NSRect leadingRect = NSZeroRect;
      NSRect bodyRect = NSZeroRect;
      NSRect trailingRect = NSZeroRect;
      [self multilineRectForRange:highlightedPreeditRange leadingRect:&leadingRect
                         bodyRect:&bodyRect              trailingRect:&trailingRect];
      leadingRect = nearEmptyRect(leadingRect) ? NSZeroRect :
      [self backingAlignedRect:NSIntersectionRect(NSOffsetRect(leadingRect, - ceil(kerning * 0.5), 0.0), innerBox)
                       options:NSAlignAllEdgesNearest];
      bodyRect = nearEmptyRect(bodyRect) ? NSZeroRect :
      [self backingAlignedRect:NSIntersectionRect(NSOffsetRect(bodyRect, - ceil(kerning * 0.5), 0.0), innerBox)
                       options:NSAlignAllEdgesNearest];
      trailingRect = nearEmptyRect(trailingRect) ? NSZeroRect :
      [self backingAlignedRect:NSIntersectionRect(NSOffsetRect(trailingRect, - ceil(kerning * 0.5), 0.0), innerBox)
                       options:NSAlignAllEdgesNearest];

      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) &&
          NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPreeditPath = drawRoundedPolygon(rectVertex(leadingRect), cornerRadius);
        [highlightedPreeditPath appendBezierPath:drawRoundedPolygon(rectVertex(trailingRect), cornerRadius)];
      } else {
        highlightedPreeditPath = drawRoundedPolygon(multilineRectVertex(leadingRect, bodyRect, trailingRect), cornerRadius);
      }
    }
    NSRect deleteBackRect = [self contentRectForRange:NSMakeRange(NSMaxRange(_preeditRange) - 1, 1)];
    deleteBackRect.size.width += floor(theme.separatorWidth * 0.5);
    deleteBackRect.origin.x = NSMaxX(backgroundRect) - NSWidth(deleteBackRect);
    deleteBackRect = [self backingAlignedRect:NSIntersectionRect(deleteBackRect, preeditRect)
                                      options:NSAlignAllEdgesNearest];
    _deleteBackPath = drawRoundedPolygon(rectVertex(deleteBackRect), cornerRadius);
  }

  // Draw candidate Rect
  NSRect candidateBlockRect = NSZeroRect;
  if (candidateBlockRange.length > 0) {
    candidateBlockRect = NSInsetRect([self contentRectForRange:candidateBlockRange], 0.0, - theme.linespace * 0.5);
    candidateBlockRect.size.width = backgroundRect.size.width;
    candidateBlockRect.origin = backgroundRect.origin;
    if (preeditRange.length != 0) {
      candidateBlockRect.origin.y = NSMaxY(preeditRect);
    }
    if (pagingRange.length == 0 || theme.linear) {
      candidateBlockRect.size.height = NSMaxY(backgroundRect) - NSMinY(candidateBlockRect);
    }
    candidateBlockRect = [self backingAlignedRect:NSIntersectionRect(candidateBlockRect, backgroundRect)
                                          options:NSAlignAllEdgesNearest];
    candidateBlockPath = drawRoundedPolygon(rectVertex(candidateBlockRect),
                                            MIN(theme.highlightedCornerRadius, NSHeight(candidateBlockRect) / 3));

    // Draw candidate highlight rect
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius, theme.paragraphStyle.maximumLineHeight / 3);
    if (theme.linear) {
      CGFloat gridOriginY = NSMinY(candidateBlockRect);
      CGFloat tabInterval = theme.separatorWidth * 2;
      CGFloat kerning = [theme.attrs[NSKernAttributeName] doubleValue];
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange(_candidateRanges[i].rangeValue, visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect leadingRect = NSZeroRect;
        NSRect bodyRect = NSZeroRect;
        NSRect trailingRect = NSZeroRect;
        [self multilineRectForRange:candidateRange leadingRect:&leadingRect 
                           bodyRect:&bodyRect     trailingRect:&trailingRect];
        if (nearEmptyRect(leadingRect)) {
          leadingRect = NSZeroRect;
          bodyRect.origin.y -= ceil(theme.linespace * 0.5);
          bodyRect.size.height += ceil(theme.linespace * 0.5);
        } else {
          leadingRect.origin.x -= ceil(theme.separatorWidth * 0.5 + kerning * 0.5);
          leadingRect.size.width += theme.separatorWidth + kerning * 0.5;
          leadingRect.origin.y -= ceil(theme.linespace * 0.5);
          leadingRect.size.height += ceil(theme.linespace * 0.5);
          leadingRect = [self backingAlignedRect:NSIntersectionRect(leadingRect, candidateBlockRect)
                                         options:NSAlignAllEdgesNearest];
        }
        if (nearEmptyRect(trailingRect)) {
          trailingRect = NSZeroRect;
          bodyRect.size.height += floor(theme.linespace * 0.5);
        } else {
          trailingRect.origin.x -= ceil(theme.separatorWidth * 0.5 + kerning * 0.5);
          trailingRect.size.width += theme.separatorWidth + kerning * 0.5;
          trailingRect.size.height += floor(theme.linespace * 0.5);
          trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, candidateBlockRect)
                                          options:NSAlignAllEdgesNearest];
        }
        if (nearEmptyRect(bodyRect)) {
          bodyRect = NSZeroRect;
        } else {
          bodyRect.origin.x -= ceil(theme.separatorWidth * 0.5 + kerning * 0.5);
          bodyRect.size.width += theme.separatorWidth + kerning * 0.5;
          bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, candidateBlockRect)
                                      options:NSAlignAllEdgesNearest];
        }
        if (theme.tabled) {
          CGFloat bottomEdge = NSMaxY(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          if (ABS(bottomEdge - gridOriginY) > 2 && ABS(bottomEdge - NSMaxY(candidateBlockRect)) > 2) { // horizontal border
            [gridPath moveToPoint:NSMakePoint(NSMinX(candidateBlockRect) + theme.separatorWidth * 0.5, bottomEdge)];
            [gridPath lineToPoint:NSMakePoint(NSMaxX(candidateBlockRect) - theme.separatorWidth * 0.5, bottomEdge)];
            [gridPath closePath];
            gridOriginY = bottomEdge;
          }
          CGPoint leadOrigin = (NSIsEmptyRect(leadingRect) ? bodyRect : leadingRect).origin;
          if (leadOrigin.x > NSMinX(candidateBlockRect) +theme.separatorWidth * 0.5) { // vertical bar
            [gridPath moveToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + ceil(theme.linespace * 0.5) +
                                              theme.highlightedCornerRadius / 2)];
            [gridPath lineToPoint:NSMakePoint(leadOrigin.x, leadOrigin.y + floor(theme.linespace * 0.5) +
                                              theme.paragraphStyle.maximumLineHeight - theme.highlightedCornerRadius / 2)];
            [gridPath closePath];
          }
          CGFloat endEdge = NSMaxX(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          CGFloat tabPosition = ceil((endEdge + kerning + theme.separatorWidth * 0.5) / tabInterval) * tabInterval - theme.separatorWidth * 0.5;
          if (!NSIsEmptyRect(trailingRect)) {
            trailingRect.size.width += tabPosition - endEdge;
            trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, candidateBlockRect)
                                            options:NSAlignAllEdgesNearest];
          } else if (NSIsEmptyRect(leadingRect)) {
            bodyRect.size.width += tabPosition - endEdge;
            bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, candidateBlockRect)
                                        options:NSAlignAllEdgesNearest];
          }
        }
        NSBezierPath *candidatePath;
        // Handles the special case where containing boxes are separated
        if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) &&
            !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePath = drawRoundedPolygon(rectVertex(leadingRect), cornerRadius);
          [candidatePath appendBezierPath:drawRoundedPolygon(rectVertex(trailingRect), cornerRadius)];
        } else {
          candidatePath = drawRoundedPolygon(multilineRectVertex(leadingRect, bodyRect, trailingRect), cornerRadius);
        }
        _candidatePaths[i] = candidatePath;
      }
    } else { // stacked layout
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange(_candidateRanges[i].rangeValue, visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect candidateRect = [self contentRectForRange:candidateRange];
        candidateRect.size.width = backgroundRect.size.width;
        candidateRect.origin.x = backgroundRect.origin.x;
        candidateRect.origin.y -= ceil(theme.linespace * 0.5);
        candidateRect.size.height += theme.linespace;
        candidateRect = [self backingAlignedRect:NSIntersectionRect(candidateRect, candidateBlockRect)
                                         options:NSAlignAllEdgesNearest];
        NSBezierPath *candidatePath = drawRoundedPolygon(rectVertex(candidateRect), cornerRadius);
        _candidatePaths[i] = candidatePath;
      }
    }
  }

  // Draw paging Rect
  if (pagingRange.length > 0) {
    NSRect pageUpRect = [self contentRectForRange:NSMakeRange(pagingRange.location, 1)];
    NSRect pageDownRect = [self contentRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)];
    pageDownRect.size.width += ceil(theme.separatorWidth * 0.5);
    pageUpRect.origin.x -= ceil(theme.separatorWidth * 0.5);
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    if (theme.linear) {
      pageUpRect.origin.y -= ceil(theme.linespace * 0.5);
      pageUpRect.size.height += theme.linespace;
      pageDownRect.origin.y -= ceil(theme.linespace * 0.5);
      pageDownRect.size.height += theme.linespace;
      pageUpRect = NSIntersectionRect(pageUpRect, candidateBlockRect);
      pageDownRect = NSIntersectionRect(pageDownRect, candidateBlockRect);
    } else {
      NSRect pagingRect = NSMakeRect(NSMinX(backgroundRect), NSMaxY(candidateBlockRect),
                                     NSWidth(backgroundRect), NSMaxY(backgroundRect) - NSMaxY(candidateBlockRect));
      pageUpRect = NSIntersectionRect(pageUpRect, pagingRect);
      pageDownRect = NSIntersectionRect(pageDownRect, pagingRect);
    }
    pageUpRect = [self backingAlignedRect:pageUpRect options:NSAlignAllEdgesNearest];
    pageDownRect = [self backingAlignedRect:pageDownRect options:NSAlignAllEdgesNearest];
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius, MIN(NSWidth(pageDownRect), NSHeight(pageDownRect)) / 3);
    _pagingPaths[0] = drawRoundedPolygon(rectVertex(pageUpRect), cornerRadius);
    _pagingPaths[1] = drawRoundedPolygon(rectVertex(pageDownRect), cornerRadius);
  }

  // Draw borders
  backgroundPath = drawRoundedPolygon(rectVertex(backgroundRect),
                                      MIN(theme.highlightedCornerRadius, NSHeight(backgroundRect) / 3));
  panelPath = drawRoundedPolygon(rectVertex(panelRect), MIN(theme.cornerRadius, NSHeight(panelRect) / 3));
  if (!NSEqualSizes(theme.edgeInset, NSZeroSize)) {
    borderPath = [panelPath copy];
    [borderPath appendBezierPath:backgroundPath];
  }

  // Set layers
  _shape.path = panelPath.quartzPath;
  _shape.fillColor = NSColor.whiteColor.CGColor;
  [self.layer setSublayers:nil];
  CALayer *panelLayer = [[CALayer alloc] init];
  if (theme.translucency > 0) {
    panelLayer.opacity = 1.0f - (float)theme.translucency;
  }
  [self.layer addSublayer:panelLayer];
  // background image (pattern style) layer
  if (theme.backgroundImage && theme.backgroundImage.valid) {
    CAShapeLayer *backgroundImageLayer = [[CAShapeLayer alloc] init];
    CGAffineTransform transform = theme.vertical ? CGAffineTransformMakeRotation(M_PI_2) : CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, _alignmentRectInsets.left - theme.edgeInset.width,
                                                      _alignmentRectInsets.top - theme.edgeInset.height);
    backgroundImageLayer.path = CFAutorelease(CGPathCreateCopyByTransformingPath(backgroundPath.quartzPath, &transform));
    backgroundImageLayer.fillColor = [NSColor colorWithPatternImage:theme.backgroundImage].CGColor;
    backgroundImageLayer.affineTransform = CGAffineTransformInvert(transform);
    [panelLayer addSublayer:backgroundImageLayer];
  }
  // background color layer
  CAShapeLayer *backgroundLayer = [[CAShapeLayer alloc] init];
  backgroundLayer.path = backgroundPath.quartzPath;
  backgroundLayer.fillColor = theme.backgroundColor.CGColor;
  [panelLayer addSublayer:backgroundLayer];
  if ((_preeditRange.length > 0 || (!theme.linear && _pagingRange.length > 0)) &&
      theme.preeditBackgroundColor) {
    backgroundLayer.fillColor = theme.preeditBackgroundColor.CGColor;
    if (!candidateBlockPath.empty) {
      [backgroundPath appendBezierPath:candidateBlockPath.bezierPathByReversingPath];
      backgroundLayer.path = backgroundPath.quartzPath;
      backgroundLayer.fillRule = kCAFillRuleEvenOdd;
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = candidateBlockPath.quartzPath;
      candidateLayer.fillColor = theme.backgroundColor.CGColor;
      [panelLayer addSublayer:candidateLayer];
    }
  }
  // highlighted preedit layer
  if (theme.highlightedPreeditColor && !highlightedPreeditPath.empty) {
    CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
    highlightedPreeditLayer.path = highlightedPreeditPath.quartzPath;
    highlightedPreeditLayer.fillColor = theme.highlightedPreeditColor.CGColor;
    [self.layer addSublayer:highlightedPreeditLayer];
  }
  // highlighted candidate layer
  if (_highlightedIndex < _candidatePaths.count && theme.highlightedStripColor) {
    CAShapeLayer *highlightedLayer = [[CAShapeLayer alloc] init];
    highlightedPath = _candidatePaths[_highlightedIndex];
    highlightedLayer.path = highlightedPath.quartzPath;
    highlightedLayer.fillColor = theme.highlightedStripColor.CGColor;
    [self.layer addSublayer:highlightedLayer];
  }
  // function buttons (page up, page down, backspace) layer
  if (_functionButton != kVoidSymbol) {
    CAShapeLayer *functionButtonLayer = [self getFunctionButtonLayer];
    if (functionButtonLayer) {
      [self.layer addSublayer:functionButtonLayer];
    }
  }
  // grids (in candidate block) layer
  if (theme.tabled) {
    CAShapeLayer *gridLayer = [[CAShapeLayer alloc] init];
    gridLayer.path = gridPath.quartzPath;
    gridLayer.strokeColor = [theme.backgroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                               ofColor:(self.appear == darkAppear ? NSColor.lightGrayColor : NSColor.blackColor)].CGColor;
    gridLayer.lineWidth = theme.edgeInset.height * 0.5;
    gridLayer.lineCap = kCALineCapRound;
    [panelLayer addSublayer:gridLayer];
  }
  // border layer
  if (!borderPath.empty && theme.borderColor) {
    CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
    borderLayer.path = borderPath.quartzPath;
    borderLayer.fillColor = theme.borderColor.CGColor;
    borderLayer.fillRule = kCAFillRuleEvenOdd;
    [panelLayer addSublayer:borderLayer];
  }
}

- (BOOL)convertClickSpot:(NSPoint)spot
                 toIndex:(NSUInteger *)index {
  if (NSPointInRect(spot, self.bounds)) {
    if (_deleteBackPath != nil && [_deleteBackPath containsPoint:spot]) {
      *index = kBackSpace;
      return YES;
    }
    if (_pagingPaths.count > 0) {
      if ([_pagingPaths[0] containsPoint:spot]) {
        *index = kPageUp;
        return YES;
      }
      if ([_pagingPaths[1] containsPoint:spot]) {
        *index = kPageDown;
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


#pragma mark - Panel window, dealing with text content and mouse interactions


@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;

  NSSize _maxSize;
  CGFloat _textWidthLimit;
  NSPoint _scrollLocus;
  BOOL _initPosition;

  NSUInteger _numCandidates;
  NSUInteger _highlighted;
  NSUInteger _functionButton;
  BOOL _caretAtHome;
  BOOL _firstPage;
  BOOL _lastPage;

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

  NSMutableDictionary *attrs = defaultAttrs.mutableCopy;
  attrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;
  attrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *highlightedAttrs = defaultAttrs.mutableCopy;
  highlightedAttrs[NSForegroundColorAttributeName] = NSColor.selectedMenuItemTextColor;
  highlightedAttrs[NSFontAttributeName] = userFont;
  // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
  attrs[NSWritingDirectionAttributeName] = @[@(0)];
  highlightedAttrs[NSWritingDirectionAttributeName] = @[@(0)];

  NSMutableDictionary *labelAttrs = attrs.mutableCopy;
  labelAttrs[NSForegroundColorAttributeName] = NSColor.controlAccentColor;
  labelAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *labelHighlightedAttrs = highlightedAttrs.mutableCopy;
  labelHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.alternateSelectedControlTextColor;
  labelHighlightedAttrs[NSFontAttributeName] = userMonoFont;

  NSMutableDictionary *commentAttrs = defaultAttrs.mutableCopy;
  commentAttrs[NSForegroundColorAttributeName] = NSColor.secondaryLabelColor;
  commentAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *commentHighlightedAttrs = defaultAttrs.mutableCopy;
  commentHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.alternateSelectedControlTextColor;
  commentHighlightedAttrs[NSFontAttributeName] = userFont;

  NSMutableDictionary *preeditAttrs = defaultAttrs.mutableCopy;
  preeditAttrs[NSForegroundColorAttributeName] = NSColor.textColor;
  preeditAttrs[NSFontAttributeName] = userFont;
  preeditAttrs[NSLigatureAttributeName] = @(0);

  NSMutableDictionary *preeditHighlightedAttrs = defaultAttrs.mutableCopy;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.selectedTextColor;
  preeditHighlightedAttrs[NSFontAttributeName] = userFont;
  preeditHighlightedAttrs[NSLigatureAttributeName] = @(0);

  NSMutableDictionary *pagingAttrs = defaultAttrs.mutableCopy;
  pagingAttrs[NSForegroundColorAttributeName] = theme.linear ? NSColor.controlAccentColor : NSColor.controlTextColor;

  NSMutableDictionary *pagingHighlightedAttrs = defaultAttrs.mutableCopy;
  pagingHighlightedAttrs[NSForegroundColorAttributeName] = theme.linear
    ? NSColor.alternateSelectedControlTextColor : NSColor.selectedMenuItemTextColor;

  NSMutableParagraphStyle *preeditParagraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
  NSMutableParagraphStyle *paragraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
  NSMutableParagraphStyle *pagingParagraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
  NSMutableParagraphStyle *statusParagraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;

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

  NSMutableDictionary *statusAttrs = commentAttrs.mutableCopy;
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
                          styleMask:NSWindowStyleMaskNonactivatingPanel|NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    self.level = CGWindowLevelForKey(kCGCursorWindowLevelKey) - 10;
    self.alphaValue = 1.0;
    self.hasShadow = NO;
    self.opaque = NO;
    self.displaysWhenScreenProfileChanges = YES;
    self.backgroundColor = NSColor.clearColor;
    self.delegate = self;

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

    [self updateDisplayParameters];
    [self initializeUIStyleForAppearance:defaultAppear];
    [self initializeUIStyleForAppearance:darkAppear];
  }
  return self;
}

- (void)windowDidChangeScreenProfile:(NSNotification *)notification {
  if (self.isVisible) {
    [self.inputController.client attributesForCharacterIndex:0 
                                         lineHeightRectangle:&_position];
    [self updateDisplayParameters];
    [self display];
  }
}

- (void)windowDidChangeScreen:(NSNotification *)notification {
  if (self.isVisible) {
    [self.inputController.client attributesForCharacterIndex:0
                                         lineHeightRectangle:&_position];
    [self updateDisplayParameters];
    [self display];
  }
}

- (void)sendEvent:(NSEvent *)event {
  NSPoint spot = [_view convertPoint:self.mouseLocationOutsideOfEventStream
                            fromView:nil];
  NSUInteger cursorIndex = NSNotFound;
  switch (event.type) {
    case NSEventTypeLeftMouseUp:
      if (event.clickCount == 1 && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _highlighted || cursorIndex == _functionButton) {
          [_inputController perform:kSELECT onIndex:cursorIndex];
        }
      }
      break;
    case NSEventTypeRightMouseUp:
      if (event.clickCount == 1 && [_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex == _highlighted) {
          [_inputController perform:kDELETE onIndex:cursorIndex];
        } else if (cursorIndex == _functionButton) {
          switch (cursorIndex) {
            case kPageUp:
              [_inputController perform:kSELECT onIndex:kHome];
              break;
            case kPageDown:
              [_inputController perform:kSELECT onIndex:kEnd];
              break;
            case kBackSpace:
              [_inputController perform:kSELECT onIndex:kEscape];
              break;
          }
        }
      }
      break;
    case NSEventTypeMouseMoved:
      if ([_view convertClickSpot:spot toIndex:&cursorIndex]) {
        if (cursorIndex >= 0 && cursorIndex < _numCandidates && _highlighted != cursorIndex) {
          _highlighted = cursorIndex;
          [_inputController perform:kHILITE onIndex:[_view.currentTheme.selectKeys characterAtIndex:cursorIndex]];
        } else if ((cursorIndex == kPageUp || cursorIndex == kPageDown ||
                    cursorIndex == kBackSpace) && _functionButton != cursorIndex) {
          _functionButton = cursorIndex;
          SquirrelTheme *theme = _view.currentTheme;
          switch (_functionButton) {
            case kPageUp:
              [_view.textStorage addAttributes:theme.pagingHighlightedAttrs
                                         range:NSMakeRange(_view.pagingRange.location, 1)];
              [_view.textStorage addAttributes:theme.pagingAttrs
                                         range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
              if (_view.preeditRange.length > 0) {
                [_view.textStorage addAttributes:theme.preeditAttrs
                                           range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
              }
              cursorIndex = _firstPage ? kHome : kPageUp;
              break;
            case kPageDown:
              [_view.textStorage addAttributes:theme.pagingAttrs 
                                         range:NSMakeRange(_view.pagingRange.location, 1)];
              [_view.textStorage addAttributes:theme.pagingHighlightedAttrs
                                         range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
              if (_view.preeditRange.length > 0) {
                [_view.textStorage addAttributes:theme.preeditAttrs 
                                           range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
              }
              cursorIndex = _lastPage ? kEnd : kPageDown;
              break;
            case kBackSpace:
              [_view.textStorage addAttributes:theme.preeditHighlightedAttrs
                                         range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
              if (_view.pagingRange.length > 0) {
                [_view.textStorage addAttributes:theme.pagingAttrs
                                           range:NSMakeRange(_view.pagingRange.location, 1)];
                [_view.textStorage addAttributes:theme.pagingAttrs 
                                           range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
              }
              cursorIndex = _caretAtHome ? kEscape : kBackSpace;
              break;
          }
          [_view highlightFunctionButton:cursorIndex];
          [self display];
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
          [_inputController perform:kSELECT 
                            onIndex:(theme.vertical ? kPageDown : kPageUp)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y > scrollThreshold) {
          [_inputController perform:kSELECT
                            onIndex:kPageUp];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [_inputController perform:kSELECT 
                            onIndex:(theme.vertical ? kPageUp : kPageDown)];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        } else if (_scrollLocus.y < -scrollThreshold) {
          [_inputController perform:kSELECT
                            onIndex:kPageDown];
          _scrollLocus = NSMakePoint(NSNotFound, NSNotFound);
        }
      }
    } break;
    default:
      [super sendEvent:event];
      break;
  }
}

- (NSScreen *)screen {
  if (!NSIsEmptyRect(_position)) {
    for (NSScreen *screen in NSScreen.screens) {
      if (NSPointInRect(_position.origin, screen.frame)) {
        return screen;
      }
    }
  }
  return NSScreen.mainScreen;
}

- (void)updateDisplayParameters {
  // repositioning the panel window
  _initPosition = YES;
  _maxSize = NSZeroSize;

  // size limits on textContainer
  NSRect screenRect = self.screen.visibleFrame;
  SquirrelTheme *theme = _view.currentTheme;
  CGFloat textWidthRatio = MIN(0.5, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit = (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio - theme.separatorWidth - theme.edgeInset.width * 2 -kOffsetGap;
  if (theme.lineLength > 0) {
    _textWidthLimit = MIN(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabled) {
    CGFloat tabInterval = theme.separatorWidth * 2;
    _textWidthLimit = floor((_textWidthLimit + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
  }
  CGFloat textHeightLimit = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.5 - theme.edgeInset.height * 2 - kOffsetGap;
  _view.textView.textContainer.size = NSMakeSize(_textWidthLimit, textHeightLimit);
  [_view.textView invalidateTextContainerOrigin];

  // resize background image, if any
  if (theme.backgroundImage && theme.backgroundImage.valid) {
    CGFloat panelWidth = _textWidthLimit + theme.separatorWidth;
    NSSize backgroundImageSize = theme.backgroundImage.size;
    theme.backgroundImage.resizingMode = NSImageResizingModeStretch;
    theme.backgroundImage.size = theme.vertical ?
      NSMakeSize(backgroundImageSize.width / backgroundImageSize.height * panelWidth, panelWidth) :
      NSMakeSize(panelWidth, backgroundImageSize.height / backgroundImageSize.width * panelWidth);
  }
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  NSAppearanceName appearanceName = _view.appear == darkAppear ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
  NSAppearance *requestedAppearance = [NSAppearance appearanceNamed:appearanceName];
  if (self.appearance != requestedAppearance) {
    self.appearance = requestedAppearance;
  }

  //Break line if the text is too long, based on screen size.
  SquirrelTheme *theme = _view.currentTheme;
  NSTextContainer *textContainer = _view.textView.textContainer;
  NSEdgeInsets insets = _view.alignmentRectInsets;
  CGFloat textWidthRatio = MIN(0.5, 1.0 / (theme.vertical ? 4 : 3) + [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = self.screen.visibleFrame;
  CGFloat textHeightLimit = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.5 - insets.top - insets.bottom - kOffsetGap;

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  BOOL sweepVertical = NSWidth(_position) > NSHeight(_position);
  NSRect contentRect = _view.contentRect;
  NSRect maxContentRect = contentRect;
  // fixed line length (text width), but not applicable to status message
  if (theme.lineLength > 0 && _statusMessage == nil) {
    maxContentRect.size.width = _textWidthLimit;
  }
  // remember panel size (fix the top leading anchor of the panel in screen coordiantes)
  // but only when the text would expand on the side of upstream (i.e. towards the beginning of text)
  if (theme.rememberSize && _statusMessage == nil) {
    if (theme.lineLength == 0 && (theme.vertical
        ? (sweepVertical ? (NSMinY(_position) - MAX(NSWidth(maxContentRect), _maxSize.width) - insets.right < NSMinY(screenRect))
                         : (NSMinY(_position) - kOffsetGap - NSHeight(screenRect) * textWidthRatio - insets.left - insets.right < NSMinY(screenRect)))
        : (sweepVertical ? (NSMinX(_position) - kOffsetGap - NSWidth(screenRect) * textWidthRatio - insets.left - insets.right >= NSMinX(screenRect))
                         : (NSMaxX(_position) + MAX(NSWidth(maxContentRect), _maxSize.width) + insets.right > NSMaxX(screenRect))))) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        maxContentRect.size.width = _maxSize.width;
        textContainer.size = NSMakeSize(_maxSize.width, textHeightLimit);
      }
    }
    CGFloat textHeight = MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom;
    if (theme.vertical ? (NSMinX(_position) - textHeight - (sweepVertical ? kOffsetGap : 0) < NSMinX(screenRect))
                       : (NSMinY(_position) - textHeight - (sweepVertical ? 0 : kOffsetGap) < NSMinY(screenRect))) {
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
      windowRect.origin.x = NSMinX(_position) - kOffsetGap - NSWidth(windowRect);
      windowRect.origin.y = NSMidY(_position) - NSHeight(windowRect) * 0.5;
    } else { // horizontally centre-align (MidX) in screen coordinates
      windowRect.origin.x = NSMidX(_position) - NSWidth(windowRect) * 0.5;
      windowRect.origin.y = NSMinY(_position) - kOffsetGap - NSHeight(windowRect);
    }
  } else {
    if (theme.vertical) { // anchor is the top right corner in screen coordinates (MaxX, MaxY)
      windowRect = NSMakeRect(NSMaxX(self.frame) - NSHeight(maxContentRect) - insets.top - insets.bottom,
                              NSMaxY(self.frame) - NSWidth(maxContentRect) - insets.left - insets.right,
                              NSHeight(maxContentRect) + insets.top + insets.bottom,
                              NSWidth(maxContentRect) + insets.left + insets.right);
      _initPosition |= NSIntersectsRect(windowRect, _position);
      if (_initPosition) {
        if (!sweepVertical) {
          // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
          if (NSMinY(_position) - kOffsetGap - NSHeight(screenRect) * textWidthRatio - insets.left - insets.right < NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_position) + kOffsetGap;
          } else {
            windowRect.origin.y = NSMinY(_position) - kOffsetGap - NSHeight(windowRect);
          }
          // Make the right edge of candidate block fixed at the left of cursor
          windowRect.origin.x = NSMinX(_position) + insets.top - NSWidth(windowRect);
          if (_view.preeditRange.length > 0) {
            NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
            windowRect.origin.x += NSHeight(preeditRect);
          }
        } else {
          if (NSMinX(_position) - kOffsetGap - NSWidth(windowRect) < NSMinX(screenRect)) {
            windowRect.origin.x = NSMaxX(_position) + kOffsetGap;
          } else {
            windowRect.origin.x = NSMinX(_position) - kOffsetGap - NSWidth(windowRect);
          }
          windowRect.origin.y = NSMinY(_position) + insets.left - NSHeight(windowRect);
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
          if (NSMinX(_position) - kOffsetGap - NSWidth(screenRect) * textWidthRatio - insets.left - insets.right >= NSMinX(screenRect)) {
            windowRect.origin.x = NSMinX(_position) - kOffsetGap - NSWidth(windowRect);
          } else {
            windowRect.origin.x = NSMaxX(_position) + kOffsetGap;
          }
          windowRect.origin.y = NSMinY(_position) + insets.top - NSHeight(windowRect);
          if (_view.preeditRange.length > 0) {
            NSRect preeditRect = [_view contentRectForRange:_view.preeditRange];
            windowRect.origin.y += NSHeight(preeditRect);
          }
        } else {
          if (NSMinY(_position) - kOffsetGap - NSHeight(windowRect) < NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_position) + kOffsetGap;
          } else {
            windowRect.origin.y = NSMinY(_position) - kOffsetGap - NSHeight(windowRect);
          }
          windowRect.origin.x = NSMaxX(_position) - insets.left;
        }
      }
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (_initPosition && sweepVertical ? MIN(NSMinX(_position) - kOffsetGap, NSMaxX(screenRect)) : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = _initPosition && sweepVertical ? MAX(NSMaxX(_position) + kOffsetGap, NSMinX(screenRect)) : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = _initPosition && !sweepVertical ? MAX(NSMaxY(_position) + kOffsetGap, NSMinY(screenRect)) : NSMinY(screenRect);
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (_initPosition && !sweepVertical ? MIN(NSMinY(_position) - kOffsetGap, NSMaxY(screenRect)) : NSMaxY(screenRect)) - NSHeight(windowRect);
  }
  windowRect = NSIntersectionRect(windowRect, screenRect);

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }

  // rotate the view, the core in vertical mode!
  if (theme.vertical) {
    windowRect = [self.screen backingAlignedRect:windowRect options:NSAlignAllEdgesNearest];
    [self setFrame:windowRect display:YES];
    self.contentView.boundsRotation = -90.0;
    [self.contentView setBoundsOrigin:NSMakePoint(0.0, NSWidth(windowRect))];
  } else {
    windowRect = [self.screen backingAlignedRect:windowRect options:NSAlignAllEdgesNearest];
    [self setFrame:windowRect display:YES];
    self.contentView.boundsRotation = 0.0;
    [self.contentView setBoundsOrigin:NSZeroPoint];
  }
  NSRect viewRect = self.contentView.bounds;
  NSRect textViewRect = NSMakeRect(NSMinX(viewRect) + insets.left - _view.textView.textContainerOrigin.x,
                                   NSMinY(viewRect) + insets.bottom - _view.textView.textContainerOrigin.y,
                                   NSWidth(viewRect) - insets.left - insets.right,
                                   NSHeight(viewRect) - insets.top - insets.bottom);
  textViewRect = [self.contentView backingAlignedRect:textViewRect options:NSAlignAllEdgesNearest];
  NSPoint viewOrigin = NSMakePoint(NSMinX(viewRect) - NSMinX(textViewRect), NSMaxY(textViewRect) - NSMaxY(viewRect));
  _view.textView.boundsRotation = 0.0;
  [_view setBoundsOrigin:viewOrigin];
  [_view.textView setBoundsOrigin:NSZeroPoint];
  _view.frame = viewRect;
  _view.textView.frame = textViewRect;

  if (theme.translucency > 0) {
    [_back setBoundsOrigin:viewOrigin];
    _back.frame = viewRect;
    _back.appearance = NSApp.effectiveAppearance;
    [_back setHidden:NO];
  } else {
    [_back setHidden:YES];
  }
  self.alphaValue = theme.alpha;
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

- (BOOL)shouldBreakLineInsideRange:(NSRange)range {
  [_view.textStorage fixFontAttributeInRange:range];
  NSUInteger __block lineCount = 0;
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromCharRange:range];
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeHighlight
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^BOOL(NSTextRange *segRange, CGRect segFrame, CGFloat baseline,
                                        NSTextContainer *textContainer) {
      lineCount += 1 + (NSMaxX(segFrame) > _textWidthLimit);
      return YES;
    }];
  } else {
    NSRange glyphRange = [_view.textView.layoutManager glyphRangeForCharacterRange:range
                                                              actualCharacterRange:NULL];
    [_view.textView.layoutManager enumerateLineFragmentsForGlyphRange:glyphRange
      usingBlock:^(NSRect rect, NSRect usedRect, NSTextContainer *textContainer,
                   NSRange lineRange, BOOL *stop) {
      lineCount += 1 + (NSMaxX(usedRect) > self->_textWidthLimit);
    }];
  }
  return lineCount > 1;
}

- (BOOL)shouldUseTabInRange:(NSRange)range
              maxLineLength:(CGFloat *)maxLineLength {
  [_view.textStorage fixFontAttributeInRange:range];
  if (_view.currentTheme.lineLength > 0) {
    *maxLineLength = MAX(_textWidthLimit, _maxSize.width);
    return YES;
  }
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [_view getTextRangeFromCharRange:range];
    CGFloat __block rangeEndEdge;
    [_view.textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
                             type:NSTextLayoutManagerSegmentTypeHighlight
                          options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                       usingBlock:^(NSTextRange *segRange, CGRect segFrame, CGFloat baseline, 
                                    NSTextContainer *textContainer) {
      rangeEndEdge = NSMaxX(segFrame);
      return YES;
    }];
    [_view.textView.textLayoutManager ensureLayoutForRange:_view.textView.textContentStorage.documentRange];
    NSRect container = _view.textView.textLayoutManager.usageBoundsForTextContainer;
    *maxLineLength = MAX(*maxLineLength, MAX(NSMaxX(container), _maxSize.width));
    return *maxLineLength > rangeEndEdge;
  } else {
    NSUInteger glyphIndex = [_view.textView.layoutManager glyphIndexForCharacterAtIndex:range.location];
    CGFloat rangeEndEdge = NSMaxX([_view.textView.layoutManager
                                   lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:NULL]);
    NSRect container = [_view.textView.layoutManager usedRectForTextContainer:_view.textView.textContainer];
    *maxLineLength = MAX(*maxLineLength, MAX(NSMaxX(container), _maxSize.width));
    return *maxLineLength > rangeEndEdge;
  }
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray<NSString *> *)candidates
           comments:(NSArray<NSString *> *)comments
        highlighted:(NSUInteger)highlighted
            pageNum:(NSUInteger)pageNum
           lastPage:(BOOL)lastPage {
  _numCandidates = candidates.count;
  _highlighted = _numCandidates == 0 ? NSNotFound : highlighted;
  _caretAtHome = caretPos == NSNotFound || (caretPos == selRange.location && selRange.location == 1);
  _firstPage = pageNum == 0;
  _lastPage = lastPage;
  _functionButton = kVoidSymbol;
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

  if (!NSIntersectsRect(_position, self.screen.frame)) {
    [self updateDisplayParameters];
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
  NSMutableArray<NSValue *> *candidateRanges =
        [[NSMutableArray alloc] initWithCapacity:_numCandidates];
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);

  CGFloat topMargin = preedit ? 0.0 : ceil(theme.linespace * 0.5);
  CGFloat bottomMargin = _numCandidates > 0 && (theme.linear || !theme.showPaging) ?
                         floor(theme.linespace * 0.5) : 0.0;
  NSMutableParagraphStyle *paragraphStyleCandidate;
  CGFloat tabInterval = theme.separatorWidth * 2;
  CGFloat maxLineLength = 0.0;

  // preedit
  if (preedit) {
    NSMutableAttributedString *preeditLine = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [preeditLine appendAttributedString:
       [[NSAttributedString alloc] initWithString:[preedit substringToIndex:selRange.location]
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
      [preeditLine appendAttributedString:
       [[NSAttributedString alloc] initWithString:[preedit substringFromIndex:NSMaxRange(selRange)]
                                       attributes:theme.preeditAttrs]];
    }
    [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:kFullWidthSpace attributes:theme.preeditAttrs]];
    [preeditLine appendAttributedString:_caretAtHome ? theme.symbolDeleteStroke : theme.symbolDeleteFill];
    // force caret to be rendered sideways, instead of uprights, in vertical orientation
    if (caretPos != NSNotFound) {
      [preeditLine addAttribute:NSVerticalGlyphFormAttributeName value:@(NO)
                          range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)), 1)];
    }
    preeditRange = NSMakeRange(0, preeditLine.length);
    [text appendAttributedString:preeditLine];

    if (_numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc] 
                                    initWithString:@"\n" attributes:theme.preeditAttrs]];
    } else {
      if ([self shouldUseTabInRange:NSMakeRange(preeditLine.length - 2, 2) 
                      maxLineLength:&maxLineLength]) {
        if (theme.tabled) {
          maxLineLength = ceil((maxLineLength + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
        }
        [text replaceCharactersInRange:NSMakeRange(preeditLine.length - 2, 1) withString:@"\t"];
        NSMutableParagraphStyle *paragraphStylePreedit = theme.preeditParagraphStyle.mutableCopy;
        paragraphStylePreedit.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                           location:maxLineLength options:@{}]];
        [text addAttribute:NSParagraphStyleAttributeName
                     value:paragraphStylePreedit range:preeditRange];
      }
      goto drawPanel;
    }
  }

  // candidate items
  NSUInteger candidateBlockStart = text.length;
  NSUInteger lineStart = text.length;
  if (theme.linear) {
    paragraphStyleCandidate = [theme.paragraphStyle copy];
  }
  for (NSUInteger idx = 0; idx < _numCandidates; ++idx) {
    // attributed labels are already included in candidateFormats
    NSMutableAttributedString *item = (idx == highlighted) ? [theme.candidateHighlightedFormats[idx] mutableCopy] 
                                                           : [theme.candidateFormats[idx] mutableCopy];
    NSRange candidateRange = [item.string rangeOfString:@"%@"];
    // get the label size for indent
    CGFloat labelWidth = theme.linear ? 0.0 : ceil([item attributedSubstringFromRange:NSMakeRange(0, candidateRange.location)].size.width);
    // plug in candidate texts and comments into the template
    [item replaceCharactersInRange:candidateRange
                        withString:candidates[idx]];

    NSRange commentRange = [item.string rangeOfString:kTipSpecifier];
    if (comments[idx].length != 0) {
      [item replaceCharactersInRange:commentRange 
                          withString:[@" " stringByAppendingString:comments[idx]]];
    } else {
      [item deleteCharactersInRange:commentRange];
    }

    [item formatMarkDown];
    CGFloat annotationHeight = [item annotateRubyInRange:NSMakeRange(0, item.length)
                                     verticalOrientation:theme.vertical maximumLength:_textWidthLimit];
    if (annotationHeight * 2 > theme.linespace) {
      [self setAnnotationHeight:annotationHeight];
      paragraphStyleCandidate = theme.paragraphStyle.copy;
      [text enumerateAttribute:NSParagraphStyleAttributeName
                       inRange:NSMakeRange(candidateBlockStart, text.length - candidateBlockStart) options:0
                    usingBlock:^(NSParagraphStyle *value, NSRange range, BOOL *stop) {
        NSMutableParagraphStyle *style = value.mutableCopy;
        style.paragraphSpacing = annotationHeight;
        style.paragraphSpacingBefore = annotationHeight;
        [text addAttribute:NSParagraphStyleAttributeName value:style range:range];
      }];
      topMargin = preedit ? 0.0 : annotationHeight;
      bottomMargin = (theme.linear || !theme.showPaging) ? annotationHeight : 0.0;
    }
    if (comments[idx].length != 0 && [item.string hasSuffix:@" "]) {
      [item deleteCharactersInRange:NSMakeRange(item.length - 1, 1)];
    }
    if (!theme.linear) {
      paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    [item addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate range:NSMakeRange(0, item.length)];

    // determine if the line is too wide and line break is needed, based on screen size.
    if (lineStart != text.length) {
      NSUInteger separatorStart = text.length;
      // separator: linear = "　"; tabled = "　\t"; stacked = "\n"
      NSMutableAttributedString *separator = theme.separator.mutableCopy;
      [text appendAttributedString:separator];
      [text appendAttributedString:item];
      if (theme.linear && (ceil(item.size.width) > _textWidthLimit ||
          [self shouldBreakLineInsideRange:NSMakeRange(lineStart, text.length - lineStart)])) {
        [text replaceCharactersInRange:NSMakeRange(separatorStart, separator.length) withString:@"\n"];
        lineStart = separatorStart + 1;
      }
    } else { // at the start of a new line, no need to determine line break
      [text appendAttributedString:item];
    }
    // for linear layout, middle-truncate candidates that are longer than one line
    if (theme.linear && ceil(item.size.width) > _textWidthLimit) {
      if (idx < _numCandidates - 1 || theme.showPaging) {
        [text appendAttributedString:[[NSAttributedString alloc] 
                                      initWithString:@"\n" attributes:theme.commentAttrs]];
      }
      NSMutableParagraphStyle *paragraphStyleTruncating = paragraphStyleCandidate.mutableCopy;
      paragraphStyleTruncating.lineBreakMode = NSLineBreakByTruncatingMiddle;
      [text addAttribute:NSParagraphStyleAttributeName 
                   value:paragraphStyleTruncating
                   range:NSMakeRange(lineStart, item.length)];
      [candidateRanges addObject:[NSValue valueWithRange:
                                  NSMakeRange(lineStart, item.length)]];
      lineStart = text.length;
    } else {
      [candidateRanges addObject:[NSValue valueWithRange:
                                  NSMakeRange(text.length - item.length, item.length)]];
    }
  }

  // paging indication
  if (theme.showPaging) {
    NSMutableAttributedString *paging = [[NSMutableAttributedString alloc] initWithString:
                                         [NSString stringWithFormat:@" %lu ", pageNum + 1] attributes:theme.pagingAttrs];
    [paging insertAttributedString:pageNum > 0 ? theme.symbolBackFill : theme.symbolBackStroke atIndex:0];
    [paging appendAttributedString:lastPage ? theme.symbolForwardStroke : theme.symbolForwardFill];
    [text appendAttributedString:theme.separator];
    NSUInteger pagingStart = text.length;
    [text appendAttributedString:paging];
    if (theme.linear) {
      if ([self shouldBreakLineInsideRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 0) withString:@"\n"];
        lineStart = pagingStart;
        pagingStart += 1;
      }
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length) 
                      maxLineLength:&maxLineLength] ||
          lineStart != candidateBlockStart) {
        if (theme.tabled) {
          maxLineLength = ceil((maxLineLength + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
        } else {
          [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1) withString:@"\t"];
        }
        paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
        paragraphStyleCandidate.tabStops = @[];
        NSUInteger candidateEnd = pagingStart - 1;
        CGFloat candidateEndPosition = NSMaxX([_view contentRectForRange:
                                               NSMakeRange(lineStart, candidateEnd - lineStart)]);
        for (NSUInteger i = 1; i * tabInterval < candidateEndPosition; ++i) {
          [paragraphStyleCandidate addTabStop:[[NSTextTab alloc]
                                               initWithTextAlignment:NSTextAlignmentLeft
                                               location:i * tabInterval options:@{}]];
        }
        [paragraphStyleCandidate addTabStop:[[NSTextTab alloc]
                                             initWithTextAlignment:NSTextAlignmentRight
                                             location:maxLineLength options:@{}]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleCandidate range:NSMakeRange(lineStart, text.length - lineStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = theme.pagingParagraphStyle.mutableCopy;
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length) 
                      maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1)
                            withString:@"\t"];
        [text replaceCharactersInRange:NSMakeRange(pagingStart + paging.length - 2, 1)
                            withString:@"\t"];
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
  // right-align the backward delete symbol
  if (preedit && [self shouldUseTabInRange:NSMakeRange(preeditRange.length - 2, 2) 
                             maxLineLength:&maxLineLength]) {
    [text replaceCharactersInRange:NSMakeRange(preeditRange.length - 2, 1)
                        withString:@"\t"];
    NSMutableParagraphStyle *paragraphStylePreedit = theme.preeditParagraphStyle.mutableCopy;
    paragraphStylePreedit.tabStops = @[[[NSTextTab alloc] 
                                        initWithTextAlignment:NSTextAlignmentRight
                                        location:maxLineLength options:@{}]];
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStylePreedit range:preeditRange];
  }

  // text done!
drawPanel:
  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height + topMargin,
                                         theme.edgeInset.width + ceil(theme.separatorWidth * 0.5),
                                         theme.edgeInset.height + bottomMargin,
                                         theme.edgeInset.width + floor(theme.separatorWidth * 0.5));
  self.animationBehavior = caretPos == NSNotFound ?
   NSWindowAnimationBehaviorUtilityWindow : NSWindowAnimationBehaviorDefault;
  [_view drawViewWithInsets:insets
            candidateRanges:candidateRanges
           highlightedIndex:highlighted
               preeditRange:preeditRange
    highlightedPreeditRange:highlightedPreeditRange
                pagingRange:pagingRange];
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
      _statusMessage = [messageLong substringWithRange:
                        [messageLong rangeOfComposedCharacterSequenceAtIndex:0]];
    }
  }
}

- (void)showStatus:(NSString *)message {
  SquirrelTheme *theme = _view.currentTheme;
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.edgeInset.height,
                                         theme.edgeInset.width + ceil(theme.separatorWidth * 0.5),
                                         theme.edgeInset.height,
                                         theme.edgeInset.width + floor(theme.separatorWidth * 0.5));
  _view.textView.layoutOrientation = theme.vertical ?
    NSTextLayoutOrientationVertical : NSTextLayoutOrientationHorizontal;

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSAttributedString alloc]
                             initWithString:message
                             attributes:theme.statusAttrs]];

  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  // disable remember_size and fixed line_length for status messages
  _initPosition = YES;
  _maxSize = NSZeroSize;
  if (_statusTimer) {
    [_statusTimer invalidate];
  }
  self.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
  [_view drawViewWithInsets:insets
            candidateRanges:@[]
           highlightedIndex:NSNotFound
               preeditRange:NSMakeRange(NSNotFound, 0)
    highlightedPreeditRange:NSMakeRange(NSNotFound, 0)
                pagingRange:NSMakeRange(NSNotFound, 0)];
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
    backgroundColor = NSColor.lightGrayColor;
  }
  return [[foregroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                                            ofColor:backgroundColor]
          colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static NSFontDescriptor * getFontDescriptor(NSString *fullname) {
  if (fullname == nil) {
    return nil;
  }
  NSArray<NSString *> *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray<NSFontDescriptor *> *validFontDescriptors = [[NSMutableArray alloc]
                                                              initWithCapacity:fontNames.count];
  for (__strong NSString *fontName in fontNames) {
    fontName = [fontName stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if ([NSFont fontWithName:fontName size:0.0] != nil) {
      // If the font name is not valid, NSFontDescriptor will still create something for us.
      // However, when we draw the actual text, Squirrel will crash if there is any font descriptor
      // with invalid font name.
      NSFontDescriptor *fontDescriptor =
        [NSFontDescriptor fontDescriptorWithName:fontName size:0.0];
      NSFontDescriptor *UIFontDescriptor = 
        [fontDescriptor fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized];
      [validFontDescriptors addObject:([NSFont fontWithDescriptor:UIFontDescriptor size:0.0] != nil 
                                       ? UIFontDescriptor : fontDescriptor)];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  }
  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  NSFontDescriptor *emojiFontDescriptor = 
    [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
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
  NSArray<NSFontDescriptor *> *fallbackList =
    [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor *fallback in fallbackList) {
    NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback
                                                 size:font.pointSize];
    if (vertical) {
      fallbackFont = fallbackFont.verticalFont;
    }
    lineHeight = MAX(lineHeight, fallbackFont.ascender - fallbackFont.descender);
  }
  return lineHeight;
}

static NSFont * getTallestFont(NSArray<NSFont *> *fonts, BOOL vertical) {
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

static void updateCandidateListLayout(BOOL *isLinearCandidateList, BOOL *isTabledCandidateList,
                                      SquirrelConfig *config, NSString *prefix) {
  NSString *candidateListLayout = [config getString:
                                   [prefix stringByAppendingString:@"/candidate_list_layout"]];
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
    NSNumber *horizontal = [config getOptionalBool:
                            [prefix stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinearCandidateList = horizontal.boolValue;
      *isTabledCandidateList = NO;
    }
  }
}

static void updateTextOrientation(BOOL *isVerticalText, SquirrelConfig *config, NSString *prefix) {
  NSString *textOrientation = [config getString:
                               [prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVerticalText = NO;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVerticalText = YES;
  } else {
    NSNumber *vertical = [config getOptionalBool:
                          [prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVerticalText = vertical.boolValue;
    }
  }
}

- (void)setAnnotationHeight:(CGFloat)height {
  [[_view selectTheme:defaultAppear] setAnnotationHeight:height];
  [[_view selectTheme:darkAppear] setAnnotationHeight:height];
}

- (void)loadLabelConfig:(SquirrelConfig *)config
           directUpdate:(BOOL)update {
  SquirrelTheme *theme = [_view selectTheme:defaultAppear];
  [SquirrelPanel updateTheme:theme 
             withLabelConfig:config
                directUpdate:update];
  SquirrelTheme *darkTheme = [_view selectTheme:darkAppear];
  [SquirrelPanel updateTheme:darkTheme 
             withLabelConfig:config
                directUpdate:update];
  if (update) {
    [self updateDisplayParameters];
  }
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
      NSString *keyCaps = [selectKeys.uppercaseString
                           stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                           reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [keyCaps substringWithRange:NSMakeRange(i, 1)];
      }
    }
  } else {
    selectKeys = [@"1234567890" substringToIndex:menuSize];
    if (!selectLabels) {
      NSString *numerals = [selectKeys
                            stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                            reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [numerals substringWithRange:NSMakeRange(i, 1)];
      }
    }
  }
  [theme setSelectKeys:selectKeys
                labels:labels
          directUpdate:update];
}

- (void)loadConfig:(SquirrelConfig *)config
       forAppearance:(SquirrelAppear)appear {
  SquirrelTheme *theme = [_view selectTheme:appear];
  NSSet<NSString *> *styleOptions = [NSSet setWithArray:self.optionSwitcher.optionStates];
  [SquirrelPanel updateTheme:theme 
                  withConfig:config
                styleOptions:styleOptions 
               forAppearance:appear];
  [self updateDisplayParameters];
}

// functions for post-retrieve processing
double positive(double param) { return fmax(0.0, param); }
double pos_round(double param) { return round(fmax(0.0, param)); }
double pos_ceil(double param) { return ceil(fmax(0.0, param)); }
double clamp_uni(double param) { return fmin(1.0, fmax(0.0, param)); }

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
  NSNumber *fontSize = [config getOptionalDouble:@"style/font_point"
                                 applyConstraint:pos_round];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  NSNumber *labelFontSize = [config getOptionalDouble:@"style/label_font_point" 
                                      applyConstraint:pos_round];
  NSString *commentFontName = [config getString:@"style/comment_font_face"];
  NSNumber *commentFontSize = [config getOptionalDouble:@"style/comment_font_point"
                                        applyConstraint:pos_round];
  NSNumber *alpha = [config getOptionalDouble:@"style/alpha"
                              applyConstraint:clamp_uni];
  NSNumber *translucency = [config getOptionalDouble:@"style/translucency" 
                                     applyConstraint:clamp_uni];
  NSNumber *cornerRadius = [config getOptionalDouble:@"style/corner_radius" 
                                     applyConstraint:positive];
  NSNumber *highlightedCornerRadius = [config getOptionalDouble:@"style/hilited_corner_radius" 
                                                applyConstraint:positive];
  NSNumber *borderHeight = [config getOptionalDouble:@"style/border_height"
                                     applyConstraint:pos_ceil];
  NSNumber *borderWidth = [config getOptionalDouble:@"style/border_width" 
                                    applyConstraint:pos_ceil];
  NSNumber *lineSpacing = [config getOptionalDouble:@"style/line_spacing"
                                    applyConstraint:pos_round];
  NSNumber *spacing = [config getOptionalDouble:@"style/spacing"
                                applyConstraint:pos_round];
  NSNumber *baseOffset = [config getOptionalDouble:@"style/base_offset"];
  NSNumber *lineLength = [config getOptionalDouble:@"style/line_length"];
  // CHROMATICS
  NSColor *backgroundColor;
  NSImage *backgroundImage;
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
      if ((colorScheme = [config getString:
                          [NSString stringWithFormat:@"style/%@/color_scheme_dark", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme_dark"];
  }
  if (!colorScheme) {
    for (NSString *option in styleOptions) {
      if ((colorScheme = [config getString:
                          [NSString stringWithFormat:@"style/%@/color_scheme", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme"];
  }
  BOOL isNative = !colorScheme || [colorScheme isEqualToString:@"native"];
  NSArray<NSString *> *configPrefixes = isNative
    ? [@"style/" stringsByAppendingPaths:styleOptions.allObjects]
    : [@[[@"preset_color_schemes/" stringByAppendingString:colorScheme]]
        arrayByAddingObjectsFromArray:[@"style/" stringsByAppendingPaths:styleOptions.allObjects]];

  // get color scheme and then check possible overrides from styleSwitcher
  for (NSString *prefix in configPrefixes) {
    // CHROMATICS override
    config.colorSpace = [config getString:[prefix stringByAppendingString:@"/color_space"]] ? : config.colorSpace;
    backgroundColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]] ? : backgroundColor;
    backgroundImage = [config getImage:[prefix stringByAppendingString:@"/back_image"]] ? : backgroundImage;
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
    statusMessageType = [config getString:[prefix stringByAppendingString:@"/status_message_type"]] ? : statusMessageType;
    candidateFormat = [config getString:[prefix stringByAppendingString:@"/candidate_format"]] ? : candidateFormat;
    // TYPOGRAPHY override
    fontName = [config getString:[prefix stringByAppendingString:@"/font_face"]] ? : fontName;
    fontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/font_point"]
                         applyConstraint:pos_round] ? : fontSize;
    labelFontName = [config getString:[prefix stringByAppendingString:@"/label_font_face"]] ? : labelFontName;
    labelFontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/label_font_point"] 
                              applyConstraint:pos_round] ? : labelFontSize;
    commentFontName = [config getString:[prefix stringByAppendingString:@"/comment_font_face"]] ? : commentFontName;
    commentFontSize = [config getOptionalDouble:[prefix stringByAppendingString:@"/comment_font_point"] 
                                applyConstraint:pos_round] ? : commentFontSize;
    alpha = [config getOptionalDouble:[prefix stringByAppendingString:@"/alpha"]
                      applyConstraint:clamp_uni] ? : alpha;
    translucency = [config getOptionalDouble:[prefix stringByAppendingString:@"/translucency"]
                             applyConstraint:clamp_uni] ? : translucency;
    cornerRadius = [config getOptionalDouble:[prefix stringByAppendingString:@"/corner_radius"]
                             applyConstraint:positive] ? : cornerRadius;
    highlightedCornerRadius = [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]
                                        applyConstraint:positive] ? : highlightedCornerRadius;
    borderHeight = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_height"]
                             applyConstraint:pos_ceil] ? : borderHeight;
    borderWidth = [config getOptionalDouble:[prefix stringByAppendingString:@"/border_width"]
                            applyConstraint:pos_ceil] ? : borderWidth;
    lineSpacing = [config getOptionalDouble:[prefix stringByAppendingString:@"/line_spacing"]
                            applyConstraint:pos_round] ? : lineSpacing;
    spacing = [config getOptionalDouble:[prefix stringByAppendingString:@"/spacing"]
                        applyConstraint:pos_round] ? : spacing;
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
                                       size:fontSize.doubleValue];

  NSFontDescriptor *labelFontDescriptor = [(getFontDescriptor(labelFontName) ? : fontDescriptor)
                                           fontDescriptorByAddingAttributes:monoDigitAttrs];
  NSFont *labelFont = labelFontDescriptor ? [NSFont fontWithDescriptor:labelFontDescriptor 
                                                                  size:labelFontSize.doubleValue]
                                          : [NSFont monospacedDigitSystemFontOfSize:labelFontSize.doubleValue
                                                                             weight:NSFontWeightRegular];
  NSString *labelString = [theme.labels componentsJoinedByString:@""];
  labelFont = CFBridgingRelease(CTFontCreateForStringWithLanguage((CTFontRef)labelFont, (CFStringRef)labelString,
                                 CFRangeMake(0, (CFIndex)labelString.length), CFSTR("zh")));

  NSFontDescriptor *commentFontDescriptor = getFontDescriptor(commentFontName);
  NSFont *commentFont = [NSFont fontWithDescriptor:(commentFontDescriptor ? : fontDescriptor)
                                              size:commentFontSize.doubleValue];

  NSFont *pagingFont = [NSFont monospacedDigitSystemFontOfSize:labelFontSize.doubleValue 
                                                        weight:NSFontWeightRegular];

  CGFloat fontHeight = ceil(getLineHeight(font, vertical));
  CGFloat labelFontHeight = ceil(getLineHeight(labelFont, vertical));
  CGFloat commentFontHeight = ceil(getLineHeight(commentFont, vertical));
  CGFloat lineHeight = fmax(fontHeight, fmax(labelFontHeight, commentFontHeight));
  CGFloat separatorWidth = ceil([kFullWidthSpace sizeWithAttributes:@{NSFontAttributeName: commentFont}].width);
  spacing = spacing ? : @(0.0);
  lineSpacing = lineSpacing ? : @(0.0);

  NSMutableParagraphStyle *preeditParagraphStyle = theme.preeditParagraphStyle.mutableCopy;
  preeditParagraphStyle.minimumLineHeight = fontHeight;
  preeditParagraphStyle.maximumLineHeight = fontHeight;
  preeditParagraphStyle.paragraphSpacing = spacing.doubleValue;
  preeditParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle *paragraphStyle = theme.paragraphStyle.mutableCopy;
  paragraphStyle.minimumLineHeight = lineHeight;
  paragraphStyle.maximumLineHeight = lineHeight;
  paragraphStyle.paragraphSpacingBefore = ceil(lineSpacing.doubleValue * 0.5);
  paragraphStyle.paragraphSpacing = floor(lineSpacing.doubleValue * 0.5);
  paragraphStyle.tabStops = @[];
  paragraphStyle.defaultTabInterval = separatorWidth * 2;

  NSMutableParagraphStyle *pagingParagraphStyle = theme.pagingParagraphStyle.mutableCopy;
  pagingParagraphStyle.minimumLineHeight = ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.maximumLineHeight = ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle *statusParagraphStyle = theme.statusParagraphStyle.mutableCopy;
  statusParagraphStyle.minimumLineHeight = commentFontHeight;
  statusParagraphStyle.maximumLineHeight = commentFontHeight;

  NSMutableDictionary *attrs = theme.attrs.mutableCopy;
  NSMutableDictionary *highlightedAttrs = theme.highlightedAttrs.mutableCopy;
  NSMutableDictionary *labelAttrs = theme.labelAttrs.mutableCopy;
  NSMutableDictionary *labelHighlightedAttrs = theme.labelHighlightedAttrs.mutableCopy;
  NSMutableDictionary *commentAttrs = theme.commentAttrs.mutableCopy;
  NSMutableDictionary *commentHighlightedAttrs = theme.commentHighlightedAttrs.mutableCopy;
  NSMutableDictionary *preeditAttrs = theme.preeditAttrs.mutableCopy;
  NSMutableDictionary *preeditHighlightedAttrs = theme.preeditHighlightedAttrs.mutableCopy;
  NSMutableDictionary *pagingAttrs = theme.pagingAttrs.mutableCopy;
  NSMutableDictionary *pagingHighlightedAttrs = theme.pagingHighlightedAttrs.mutableCopy;
  NSMutableDictionary *statusAttrs = theme.statusAttrs.mutableCopy;

  attrs[NSFontAttributeName] = font;
  highlightedAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  commentHighlightedAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  preeditHighlightedAttrs[NSFontAttributeName] = font;
  pagingAttrs[NSFontAttributeName] = linear ? labelFont : pagingFont;
  pagingHighlightedAttrs[NSFontAttributeName] = linear ? labelFont : pagingFont;
  statusAttrs[NSFontAttributeName] = commentFont;

  NSFont *zhFont = CFBridgingRelease(CTFontCreateForStringWithLanguage((CTFontRef)font, CFSTR("　"), CFRangeMake(0, 1), CFSTR("zh")));
  NSFont *zhCommentFont = CFBridgingRelease(CTFontCreateForStringWithLanguage((CTFontRef)commentFont, CFSTR("　"), CFRangeMake(0, 1), CFSTR("zh")));
  NSFont *refFont = getTallestFont(@[zhFont, labelFont, zhCommentFont], vertical);

  attrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  highlightedAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  labelAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  labelHighlightedAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  commentAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] = 
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  commentHighlightedAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? refFont.verticalFont : refFont};
  preeditAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] = 
    @{(NSString *)kCTBaselineReferenceFont: vertical ? zhFont.verticalFont : zhFont};
  preeditHighlightedAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? zhFont.verticalFont : zhFont};
  pagingAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] = 
    @{(NSString *)kCTBaselineReferenceFont: linear ? (vertical ? refFont.verticalFont : refFont) : pagingFont};
  pagingHighlightedAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] = 
    @{(NSString *)kCTBaselineReferenceFont: linear ? (vertical ? refFont.verticalFont : refFont) : pagingFont};
  statusAttrs[(NSString *)kCTBaselineReferenceInfoAttributeName] =
    @{(NSString *)kCTBaselineReferenceFont: vertical ? zhCommentFont.verticalFont : zhCommentFont};

  attrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  highlightedAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  labelAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassIdeographicCentered;
  labelHighlightedAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassIdeographicCentered;
  commentAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  commentHighlightedAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  preeditAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  preeditHighlightedAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  statusAttrs[(NSString *)kCTBaselineClassAttributeName] =
    vertical ? (NSString *)kCTBaselineClassIdeographicCentered : (NSString *)kCTBaselineClassRoman;
  pagingAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassRoman;
  pagingHighlightedAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassRoman;

  attrs[NSBaselineOffsetAttributeName] = baseOffset;
  highlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  labelAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  labelHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  commentAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  commentHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  preeditAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  preeditHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  pagingAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  pagingHighlightedAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  statusAttrs[NSBaselineOffsetAttributeName] = baseOffset;

  attrs[NSKernAttributeName] = @(ceil(lineHeight * 0.05));
  highlightedAttrs[NSKernAttributeName] = @(ceil(lineHeight * 0.05));
  commentAttrs[NSKernAttributeName] = @(ceil(lineHeight * 0.05));
  commentHighlightedAttrs[NSKernAttributeName] = @(ceil(lineHeight * 0.05));
  preeditAttrs[NSKernAttributeName] = @(ceil(fontHeight * 0.05));
  preeditHighlightedAttrs[NSKernAttributeName] = @(ceil(fontHeight * 0.05));

  preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  preeditHighlightedAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  pagingHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  // CHROMATICS refinement
  translucency = translucency ? : @(0.0);
  if (translucency.doubleValue > 0 && (appear == darkAppear ? backgroundColor.luminanceComponent > 0.65
                                                            : backgroundColor.luminanceComponent < 0.55)) {
    backgroundColor = [backgroundColor invertLuminanceWithAdjustment:0];
    borderColor = [borderColor invertLuminanceWithAdjustment:0];
    preeditBackgroundColor = [preeditBackgroundColor invertLuminanceWithAdjustment:0];
    candidateTextColor = [candidateTextColor invertLuminanceWithAdjustment:0];
    highlightedCandidateTextColor = [highlightedCandidateTextColor invertLuminanceWithAdjustment:1];
    highlightedCandidateBackColor = [highlightedCandidateBackColor invertLuminanceWithAdjustment:-1];
    candidateLabelColor = [candidateLabelColor invertLuminanceWithAdjustment:0];
    highlightedCandidateLabelColor = [highlightedCandidateLabelColor invertLuminanceWithAdjustment:1];
    commentTextColor = [commentTextColor invertLuminanceWithAdjustment:0];
    highlightedCommentTextColor = [highlightedCommentTextColor invertLuminanceWithAdjustment:1];
    textColor = [textColor invertLuminanceWithAdjustment:0];
    highlightedTextColor = [highlightedTextColor invertLuminanceWithAdjustment:1];
    highlightedBackColor = [highlightedBackColor invertLuminanceWithAdjustment:-1];
  }

  backgroundColor = backgroundColor ? : NSColor.controlBackgroundColor;
  borderColor = borderColor ? : isNative ? NSColor.gridColor : nil;
  preeditBackgroundColor = preeditBackgroundColor ? : isNative ? NSColor.windowBackgroundColor : nil;
  candidateTextColor = candidateTextColor ? : NSColor.controlTextColor;
  highlightedCandidateTextColor = highlightedCandidateTextColor ? : NSColor.selectedMenuItemTextColor;
  highlightedCandidateBackColor = highlightedCandidateBackColor ? : isNative ? NSColor.selectedContentBackgroundColor : nil;
  candidateLabelColor = candidateLabelColor ? : isNative ? NSColor.controlAccentColor :
    blendColors(highlightedCandidateBackColor, highlightedCandidateTextColor);
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? : isNative ?
    NSColor.alternateSelectedControlTextColor : blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);
  commentTextColor = commentTextColor ? : NSColor.secondaryLabelColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? : NSColor.alternateSelectedControlTextColor;
  textColor = textColor ? : NSColor.textColor;
  highlightedTextColor = highlightedTextColor ? : NSColor.selectedTextColor;
  highlightedBackColor = highlightedBackColor ? : isNative ? NSColor.selectedTextBackgroundColor : nil;

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

  NSSize edgeInset = vertical ? NSMakeSize(borderHeight.doubleValue, borderWidth.doubleValue)
                              : NSMakeSize(borderWidth.doubleValue, borderHeight.doubleValue);

  [theme  setCornerRadius:cornerRadius.doubleValue
  highlightedCornerRadius:highlightedCornerRadius.doubleValue
           separatorWidth:separatorWidth
                edgeInset:edgeInset
                linespace:lineSpacing.doubleValue
         preeditLinespace:spacing.doubleValue
                    alpha:alpha ? alpha.doubleValue : 1.0
             translucency:translucency.doubleValue
               lineLength:lineLength && lineLength.doubleValue > 0 ? fmax(ceil(lineLength.doubleValue), separatorWidth * 5) : 0.0
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
