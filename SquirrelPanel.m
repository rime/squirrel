#import "SquirrelPanel.h"

#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOffsetGap = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 2.0;
static NSString *const kDefaultCandidateFormat = @"%c. %@";
static NSString *const kTipSpecifier = @"%s";
static NSString *const kFullWidthSpace = @"　";

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
      for (NSInteger i = 0; i < numElements; i++) {
        switch ([self elementAtIndex:i associatedPoints:points]) {
          case NSBezierPathElementMoveTo:
            CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
            break;
          case NSBezierPathElementLineTo:
            CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
            break;
          case NSBezierPathElementCurveTo:
            CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                  points[1].x, points[1].y,
                                  points[2].x, points[2].y);
            break;
          case NSBezierPathElementQuadraticCurveTo:
            CGPathAddQuadCurveToPoint(path, NULL, points[0].x, points[0].y,
                                      points[1].x, points[1].y);
            break;
          case NSBezierPathElementClosePath:
            CGPathCloseSubpath(path);
            break;
        }
      }
      immutablePath = (CGPathRef)CFAutorelease(CGPathCreateCopy(path));
      CGPathRelease(path);
    }
    return immutablePath;
  }
}

@end // NSBezierPath (BezierPathQuartzUtilities)


@implementation NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)

static NSString *const kMarkDownPattern = @"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|"
                        "<(b|strong|i|em|u|sup|sub|s)>)(.+?)(\\2|\\3(?=\\b)|<\\/\\4>)";
static NSString *const kRubyPattern = @"(\uFFF9\\s*)(\\S+?)(\\s*\uFFFA(.+?)\uFFFB)";

- (void)superscriptRange:(NSRange)range {
  [self enumerateAttribute:NSFontAttributeName
                   inRange:range
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(NSFont *value, NSRange subRange, BOOL *stop) {
    NSFont *font = [NSFont fontWithDescriptor:value.fontDescriptor
                                         size:floor(value.pointSize * 0.55)];
    [self addAttributes:@{  NSFontAttributeName:font,
      (NSString *)kCTBaselineClassAttributeName:(NSString *)kCTBaselineClassIdeographicHigh,
                     NSSuperscriptAttributeName:@(1)}
                  range:subRange];
  }];
}

- (void)subscriptRange:(NSRange)range {
  [self enumerateAttribute:NSFontAttributeName
                   inRange:range
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(NSFont *value, NSRange subRange, BOOL *stop) {
    NSFont *font = [NSFont fontWithDescriptor:value.fontDescriptor
                                         size:floor(value.pointSize * 0.55)];
    [self addAttributes:@{  NSFontAttributeName:font,
      (NSString *)kCTBaselineClassAttributeName:(NSString *)kCTBaselineClassIdeographicLow,
                     NSSuperscriptAttributeName:@(-1)}
                  range:subRange];
  }];
}

- (void)formatMarkDown {
  NSRegularExpression *regex = [[NSRegularExpression alloc]
                                initWithPattern:kMarkDownPattern
                                options:NSRegularExpressionUseUnicodeWordBoundaries
                                error:nil];
  NSInteger __block offset = 0;
  [regex enumerateMatchesInString:self.string
                          options:0
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
  NSRegularExpression *regex = [[NSRegularExpression alloc]
                                initWithPattern:kRubyPattern options:0 error:nil];
  CGFloat __block rubyLineHeight = 0.0;
  NSInteger __block offset = 0;
  [regex enumerateMatchesInString:self.mutableString
                          options:0
                            range:range
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
      baseFont = CFBridgingRelease(CTFontCreateForStringWithLanguage
                                   ((CTFontRef)baseFont, (CFStringRef)self.string,
                                    CFRangeMake((CFIndex)baseRange.location, (CFIndex)baseRange.length),
                                    CFSTR("zh")));
      [self addAttribute:NSFontAttributeName value:baseFont range:baseRange];

      CGFloat rubyScale = 0.5;
      CFStringRef rubyString = (__bridge CFStringRef)[self.string substringWithRange:
                                                      [result rangeAtIndex:4]];
      NSFont *rubyFont = [self attribute:NSFontAttributeName
                                 atIndex:[result rangeAtIndex:4].location
                          effectiveRange:NULL];
      rubyFont = [NSFont fontWithDescriptor:rubyFont.fontDescriptor
                                       size:rubyFont.pointSize * rubyScale];
      rubyFont = CFBridgingRelease(CTFontCreateForStringWithLanguage
                                   ((CTFontRef)rubyFont, rubyString,
                                    CFRangeMake(0, CFStringGetLength(rubyString)),
                                    CFSTR("zh")));
      rubyFont = isVertical ? rubyFont.verticalFont : rubyFont;
      rubyLineHeight = MAX(rubyLineHeight, rubyFont.ascender - rubyFont.descender);
      CGColorRef rubyColor = [[self attribute:NSForegroundColorAttributeName
                                      atIndex:[result rangeAtIndex:4].location
                               effectiveRange:NULL] CGColor];
      CFTypeRef keys[] = {kCTFontAttributeName,
                          kCTForegroundColorAttributeName,
                          kCTBaselineClassAttributeName,
                          kCTRubyAnnotationSizeFactorAttributeName,
                          kCTRubyAnnotationScaleToFitAttributeName};
      CFTypeRef values[] = {(__bridge CTFontRef)rubyFont,
                            rubyColor,
                            kCTBaselineClassIdeographicHigh,
                            CFNumberCreate(NULL, kCFNumberDoubleType, &rubyScale),
                            kCFBooleanFalse};
      CFDictionaryRef rubyAttrs = CFDictionaryCreate(NULL, keys, values, 5,
                                                     &kCFTypeDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
      CTRubyAnnotationRef rubyAnnotation =
        CTRubyAnnotationCreateWithAttributes(kCTRubyAlignmentDistributeSpace,
                                             kCTRubyOverhangNone,
                                             kCTRubyPositionBefore,
                                             rubyString, rubyAttrs);

      [self deleteCharactersInRange:[result rangeAtIndex:3]];
      if (@available(macOS 12.0, *)) {
        [self addAttributes:@{(NSString *)kCTRubyAnnotationAttributeName:CFBridgingRelease(rubyAnnotation),
                                        NSVerticalGlyphFormAttributeName:@(isVertical)}
                      range:baseRange];
        [self deleteCharactersInRange:[result rangeAtIndex:1]];
        offset -= [result rangeAtIndex:3].length + [result rangeAtIndex:1].length;
      } else {
        // use U+008B as placeholder for line-forward spaces in case ruby is wider than base
        [self replaceCharactersInRange:NSMakeRange(NSMaxRange(baseRange), 0)
                            withString:[NSString stringWithFormat:@"%C", 0x8B]];
        baseRange.length += 1;
        [self addAttributes:@{(NSString *)kCTRubyAnnotationAttributeName:CFBridgingRelease(rubyAnnotation),
                                        NSVerticalGlyphFormAttributeName:@(isVertical)}
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
  NSColorSpace *labColorSpace = [[NSColorSpace alloc] initWithCGColorSpace:
                                 (CGColorSpaceRef)CFAutorelease(colorSpaceLab)];
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

typedef NS_ENUM(NSUInteger, SquirrelStatusMessageType) {
  kStatusMessageTypeMixed = 0,
  kStatusMessageTypeShort = 1,
  kStatusMessageTypeLong = 2
};

@property(nonatomic, strong, readonly) NSColor *backColor;
@property(nonatomic, strong, readonly) NSColor *highlightedCandidateBackColor;
@property(nonatomic, strong, readonly) NSColor *highlightedPreeditBackColor;
@property(nonatomic, strong, readonly) NSColor *preeditBackColor;
@property(nonatomic, strong, readonly) NSColor *borderColor;
@property(nonatomic, strong, readonly) NSImage *backImage;

@property(nonatomic, readonly) CGFloat cornerRadius;
@property(nonatomic, readonly) CGFloat highlightedCornerRadius;
@property(nonatomic, readonly) CGFloat separatorWidth;
@property(nonatomic, readonly) NSSize borderInset;
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
@property(nonatomic, readonly) SquirrelStatusMessageType statusMessageType;

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

- (instancetype)init;

- (void)           setBackColor:(NSColor *)backColor
  highlightedCandidateBackColor:(NSColor *)highlightedCandidateBackColor
    highlightedPreeditBackColor:(NSColor *)highlightedPreeditBackColor
               preeditBackColor:(NSColor *)preeditBackColor
                    borderColor:(NSColor *)borderColor
                      backImage:(NSImage *)backImage;

- (void)  setCornerRadius:(CGFloat)cornerRadius
  highlightedCornerRadius:(CGFloat)highlightedCornerRadius
           separatorWidth:(CGFloat)separatorWidth
              borderInset:(NSSize)borderInset
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

- (void)setStatusMessageType:(NSString *)type;

- (void)setAnnotationHeight:(CGFloat)height;

@end

@implementation SquirrelTheme

static inline NSColor *blendColors(NSColor *foregroundColor, NSColor *backgroundColor) {
  return [[foregroundColor blendedColorWithFraction:kBlendedBackgroundColorFraction
                                            ofColor:backgroundColor ? : NSColor.lightGrayColor]
          colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static NSFontDescriptor *getFontDescriptor(NSString *fullname) {
  if (fullname.length == 0) {
    return nil;
  }
  NSArray *fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray *validFontDescriptors = [[NSMutableArray alloc]
                                          initWithCapacity:fontNames.count];
  for (NSString *fontName in fontNames) {
    NSFont *font = [NSFont fontWithName:[fontName stringByTrimmingCharactersInSet:
                                         NSCharacterSet.whitespaceAndNewlineCharacterSet] size:0.0];
    if (font != nil) {
      // If the font name is not valid, NSFontDescriptor will still create something for us.
      // However, when we draw the actual text, Squirrel will crash if there is any font descriptor
      // with invalid font name.
      NSFontDescriptor *fontDescriptor = font.fontDescriptor;
      NSFontDescriptor *UIFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:
                                            NSFontDescriptorTraitUIOptimized];
      [validFontDescriptors addObject:[NSFont fontWithDescriptor:UIFontDescriptor size:0.0] != nil ?
                    UIFontDescriptor : fontDescriptor];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  }
  NSFontDescriptor *initialFontDescriptor = validFontDescriptors[0];
  NSFontDescriptor *emojiFontDescriptor =
  [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
  NSArray *fallbackDescriptors = [[validFontDescriptors subarrayWithRange:
                                   NSMakeRange(1, validFontDescriptors.count - 1)]
                                  arrayByAddingObject:emojiFontDescriptor];
  return [initialFontDescriptor fontDescriptorByAddingAttributes:
          @{NSFontCascadeListAttribute:fallbackDescriptors}];
}

static CGFloat getLineHeight(NSFont *font, BOOL vertical) {
  if (vertical) {
    font = font.verticalFont;
  }
  CGFloat lineHeight = ceil(font.ascender - font.descender);
  NSArray *fallbackList = [font.fontDescriptor
                           objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor *fallback in fallbackList) {
    NSFont *fallbackFont = [NSFont fontWithDescriptor:fallback
                                                 size:font.pointSize];
    if (vertical) {
      fallbackFont = fallbackFont.verticalFont;
    }
    lineHeight = MAX(lineHeight, ceil(fallbackFont.ascender - fallbackFont.descender));
  }
  return lineHeight;
}

static NSFont *getTallestFont(NSArray<NSFont *> *fonts, BOOL vertical) {
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

static NSArray<NSAttributedString *> * formatLabels(NSAttributedString *format,
                                                    NSArray<NSString *> *labels) {
  NSRange enumRange = NSMakeRange(0, 0);
  NSMutableArray *formatted = [[NSMutableArray alloc] initWithCapacity:labels.count];
  NSCharacterSet *labelCharacters = [NSCharacterSet characterSetWithCharactersInString:
                                     [labels componentsJoinedByString:@""]];
  if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF10, 10)]
       isSupersetOfSet:labelCharacters]) { // ０１..９
    if ([format.string containsString:@"%c\u20E3"]) { // 1︎⃣..9︎⃣0︎⃣
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

+ (NSColor *)secondaryTextColor {
  if (@available(macOS 10.10, *)) {
    return NSColor.secondaryLabelColor;
  } else {
    return NSColor.disabledControlTextColor;
  }
}

+ (NSColor *)accentColor {
  if (@available(macOS 10.14, *)) {
    return NSColor.controlAccentColor;
  } else {
    return [NSColor colorForControlTint:NSColor.currentControlTint];
  }
}

- (instancetype)init {
  if (self = [super init]) {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    // Use left-to-right marks to declare the default writing direction and prevent strong right-to-left
    // characters from setting the writing direction in case the label are direction-less symbols
    paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;

    NSMutableParagraphStyle *preeditParagraphStyle = paragraphStyle.mutableCopy;
    NSMutableParagraphStyle *pagingParagraphStyle = paragraphStyle.mutableCopy;
    NSMutableParagraphStyle *statusParagraphStyle = paragraphStyle.mutableCopy;

    preeditParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    statusParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;

    NSFont *userFont = [NSFont fontWithDescriptor:
                        getFontDescriptor([NSFont userFontOfSize:0.0].fontName)
                                             size:kDefaultFontSize];
    NSFont *userMonoFont = [NSFont fontWithDescriptor:
                            getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName)
                                                 size:kDefaultFontSize];
    NSFont *monoDigitFont = [NSFont monospacedDigitSystemFontOfSize:kDefaultFontSize
                                                             weight:NSFontWeightRegular];

    NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
    attrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;
    attrs[NSFontAttributeName] = userFont;
    // Use left-to-right embedding to prevent right-to-left text from changing the layout of the candidate.
    attrs[NSWritingDirectionAttributeName] = @[@(0)];

    NSMutableDictionary *highlightedAttrs = attrs.mutableCopy;
    highlightedAttrs[NSForegroundColorAttributeName] = NSColor.selectedMenuItemTextColor;

    NSMutableDictionary *labelAttrs = attrs.mutableCopy;
    labelAttrs[NSForegroundColorAttributeName] = SquirrelTheme.accentColor;
    labelAttrs[NSFontAttributeName] = userMonoFont;

    NSMutableDictionary *labelHighlightedAttrs = labelAttrs.mutableCopy;
    labelHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.alternateSelectedControlTextColor;

    NSMutableDictionary *commentAttrs = [[NSMutableDictionary alloc] init];
    commentAttrs[NSForegroundColorAttributeName] = SquirrelTheme.secondaryTextColor;
    commentAttrs[NSFontAttributeName] = userFont;

    NSMutableDictionary *commentHighlightedAttrs = commentAttrs.mutableCopy;
    commentHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.alternateSelectedControlTextColor;

    NSMutableDictionary *preeditAttrs = [[NSMutableDictionary alloc] init];
    preeditAttrs[NSForegroundColorAttributeName] = NSColor.textColor;
    preeditAttrs[NSFontAttributeName] = userFont;
    preeditAttrs[NSLigatureAttributeName] = @(0);
    preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;

    NSMutableDictionary *preeditHighlightedAttrs = preeditAttrs.mutableCopy;
    preeditHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.selectedTextColor;

    NSMutableDictionary *pagingAttrs = [[NSMutableDictionary alloc] init];
    pagingAttrs[NSFontAttributeName] = monoDigitFont;
    pagingAttrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;

    NSMutableDictionary *pagingHighlightedAttrs = pagingAttrs.mutableCopy;
    pagingHighlightedAttrs[NSForegroundColorAttributeName] = NSColor.selectedMenuItemTextColor;

    NSMutableDictionary *statusAttrs = commentAttrs.mutableCopy;
    statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

    [self          setAttrs:attrs
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

    [self setParagraphStyle:paragraphStyle
      preeditParagraphStyle:preeditParagraphStyle
       pagingParagraphStyle:pagingParagraphStyle
       statusParagraphStyle:statusParagraphStyle];

    [self setSelectKeys:@"12345" labels:@[@"１", @"２", @"３", @"４", @"５"] directUpdate:NO];
    [self setCandidateFormat:kDefaultCandidateFormat];
  }
  return self;
}

- (void)           setBackColor:(NSColor *)backColor
  highlightedCandidateBackColor:(NSColor *)highlightedCandidateBackColor
    highlightedPreeditBackColor:(NSColor *)highlightedPreeditBackColor
               preeditBackColor:(NSColor *)preeditBackColor
                    borderColor:(NSColor *)borderColor
                      backImage:(NSImage *)backImage {
  _backColor = backColor;
  _highlightedCandidateBackColor = highlightedCandidateBackColor;
  _highlightedPreeditBackColor = highlightedPreeditBackColor;
  _preeditBackColor = preeditBackColor;
  _borderColor = borderColor;
  _backImage = backImage;
}

- (void)  setCornerRadius:(CGFloat)cornerRadius
  highlightedCornerRadius:(CGFloat)highlightedCornerRadius
           separatorWidth:(CGFloat)separatorWidth
              borderInset:(NSSize)borderInset
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
  _borderInset = borderInset;
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
  _separator = [[NSAttributedString alloc] initWithString:
                _linear ? (_tabled ? [kFullWidthSpace stringByAppendingString:@"\t"]
                                   : kFullWidthSpace) : @"\n" attributes:sepAttrs];

  // Symbols for function buttons
  NSString *attmCharacter = [NSString stringWithFormat:@"%C", (unichar)NSAttachmentCharacter];

  NSTextAttachment *attmBackFill = [[NSTextAttachment alloc] init];
  attmBackFill.image = [NSImage imageNamed:[NSString stringWithFormat:
                                            @"Symbols/chevron.%@.circle.fill", _linear ? @"up" : @"left"]];
  NSMutableDictionary *attrsBackFill = pagingAttrs.mutableCopy;
  attrsBackFill[NSAttachmentAttributeName] = attmBackFill;
  _symbolBackFill = [[NSAttributedString alloc] initWithString:attmCharacter
                                                    attributes:attrsBackFill];

  NSTextAttachment *attmBackStroke = [[NSTextAttachment alloc] init];
  attmBackStroke.image = [NSImage imageNamed:[NSString stringWithFormat:
                                              @"Symbols/chevron.%@.circle", _linear ? @"up" : @"left"]];
  NSMutableDictionary *attrsBackStroke = pagingAttrs.mutableCopy;
  attrsBackStroke[NSAttachmentAttributeName] = attmBackStroke;
  _symbolBackStroke = [[NSAttributedString alloc] initWithString:attmCharacter
                                                      attributes:attrsBackStroke];

  NSTextAttachment *attmForwardFill = [[NSTextAttachment alloc] init];
  attmForwardFill.image = [NSImage imageNamed:[NSString stringWithFormat:
                                               @"Symbols/chevron.%@.circle.fill", _linear ? @"down" : @"right"]];
  NSMutableDictionary *attrsForwardFill = pagingAttrs.mutableCopy;
  attrsForwardFill[NSAttachmentAttributeName] = attmForwardFill;
  _symbolForwardFill = [[NSAttributedString alloc] initWithString:attmCharacter
                                                       attributes:attrsForwardFill];

  NSTextAttachment *attmForwardStroke = [[NSTextAttachment alloc] init];
  attmForwardStroke.image = [NSImage imageNamed:[NSString stringWithFormat:
                                                 @"Symbols/chevron.%@.circle", _linear ? @"down" : @"right"]];
  NSMutableDictionary *attrsForwardStroke = pagingAttrs.mutableCopy;
  attrsForwardStroke[NSAttachmentAttributeName] = attmForwardStroke;
  _symbolForwardStroke = [[NSAttributedString alloc] initWithString:attmCharacter
                                                         attributes:attrsForwardStroke];

  NSTextAttachment *attmDeleteFill = [[NSTextAttachment alloc] init];
  attmDeleteFill.image = [NSImage imageNamed:@"Symbols/delete.backward.fill"];
  NSMutableDictionary *attrsDeleteFill = preeditAttrs.mutableCopy;
  attrsDeleteFill[NSAttachmentAttributeName] = attmDeleteFill;
  attrsDeleteFill[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteFill = [[NSAttributedString alloc] initWithString:attmCharacter
                                                      attributes:attrsDeleteFill];

  NSTextAttachment *attmDeleteStroke = [[NSTextAttachment alloc] init];
  attmDeleteStroke.image = [NSImage imageNamed:@"Symbols/delete.backward"];
  NSMutableDictionary *attrsDeleteStroke = preeditAttrs.mutableCopy;
  attrsDeleteStroke[NSAttachmentAttributeName] = attmDeleteStroke;
  attrsDeleteStroke[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteStroke = [[NSAttributedString alloc] initWithString:attmCharacter
                                                        attributes:attrsDeleteStroke];
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
  NSMutableAttributedString *format = [[NSMutableAttributedString alloc]
                                       initWithString:candidateFormat];
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
     [kTipSpecifier stringByAppendingString:
      [format.string substringWithRange:commentRange]]];
    [highlightedFormat replaceCharactersInRange:commentRange withString:
     [kTipSpecifier stringByAppendingString:
      [highlightedFormat.string substringWithRange:commentRange]]];
  } else {
    [format appendAttributedString:
     [[NSAttributedString alloc] initWithString:kTipSpecifier
                                     attributes:_commentAttrs]];
    [highlightedFormat appendAttributedString:
     [[NSAttributedString alloc] initWithString:kTipSpecifier
                                     attributes:_commentHighlightedAttrs]];
  }
  _candidateFormats = formatLabels(format, _labels);
  _candidateHighlightedFormats = formatLabels(highlightedFormat, _labels);
}

- (void)setStatusMessageType:(NSString *)type {
  if ([type isEqualToString:@"long"]) {
    _statusMessageType = kStatusMessageTypeLong;
  } else if ([type isEqualToString:@"short"]) {
    _statusMessageType = kStatusMessageTypeShort;
  } else {
    _statusMessageType = kStatusMessageTypeMixed;
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

#pragma mark - Typesetting extensions for TextKit 1 (Mac OSX 10.9 to MacOS 11)

@interface SquirrelLayoutManager : NSLayoutManager <NSLayoutManagerDelegate>
@end @implementation SquirrelLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange
                        atPoint:(NSPoint)origin {
  NSRange charRange = [self characterRangeForGlyphRange:glyphRange
                                       actualGlyphRange:NULL];
  NSTextContainer *textContainer = [self textContainerForGlyphAtIndex:glyphRange.location
                                                       effectiveRange:NULL
                                              withoutAdditionalLayout:YES];
  BOOL verticalOrientation = (BOOL)textContainer.layoutOrientation;
  CGContextRef context = NSGraphicsContext.currentContext.CGContext;
  CGContextResetClip(context);
  [self.textStorage
   enumerateAttributesInRange:charRange
   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
   usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange range, BOOL *stop) {
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
      CFArrayRef runs = CTLineGetGlyphRuns((CTLineRef)CFAutorelease(line));
      for (CFIndex i = 0; i < CFArrayGetCount(runs); ++i) {
        CGPoint position = [self locationForGlyphAtIndex:glyphIndex];
        CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, i);
        CGAffineTransform matrix = CTRunGetTextMatrix(run);
        CGPoint glyphOrigin = [textContainer.textView convertPointToBacking:
                               CGPointMake(origin.x + lineRect.origin.x + position.x,
                                           -origin.y - lineRect.origin.y - position.y)];
        glyphOrigin = [textContainer.textView convertPointFromBacking:
                       CGPointMake(round(glyphOrigin.x), round(glyphOrigin.y))];
        matrix.tx = glyphOrigin.x;
        matrix.ty = glyphOrigin.y;
        CGContextSetTextMatrix(context, matrix);
        CTRunDraw(run, context, CFRangeMake(0, 0));
        glyphIndex += (NSUInteger)CTRunGetGlyphCount(run);
      }
    } else {
      NSPoint position = [self locationForGlyphAtIndex:glyRange.location];
      position.x += lineRect.origin.x;
      position.y += lineRect.origin.y;
      NSPoint backingPosition = [textContainer.textView convertPointToBacking:position];
      position = [textContainer.textView convertPointFromBacking:
                  NSMakePoint(round(backingPosition.x), round(backingPosition.y))];
      NSFont *runFont = attrs[NSFontAttributeName];
      NSString *baselineClass = attrs[(NSString *)kCTBaselineClassAttributeName];
      NSPoint offset = origin;
      if (!verticalOrientation &&
          ([baselineClass isEqualToString:(NSString *)kCTBaselineClassIdeographicCentered] ||
           [baselineClass isEqualToString:(NSString *)kCTBaselineClassMath])) {
        NSFont *refFont = attrs[(NSString *)kCTBaselineReferenceInfoAttributeName][(NSString *)kCTBaselineReferenceFont];
        offset.y += runFont.ascender * 0.5 + runFont.descender * 0.5 - refFont.ascender * 0.5 - refFont.descender * 0.5;
      } else if (verticalOrientation && runFont.pointSize < 24 &&
                 [runFont.fontName isEqualToString:@"AppleColorEmoji"]) {
        NSInteger superscript = [attrs[NSSuperscriptAttributeName] integerValue];
        offset.x += runFont.capHeight - runFont.pointSize;
        offset.y += (runFont.capHeight - runFont.pointSize) *
                    (superscript == 0 ? 0.5 : (superscript == 1 ? 1.0 / 0.55 - 0.55 : 0.0));
      }
      NSPoint glyphOrigin = [textContainer.textView convertPointToBacking:
                             NSMakePoint(position.x + offset.x, position.y + offset.y)];
      glyphOrigin = [textContainer.textView convertPointFromBacking:
                     NSMakePoint(round(glyphOrigin.x), round(glyphOrigin.y))];
      [super drawGlyphsForGlyphRange:glyRange atPoint:
       NSMakePoint(glyphOrigin.x - position.x, glyphOrigin.y - position.y)];
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
  BOOL verticalOrientation = (BOOL)textContainer.layoutOrientation;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                actualGlyphRange:NULL];
  NSFont *refFont = [layoutManager.textStorage
                     attribute:(NSString *)kCTBaselineReferenceInfoAttributeName
                     atIndex:charRange.location
                     effectiveRange:NULL][(NSString *)kCTBaselineReferenceFont];
  NSParagraphStyle *rulerAttrs = [layoutManager.textStorage
                                  attribute:NSParagraphStyleAttributeName
                                  atIndex:charRange.location
                                  effectiveRange:NULL];
  CGFloat lineHeightDelta = lineFragmentUsedRect->size.height - rulerAttrs.minimumLineHeight - rulerAttrs.lineSpacing;
  if (ABS(lineHeightDelta) > 0.1) {
    lineFragmentUsedRect->size.height = round(lineFragmentUsedRect->size.height - lineHeightDelta);
    lineFragmentRect->size.height = round(lineFragmentRect->size.height - lineHeightDelta);
  }
  *baselineOffset = round(lineFragmentUsedRect->origin.y - lineFragmentRect->origin.y + rulerAttrs.minimumLineHeight * 0.5 +
                          (verticalOrientation ? 0.0 : refFont.ascender * 0.5 + refFont.descender * 0.5));
  return YES;
}

- (BOOL)                        layoutManager:(NSLayoutManager *)layoutManager
  shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex {
  return charIndex <= 1 || [layoutManager.textStorage.string
                            characterAtIndex:charIndex - 1] != '\t';
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
    id rubyAnnotation = [layoutManager.textStorage
                         attribute:(NSString *)kCTRubyAnnotationAttributeName
                         atIndex:charIndex
                         effectiveRange:&rubyRange];
    if (rubyAnnotation) {
      NSAttributedString *rubyString = [layoutManager.textStorage
                                        attributedSubstringFromRange:rubyRange];
      CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)rubyString);
      CGRect rubyRect = CTLineGetBoundsWithOptions((CTLineRef)CFAutorelease(line), 0);
      NSSize baseSize = rubyString.size;
      width = fdim(rubyRect.size.width, baseSize.width);
    }
  }
  return NSMakeRect(glyphPosition.x, 0.0, width, glyphPosition.y);
}

@end // SquirrelLayoutManager

#pragma mark - Typesetting extensions for TextKit 2 (MacOS 12 or higher)

API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutFragment : NSTextLayoutFragment
@end @implementation SquirrelTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point
          inContext:(CGContextRef)context {
  if (@available(macOS 14.0, *)) {
  } else { // in macOS 12 and 13, textLineFragments.typographicBouonds are in textContainer coordinates
    point.x += self.layoutFragmentFrame.origin.x;
    point.y += self.layoutFragmentFrame.origin.y;
  }
  BOOL verticalOrientation = (BOOL)self.textLayoutManager.textContainer.layoutOrientation;
  for (NSTextLineFragment *lineFrag in self.textLineFragments) {
    CGRect lineRect = CGRectOffset(lineFrag.typographicBounds, point.x, point.y);
    CGFloat baseline = NSMidY(lineRect);
    if (!verticalOrientation) {
      NSFont *refFont = [lineFrag.attributedString
                         attribute:(NSString *)kCTBaselineReferenceInfoAttributeName
                         atIndex:lineFrag.characterRange.location
                         effectiveRange:NULL][(NSString *)kCTBaselineReferenceFont];
      baseline += refFont.ascender * 0.5 + refFont.descender * 0.5;
    }
    CGPoint renderOrigin = CGPointMake(NSMinX(lineRect) + lineFrag.glyphOrigin.x,
                                       baseline - lineFrag.glyphOrigin.y);
    CGPoint deviceOrigin = CGContextConvertPointToDeviceSpace(context, renderOrigin);
    renderOrigin = CGContextConvertPointToUserSpace(context,
                    CGPointMake(round(deviceOrigin.x), round(deviceOrigin.y)));
    [lineFrag drawAtPoint:renderOrigin inContext:context];
  }
}

@end // SquirrelTextLayoutFragment


API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutManager : NSTextLayoutManager <NSTextLayoutManagerDelegate>
@end @implementation SquirrelTextLayoutManager

- (BOOL)      textLayoutManager:(NSTextLayoutManager *)textLayoutManager
  shouldBreakLineBeforeLocation:(id<NSTextLocation>)location
                    hyphenating:(BOOL)hyphenating {
  NSTextContentStorage *contentStorage = textLayoutManager.textContainer.textView.textContentStorage;
  NSInteger charIndex = [contentStorage
                         offsetFromLocation:contentStorage.documentRange.location
                         toLocation:location];
  return charIndex <= 1 || [contentStorage.textStorage.string
                            characterAtIndex:(NSUInteger)charIndex - 1] != '\t';
}

- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager
              textLayoutFragmentForLocation:(id<NSTextLocation>)location
                              inTextElement:(NSTextElement *)textElement {
  NSTextRange *textRange = [[NSTextRange alloc] initWithLocation:location
                                                     endLocation:textElement.elementRange.endLocation];
  return [[SquirrelTextLayoutFragment alloc] initWithTextElement:textElement
                                                           range:textRange];
}

@end // SquirrelTextLayoutManager

#pragma mark - View behind text, containing drawings of backgrounds and highlights

@interface SquirrelView : NSView

@property(nonatomic, strong, readonly) NSTextView *textView;
@property(nonatomic, strong, readonly) NSTextStorage *textStorage;
@property(nonatomic, strong, readonly) SquirrelTheme *currentTheme;
@property(nonatomic, strong, readonly) CAShapeLayer *shape;
@property(nonatomic, strong, readonly) NSMutableArray<NSBezierPath *> *candidatePaths;
@property(nonatomic, strong, readonly) NSMutableArray<NSBezierPath *> *pagingPaths;
@property(nonatomic, strong, readonly) NSBezierPath *deleteBackPath;
@property(nonatomic, strong, readonly) NSArray<NSValue *> *candidateRanges;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) NSUInteger highlightedIndex;
@property(nonatomic, readonly) SquirrelIndex functionButton;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) NSRect preeditBlock;
@property(nonatomic, readonly) NSRect candidateBlock;
@property(nonatomic, readonly) NSRect pagingBlock;
@property(nonatomic, readonly) NSEdgeInsets alignmentRectInsets;
@property(nonatomic, readonly) SquirrelAppear appear;

- (NSTextRange *)getTextRangeFromCharRange:(NSRange)charRange API_AVAILABLE(macos(12.0));

- (NSRange)getCharRangeFromTextRange:(NSTextRange *)textRange API_AVAILABLE(macos(12.0));

- (NSRect)blockRectForRange:(NSRange)range;

- (void)multilineRectForRange:(NSRange)charRange
                  leadingRect:(NSRectPointer)leadingRect
                     bodyRect:(NSRectPointer)bodyRect
                 trailingRect:(NSRectPointer)trailingRect;

- (void)drawViewWithInsets:(NSEdgeInsets)alignmentRectInsets
           candidateRanges:(NSArray<NSValue *> *)candidateRanges
          highlightedIndex:(NSUInteger)highlightedIndex
              preeditRange:(NSRange)preeditRange
   highlightedPreeditRange:(NSRange)highlightedPreeditRange
               pagingRange:(NSRange)pagingRange;

- (void)highlightFunctionButton:(SquirrelIndex)functionButton;

- (NSUInteger)getIndexFromMouseSpot:(NSPoint)spot;

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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
  NSAppearance *effectiveAppearance = [SquirrelInputController.currentController.client performSelector:
                                       @selector(viewEffectiveAppearance)] ? : NSApp.effectiveAppearance;
#pragma clang diagnostic pop
  if ([effectiveAppearance bestMatchFromAppearancesWithNames:
       @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] == NSAppearanceNameDarkAqua) {
    return darkAppear;
  }
  return defaultAppear;
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
    self.layerUsesCoreImageFilters = YES;

    if (@available(macOS 12.0, *)) {
      SquirrelTextLayoutManager *textLayoutManager = [[SquirrelTextLayoutManager alloc] init];
      textLayoutManager.usesFontLeading = NO;
      textLayoutManager.usesHyphenation = NO;
      textLayoutManager.delegate = textLayoutManager;
      NSTextContainer *textContainer = [[NSTextContainer alloc]
                                        initWithSize:NSZeroSize];
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
                                        initWithContainerSize:NSZeroSize];
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
  }
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
    NSInteger location = [contentStorage
                          offsetFromLocation:contentStorage.documentRange.location
                          toLocation:textRange.location];
    NSInteger length = [contentStorage
                        offsetFromLocation:textRange.location
                        toLocation:textRange.endLocation];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
  }
}

// Get the rectangle containing entire contents, expensive to calculate
- (NSRect)contentRect {
  if (@available(macOS 12.0, *)) {
    [_textView.textLayoutManager
     ensureLayoutForRange:_textView.textContentStorage.documentRange];
    return _textView.textLayoutManager.usageBoundsForTextContainer;
  } else {
    [_textView.layoutManager
     ensureLayoutForTextContainer:_textView.textContainer];
    return [_textView.layoutManager
            usedRectForTextContainer:_textView.textContainer];
  }
}

// Get the rectangle containing the range of text, will first convert to glyph or text range, expensive to calculate
- (NSRect)blockRectForRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromCharRange:range];
    NSRect __block blockRect = NSZeroRect;
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
     type:NSTextLayoutManagerSegmentTypeHighlight
     options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
     usingBlock:^(NSTextRange *segRange, CGRect segFrame,
                  CGFloat baseline, NSTextContainer *textContainer) {
      blockRect = NSUnionRect(blockRect, segFrame);
      return YES;
    }];
    CGFloat lineSpacing = [[_textStorage attribute:NSParagraphStyleAttributeName
                                           atIndex:NSMaxRange(range) - 1
                                    effectiveRange:NULL] lineSpacing];
    blockRect.size.height += lineSpacing;
    return blockRect;
  } else {
    NSTextContainer *textContainer = _textView.textContainer;
    NSLayoutManager *layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range
                                               actualCharacterRange:NULL];
    NSRange firstLineRange = NSMakeRange(NSNotFound, 0);
    NSRect firstLineRect = [layoutManager
                            lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                            effectiveRange:&firstLineRange];
    if (NSMaxRange(glyphRange) <= NSMaxRange(firstLineRange)) {
      CGFloat headX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
      CGFloat tailX = NSMaxRange(glyphRange) < NSMaxRange(firstLineRange)
                      ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
                      : NSWidth(firstLineRect);
      return NSMakeRect(NSMinX(firstLineRect) + headX,
                        NSMinY(firstLineRect),
                        tailX - headX,
                        NSHeight(firstLineRect));
    } else {
      NSRect finalLineRect = [layoutManager
                              lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                              effectiveRange:NULL];
      return NSMakeRect(NSMinX(firstLineRect),
                        NSMinY(firstLineRect),
                        textContainer.size.width,
                        NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    }
  }
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect are incomplete line rectangle
// bodyRect is the complete line fragment in the middle if the range spans no less than one full line
- (void)multilineRectForRange:(NSRange)charRange
                  leadingRect:(NSRectPointer)leadingRect
                     bodyRect:(NSRectPointer)bodyRect
                 trailingRect:(NSRectPointer)trailingRect {
  if (@available(macOS 12.0, *)) {
    NSTextRange *textRange = [self getTextRangeFromCharRange:charRange];
    NSMutableArray *lineRects = [[NSMutableArray alloc] init];
    NSMutableArray *lineRanges = [[NSMutableArray alloc] init];
    [_textView.textLayoutManager
     enumerateTextSegmentsInRange:textRange
     type:NSTextLayoutManagerSegmentTypeHighlight
     options:NSTextLayoutManagerSegmentOptionsNone
     usingBlock:^(NSTextRange *segRange, CGRect segFrame,
                  CGFloat baseline, NSTextContainer *textContainer) {
      if (!NSIsEmptyRect(segFrame)) {
        NSRect lastSegFrame = lineRects.count > 0 ? [lineRects.lastObject rectValue] : NSZeroRect;
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
      *bodyRect = [lineRects[0] rectValue];
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
      NSRect leadingLineRect = [lineRects.firstObject rectValue];
      leadingLineRect.size.width = containerWidth - NSMinX(leadingLineRect);
      NSRect trailingLineRect = [lineRects.lastObject rectValue];
      if (NSMaxX(trailingLineRect) == NSMaxX(leadingLineRect)) {
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect = NSUnionRect(leadingLineRect, trailingLineRect);
        } else {
          *leadingRect = leadingLineRect;
          *bodyRect = NSMakeRect(0.0,
                                 NSMaxY(leadingLineRect),
                                 containerWidth,
                                 NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = trailingLineRect;
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect = NSMakeRect(0.0,
                                 NSMinY(leadingLineRect),
                                 containerWidth,
                                 NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = leadingLineRect;
          if (![lineRanges.lastObject containsLocation:[lineRanges.firstObject endLocation]]) {
            *bodyRect = NSMakeRect(0.0,
                                   NSMaxY(leadingLineRect),
                                   containerWidth,
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
    NSRect leadingLineRect = [layoutManager
                              lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                              effectiveRange:&leadingLineRange];
    CGFloat headX = [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
    if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
      CGFloat tailX = NSMaxRange(glyphRange) < NSMaxRange(leadingLineRange)
                      ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
                      : NSWidth(leadingLineRect);
      *bodyRect = NSMakeRect(headX, NSMinY(leadingLineRect),
                             tailX - headX, NSHeight(leadingLineRect));
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
      NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
      NSRect trailingLineRect = [layoutManager
                                 lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                                 effectiveRange:&trailingLineRange];
      CGFloat tailX = NSMaxRange(glyphRange) < NSMaxRange(trailingLineRange)
                      ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
                      : NSWidth(trailingLineRect);
      if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(0.0,
                                 NSMinY(leadingLineRect),
                                 containerWidth,
                                 NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(headX,
                                    NSMinY(leadingLineRect),
                                    containerWidth - headX,
                                    NSHeight(leadingLineRect));
          *bodyRect = NSMakeRect(0.0,
                                 NSMaxY(leadingLineRect),
                                 containerWidth,
                                 NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = NSMakeRect(0.0,
                                   NSMinY(trailingLineRect),
                                   tailX,
                                   NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect = NSMakeRect(0.0,
                                 NSMinY(leadingLineRect),
                                 containerWidth,
                                 NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = NSMakeRect(headX,
                                    NSMinY(leadingLineRect),
                                    containerWidth - headX,
                                    NSHeight(leadingLineRect));
          if (trailingLineRange.location > NSMaxRange(leadingLineRange)) {
            *bodyRect = NSMakeRect(0.0,
                                   NSMaxY(leadingLineRect),
                                   containerWidth,
                                   NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
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
  _deleteBackPath = nil;
  _candidatePaths = [[NSMutableArray alloc] initWithCapacity:candidateRanges.count];
  _pagingPaths = [[NSMutableArray alloc] initWithCapacity:pagingRange.length > 0 ? 2 : 0];
  _functionButton = kVoidSymbol;
  // invalidate Rect beyond bound of textview to clear any out-of-bound drawing from last round
  [self setNeedsDisplayInRect:self.bounds];
  [self.textView setNeedsDisplayInRect:self.bounds];
}

- (void)highlightFunctionButton:(SquirrelIndex)functionButton {
  _functionButton = functionButton;
  if (_deleteBackPath) {
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
static NSBezierPath * squirclePath(NSArray<NSValue *> *vertex, CGFloat radius) {
  if (vertex.count < 1) {
    return nil;
  }
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSPoint point = vertex.lastObject.pointValue;
  NSPoint nextPoint = vertex.firstObject.pointValue;
  NSPoint startPoint;
  NSPoint endPoint;
  NSPoint controlPoint1;
  NSPoint controlPoint2;
  CGFloat arcRadius;
  CGVector nextDiff = CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
  CGVector lastDiff;
  if (ABS(nextDiff.dx) >= ABS(nextDiff.dy)) {
    endPoint = NSMakePoint(point.x + nextDiff.dx / 2, nextPoint.y);
  } else {
    endPoint = NSMakePoint(nextPoint.x, point.y + nextDiff.dy / 2);
  }
  [path moveToPoint:endPoint];
  for (NSUInteger i = 0; i < vertex.count; ++i) {
    lastDiff = nextDiff;
    point = nextPoint;
    nextPoint = vertex[(i + 1) % vertex.count].pointValue;
    nextDiff = CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
    if (ABS(nextDiff.dx) >= ABS(nextDiff.dy)) {
      arcRadius = MIN(radius * 1.5, MIN(ABS(nextDiff.dx), ABS(lastDiff.dy)) / 2);
      point.y = nextPoint.y;
      startPoint = NSMakePoint(point.x, point.y - copysign(arcRadius, lastDiff.dy));
      controlPoint1 = NSMakePoint(point.x, point.y - copysign(arcRadius * 0.1, lastDiff.dy));
      endPoint = NSMakePoint(point.x + copysign(arcRadius, nextDiff.dx), nextPoint.y);
      controlPoint2 = NSMakePoint(point.x + copysign(arcRadius * 0.1, nextDiff.dx), nextPoint.y);
    } else {
      arcRadius = MIN(radius * 1.5, MIN(ABS(nextDiff.dy), ABS(lastDiff.dx)) / 2);
      point.x = nextPoint.x;
      startPoint = NSMakePoint(point.x - copysign(arcRadius, lastDiff.dx), point.y);
      controlPoint1 = NSMakePoint(point.x - copysign(arcRadius * 0.1, lastDiff.dx), point.y);
      endPoint = NSMakePoint(nextPoint.x, point.y + copysign(arcRadius, nextDiff.dy));
      controlPoint2 = NSMakePoint(nextPoint.x, point.y + copysign(arcRadius * 0.1, nextDiff.dy));
    }
    [path lineToPoint:startPoint];
    [path curveToPoint:endPoint
         controlPoint1:controlPoint1
         controlPoint2:controlPoint2];
  }
  [path closePath];
  return path;
}

static inline NSArray<NSValue *> *rectVertex(NSRect rect) {
  return @[@(rect.origin),
           @(NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)),
           @(NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y))];
}

// Based on the 3 boxes from multilineRectForRange, calculate the vertex of the polygon containing the text in range
static NSArray<NSValue *> *multilineRectVertex(NSRect leadingRect, NSRect bodyRect, NSRect trailingRect) {
  if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && NSIsEmptyRect(trailingRect)) {
    return rectVertex(leadingRect);
  } else if (NSIsEmptyRect(bodyRect) && NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect)) {
    return rectVertex(trailingRect);
  } else if (NSIsEmptyRect(leadingRect) && NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    return rectVertex(bodyRect);
  } else if (NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray *leadingVertex = rectVertex(leadingRect);
    NSArray *bodyVertex = rectVertex(bodyRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0],
             bodyVertex[1], bodyVertex[2], leadingVertex[3]];
  } else if (NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray *trailingVertex = rectVertex(trailingRect);
    NSArray *bodyVertex = rectVertex(bodyRect);
    return @[bodyVertex[0], trailingVertex[1], trailingVertex[2],
             trailingVertex[3], bodyVertex[2], bodyVertex[3]];
  } else if (!NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) &&
             NSIsEmptyRect(bodyRect) && NSMinX(leadingRect) <= NSMaxX(trailingRect)) {
    NSArray *leadingVertex = rectVertex(leadingRect);
    NSArray *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], trailingVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], leadingVertex[2], leadingVertex[3]];
  } else if (!NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) && !NSIsEmptyRect(bodyRect)) {
    NSArray *leadingVertex = rectVertex(leadingRect);
    NSArray *bodyVertex = rectVertex(bodyRect);
    NSArray *trailingVertex = rectVertex(trailingRect);
    return @[leadingVertex[0], leadingVertex[1], bodyVertex[0], trailingVertex[1],
             trailingVertex[2], trailingVertex[3], bodyVertex[2], leadingVertex[3]];
  } else {
    return @[];
  }
}

static inline NSColor *hooverColor(NSColor *color, SquirrelAppear appear) {
  if (color == nil) {
    return nil;
  }
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  } else {
    return appear == darkAppear ? [color highlightWithLevel:0.3] : [color shadowWithLevel:0.3];
  }
}

static inline NSColor *disabledColor(NSColor *color, SquirrelAppear appear) {
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
      buttonColor = hooverColor(theme.linear ? theme.highlightedCandidateBackColor
                                             : theme.highlightedPreeditBackColor, self.appear);
      buttonPath = _pagingPaths[0];
      break;
    case kHome:
      buttonColor = disabledColor(theme.linear ? theme.highlightedCandidateBackColor
                                               : theme.highlightedPreeditBackColor, self.appear);
      buttonPath = _pagingPaths[0];
      break;
    case kPageDown:
      buttonColor = hooverColor(theme.linear ? theme.highlightedCandidateBackColor
                                             : theme.highlightedPreeditBackColor, self.appear);
      buttonPath = _pagingPaths[1];
      break;
    case kEnd:
      buttonColor = disabledColor(theme.linear ? theme.highlightedCandidateBackColor
                                               : theme.highlightedPreeditBackColor, self.appear);
      buttonPath = _pagingPaths[1];
      break;
    case kBackSpace:
      buttonColor = hooverColor(theme.highlightedPreeditBackColor, self.appear);
      buttonPath = _deleteBackPath;
      break;
    case kEscape:
      buttonColor = disabledColor(theme.highlightedPreeditBackColor, self.appear);
      buttonPath= _deleteBackPath;
      break;
    default:
      return nil;
      break;
  }
  if (buttonPath && buttonColor) {
    CAShapeLayer *functionButtonLayer = [[CAShapeLayer alloc] init];
    functionButtonLayer.path = buttonPath.quartzPath;
    functionButtonLayer.fillColor = buttonColor.CGColor;
    return functionButtonLayer;
  }
  return nil;
}

// All draws happen here
- (void)updateLayer {
  SquirrelTheme *theme = self.currentTheme;
  NSRect panelRect = self.bounds;
  NSRect backgroundRect = [self backingAlignedRect:NSInsetRect(panelRect, theme.borderInset.width,
                                                                          theme.borderInset.height)
                                           options:NSAlignAllEdgesNearest];
  CGFloat outerCornerRadius = MIN(theme.cornerRadius, NSHeight(panelRect) * 0.5);
  CGFloat innerCornerRadius = MAX(MIN(theme.highlightedCornerRadius, NSHeight(backgroundRect) * 0.5),
                                  outerCornerRadius - MIN(theme.borderInset.width, theme.borderInset.height));
  NSBezierPath *panelPath = squirclePath(rectVertex(panelRect), outerCornerRadius);
  NSBezierPath *backgroundPath = squirclePath(rectVertex(backgroundRect), innerCornerRadius);
  NSBezierPath *borderPath = [panelPath copy];
  [borderPath appendBezierPath:backgroundPath];

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
  _preeditBlock = NSZeroRect;
  NSBezierPath *highlightedPreeditPath;
  if (preeditRange.length > 0) {
    NSRect innerBox = [self blockRectForRange:preeditRange];
    _preeditBlock = NSMakeRect(backgroundRect.origin.x,
                               backgroundRect.origin.y,
                               backgroundRect.size.width,
                               innerBox.size.height + (candidateBlockRange.length > 0 ? theme.preeditLinespace : 0.0));
    _preeditBlock = [self backingAlignedRect:_preeditBlock
                                     options:NSAlignAllEdgesNearest];

    // Draw highlighted part of preedit text
    NSRange highlightedPreeditRange = NSIntersectionRange(_highlightedPreeditRange, visibleRange);
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius,
                               theme.preeditParagraphStyle.minimumLineHeight * 0.5);
    if (highlightedPreeditRange.length > 0 && theme.highlightedPreeditBackColor) {
      CGFloat kerning = [theme.preeditAttrs[NSKernAttributeName] doubleValue];
      innerBox.origin.x += _alignmentRectInsets.left - ceil(kerning * 0.5);
      innerBox.size.width = backgroundRect.size.width - theme.separatorWidth + kerning;
      innerBox.origin.y += _alignmentRectInsets.top;
      innerBox = [self backingAlignedRect:innerBox
                                  options:NSAlignAllEdgesNearest];
      NSRect leadingRect = NSZeroRect;
      NSRect bodyRect = NSZeroRect;
      NSRect trailingRect = NSZeroRect;
      [self multilineRectForRange:highlightedPreeditRange
                      leadingRect:&leadingRect
                         bodyRect:&bodyRect
                     trailingRect:&trailingRect];
      if (!NSIsEmptyRect(leadingRect)) {
        leadingRect.origin.x += _alignmentRectInsets.left - ceil(kerning * 0.5);
        leadingRect.origin.y += _alignmentRectInsets.top;
        leadingRect.size.width += kerning;
        leadingRect = [self backingAlignedRect:NSIntersectionRect(leadingRect, innerBox)
                                       options:NSAlignAllEdgesNearest];
      }
      if (!NSIsEmptyRect(bodyRect)) {
        bodyRect.origin.x += _alignmentRectInsets.left - ceil(kerning * 0.5);
        bodyRect.origin.y += _alignmentRectInsets.top;
        bodyRect.size.width += kerning;
        bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, innerBox)
                                    options:NSAlignAllEdgesNearest];
      }
      if (!NSIsEmptyRect(trailingRect)) {
        trailingRect.origin.x += _alignmentRectInsets.left - ceil(kerning * 0.5);
        trailingRect.origin.y += _alignmentRectInsets.top;
        trailingRect.size.width += kerning;
        trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, innerBox)
                                        options:NSAlignAllEdgesNearest];
      }

      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) && !NSIsEmptyRect(trailingRect) &&
          NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        highlightedPreeditPath = squirclePath(rectVertex(leadingRect), cornerRadius);
        [highlightedPreeditPath appendBezierPath:squirclePath(rectVertex(trailingRect), cornerRadius)];
      } else {
        highlightedPreeditPath = squirclePath(multilineRectVertex(leadingRect, bodyRect, trailingRect),
                                              cornerRadius);
      }
    }
    NSRect deleteBackRect = [self blockRectForRange:NSMakeRange(NSMaxRange(_preeditRange) - 1, 1)];
    deleteBackRect.size.width += floor(theme.separatorWidth * 0.5);
    deleteBackRect.origin.x = NSMaxX(backgroundRect) - NSWidth(deleteBackRect);
    deleteBackRect.origin.y += _alignmentRectInsets.top;
    deleteBackRect = [self backingAlignedRect:NSIntersectionRect(deleteBackRect, _preeditBlock)
                                      options:NSAlignAllEdgesNearest];
    _deleteBackPath = squirclePath(rectVertex(deleteBackRect), cornerRadius);
  }

  // Draw candidate Rect
  _candidateBlock = NSZeroRect;
  NSBezierPath *candidateBlockPath;
  NSBezierPath *gridPath;
  if (candidateBlockRange.length > 0) {
    _candidateBlock = [self blockRectForRange:candidateBlockRange];
    _candidateBlock.size.width = backgroundRect.size.width;
    _candidateBlock.origin.x = backgroundRect.origin.x;
    _candidateBlock.origin.y = preeditRange.length == 0 ? NSMinY(backgroundRect) : NSMaxY(_preeditBlock);
    if (pagingRange.length == 0 || theme.linear) {
      _candidateBlock.size.height = NSMaxY(backgroundRect) - NSMinY(_candidateBlock);
    } else {
      _candidateBlock.size.height += theme.linespace;
    }
    _candidateBlock = [self backingAlignedRect:NSIntersectionRect(_candidateBlock, backgroundRect)
                                       options:NSAlignAllEdgesNearest];
    candidateBlockPath = squirclePath(rectVertex(_candidateBlock),
                                      MIN(theme.highlightedCornerRadius, NSHeight(_candidateBlock) * 0.5));

    // Draw candidate highlight rect
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius,
                               theme.paragraphStyle.minimumLineHeight * 0.5);
    if (theme.linear) {
      CGFloat gridOriginY;
      CGFloat tabInterval;
      CGFloat kerning = [theme.attrs[NSKernAttributeName] doubleValue];
      if (theme.tabled) {
        gridPath = [NSBezierPath bezierPath];
        gridOriginY = NSMinY(_candidateBlock);
        tabInterval = theme.separatorWidth * 2;
      }
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange(_candidateRanges[i].rangeValue, visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect leadingRect = NSZeroRect;
        NSRect bodyRect = NSZeroRect;
        NSRect trailingRect = NSZeroRect;
        [self multilineRectForRange:candidateRange
                        leadingRect:&leadingRect
                           bodyRect:&bodyRect
                       trailingRect:&trailingRect];
        if (NSIsEmptyRect(leadingRect)) {
          bodyRect.origin.y -= ceil(theme.linespace * 0.5);
          bodyRect.size.height += ceil(theme.linespace * 0.5);
        } else {
          leadingRect.origin.x += theme.borderInset.width;
          leadingRect.size.width += theme.separatorWidth;
          leadingRect.origin.y += _alignmentRectInsets.top - ceil(theme.linespace * 0.5);
          leadingRect.size.height += ceil(theme.linespace * 0.5);
          leadingRect = [self backingAlignedRect:NSIntersectionRect(leadingRect, _candidateBlock)
                                         options:NSAlignAllEdgesNearest];
        }
        if (NSIsEmptyRect(trailingRect)) {
          bodyRect.size.height += floor(theme.linespace * 0.5);
        } else {
          trailingRect.origin.x += theme.borderInset.width;
          trailingRect.size.width += theme.separatorWidth;
          trailingRect.origin.y += _alignmentRectInsets.top;
          trailingRect.size.height += floor(theme.linespace * 0.5);
          trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, _candidateBlock)
                                          options:NSAlignAllEdgesNearest];
        }
        if (!NSIsEmptyRect(bodyRect)) {
          bodyRect.origin.x += theme.borderInset.width;
          bodyRect.size.width += theme.separatorWidth;
          bodyRect.origin.y += _alignmentRectInsets.top;
          bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, _candidateBlock)
                                      options:NSAlignAllEdgesNearest];
        }
        if (theme.tabled) {
          CGFloat bottomEdge = NSMaxY(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          if (ABS(bottomEdge - gridOriginY) > 2 && ABS(bottomEdge - NSMaxY(_candidateBlock)) > 2) { // horizontal border
            [gridPath moveToPoint:NSMakePoint(NSMinX(_candidateBlock) +
                                              theme.separatorWidth * 0.5, bottomEdge)];
            [gridPath lineToPoint:NSMakePoint(NSMaxX(_candidateBlock) -
                                              theme.separatorWidth * 0.5, bottomEdge)];
            gridOriginY = bottomEdge;
          }
          CGPoint headOrigin = (NSIsEmptyRect(leadingRect) ? bodyRect : leadingRect).origin;
          if (headOrigin.x > NSMinX(_candidateBlock) + theme.separatorWidth + kerning) { // vertical bar
            [gridPath moveToPoint:NSMakePoint(headOrigin.x, headOrigin.y + cornerRadius * 0.8)];
            [gridPath lineToPoint:NSMakePoint(headOrigin.x, NSMaxY(NSIsEmptyRect(leadingRect) ? bodyRect : leadingRect) - cornerRadius * 0.8)];
          }
          CGFloat tailEdge = NSMaxX(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          CGFloat tabPosition = ceil((tailEdge + kerning * 0.5 - theme.borderInset.width) / tabInterval) * tabInterval + theme.borderInset.width;
          if (!NSIsEmptyRect(trailingRect)) {
            trailingRect.size.width += tabPosition - tailEdge;
            trailingRect = [self backingAlignedRect:NSIntersectionRect(trailingRect, _candidateBlock)
                                            options:NSAlignAllEdgesNearest];
          } else if (NSIsEmptyRect(leadingRect)) {
            bodyRect.size.width += tabPosition - tailEdge;
            bodyRect = [self backingAlignedRect:NSIntersectionRect(bodyRect, _candidateBlock)
                                        options:NSAlignAllEdgesNearest];
          }
        }

        NSBezierPath *candidatePath;
        // Handles the special case where containing boxes are separated
        if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) &&
            !NSIsEmptyRect(trailingRect) && NSMaxX(trailingRect) < NSMinX(leadingRect)) {
          candidatePath = squirclePath(rectVertex(leadingRect), cornerRadius);
          [candidatePath appendBezierPath:squirclePath(rectVertex(trailingRect), cornerRadius)];
        } else {
          candidatePath = squirclePath(multilineRectVertex(leadingRect, bodyRect, trailingRect), cornerRadius);
        }
        _candidatePaths[i] = candidatePath;
      }
    } else { // stacked layout
      for (NSUInteger i = 0; i < _candidateRanges.count; ++i) {
        NSRange candidateRange = NSIntersectionRange(_candidateRanges[i].rangeValue, visibleRange);
        if (candidateRange.length == 0) {
          break;
        }
        NSRect candidateRect = [self blockRectForRange:candidateRange];
        candidateRect.size.width = backgroundRect.size.width;
        candidateRect.origin.x = backgroundRect.origin.x;
        candidateRect.origin.y += _alignmentRectInsets.top - ceil(theme.linespace * 0.5);
        candidateRect.size.height += theme.linespace;
        candidateRect = [self backingAlignedRect:NSIntersectionRect(candidateRect, _candidateBlock)
                                         options:NSAlignAllEdgesNearest];
        _candidatePaths[i] = squirclePath(rectVertex(candidateRect), cornerRadius);
      }
    }
  }

  // Draw paging Rect
  _pagingBlock = NSZeroRect;
  if (pagingRange.length > 0) {
    NSRect pageUpRect = [self blockRectForRange:
                         NSMakeRange(pagingRange.location, 1)];
    NSRect pageDownRect = [self blockRectForRange:
                           NSMakeRange(NSMaxRange(pagingRange) - 1, 1)];
    pageDownRect.origin.x += _alignmentRectInsets.left;
    pageDownRect.size.width += ceil(theme.separatorWidth * 0.5);
    pageDownRect.origin.y += _alignmentRectInsets.top;
    pageUpRect.origin.x += theme.borderInset.width;
    pageUpRect.size.width = NSWidth(pageDownRect); // bypass the bug of getting wrong glyph position when tab is presented
    pageUpRect.origin.y += _alignmentRectInsets.top;
    if (theme.linear) {
      pageUpRect.origin.y -= ceil(theme.linespace * 0.5);
      pageUpRect.size.height += theme.linespace;
      pageDownRect.origin.y -= ceil(theme.linespace * 0.5);
      pageDownRect.size.height += theme.linespace;
      pageUpRect = NSIntersectionRect(pageUpRect, _candidateBlock);
      pageDownRect = NSIntersectionRect(pageDownRect, _candidateBlock);
    } else {
      _pagingBlock = NSMakeRect(NSMinX(backgroundRect),
                                NSMaxY(_candidateBlock),
                                NSWidth(backgroundRect),
                                NSMaxY(backgroundRect) - NSMaxY(_candidateBlock));
      pageUpRect = NSIntersectionRect(pageUpRect, _pagingBlock);
      pageDownRect = NSIntersectionRect(pageDownRect, _pagingBlock);
    }
    pageUpRect = [self backingAlignedRect:pageUpRect
                                  options:NSAlignAllEdgesNearest];
    pageDownRect = [self backingAlignedRect:pageDownRect
                                    options:NSAlignAllEdgesNearest];
    CGFloat cornerRadius = MIN(theme.highlightedCornerRadius,
                               MIN(NSWidth(pageDownRect), NSHeight(pageDownRect)) * 0.5);
    _pagingPaths[0] = squirclePath(rectVertex(pageUpRect), cornerRadius);
    _pagingPaths[1] = squirclePath(rectVertex(pageDownRect), cornerRadius);
  }

  // Set layers
  _shape.path = panelPath.quartzPath;
  _shape.fillColor = NSColor.whiteColor.CGColor;
  self.layer.sublayers = nil;
  // layers of large background elements
  CALayer *BackLayers = [[CALayer alloc] init];
  BackLayers.opacity = 1.0f - (float)theme.translucency;
  BackLayers.allowsGroupOpacity = YES;
  [self.layer addSublayer:BackLayers];
  // background image (pattern style) layer
  if (theme.backImage.valid) {
    CAShapeLayer *backImageLayer = [[CAShapeLayer alloc] init];
    CGAffineTransform transform = theme.vertical ? CGAffineTransformMakeRotation(M_PI_2)
                                                 : CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, - backgroundRect.origin.x,
                                                      - backgroundRect.origin.y);
    backImageLayer.path = (CGPathRef)CFAutorelease(CGPathCreateCopyByTransformingPath
                                                   (backgroundPath.quartzPath, &transform));
    backImageLayer.fillColor = [NSColor colorWithPatternImage:theme.backImage].CGColor;
    backImageLayer.affineTransform = CGAffineTransformInvert(transform);
    [BackLayers addSublayer:backImageLayer];
  }
  // background color layer
  CAShapeLayer *backColorLayer = [[CAShapeLayer alloc] init];
  if ((!NSIsEmptyRect(_preeditBlock) || !NSIsEmptyRect(_pagingBlock)) &&
      theme.preeditBackColor) {
    if (candidateBlockPath) {
      NSBezierPath *nonCandidatePath = [backgroundPath copy];
      [nonCandidatePath appendBezierPath:candidateBlockPath];
      backColorLayer.path = nonCandidatePath.quartzPath;
      backColorLayer.fillRule = kCAFillRuleEvenOdd;
      backColorLayer.strokeColor = theme.preeditBackColor.CGColor;
      backColorLayer.lineWidth = 0.5;
      backColorLayer.fillColor = theme.preeditBackColor.CGColor;
      [BackLayers addSublayer:backColorLayer];
      // candidate block's background color layer
      CAShapeLayer *candidateLayer = [[CAShapeLayer alloc] init];
      candidateLayer.path = candidateBlockPath.quartzPath;
      candidateLayer.fillColor = theme.backColor.CGColor;
      [BackLayers addSublayer:candidateLayer];
    } else {
      backColorLayer.path = backgroundPath.quartzPath;
      backColorLayer.strokeColor = theme.preeditBackColor.CGColor;
      backColorLayer.lineWidth = 0.5;
      backColorLayer.fillColor = theme.preeditBackColor.CGColor;
      [BackLayers addSublayer:backColorLayer];
    }
  } else {
    backColorLayer.path = backgroundPath.quartzPath;
    backColorLayer.strokeColor = theme.backColor.CGColor;
    backColorLayer.lineWidth = 0.5;
    backColorLayer.fillColor = theme.backColor.CGColor;
    [BackLayers addSublayer:backColorLayer];
  }
  // grids (in candidate block) layer
  if (gridPath) {
    CAShapeLayer *gridLayer = [[CAShapeLayer alloc] init];
    gridLayer.path = gridPath.quartzPath;
    gridLayer.lineWidth = 1.0;
    gridLayer.strokeColor = [theme.commentAttrs[NSForegroundColorAttributeName]
                              blendedColorWithFraction:0.5 ofColor:theme.backColor].CGColor;
    [BackLayers addSublayer:gridLayer];
  }
  // border layer
  CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
  borderLayer.path = borderPath.quartzPath;
  borderLayer.fillRule = kCAFillRuleEvenOdd;
  borderLayer.fillColor = (theme.borderColor ? : theme.backColor).CGColor;
  [BackLayers addSublayer:borderLayer];
  // layers of small highlighting elements
  CALayer *ForeLayers = [[CALayer alloc] init];
  CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
  maskLayer.path = backgroundPath.quartzPath;
  maskLayer.fillColor = NSColor.whiteColor.CGColor;
  ForeLayers.mask = maskLayer;
  [self.layer addSublayer:ForeLayers];
  // highlighted preedit layer
  if (highlightedPreeditPath && theme.highlightedPreeditBackColor) {
    CAShapeLayer *highlightedPreeditLayer = [[CAShapeLayer alloc] init];
    highlightedPreeditLayer.path = highlightedPreeditPath.quartzPath;
    highlightedPreeditLayer.fillColor = theme.highlightedPreeditBackColor.CGColor;
    [ForeLayers addSublayer:highlightedPreeditLayer];
  }
  // highlighted candidate layer
  if (_highlightedIndex < _candidatePaths.count && theme.highlightedCandidateBackColor) {
    CAShapeLayer *highlightedCandidateLayer = [[CAShapeLayer alloc] init];
    highlightedCandidateLayer.path = _candidatePaths[_highlightedIndex].quartzPath;
    highlightedCandidateLayer.fillColor = theme.highlightedCandidateBackColor.CGColor;
    [ForeLayers addSublayer:highlightedCandidateLayer];
  }
  // function buttons (page up, page down, backspace) layer
  if (_functionButton != kVoidSymbol) {
    CAShapeLayer *functionButtonLayer = [self getFunctionButtonLayer];
    if (functionButtonLayer) {
      [ForeLayers addSublayer:functionButtonLayer];
    }
  }
  // logo at the beginning for status message
  if (NSIsEmptyRect(_preeditBlock) && NSIsEmptyRect(_candidateBlock)) {
    CALayer *logoLayer = [[CALayer alloc] init];
    CGFloat height = [theme.statusAttrs[NSParagraphStyleAttributeName] minimumLineHeight];
    NSRect logoRect = NSMakeRect(backgroundRect.origin.x, backgroundRect.origin.y, height, height);
    logoLayer.frame = [self backingAlignedRect:NSInsetRect(logoRect, -0.1 * height, -0.1 * height)
                                       options:NSAlignAllEdgesNearest];
    NSImage *logoImage = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoImage.size = logoRect.size;
    CGFloat scaleFactor = [logoImage recommendedLayerContentsScale:
                           self.window.backingScaleFactor];
    logoLayer.contents = logoImage;
    logoLayer.contentsScale = scaleFactor;
    logoLayer.affineTransform = theme.vertical ? CGAffineTransformMakeRotation(-M_PI_2)
                                               : CGAffineTransformIdentity;
    [ForeLayers addSublayer:logoLayer];
  }
}

- (NSUInteger)getIndexFromMouseSpot:(NSPoint)spot {
  NSPoint point = [self convertPoint:spot fromView:nil];
  if (NSPointInRect(point, self.bounds)) {
    if (NSPointInRect(point, _preeditBlock)) {
      return [_deleteBackPath containsPoint:point] ? kBackSpace : kCodeInput;
    }
    if (_pagingPaths.count > 0) {
      if ([_pagingPaths[0] containsPoint:point]) {
        return kPageUp;
      }
      if ([_pagingPaths[1] containsPoint:point]) {
        return kPageDown;
      }
    }
    for (NSUInteger i = 0; i < _candidatePaths.count; ++i) {
      if ([_candidatePaths[i] containsPoint:point]) {
        return i;
      }
    }
  }
  return NSNotFound;
}

@end // SquirrelView


@interface SquirrelToolTip : NSWindow

@property(nonatomic, weak, readonly) SquirrelPanel *panel;

@end

@implementation SquirrelToolTip {
  NSVisualEffectView *_backView;
  NSTextField *_textView;
  NSTimer *_displayTimer;
}

- (instancetype)initWithPanel:(SquirrelPanel *)panel {
  self = [super initWithContentRect:NSZeroRect
                          styleMask:NSWindowStyleMaskNonactivatingPanel
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    _panel = panel;
    self.level = panel.level + 1;
    self.appearanceSource = panel;
    self.backgroundColor = NSColor.clearColor;
    self.opaque = YES;
    self.hasShadow = YES;
    NSView *contentView = [[NSView alloc] init];
    _backView = [[NSVisualEffectView alloc] init];
    _backView.material = NSVisualEffectMaterialToolTip;
    [contentView addSubview:_backView];
    _textView = [[NSTextField alloc] init];
    _textView.bezeled = YES;
    _textView.bezelStyle = NSTextFieldSquareBezel;
    _textView.selectable = NO;
    [contentView addSubview:_textView];
    self.contentView = contentView;
  }
  return self;
}

- (void)showWithToolTip:(NSString *)toolTip {
  if (toolTip.length == 0) {
    [self hide];
    return;
  }

  _textView.stringValue = toolTip;
  _textView.font = [NSFont toolTipsFontOfSize:0];
  _textView.textColor = NSColor.windowFrameTextColor;
  [_textView sizeToFit];
  NSSize contentSize = _textView.fittingSize;

  NSPoint spot = NSEvent.mouseLocation;
  NSCursor *cursor = NSCursor.currentSystemCursor;
  spot.x += cursor.image.size.width - cursor.hotSpot.x;
  spot.y -= cursor.image.size.height - cursor.hotSpot.y;
  NSRect windowRect = NSMakeRect(spot.x, spot.y - contentSize.height, contentSize.width, contentSize.height);

  NSRect screenRect = _panel.screen.visibleFrame;
  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = NSMaxX(screenRect) - NSWidth(windowRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = NSMinY(screenRect);
  }
  [self setFrame:[_panel.screen backingAlignedRect:windowRect
                                           options:NSAlignAllEdgesNearest]
         display:NO];
  _textView.frame = self.contentView.bounds;
  _backView.frame = self.contentView.bounds;

  _displayTimer = [NSTimer scheduledTimerWithTimeInterval:kShowStatusDuration
                                                   target:self
                                                 selector:@selector(delayedDisplay:)
                                                 userInfo:nil
                                                  repeats:NO];
}

- (void)delayedDisplay:(NSTimer *)timer {
  [self display];
  [self orderFrontRegardless];
}

- (void)hide {
  if (_displayTimer) {
    [_displayTimer invalidate];
    _displayTimer = nil;
  }
  if (self.visible) {
    [self orderOut:nil];
  }
}

@end // SquirrelToolTipView

#pragma mark - Panel window, dealing with text content and mouse interactions

@implementation SquirrelPanel {
  SquirrelView *_view;
  NSVisualEffectView *_back;
  NSScreen *_screen;
  SquirrelToolTip *_toolTip;

  NSSize _maxSize;
  CGFloat _textWidthLimit;
  NSPoint _scrollLocus;
  BOOL _initPosition;
  NSTimer *_statusTimer;

  NSUInteger _numCandidates;
  NSUInteger _highlightedIndex;
  NSUInteger _functionButton;
  NSUInteger _caretPos;
  BOOL _caretAtHome;
  BOOL _firstPage;
  BOOL _lastPage;
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

- (SquirrelInputController *)inputController {
  return SquirrelInputController.currentController;
}

- (instancetype)init {
  self = [super initWithContentRect:_IbeamRect
                          styleMask:NSWindowStyleMaskNonactivatingPanel|NSWindowStyleMaskBorderless
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    self.level = CGWindowLevelForKey(kCGCursorWindowLevelKey) - 100;
    self.alphaValue = 1.0;
    self.hasShadow = NO;
    self.opaque = NO;
    self.backgroundColor = NSColor.clearColor;
    self.delegate = self;
    self.acceptsMouseMovedEvents = YES;

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
    _toolTip = [[SquirrelToolTip alloc] initWithPanel:self];
  }
  return self;
}

- (void)windowDidChangeBackingProperties:(NSNotification *)notification {
  if ([notification.object isMemberOfClass:SquirrelPanel.class]) {
    [notification.object updateDisplayParameters];
  }
}

- (void)sendEvent:(NSEvent *)event {
  NSUInteger cursorIndex;
  switch (event.type) {
    case NSEventTypeLeftMouseDown:
      if (event.clickCount == 1 && _functionButton == kCodeInput) {
        NSPoint spot = [_view.textView convertPoint:self.mouseLocationOutsideOfEventStream
                                           fromView:nil];
        NSUInteger inputIndex = [_view.textView characterIndexForInsertionAtPoint:spot];
        if (inputIndex == 0) {
          [self.inputController perform:kSELECT onIndex:kHome];
        } else if (inputIndex < _caretPos) {
          [self.inputController moveCursor:_caretPos
                                toPosition:inputIndex
                             inlinePreedit:NO
                           inlineCandidate:NO];
        } else if (inputIndex >= _view.preeditRange.length) {
          [self.inputController perform:kSELECT onIndex:kEnd];
        } else if (inputIndex > _caretPos + 1) {
          [self.inputController moveCursor:_caretPos
                                toPosition:inputIndex - 1
                             inlinePreedit:NO
                           inlineCandidate:NO];
        }
      }
      break;
    case NSEventTypeLeftMouseUp:
      cursorIndex = [_view getIndexFromMouseSpot:self.mouseLocationOutsideOfEventStream];
      if (event.clickCount == 1 && cursorIndex != NSNotFound &&
          (cursorIndex == _highlightedIndex || cursorIndex == _functionButton)) {
        [self.inputController perform:kSELECT onIndex:cursorIndex];
      }
      break;
    case NSEventTypeRightMouseUp:
      cursorIndex = [_view getIndexFromMouseSpot:self.mouseLocationOutsideOfEventStream];
      if (event.clickCount == 1 && cursorIndex != NSNotFound) {
        if (cursorIndex == _highlightedIndex) {
          [self.inputController perform:kDELETE onIndex:cursorIndex];
        } else if (cursorIndex == _functionButton) {
          switch (cursorIndex) {
            case kPageUp:
              [self.inputController perform:kSELECT onIndex:kHome];
              break;
            case kPageDown:
              [self.inputController perform:kSELECT onIndex:kEnd];
              break;
            case kBackSpace:
              [self.inputController perform:kSELECT onIndex:kEscape];
              break;
          }
        }
      }
      break;
    case NSEventTypeMouseMoved:
      cursorIndex = [_view getIndexFromMouseSpot:self.mouseLocationOutsideOfEventStream];
      if (cursorIndex != _highlightedIndex && cursorIndex != _functionButton) {
        [_toolTip hide];
      }
      if (cursorIndex >= 0 && cursorIndex < _numCandidates && _highlightedIndex != cursorIndex) {
        _highlightedIndex = cursorIndex;
        [_toolTip showWithToolTip:NSLocalizedString(@"candidate", nil)];
        [self.inputController perform:kHILITE onIndex:
         [_view.currentTheme.selectKeys characterAtIndex:cursorIndex]];
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
            [_toolTip showWithToolTip:NSLocalizedString(_firstPage ? @"home" : @"page_up", nil)];
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
            [_toolTip showWithToolTip:NSLocalizedString(_lastPage ? @"end" : @"page_down", nil)];
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
            [_toolTip showWithToolTip:NSLocalizedString(_caretAtHome ? @"escape" : @"delete", nil)];
            break;
        }
        [_view highlightFunctionButton:cursorIndex];
        [self display];
      } else if (cursorIndex == kCodeInput && _functionButton != cursorIndex) {
        _functionButton = cursorIndex;
      }
      break;
    case NSEventTypeLeftMouseDragged:
      _maxSize = NSZeroSize; // reset the remember_size references after moving the panel
      [self performWindowDragWithEvent:event];
      break;
    case NSEventTypeScrollWheel: {
      SquirrelTheme *theme = _view.currentTheme;
      CGFloat scrollThreshold = [theme.attrs[NSParagraphStyleAttributeName] minimumLineHeight] +
                                [theme.attrs[NSParagraphStyleAttributeName] lineSpacing];
      if (event.phase == NSEventPhaseBegan) {
        _scrollLocus = NSZeroPoint;
      } else if ((event.phase == NSEventPhaseNone || event.momentumPhase == NSEventPhaseNone) &&
                 !isnan(_scrollLocus.x) && !isnan(_scrollLocus.y)) {
        // determine scrolling direction by confining to sectors within ±30º of any axis
        if (ABS(event.scrollingDeltaX) > ABS(event.scrollingDeltaY) * sqrt(3.0)) {
          _scrollLocus.x += event.scrollingDeltaX * (event.hasPreciseScrollingDeltas ? 1 : 10);
        } else if (ABS(event.scrollingDeltaY) > ABS(event.scrollingDeltaX) * sqrt(3.0)) {
          _scrollLocus.y += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 10);
        }
        // compare accumulated locus length against threshold and limit paging to max once
        if (_scrollLocus.x > scrollThreshold) {
          [self.inputController perform:kSELECT
                                onIndex:(theme.vertical ? kPageDown : kPageUp)];
          _scrollLocus = NSMakePoint(NAN, NAN);
        } else if (_scrollLocus.y > scrollThreshold) {
          [self.inputController perform:kSELECT
                                onIndex:kPageUp];
          _scrollLocus = NSMakePoint(NAN, NAN);
        } else if (_scrollLocus.x < -scrollThreshold) {
          [self.inputController perform:kSELECT
                                onIndex:(theme.vertical ? kPageUp : kPageDown)];
          _scrollLocus = NSMakePoint(NAN, NAN);
        } else if (_scrollLocus.y < -scrollThreshold) {
          [self.inputController perform:kSELECT
                                onIndex:kPageDown];
          _scrollLocus = NSMakePoint(NAN, NAN);
        }
      }
    } break;
    default:
      [super sendEvent:event];
      break;
  }
}

- (void)updateScreen {
  for (NSScreen *screen in NSScreen.screens) {
    if (NSPointInRect(_IbeamRect.origin, screen.frame)) {
      _screen = screen;
      return;
    }
  }
  _screen = NSScreen.mainScreen;
}

- (NSScreen *)screen {
  return _screen;
}

- (void)updateDisplayParameters {
  // repositioning the panel window
  _initPosition = YES;
  _maxSize = NSZeroSize;

  // size limits on textContainer
  NSRect screenRect = _screen.visibleFrame;
  SquirrelTheme *theme = _view.currentTheme;
  CGFloat textWidthRatio = MIN(0.8, 1.0 / (theme.vertical ? 4 : 3) +
                                    [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit = (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) * textWidthRatio -
                    theme.separatorWidth - theme.borderInset.width * 2;
  if (theme.lineLength > 0) {
    _textWidthLimit = MIN(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabled) {
    CGFloat tabInterval = theme.separatorWidth * 2;
    _textWidthLimit = floor((_textWidthLimit + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
  }
  CGFloat textHeightLimit = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.8 -
                            theme.borderInset.height * 2 - (theme.inlinePreedit ? ceil(theme.linespace * 0.5) : 0.0) -
                            (theme.linear || !theme.showPaging ? floor(theme.linespace * 0.5) : 0.0);
  _view.textView.textContainer.size = NSMakeSize(_textWidthLimit, textHeightLimit);

  // resize background image, if any
  if (theme.backImage.valid) {
    CGFloat widthLimit = _textWidthLimit + theme.separatorWidth;
    NSSize backImageSize = theme.backImage.size;
    theme.backImage.resizingMode = NSImageResizingModeStretch;
    theme.backImage.size = theme.vertical
    ? NSMakeSize(backImageSize.width / backImageSize.height * widthLimit, widthLimit)
    : NSMakeSize(widthLimit, backImageSize.height / backImageSize.width * widthLimit);
  }
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  NSAppearanceName appearanceName = _view.appear == darkAppear ? NSAppearanceNameDarkAqua
                                                               : NSAppearanceNameAqua;
  NSAppearance *requestedAppearance = [NSAppearance appearanceNamed:appearanceName];
  if (self.appearance != requestedAppearance) {
    self.appearance = requestedAppearance;
  }

  //Break line if the text is too long, based on screen size.
  SquirrelTheme *theme = _view.currentTheme;
  NSTextContainer *textContainer = _view.textView.textContainer;
  NSEdgeInsets insets = _view.alignmentRectInsets;
  CGFloat textWidthRatio = MIN(0.8, 1.0 / (theme.vertical ? 4 : 3) +
                                    [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = _screen.visibleFrame;

  // the sweep direction of the client app changes the behavior of adjusting squirrel panel position
  BOOL sweepVertical = NSWidth(_IbeamRect) > NSHeight(_IbeamRect);
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
        ? (sweepVertical ? (NSMinY(_IbeamRect) - MAX(NSWidth(maxContentRect), _maxSize.width) - insets.right < NSMinY(screenRect))
                         : (NSMinY(_IbeamRect) - kOffsetGap - NSHeight(screenRect) * textWidthRatio - insets.left - insets.right < NSMinY(screenRect)))
        : (sweepVertical ? (NSMinX(_IbeamRect) - kOffsetGap - NSWidth(screenRect) * textWidthRatio - insets.left - insets.right >= NSMinX(screenRect))
                         : (NSMaxX(_IbeamRect) + MAX(NSWidth(maxContentRect), _maxSize.width) + insets.right > NSMaxX(screenRect))))) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        CGFloat textHeightLimit = (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.8 - insets.top - insets.bottom;
        maxContentRect.size.width = _maxSize.width;
        textContainer.size = NSMakeSize(_maxSize.width, textHeightLimit);
      }
    }
    CGFloat textHeight = MAX(NSHeight(maxContentRect), _maxSize.height) + insets.top + insets.bottom;
    if (theme.vertical ? (NSMinX(_IbeamRect) - textHeight - (sweepVertical ? kOffsetGap : 0) < NSMinX(screenRect))
                       : (NSMinY(_IbeamRect) - textHeight - (sweepVertical ? 0 : kOffsetGap) < NSMinY(screenRect))) {
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
      windowRect.origin.x = NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
      windowRect.origin.y = NSMidY(_IbeamRect) - NSHeight(windowRect) * 0.5;
    } else { // horizontally centre-align (MidX) in screen coordinates
      windowRect.origin.x = NSMidX(_IbeamRect) - NSWidth(windowRect) * 0.5;
      windowRect.origin.y = NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
    }
  } else {
    if (theme.vertical) { // anchor is the top right corner in screen coordinates (MaxX, MaxY)
      windowRect = NSMakeRect(NSMaxX(self.frame) - NSHeight(maxContentRect) - insets.top - insets.bottom,
                              NSMaxY(self.frame) - NSWidth(maxContentRect) - insets.left - insets.right,
                              NSHeight(maxContentRect) + insets.top + insets.bottom,
                              NSWidth(maxContentRect) + insets.left + insets.right);
      _initPosition |= NSIntersectsRect(windowRect, _IbeamRect);
      if (_initPosition) {
        if (!sweepVertical) {
          // To avoid jumping up and down while typing, use the lower screen when typing on upper, and vice versa
          if (NSMinY(_IbeamRect) - kOffsetGap - NSHeight(screenRect) * textWidthRatio - insets.left - insets.right < NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.y = NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
          }
          // Make the right edge of candidate block fixed at the left of cursor
          windowRect.origin.x = NSMinX(_IbeamRect) + insets.top - NSWidth(windowRect);
          if (_view.preeditRange.length > 0) {
            windowRect.origin.x += NSHeight(_view.preeditBlock);
          }
        } else {
          if (NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect) < NSMinX(screenRect)) {
            windowRect.origin.x = NSMaxX(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.x = NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
          }
          windowRect.origin.y = NSMinY(_IbeamRect) + insets.left - NSHeight(windowRect);
        }
      }
    } else { // anchor is the top left corner in screen coordinates (MinX, MaxY)
      windowRect = NSMakeRect(NSMinX(self.frame),
                              NSMaxY(self.frame) - NSHeight(maxContentRect) - insets.top - insets.bottom,
                              NSWidth(maxContentRect) + insets.left + insets.right,
                              NSHeight(maxContentRect) + insets.top + insets.bottom);
      _initPosition |= NSIntersectsRect(windowRect, _IbeamRect);
      if (_initPosition) {
        if (sweepVertical) {
          // To avoid jumping left and right while typing, use the lefter screen when typing on righter, and vice versa
          if (NSMinX(_IbeamRect) - kOffsetGap - NSWidth(screenRect) * textWidthRatio - insets.left - insets.right >= NSMinX(screenRect)) {
            windowRect.origin.x = NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
          } else {
            windowRect.origin.x = NSMaxX(_IbeamRect) + kOffsetGap;
          }
          windowRect.origin.y = NSMinY(_IbeamRect) + insets.top - NSHeight(windowRect);
          if (_view.preeditRange.length > 0) {
            windowRect.origin.y += NSHeight(_view.preeditBlock);
          }
        } else {
          if (NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect) < NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.y = NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
          }
          windowRect.origin.x = NSMaxX(_IbeamRect) - insets.left;
        }
      }
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = (_initPosition && sweepVertical ? MIN(NSMinX(_IbeamRect) - kOffsetGap, NSMaxX(screenRect)) : NSMaxX(screenRect)) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = _initPosition && sweepVertical ? MAX(NSMaxX(_IbeamRect) + kOffsetGap, NSMinX(screenRect)) : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = _initPosition && !sweepVertical ? MAX(NSMaxY(_IbeamRect) + kOffsetGap, NSMinY(screenRect)) : NSMinY(screenRect);
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = (_initPosition && !sweepVertical ? MIN(NSMinY(_IbeamRect) - kOffsetGap, NSMaxY(screenRect)) : NSMaxY(screenRect)) - NSHeight(windowRect);
  }

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }
  windowRect = [_screen backingAlignedRect:NSIntersectionRect(windowRect, screenRect)
                                   options:NSAlignAllEdgesNearest];
  [self setFrame:windowRect display:YES];

  // rotate the view, the core in vertical mode!
  self.contentView.boundsRotation = theme.vertical ? -90.0 : 0.0;
  [self.contentView setBoundsOrigin:theme.vertical ? NSMakePoint(0.0, NSWidth(windowRect)) : NSZeroPoint];

  NSRect viewRect = self.contentView.bounds;
  [_view setBoundsOrigin:NSZeroPoint];
  _view.frame = viewRect;

  _view.textView.boundsRotation = 0.0;
  [_view.textView setBoundsOrigin:NSZeroPoint];
  _view.textView.frame = NSOffsetRect(viewRect, insets.left - _view.textView.textContainerOrigin.x,
                                                insets.top - _view.textView.textContainerOrigin.y);

  if (theme.translucency > 0) {
    [_back setBoundsOrigin:NSZeroPoint];
    _back.frame = viewRect;
    _back.hidden = NO;
  } else {
    _back.hidden = YES;
  }

  self.alphaValue = theme.alpha;
  [self orderFrontRegardless];
  // reset to initial position after showing status message
  _initPosition = _statusMessage != nil;
  // voila !
}

- (void)hide {
  if (_statusTimer.valid) {
    [_statusTimer invalidate];
    _statusTimer = nil;
  }
  [_toolTip hide];
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
     usingBlock:^BOOL(NSTextRange *segRange, CGRect segFrame,
                      CGFloat baseline, NSTextContainer *textContainer) {
      lineCount += 1 + (NSMaxX(segFrame) > _textWidthLimit);
      return YES;
    }];
  } else {
    NSRange glyphRange = [_view.textView.layoutManager
                          glyphRangeForCharacterRange:range
                          actualCharacterRange:NULL];
    [_view.textView.layoutManager
     enumerateLineFragmentsForGlyphRange:glyphRange
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
     usingBlock:^(NSTextRange *segRange, CGRect segFrame,
                  CGFloat baseline, NSTextContainer *textContainer) {
      rangeEndEdge = NSMaxX(segFrame);
      return YES;
    }];
    [_view.textView.textLayoutManager
     ensureLayoutForRange:_view.textView.textContentStorage.documentRange];
    NSRect container = _view.textView.textLayoutManager.usageBoundsForTextContainer;
    *maxLineLength = MAX(*maxLineLength, MAX(NSMaxX(container), _maxSize.width));
    return *maxLineLength > rangeEndEdge;
  } else {
    NSUInteger glyphIndex = [_view.textView.layoutManager
                             glyphIndexForCharacterAtIndex:range.location];
    CGFloat rangeEndEdge = NSMaxX([_view.textView.layoutManager
                                   lineFragmentUsedRectForGlyphAtIndex:glyphIndex
                                   effectiveRange:NULL]);
    NSRect container = [_view.textView.layoutManager
                        usedRectForTextContainer:_view.textView.textContainer];
    *maxLineLength = MAX(*maxLineLength, MAX(NSMaxX(container), _maxSize.width));
    return *maxLineLength > rangeEndEdge;
  }
}

- (NSMutableAttributedString *)getPageNumString:(NSUInteger)pageNum {
  SquirrelTheme *theme = _view.currentTheme;
  if (!theme.vertical) {
    return [[NSMutableAttributedString alloc]
            initWithString:[NSString stringWithFormat:@" %lu ", pageNum + 1]
            attributes:theme.pagingAttrs];
  }
  NSAttributedString *pageNumString =[[NSAttributedString alloc]
                                      initWithString:[NSString stringWithFormat:@"%lu", pageNum + 1]
                                      attributes:theme.pagingAttrs];
  NSMutableDictionary *pageNumAttrs = [theme.pagingAttrs mutableCopy];
  NSFont *font = pageNumAttrs[NSFontAttributeName];
  CGFloat lineHeight = (theme.linear ? theme.paragraphStyle : theme.pagingParagraphStyle).minimumLineHeight;
  CGFloat width = MAX(lineHeight, pageNumString.size.width);
  NSImage *pageNumImage = [NSImage imageWithSize:NSMakeSize(lineHeight, width)
                                         flipped:YES
                                  drawingHandler:^BOOL(NSRect dstRect) {
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, lineHeight * 0.5 + font.ascender * 0.5 + font.descender * 0.5, width);
    CGContextRotateCTM(context, -M_PI_2);
    [pageNumString drawAtPoint:NSMakePoint(width * 0.5 - pageNumString.size.width * 0.5, -font.ascender)];
    CGContextRestoreGState(context);
    return YES;
  }];
  pageNumImage.resizingMode = NSImageResizingModeStretch;
  pageNumImage.size = NSMakeSize(lineHeight, lineHeight);
  NSTextAttachment *pageNumAttm = [[NSTextAttachment alloc] init];
  pageNumAttm.image = pageNumImage;
  pageNumAttm.bounds = NSMakeRect(0, font.ascender * 0.5 + font.descender * 0.5 - lineHeight * 0.5, lineHeight, lineHeight);
  NSMutableAttributedString *attmString = [[NSMutableAttributedString alloc]
                                           initWithString:[NSString stringWithFormat:@" %C ", (unichar)NSAttachmentCharacter]
                                           attributes:pageNumAttrs];
  [attmString addAttribute:NSAttachmentAttributeName
                     value:pageNumAttm
                     range:NSMakeRange(1, 1)];
  return attmString;
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray<NSString *> *)candidates
           comments:(NSArray<NSString *> *)comments
   highlightedIndex:(NSUInteger)highlightedIndex
            pageNum:(NSUInteger)pageNum
           lastPage:(BOOL)lastPage {
  if (!NSIntersectsRect(_IbeamRect, _screen.frame)) {
    [self updateScreen];
    [self updateDisplayParameters];
  }
  _numCandidates = candidates.count;
  _highlightedIndex = _numCandidates == 0 ? NSNotFound : highlightedIndex;
  _caretPos = caretPos;
  _caretAtHome = caretPos == NSNotFound || (caretPos == selRange.location && selRange.location == 1);
  _firstPage = pageNum == 0;
  _lastPage = lastPage;
  _functionButton = kVoidSymbol;
  if (_numCandidates > 0 || preedit.length > 0) {
    _statusMessage = nil;
    if (_statusTimer.valid) {
      [_statusTimer invalidate];
      _statusTimer = nil;
    }
  } else {
    if (_statusMessage) {
      [self showStatus:_statusMessage];
      _statusMessage = nil;
    } else if (!_statusTimer.valid) {
      [self hide];
    }
    return;
  }

  SquirrelTheme *theme = _view.currentTheme;
  _view.textView.layoutOrientation = (NSTextLayoutOrientation)theme.vertical;
  if (theme.lineLength > 0) {
    _maxSize.width = MIN(theme.lineLength, _textWidthLimit);
  }

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSMutableAttributedString alloc] init]];
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  NSMutableArray *candidateRanges = [[NSMutableArray alloc]
                                     initWithCapacity:_numCandidates];
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);
  NSUInteger candidateBlockStart;
  NSUInteger lineStart;

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
    [preeditLine appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:kFullWidthSpace
                                         attributes:theme.preeditAttrs]];
    [preeditLine appendAttributedString:_caretAtHome ? theme.symbolDeleteStroke
                                                     : theme.symbolDeleteFill];
    // force caret to be rendered sideways, instead of uprights, in vertical orientation
    if (caretPos != NSNotFound) {
      [preeditLine addAttribute:NSVerticalGlyphFormAttributeName value:@(NO)
                          range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)), 1)];
    }
    preeditRange = NSMakeRange(0, preeditLine.length);
    [text appendAttributedString:preeditLine];

    if (_numCandidates > 0) {
      [text appendAttributedString:[[NSAttributedString alloc]
                                    initWithString:@"\n"
                                    attributes:theme.preeditAttrs]];
    } else {
      if ([self shouldUseTabInRange:NSMakeRange(preeditLine.length - 2, 2)
                      maxLineLength:&maxLineLength]) {
        if (theme.tabled) {
          maxLineLength = ceil((maxLineLength + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
        }
        [text replaceCharactersInRange:NSMakeRange(preeditLine.length - 2, 1)
                            withString:@"\t"];
        NSMutableParagraphStyle *paragraphStylePreedit = theme.preeditParagraphStyle.mutableCopy;
        paragraphStylePreedit.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                           location:maxLineLength
                                                                            options:@{}]];
        [text addAttribute:NSParagraphStyleAttributeName
                     value:paragraphStylePreedit
                     range:preeditRange];
      }
      goto drawPanel;
    }
  }

  // candidate items
  candidateBlockStart = text.length;
  lineStart = text.length;
  if (theme.linear) {
    paragraphStyleCandidate = [theme.paragraphStyle copy];
  }
  for (NSUInteger idx = 0; idx < _numCandidates; ++idx) {
    // attributed labels are already included in candidateFormats
    NSMutableAttributedString *item = (idx == highlightedIndex) ? [theme.candidateHighlightedFormats[idx] mutableCopy]
                                                                : [theme.candidateFormats[idx] mutableCopy];
    NSRange candidateRange = [item.string rangeOfString:@"%@"];
    // get the label size for indent
    CGFloat labelWidth = theme.linear ? 0.0 : ceil([item attributedSubstringFromRange:
                                                    NSMakeRange(0, candidateRange.location)].size.width);
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
                                     verticalOrientation:theme.vertical
                                           maximumLength:_textWidthLimit];
    if (annotationHeight * 2 > theme.linespace) {
      [self setAnnotationHeight:annotationHeight];
      paragraphStyleCandidate = theme.paragraphStyle.copy;
      [text enumerateAttribute:NSParagraphStyleAttributeName
                       inRange:NSMakeRange(candidateBlockStart, text.length - candidateBlockStart)
                       options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
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
        [text replaceCharactersInRange:NSMakeRange(separatorStart, separator.length)
                            withString:@"\n"];
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
    NSMutableAttributedString *paging = [self getPageNumString:pageNum];
    [paging insertAttributedString:pageNum > 0 ? theme.symbolBackFill : theme.symbolBackStroke
                           atIndex:0];
    [paging appendAttributedString:lastPage ? theme.symbolForwardStroke : theme.symbolForwardFill];
    [text appendAttributedString:theme.separator];
    NSUInteger pagingStart = text.length;
    [text appendAttributedString:paging];
    if (theme.linear) {
      if ([self shouldBreakLineInsideRange:NSMakeRange(lineStart, text.length - lineStart)]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 0)
                            withString:@"\n"];
        lineStart = pagingStart;
        pagingStart += 1;
      }
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length)
                      maxLineLength:&maxLineLength] ||
          lineStart != candidateBlockStart) {
        if (theme.tabled) {
          maxLineLength = ceil((maxLineLength + theme.separatorWidth) / tabInterval) * tabInterval - theme.separatorWidth;
        } else {
          [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1)
                              withString:@"\t"];
        }
        paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
        paragraphStyleCandidate.tabStops = @[];
        NSUInteger candidateEnd = pagingStart - 1;
        CGFloat candidateEndPosition = NSMaxX([_view blockRectForRange:
                                               NSMakeRange(lineStart, candidateEnd - lineStart)]);
        for (NSUInteger i = 1; i * tabInterval < candidateEndPosition; ++i) {
          [paragraphStyleCandidate addTabStop:
           [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                           location:i * tabInterval
                                            options:@{}]];
        }
        [paragraphStyleCandidate addTabStop:
         [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                         location:maxLineLength
                                          options:@{}]];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleCandidate
                   range:NSMakeRange(lineStart, text.length - lineStart)];
    } else {
      NSMutableParagraphStyle *paragraphStylePaging = theme.pagingParagraphStyle.mutableCopy;
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length)
                      maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1)
                            withString:@"\t"];
        [text replaceCharactersInRange:NSMakeRange(pagingStart + paging.length - 2, 1)
                            withString:@"\t"];
        paragraphStylePaging.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter
                                                                          location:maxLineLength / 2
                                                                           options:@{}],
                                          [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                          location:maxLineLength
                                                                           options:@{}]];
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
    paragraphStylePreedit.tabStops = @[[[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                                                       location:maxLineLength
                                                                        options:@{}]];
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStylePreedit range:preeditRange];
  }

  // text done!
drawPanel:
  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.borderInset.height + topMargin,
                                         theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
                                         theme.borderInset.height + bottomMargin,
                                         theme.borderInset.width + floor(theme.separatorWidth * 0.5));
  _view.textView.textContainerInset = NSMakeSize(theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
                                                 theme.borderInset.height + topMargin);
  self.animationBehavior = caretPos == NSNotFound ? NSWindowAnimationBehaviorUtilityWindow
                                                  : NSWindowAnimationBehaviorDefault;
  [_view drawViewWithInsets:insets
            candidateRanges:candidateRanges
           highlightedIndex:highlightedIndex
               preeditRange:preeditRange
    highlightedPreeditRange:highlightedPreeditRange
                pagingRange:pagingRange];
  [self show];
}

- (void)updateStatusLong:(NSString *)messageLong
             statusShort:(NSString *)messageShort {
  switch (_view.currentTheme.statusMessageType) {
    case kStatusMessageTypeMixed:
      _statusMessage = messageShort ? : messageLong;
      break;
    case kStatusMessageTypeLong:
      _statusMessage = messageLong;
      break;
    case kStatusMessageTypeShort:
      _statusMessage = messageShort ? :
      (messageLong ? [messageLong substringWithRange:
                      [messageLong rangeOfComposedCharacterSequenceAtIndex:0]] : nil);
      break;
  }
}

- (void)showStatus:(NSString *)message {
  SquirrelTheme *theme = _view.currentTheme;
  _view.textView.layoutOrientation = (NSTextLayoutOrientation)theme.vertical;

  NSTextStorage *text = _view.textStorage;
  [text setAttributedString:[[NSAttributedString alloc]
                             initWithString:[NSString stringWithFormat:@"%@ %@", kFullWidthSpace, message]
                             attributes:theme.statusAttrs]];

  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  NSEdgeInsets insets = NSEdgeInsetsMake(theme.borderInset.height,
                                         theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
                                         theme.borderInset.height,
                                         theme.borderInset.width + floor(theme.separatorWidth * 0.5));
  _view.textView.textContainerInset = NSMakeSize(theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
                                                 theme.borderInset.height);

  // disable remember_size and fixed line_length for status messages
  _initPosition = YES;
  _maxSize = NSZeroSize;
  if (_statusTimer.valid) {
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

static void updateCandidateListLayout(BOOL *isLinear, BOOL *isTabled,
                                      SquirrelConfig *config, NSString *prefix) {
  NSString *candidateListLayout = [config getString:
                                   [prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([candidateListLayout isEqualToString:@"stacked"]) {
    *isLinear = NO;
    *isTabled = NO;
  } else if ([candidateListLayout isEqualToString:@"linear"]) {
    *isLinear = YES;
    *isTabled = NO;
  } else if ([candidateListLayout isEqualToString:@"tabled"]) {
    // `tabled` is a derived layout of `linear`; tabled implies linear
    *isLinear = YES;
    *isTabled = YES;
  } else {
    // Deprecated. Not to be confused with text_orientation: horizontal
    NSNumber *horizontal = [config getOptionalBool:
                            [prefix stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinear = horizontal.boolValue;
      *isTabled = NO;
    }
  }
}

static void updateTextOrientation(BOOL *isVertical, SquirrelConfig *config, NSString *prefix) {
  NSString *textOrientation = [config getString:
                               [prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVertical = NO;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVertical = YES;
  } else {
    NSNumber *vertical = [config getOptionalBool:
                          [prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVertical = vertical.boolValue;
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
  NSMutableArray *labels = [[NSMutableArray alloc] initWithCapacity:menuSize];
  NSString *selectKeys = [config getString:@"menu/alternative_select_keys"];
  NSArray *selectLabels = [config getList:@"menu/alternative_select_labels"];
  if (selectLabels.count > 0) {
    for (NSUInteger i = 0; i < menuSize; ++i) {
      labels[i] = selectLabels[i];
    }
  }
  if (selectKeys) {
    if (selectLabels.count == 0) {
      NSString *keyCaps = [selectKeys.uppercaseString stringByApplyingTransform:
                           NSStringTransformFullwidthToHalfwidth reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [keyCaps substringWithRange:NSMakeRange(i, 1)];
      }
    }
  } else {
    selectKeys = [@"1234567890" substringToIndex:menuSize];
    if (selectLabels.count == 0) {
      NSString *numerals = [selectKeys stringByApplyingTransform:
                            NSStringTransformFullwidthToHalfwidth reverse:YES];
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
  NSSet *styleOptions = [NSSet setWithArray:self.optionSwitcher.optionStates];
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
  NSColor *backColor;
  NSColor *borderColor;
  NSColor *preeditBackColor;
  NSColor *textColor;
  NSColor *candidateTextColor;
  NSColor *commentTextColor;
  NSColor *candidateLabelColor;
  NSColor *highlightedBackColor;
  NSColor *highlightedTextColor;
  NSColor *highlightedCandidateBackColor;
  NSColor *highlightedCandidateTextColor;
  NSColor *highlightedCommentTextColor;
  NSColor *highlightedCandidateLabelColor;
  NSImage *backImage;

  NSString *colorScheme;
  if (appear == darkAppear) {
    for (NSString *option in styleOptions) {
      if ((colorScheme = [config getString:[NSString stringWithFormat:
                                            @"style/%@/color_scheme_dark", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme_dark"];
  }
  if (!colorScheme) {
    for (NSString *option in styleOptions) {
      if ((colorScheme = [config getString:[NSString stringWithFormat:
                                            @"style/%@/color_scheme", option]])) break;
    }
    colorScheme = colorScheme ? : [config getString:@"style/color_scheme"];
  }
  BOOL isNative = !colorScheme || [colorScheme isEqualToString:@"native"];
  NSArray *configPrefixes = isNative
  ? [@"style/" stringsByAppendingPaths:styleOptions.allObjects]
  : [@[[@"preset_color_schemes/" stringByAppendingString:colorScheme]]
     arrayByAddingObjectsFromArray:[@"style/" stringsByAppendingPaths:styleOptions.allObjects]];

  // get color scheme and then check possible overrides from styleSwitcher
  for (NSString *prefix in configPrefixes) {
    // CHROMATICS override
    config.colorSpace = [config getString:[prefix stringByAppendingString:@"/color_space"]] ? : config.colorSpace;
    backColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]] ? : backColor;
    borderColor = [config getColor:[prefix stringByAppendingString:@"/border_color"]] ? : borderColor;
    preeditBackColor = [config getColor:[prefix stringByAppendingString:@"/preedit_back_color"]] ? : preeditBackColor;
    textColor = [config getColor:[prefix stringByAppendingString:@"/text_color"]] ? : textColor;
    candidateTextColor = [config getColor:[prefix stringByAppendingString:@"/candidate_text_color"]] ? : candidateTextColor;
    commentTextColor = [config getColor:[prefix stringByAppendingString:@"/comment_text_color"]] ? : commentTextColor;
    candidateLabelColor = [config getColor:[prefix stringByAppendingString:@"/label_color"]] ? : candidateLabelColor;
    highlightedBackColor = [config getColor:[prefix stringByAppendingString:@"/hilited_back_color"]] ? : highlightedBackColor;
    highlightedTextColor = [config getColor:[prefix stringByAppendingString:@"/hilited_text_color"]] ? : highlightedTextColor;
    highlightedCandidateBackColor = [config getColor:[prefix stringByAppendingString:
                                                      @"/hilited_candidate_back_color"]] ? : highlightedCandidateBackColor;
    highlightedCandidateTextColor = [config getColor:[prefix stringByAppendingString:
                                                      @"/hilited_candidate_text_color"]] ? : highlightedCandidateTextColor;
    highlightedCommentTextColor = [config getColor:[prefix stringByAppendingString:
                                                    @"/hilited_comment_text_color"]] ? : highlightedCommentTextColor;
    // for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color' are both valid
    highlightedCandidateLabelColor = [config getColor:[prefix stringByAppendingString:@"/label_hilited_color"]] ? :
      [config getColor:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]] ? : highlightedCandidateLabelColor;
    backImage = [config getImage:[prefix stringByAppendingString:@"/back_image"]] ? : backImage;

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
                                     @[@{NSFontFeatureTypeIdentifierKey:@(kNumberSpacingType),
                                     NSFontFeatureSelectorIdentifierKey:@(kMonospacedNumbersSelector)},
                                       @{NSFontFeatureTypeIdentifierKey:@(kTextSpacingType),
                                     NSFontFeatureSelectorIdentifierKey:@(kHalfWidthTextSelector)}]};

  NSFontDescriptor *fontDescriptor = getFontDescriptor(fontName);
  NSFont *font = [NSFont fontWithDescriptor:fontDescriptor ? : getFontDescriptor([NSFont userFontOfSize:0].fontName)
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
  NSFont *commentFont = [NSFont fontWithDescriptor:commentFontDescriptor ? : fontDescriptor
                                              size:commentFontSize.doubleValue];

  NSFont *pagingFont = [NSFont monospacedDigitSystemFontOfSize:labelFontSize.doubleValue
                                                        weight:NSFontWeightRegular];

  CGFloat fontHeight = getLineHeight(font, vertical);
  CGFloat labelFontHeight = getLineHeight(labelFont, vertical);
  CGFloat commentFontHeight = getLineHeight(commentFont, vertical);
  CGFloat lineHeight = MAX(fontHeight, MAX(labelFontHeight, commentFontHeight));
  CGFloat separatorWidth = ceil([kFullWidthSpace sizeWithAttributes:
                                 @{NSFontAttributeName: commentFont}].width);
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

  NSFont *zhFont = CFBridgingRelease(CTFontCreateForStringWithLanguage
                                     ((CTFontRef)font, CFSTR("　"), CFRangeMake(0, 1), CFSTR("zh")));
  NSFont *zhCommentFont = CFBridgingRelease(CTFontCreateForStringWithLanguage
                                            ((CTFontRef)commentFont, CFSTR("　"), CFRangeMake(0, 1), CFSTR("zh")));
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
  pagingAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassIdeographicCentered;
  pagingHighlightedAttrs[(NSString *)kCTBaselineClassAttributeName] = (NSString *)kCTBaselineClassIdeographicCentered;

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
  statusAttrs[NSKernAttributeName] = @(ceil(commentFontHeight * 0.05));

  preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  preeditHighlightedAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  pagingHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  // CHROMATICS refinement
  translucency = translucency ? : @(0.0);
  if (translucency.doubleValue > 0 && !isNative && backColor != nil &&
      (appear == darkAppear ? backColor.luminanceComponent > 0.65
                            : backColor.luminanceComponent < 0.55)) {
    backColor = [backColor invertLuminanceWithAdjustment:0];
    borderColor = [borderColor invertLuminanceWithAdjustment:0];
    preeditBackColor = [preeditBackColor invertLuminanceWithAdjustment:0];
    textColor = [textColor invertLuminanceWithAdjustment:0];
    candidateTextColor = [candidateTextColor invertLuminanceWithAdjustment:0];
    commentTextColor = [commentTextColor invertLuminanceWithAdjustment:0];
    candidateLabelColor = [candidateLabelColor invertLuminanceWithAdjustment:0];
    highlightedBackColor = [highlightedBackColor invertLuminanceWithAdjustment:-1];
    highlightedTextColor = [highlightedTextColor invertLuminanceWithAdjustment:1];
    highlightedCandidateBackColor = [highlightedCandidateBackColor invertLuminanceWithAdjustment:-1];
    highlightedCandidateTextColor = [highlightedCandidateTextColor invertLuminanceWithAdjustment:1];
    highlightedCommentTextColor = [highlightedCommentTextColor invertLuminanceWithAdjustment:1];
    highlightedCandidateLabelColor = [highlightedCandidateLabelColor invertLuminanceWithAdjustment:1];
  }

  backColor = backColor ? : NSColor.controlBackgroundColor;
  borderColor = borderColor ? : isNative ? NSColor.gridColor : nil;
  preeditBackColor = preeditBackColor ? : isNative ? NSColor.windowBackgroundColor : nil;
  textColor = textColor ? : NSColor.textColor;
  candidateTextColor = candidateTextColor ? : NSColor.controlTextColor;
  commentTextColor = commentTextColor ? : SquirrelTheme.secondaryTextColor;
  candidateLabelColor = candidateLabelColor ? : isNative ? SquirrelTheme.accentColor : blendColors(candidateTextColor, backColor);
  highlightedBackColor = highlightedBackColor ? : isNative ? NSColor.selectedTextBackgroundColor : nil;
  highlightedTextColor = highlightedTextColor ? : NSColor.selectedTextColor;
  highlightedCandidateBackColor = highlightedCandidateBackColor ? : isNative ? NSColor.selectedContentBackgroundColor : nil;
  highlightedCandidateTextColor = highlightedCandidateTextColor ? : NSColor.selectedMenuItemTextColor;
  highlightedCommentTextColor = highlightedCommentTextColor ? : NSColor.alternateSelectedControlTextColor;
  highlightedCandidateLabelColor = highlightedCandidateLabelColor ? : isNative ? NSColor.alternateSelectedControlTextColor :
    blendColors(highlightedCandidateTextColor, highlightedCandidateBackColor);

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

  NSSize borderInset = vertical ? NSMakeSize(borderHeight.doubleValue, borderWidth.doubleValue)
                                : NSMakeSize(borderWidth.doubleValue, borderHeight.doubleValue);

  [theme  setCornerRadius:MIN(cornerRadius.doubleValue, lineHeight * 0.5)
  highlightedCornerRadius:MIN(highlightedCornerRadius.doubleValue, lineHeight * 0.5)
           separatorWidth:separatorWidth
              borderInset:borderInset
                linespace:lineSpacing.doubleValue
         preeditLinespace:spacing.doubleValue
                    alpha:alpha ? alpha.doubleValue : 1.0
             translucency:translucency.doubleValue
               lineLength:lineLength.doubleValue > 0 ? MAX(ceil(lineLength.doubleValue), separatorWidth * 5) : 0.0
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

  [theme           setBackColor:backColor
  highlightedCandidateBackColor:highlightedCandidateBackColor
    highlightedPreeditBackColor:highlightedBackColor
               preeditBackColor:preeditBackColor
                    borderColor:borderColor
                      backImage:backImage];

  [theme setCandidateFormat:candidateFormat ? : kDefaultCandidateFormat];
  [theme setStatusMessageType:statusMessageType];
}

@end // SquirrelPanel

