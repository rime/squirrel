#import "SquirrelPanel.h"

#import "SquirrelApplicationDelegate.h"
#import "SquirrelConfig.h"
#import <QuartzCore/QuartzCore.h>

static const CGFloat kOffsetGap = 5;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kBlendedBackgroundColorFraction = 1.0 / 5;
static const NSTimeInterval kShowStatusDuration = 2.0;
static NSString* const kDefaultCandidateFormat = @"%c. %@";
static NSString* const kTipSpecifier = @"%s";
static NSString* const kFullWidthSpace = @"　";

@implementation NSBezierPath (BezierPathQuartzUtilities)

- (CGPathRef)quartzPath {
  if (@available(macOS 14.0, *)) {
    return self.CGPath;
  }
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
                                points[1].x, points[1].y, points[2].x,
                                points[2].y);
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

@end  // NSBezierPath (BezierPathQuartzUtilities)

@implementation
NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)

static NSString* const kMarkDownPattern =
    @"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|"
     "<(b|strong|i|em|u|sup|sub|s)>)(.+?)(\\2|\\3(?=\\b)|<\\/\\4>)";
static NSString* const kRubyPattern =
    @"(\uFFF9\\s*)(\\S+?)(\\s*\uFFFA(.+?)\uFFFB)";

- (void)superscriptRange:(NSRange)range {
  [self
      enumerateAttribute:NSFontAttributeName
                 inRange:range
                 options:
                     NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(NSFont* _Nullable value, NSRange subRange,
                           BOOL* _Nonnull stop) {
                NSFont* font =
                    [NSFont fontWithDescriptor:value.fontDescriptor
                                          size:floor(value.pointSize * 0.55)];
                [self addAttributes:@{
                  NSFontAttributeName : font,
                  (id)kCTBaselineClassAttributeName :
                      (id)kCTBaselineClassIdeographicCentered,
                  NSSuperscriptAttributeName : @(1)
                }
                              range:subRange];
              }];
}

- (void)subscriptRange:(NSRange)range {
  [self
      enumerateAttribute:NSFontAttributeName
                 inRange:range
                 options:
                     NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(NSFont* _Nullable value, NSRange subRange,
                           BOOL* _Nonnull stop) {
                NSFont* font =
                    [NSFont fontWithDescriptor:value.fontDescriptor
                                          size:floor(value.pointSize * 0.55)];
                [self addAttributes:@{
                  NSFontAttributeName : font,
                  (id)kCTBaselineClassAttributeName :
                      (id)kCTBaselineClassIdeographicCentered,
                  NSSuperscriptAttributeName : @(-1)
                }
                              range:subRange];
              }];
}

- (void)formatMarkDown {
  NSRegularExpression* regex = [[NSRegularExpression alloc]
      initWithPattern:kMarkDownPattern
              options:NSRegularExpressionUseUnicodeWordBoundaries
                error:nil];
  NSInteger __block offset = 0;
  [regex
      enumerateMatchesInString:self.mutableString
                       options:0
                         range:NSMakeRange(0, self.length)
                    usingBlock:^(NSTextCheckingResult* _Nullable result,
                                 NSMatchingFlags flags, BOOL* _Nonnull stop) {
                      result =
                          [result resultByAdjustingRangesWithOffset:offset];
                      NSString* tag = [self.mutableString
                          substringWithRange:[result rangeAtIndex:1]];
                      if ([tag isEqualToString:@"**"] ||
                          [tag isEqualToString:@"__"] ||
                          [tag isEqualToString:@"<b>"] ||
                          [tag isEqualToString:@"<strong>"]) {
                        [self applyFontTraits:NSBoldFontMask
                                        range:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"*"] ||
                                 [tag isEqualToString:@"_"] ||
                                 [tag isEqualToString:@"<i>"] ||
                                 [tag isEqualToString:@"<em>"]) {
                        [self applyFontTraits:NSItalicFontMask
                                        range:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"<u>"]) {
                        [self addAttribute:NSUnderlineStyleAttributeName
                                     value:@(NSUnderlineStyleSingle)
                                     range:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"~~"] ||
                                 [tag isEqualToString:@"<s>"]) {
                        [self addAttribute:NSStrikethroughStyleAttributeName
                                     value:@(NSUnderlineStyleSingle)
                                     range:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"^"] ||
                                 [tag isEqualToString:@"<sup>"]) {
                        [self superscriptRange:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"~"] ||
                                 [tag isEqualToString:@"<sub>"]) {
                        [self subscriptRange:[result rangeAtIndex:5]];
                      }
                      [self deleteCharactersInRange:[result rangeAtIndex:6]];
                      [self deleteCharactersInRange:[result rangeAtIndex:1]];
                      offset -= [result rangeAtIndex:6].length +
                                [result rangeAtIndex:1].length;
                    }];
  if (offset != 0) {  // repeat until no more nested markdown
    [self formatMarkDown];
  }
}

- (CGFloat)annotateRubyInRange:(NSRange)range
           verticalOrientation:(BOOL)isVertical
                 maximumLength:(CGFloat)maxLength {
  NSRegularExpression* regex =
      [[NSRegularExpression alloc] initWithPattern:kRubyPattern
                                           options:0
                                             error:nil];
  CGFloat __block rubyLineHeight = 0.0;
  [regex
      enumerateMatchesInString:self.mutableString
                       options:0
                         range:range
                    usingBlock:^(NSTextCheckingResult* _Nullable result,
                                 NSMatchingFlags flags, BOOL* _Nonnull stop) {
                      NSRange baseRange = [result rangeAtIndex:2];
                      // no ruby annotation if the base string includes line
                      // breaks
                      if ([self
                              attributedSubstringFromRange:NSMakeRange(
                                                               0,
                                                               NSMaxRange(
                                                                   baseRange))]
                              .size.width > maxLength - 0.1) {
                        [self deleteCharactersInRange:NSMakeRange(
                                                          NSMaxRange(
                                                              result.range) -
                                                              1,
                                                          1)];
                        [self
                            deleteCharactersInRange:NSMakeRange(
                                                        [result rangeAtIndex:3]
                                                            .location,
                                                        1)];
                        [self
                            deleteCharactersInRange:NSMakeRange(
                                                        [result rangeAtIndex:1]
                                                            .location,
                                                        1)];
                      } else {
                        // base string must use only one font so that all fall
                        // within one glyph run and the ruby annotation is
                        // aligned with no duplicates
                        NSFont* baseFont = [self attribute:NSFontAttributeName
                                                   atIndex:baseRange.location
                                            effectiveRange:NULL];
                        baseFont =
                            CFBridgingRelease(CTFontCreateForStringWithLanguage(
                                (CTFontRef)baseFont,
                                (CFStringRef)self.mutableString,
                                CFRangeMake((CFIndex)baseRange.location,
                                            (CFIndex)baseRange.length),
                                CFSTR("zh")));
                        [self addAttribute:NSFontAttributeName
                                     value:baseFont
                                     range:baseRange];

                        CGFloat rubyScale = 0.5;
                        CFStringRef rubyString =
                            (__bridge CFStringRef)[self.mutableString
                                substringWithRange:[result rangeAtIndex:4]];
                        CGFloat height =
                            isVertical
                                ? (baseFont.verticalFont.ascender -
                                   baseFont.verticalFont.descender)
                                : (baseFont.ascender - baseFont.descender);
                        rubyLineHeight =
                            fmax(rubyLineHeight, ceil(height * 0.5));
                        CFStringRef rubyText[kCTRubyPositionCount];
                        rubyText[kCTRubyPositionBefore] = rubyString;
                        rubyText[kCTRubyPositionAfter] = NULL;
                        rubyText[kCTRubyPositionInterCharacter] = NULL;
                        rubyText[kCTRubyPositionInline] = NULL;
                        CTRubyAnnotationRef rubyAnnotation =
                            CTRubyAnnotationCreate(
                                kCTRubyAlignmentDistributeSpace,
                                kCTRubyOverhangNone, rubyScale, rubyText);

                        [self deleteCharactersInRange:[result rangeAtIndex:3]];
                        if (@available(macOS 12.0, *)) {
                          [self addAttributes:@{
                            (id)kCTRubyAnnotationAttributeName :
                                CFBridgingRelease(rubyAnnotation)
                          }
                                        range:baseRange];
                        } else {
                          // use U+008B as placeholder for line-forward spaces
                          // in case ruby is wider than base
                          [self replaceCharactersInRange:NSMakeRange(
                                                             NSMaxRange(
                                                                 baseRange),
                                                             0)
                                              withString:[NSString
                                                             stringWithFormat:
                                                                 @"%C", 0x8B]];
                          [self addAttributes:@{
                            (id)kCTRubyAnnotationAttributeName :
                                CFBridgingRelease(rubyAnnotation),
                            NSVerticalGlyphFormAttributeName : @(isVertical)
                          }
                                        range:baseRange];
                        }
                        [self deleteCharactersInRange:[result rangeAtIndex:1]];
                      }
                    }];
  [self.mutableString replaceOccurrencesOfString:@"[\uFFF9-\uFFFB]"
                                      withString:@""
                                         options:NSRegularExpressionSearch
                                           range:NSMakeRange(0, self.length)];
  return ceil(rubyLineHeight);
}

@end  // NSMutableAttributedString (NSMutableAttributedStringMarkDownFormatting)

@implementation NSColorSpace (labColorSpace)

+ (NSColorSpace*)labColorSpace {
  CGFloat whitePoint[3] = {0.950489, 1.0, 1.088840};
  CGFloat blackPoint[3] = {0.0, 0.0, 0.0};
  CGFloat range[4] = {-127.0, 127.0, -127.0, 127.0};
  CGColorSpaceRef colorSpaceLab =
      CGColorSpaceCreateLab(whitePoint, blackPoint, range);
  NSColorSpace* labColorSpace = [[NSColorSpace alloc]
      initWithCGColorSpace:(CGColorSpaceRef)CFAutorelease(colorSpaceLab)];
  return labColorSpace;
}

@end  // NSColorSpace (labColorSpace)

@implementation NSColor (semanticColors)

+ (NSColor*)secondaryTextColor {
  if (@available(macOS 10.10, *)) {
    return NSColor.secondaryLabelColor;
  } else {
    return NSColor.disabledControlTextColor;
  }
}

+ (NSColor*)accentColor {
  if (@available(macOS 10.14, *)) {
    return NSColor.controlAccentColor;
  } else {
    return [NSColor colorForControlTint:NSColor.currentControlTint];
  }
}

@end  // NSColor (semanticColors)

@implementation NSColor (colorWithLabColorSpace)

+ (NSColor*)colorWithLabLuminance:(CGFloat)luminance
                                a:(CGFloat)a
                                b:(CGFloat)b
                            alpha:(CGFloat)alpha {
  luminance = fmax(fmin(luminance, 100.0), 0.0);
  a = fmax(fmin(a, 127.0), -127.0);
  b = fmax(fmin(b, 127.0), -127.0);
  alpha = fmax(fmin(alpha, 1.0), 0.0);
  CGFloat components[4] = {luminance, a, b, alpha};
  return [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                           components:components
                                count:4];
}

- (void)getLuminance:(CGFloat*)luminance
                   a:(CGFloat*)a
                   b:(CGFloat*)b
               alpha:(CGFloat*)alpha {
  NSColor* labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  *luminance = components[0] / 100.0;
  *a = components[1] / 127.0;  // green-red
  *b = components[2] / 127.0;  // blue-yellow
  *alpha = components[3];
}

- (CGFloat)luminanceComponent {
  NSColor* labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  return components[0] / 100.0;
}

- (NSColor*)invertLuminanceWithAdjustment:(NSInteger)sign {
  if (self == nil) {
    return nil;
  }
  NSColor* labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  BOOL isDark = components[0] < 60;
  if (sign > 0) {
    components[0] = isDark ? 100.0 - components[0] * 2.0 / 3.0
                           : 150.0 - components[0] * 1.5;
  } else if (sign < 0) {
    components[0] =
        isDark ? 80.0 - components[0] / 3.0 : 135.0 - components[0] * 1.25;
  } else {
    components[0] = isDark ? 90.0 - components[0] / 2.0 : 120.0 - components[0];
  }
  NSColor* invertedColor =
      [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                        components:components
                             count:4];
  return [invertedColor colorUsingColorSpace:self.colorSpace];
}

@end  // NSColor (colorWithLabColorSpace)

#pragma mark - Color scheme and other user configurations

@interface SquirrelTheme : NSObject

typedef NS_ENUM(NSUInteger, SquirrelStatusMessageType) {
  kStatusMessageTypeMixed = 0,
  kStatusMessageTypeShort = 1,
  kStatusMessageTypeLong = 2
};

@property(nonatomic, strong, readonly, nullable) NSColor* backColor;
@property(nonatomic, strong, readonly, nullable)
    NSColor* highlightedCandidateBackColor;
@property(nonatomic, strong, readonly, nullable)
    NSColor* highlightedPreeditBackColor;
@property(nonatomic, strong, readonly, nullable) NSColor* preeditBackColor;
@property(nonatomic, strong, readonly, nullable) NSColor* borderColor;
@property(nonatomic, strong, readonly, nullable) NSImage* backImage;

@property(nonatomic, readonly) CGFloat cornerRadius;
@property(nonatomic, readonly) CGFloat highlightedCornerRadius;
@property(nonatomic, readonly) CGFloat separatorWidth;
@property(nonatomic, readonly) CGFloat linespace;
@property(nonatomic, readonly) CGFloat preeditLinespace;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) CGFloat translucency;
@property(nonatomic, readonly) CGFloat lineLength;
@property(nonatomic, readonly) CGFloat expanderWidth;
@property(nonatomic, readonly) NSSize borderInset;
@property(nonatomic, readonly) BOOL showPaging;
@property(nonatomic, readonly) BOOL rememberSize;
@property(nonatomic, readonly) BOOL tabular;
@property(nonatomic, readonly) BOOL linear;
@property(nonatomic, readonly) BOOL vertical;
@property(nonatomic, readonly) BOOL inlinePreedit;
@property(nonatomic, readonly) BOOL inlineCandidate;

@property(nonatomic, strong, readonly, nonnull) NSDictionary* attrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* highlightedAttrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* labelAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary* labelHighlightedAttrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* commentAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary* commentHighlightedAttrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* preeditAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary* preeditHighlightedAttrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* pagingAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary* pagingHighlightedAttrs;
@property(nonatomic, strong, readonly, nonnull) NSDictionary* statusAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* paragraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* preeditParagraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* pagingParagraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* statusParagraphStyle;

@property(nonatomic, strong, readonly, nonnull) NSAttributedString* separator;
@property(nonatomic, strong, readonly, nonnull)
    NSAttributedString* symbolDeleteFill;
@property(nonatomic, strong, readonly, nonnull)
    NSAttributedString* symbolDeleteStroke;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolBackFill;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolBackStroke;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolForwardFill;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolForwardStroke;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolCompress;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* symbolExpand;
@property(nonatomic, strong, readonly, nullable) NSAttributedString* symbolLock;

@property(nonatomic, strong, readonly, nonnull) NSString* selectKeys;
@property(nonatomic, strong, readonly, nonnull) NSString* candidateFormat;
@property(nonatomic, strong, readonly, nonnull) NSArray<NSString*>* labels;
@property(nonatomic, strong, readonly, nonnull)
    NSArray<NSAttributedString*>* candidateFormats;
@property(nonatomic, strong, readonly, nonnull)
    NSArray<NSAttributedString*>* candidateHighlightedFormats;
@property(nonatomic, readonly) SquirrelStatusMessageType statusMessageType;
@property(nonatomic, readonly) NSUInteger pageSize;

- (void)setBackColor:(NSColor* _Nullable)backColor
    highlightedCandidateBackColor:
        (NSColor* _Nullable)highlightedCandidateBackColor
      highlightedPreeditBackColor:
          (NSColor* _Nullable)highlightedPreeditBackColor
                 preeditBackColor:(NSColor* _Nullable)preeditBackColor
                      borderColor:(NSColor* _Nullable)borderColor
                        backImage:(NSImage* _Nullable)backImage;

- (void)setCornerRadius:(CGFloat)cornerRadius
    highlightedCornerRadius:(CGFloat)highlightedCornerRadius
             separatorWidth:(CGFloat)separatorWidth
                  linespace:(CGFloat)linespace
           preeditLinespace:(CGFloat)preeditLinespace
                      alpha:(CGFloat)alpha
               translucency:(CGFloat)translucency
                 lineLength:(CGFloat)lineLength
                borderInset:(NSSize)borderInset
                 showPaging:(BOOL)showPaging
               rememberSize:(BOOL)rememberSize
                    tabular:(BOOL)tabular
                     linear:(BOOL)linear
                   vertical:(BOOL)vertical
              inlinePreedit:(BOOL)inlinePreedit
            inlineCandidate:(BOOL)inlineCandidate;

- (void)setAttrs:(NSDictionary* _Nonnull)attrs
           highlightedAttrs:(NSDictionary* _Nonnull)highlightedAttrs
                 labelAttrs:(NSDictionary* _Nonnull)labelAttrs
      labelHighlightedAttrs:(NSDictionary* _Nonnull)labelHighlightedAttrs
               commentAttrs:(NSDictionary* _Nonnull)commentAttrs
    commentHighlightedAttrs:(NSDictionary* _Nonnull)commentHighlightedAttrs
               preeditAttrs:(NSDictionary* _Nonnull)preeditAttrs
    preeditHighlightedAttrs:(NSDictionary* _Nonnull)preeditHighlightedAttrs
                pagingAttrs:(NSDictionary* _Nonnull)pagingAttrs
     pagingHighlightedAttrs:(NSDictionary* _Nonnull)pagingHighlightedAttrs
                statusAttrs:(NSDictionary* _Nonnull)statusAttrs;

- (void)updateSeperatorAndSymbolAttrs;

- (void)setParagraphStyle:(NSParagraphStyle* _Nonnull)paragraphStyle
    preeditParagraphStyle:(NSParagraphStyle* _Nonnull)preeditParagraphStyle
     pagingParagraphStyle:(NSParagraphStyle* _Nonnull)pagingParagraphStyle
     statusParagraphStyle:(NSParagraphStyle* _Nonnull)statusParagraphStyle;

- (void)setSelectKeys:(NSString* _Nonnull)selectKeys
               labels:(NSArray<NSString*>* _Nonnull)labels
         directUpdate:(BOOL)update;

- (void)setCandidateFormat:(NSString* _Nonnull)candidateFormat;

- (void)updateCandidateFormats;

- (void)setStatusMessageType:(NSString* _Nullable)type;

- (void)setAnnotationHeight:(CGFloat)height;

@end
@implementation SquirrelTheme

static inline NSColor* blendColors(NSColor* foregroundColor,
                                   NSColor* backgroundColor) {
  return [[foregroundColor
      blendedColorWithFraction:kBlendedBackgroundColorFraction
                       ofColor:backgroundColor ?: NSColor.lightGrayColor]
      colorWithAlphaComponent:foregroundColor.alphaComponent];
}

static NSFontDescriptor* getFontDescriptor(NSString* fullname) {
  if (fullname.length == 0) {
    return nil;
  }
  NSArray* fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray* validFontDescriptors =
      [[NSMutableArray alloc] initWithCapacity:fontNames.count];
  for (NSString* fontName in fontNames) {
    NSFont* font = [NSFont
        fontWithName:[fontName
                         stringByTrimmingCharactersInSet:
                             NSCharacterSet.whitespaceAndNewlineCharacterSet]
                size:0.0];
    if (font != nil) {
      // If the font name is not valid, NSFontDescriptor will still create
      // something for us. However, when we draw the actual text, Squirrel will
      // crash if there is any font descriptor with invalid font name.
      NSFontDescriptor* fontDescriptor = font.fontDescriptor;
      NSFontDescriptor* UIFontDescriptor = [fontDescriptor
          fontDescriptorWithSymbolicTraits:NSFontDescriptorTraitUIOptimized];
      [validFontDescriptors
          addObject:[NSFont fontWithDescriptor:UIFontDescriptor size:0.0] != nil
                        ? UIFontDescriptor
                        : fontDescriptor];
    }
  }
  if (validFontDescriptors.count == 0) {
    return nil;
  }
  NSFontDescriptor* initialFontDescriptor = validFontDescriptors[0];
  NSFontDescriptor* emojiFontDescriptor =
      [NSFontDescriptor fontDescriptorWithName:@"AppleColorEmoji" size:0.0];
  NSArray* fallbackDescriptors = [[validFontDescriptors
      subarrayWithRange:NSMakeRange(1, validFontDescriptors.count - 1)]
      arrayByAddingObject:emojiFontDescriptor];
  return [initialFontDescriptor fontDescriptorByAddingAttributes:@{
    NSFontCascadeListAttribute : fallbackDescriptors
  }];
}

static CGFloat getLineHeight(NSFont* font, BOOL vertical) {
  if (vertical) {
    font = font.verticalFont;
  }
  CGFloat lineHeight = ceil(font.ascender - font.descender);
  NSArray* fallbackList =
      [font.fontDescriptor objectForKey:NSFontCascadeListAttribute];
  for (NSFontDescriptor* fallback in fallbackList) {
    NSFont* fallbackFont = [NSFont fontWithDescriptor:fallback
                                                 size:font.pointSize];
    if (vertical) {
      fallbackFont = fallbackFont.verticalFont;
    }
    lineHeight =
        fmax(lineHeight, ceil(fallbackFont.ascender - fallbackFont.descender));
  }
  return lineHeight;
}

- (instancetype)init {
  if (self = [super init]) {
    NSMutableParagraphStyle* paragraphStyle =
        [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    // Use left-to-right marks to declare the default writing direction and
    // prevent strong right-to-left characters from setting the writing
    // direction in case the label are direction-less symbols
    paragraphStyle.baseWritingDirection = NSWritingDirectionLeftToRight;

    NSMutableParagraphStyle* preeditParagraphStyle = paragraphStyle.mutableCopy;
    NSMutableParagraphStyle* pagingParagraphStyle = paragraphStyle.mutableCopy;
    NSMutableParagraphStyle* statusParagraphStyle = paragraphStyle.mutableCopy;

    preeditParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    statusParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;

    NSFont* userFont =
        [NSFont fontWithDescriptor:getFontDescriptor(
                                       [NSFont userFontOfSize:0.0].fontName)
                              size:kDefaultFontSize];
    NSFont* userMonoFont = [NSFont
        fontWithDescriptor:getFontDescriptor(
                               [NSFont userFixedPitchFontOfSize:0.0].fontName)
                      size:kDefaultFontSize];
    NSFont* monoDigitFont =
        [NSFont monospacedDigitSystemFontOfSize:kDefaultFontSize
                                         weight:NSFontWeightRegular];

    NSMutableDictionary* attrs = [[NSMutableDictionary alloc] init];
    attrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;
    attrs[NSFontAttributeName] = userFont;
    // Use left-to-right embedding to prevent right-to-left text from changing
    // the layout of the candidate.
    attrs[NSWritingDirectionAttributeName] = @[ @(0) ];

    NSMutableDictionary* highlightedAttrs = attrs.mutableCopy;
    highlightedAttrs[NSForegroundColorAttributeName] =
        NSColor.selectedMenuItemTextColor;

    NSMutableDictionary* labelAttrs = attrs.mutableCopy;
    labelAttrs[NSForegroundColorAttributeName] = NSColor.accentColor;
    labelAttrs[NSFontAttributeName] = userMonoFont;

    NSMutableDictionary* labelHighlightedAttrs = labelAttrs.mutableCopy;
    labelHighlightedAttrs[NSForegroundColorAttributeName] =
        NSColor.alternateSelectedControlTextColor;

    NSMutableDictionary* commentAttrs = [[NSMutableDictionary alloc] init];
    commentAttrs[NSForegroundColorAttributeName] = NSColor.secondaryTextColor;
    commentAttrs[NSFontAttributeName] = userFont;

    NSMutableDictionary* commentHighlightedAttrs = commentAttrs.mutableCopy;
    commentHighlightedAttrs[NSForegroundColorAttributeName] =
        NSColor.alternateSelectedControlTextColor;

    NSMutableDictionary* preeditAttrs = [[NSMutableDictionary alloc] init];
    preeditAttrs[NSForegroundColorAttributeName] = NSColor.textColor;
    preeditAttrs[NSFontAttributeName] = userFont;
    preeditAttrs[NSLigatureAttributeName] = @(0);
    preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;

    NSMutableDictionary* preeditHighlightedAttrs = preeditAttrs.mutableCopy;
    preeditHighlightedAttrs[NSForegroundColorAttributeName] =
        NSColor.selectedTextColor;

    NSMutableDictionary* pagingAttrs = [[NSMutableDictionary alloc] init];
    pagingAttrs[NSFontAttributeName] = monoDigitFont;
    pagingAttrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;

    NSMutableDictionary* pagingHighlightedAttrs = pagingAttrs.mutableCopy;
    pagingHighlightedAttrs[NSForegroundColorAttributeName] =
        NSColor.selectedMenuItemTextColor;

    NSMutableDictionary* statusAttrs = commentAttrs.mutableCopy;
    statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

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

    _paragraphStyle = paragraphStyle;
    _preeditParagraphStyle = preeditParagraphStyle;
    _pagingParagraphStyle = pagingParagraphStyle;
    _statusParagraphStyle = statusParagraphStyle;

    _selectKeys = @"12345";
    _labels = @[ @"１", @"２", @"３", @"４", @"５" ];
    _pageSize = 5;
    _candidateFormat = kDefaultCandidateFormat;
    [self updateCandidateFormats];
    [self updateSeperatorAndSymbolAttrs];
  }
  return self;
}

- (void)setBackColor:(NSColor*)backColor
    highlightedCandidateBackColor:(NSColor*)highlightedCandidateBackColor
      highlightedPreeditBackColor:(NSColor*)highlightedPreeditBackColor
                 preeditBackColor:(NSColor*)preeditBackColor
                      borderColor:(NSColor*)borderColor
                        backImage:(NSImage*)backImage {
  _backColor = backColor;
  _highlightedCandidateBackColor = highlightedCandidateBackColor;
  _highlightedPreeditBackColor = highlightedPreeditBackColor;
  _preeditBackColor = preeditBackColor;
  _borderColor = borderColor;
  _backImage = backImage;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
    highlightedCornerRadius:(CGFloat)highlightedCornerRadius
             separatorWidth:(CGFloat)separatorWidth
                  linespace:(CGFloat)linespace
           preeditLinespace:(CGFloat)preeditLinespace
                      alpha:(CGFloat)alpha
               translucency:(CGFloat)translucency
                 lineLength:(CGFloat)lineLength
                borderInset:(NSSize)borderInset
                 showPaging:(BOOL)showPaging
               rememberSize:(BOOL)rememberSize
                    tabular:(BOOL)tabular
                     linear:(BOOL)linear
                   vertical:(BOOL)vertical
              inlinePreedit:(BOOL)inlinePreedit
            inlineCandidate:(BOOL)inlineCandidate {
  _cornerRadius = cornerRadius;
  _highlightedCornerRadius = highlightedCornerRadius;
  _separatorWidth = separatorWidth;
  _linespace = linespace;
  _preeditLinespace = preeditLinespace;
  _alpha = alpha;
  _translucency = translucency;
  _lineLength = lineLength;
  _borderInset = borderInset;
  _showPaging = showPaging;
  _rememberSize = rememberSize;
  _tabular = tabular;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit;
  _inlineCandidate = inlineCandidate;
}

- (void)setAttrs:(NSDictionary*)attrs
           highlightedAttrs:(NSDictionary*)highlightedAttrs
                 labelAttrs:(NSDictionary*)labelAttrs
      labelHighlightedAttrs:(NSDictionary*)labelHighlightedAttrs
               commentAttrs:(NSDictionary*)commentAttrs
    commentHighlightedAttrs:(NSDictionary*)commentHighlightedAttrs
               preeditAttrs:(NSDictionary*)preeditAttrs
    preeditHighlightedAttrs:(NSDictionary*)preeditHighlightedAttrs
                pagingAttrs:(NSDictionary*)pagingAttrs
     pagingHighlightedAttrs:(NSDictionary*)pagingHighlightedAttrs
                statusAttrs:(NSDictionary*)statusAttrs {
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
}

- (void)updateSeperatorAndSymbolAttrs {
  NSMutableDictionary* sepAttrs = _commentAttrs.mutableCopy;
  sepAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  sepAttrs[NSKernAttributeName] = @(0.0);
  _separator = [[NSAttributedString alloc]
      initWithString:_linear ? (_tabular ? [kFullWidthSpace
                                               stringByAppendingString:@"\t"]
                                         : kFullWidthSpace)
                             : @"\n"
          attributes:sepAttrs];

  // Symbols for function buttons
  NSString* attmCharacter =
      [NSString stringWithCharacters:(unichar[1]){NSAttachmentCharacter}
                              length:1];

  NSTextAttachment* attmDeleteFill = [[NSTextAttachment alloc] init];
  attmDeleteFill.image = [NSImage imageNamed:@"Symbols/delete.backward.fill"];
  NSMutableDictionary* attrsDeleteFill = _preeditAttrs.mutableCopy;
  attrsDeleteFill[NSAttachmentAttributeName] = attmDeleteFill;
  attrsDeleteFill[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteFill =
      [[NSAttributedString alloc] initWithString:attmCharacter
                                      attributes:attrsDeleteFill];

  NSTextAttachment* attmDeleteStroke = [[NSTextAttachment alloc] init];
  attmDeleteStroke.image = [NSImage imageNamed:@"Symbols/delete.backward"];
  NSMutableDictionary* attrsDeleteStroke = _preeditAttrs.mutableCopy;
  attrsDeleteStroke[NSAttachmentAttributeName] = attmDeleteStroke;
  attrsDeleteStroke[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteStroke =
      [[NSAttributedString alloc] initWithString:attmCharacter
                                      attributes:attrsDeleteStroke];
  if (_tabular) {
    NSTextAttachment* attmCompress = [[NSTextAttachment alloc] init];
    attmCompress.image = [NSImage imageNamed:@"Symbols/chevron.up"];
    NSMutableDictionary* attrsCompress = _pagingAttrs.mutableCopy;
    attrsCompress[NSAttachmentAttributeName] = attmCompress;
    _symbolCompress = [[NSAttributedString alloc] initWithString:attmCharacter
                                                      attributes:attrsCompress];

    NSTextAttachment* attmExpand = [[NSTextAttachment alloc] init];
    attmExpand.image = [NSImage imageNamed:@"Symbols/chevron.down"];
    NSMutableDictionary* attrsExpand = _pagingAttrs.mutableCopy;
    attrsExpand[NSAttachmentAttributeName] = attmExpand;
    _symbolExpand = [[NSAttributedString alloc] initWithString:attmCharacter
                                                    attributes:attrsExpand];

    NSTextAttachment* attmLock = [[NSTextAttachment alloc] init];
    attmLock.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/lock%@.fill",
                                              _vertical ? @".vertical" : @""]];
    NSMutableDictionary* attrsLock = _pagingAttrs.mutableCopy;
    attrsLock[NSAttachmentAttributeName] = attmLock;
    _symbolLock = [[NSAttributedString alloc] initWithString:attmCharacter
                                                  attributes:attrsLock];

    _expanderWidth = fmax(
        fmax(ceil(_symbolCompress.size.width), ceil(_symbolExpand.size.width)),
        ceil(_symbolLock.size.width));
    NSMutableParagraphStyle* paragraphStyle = _paragraphStyle.mutableCopy;
    paragraphStyle.tailIndent = -_expanderWidth;
    _paragraphStyle = paragraphStyle;
  } else if (_showPaging) {
    NSTextAttachment* attmBackFill = [[NSTextAttachment alloc] init];
    attmBackFill.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle.fill",
                                              _linear ? @"up" : @"left"]];
    NSMutableDictionary* attrsBackFill = _pagingAttrs.mutableCopy;
    attrsBackFill[NSAttachmentAttributeName] = attmBackFill;
    _symbolBackFill = [[NSAttributedString alloc] initWithString:attmCharacter
                                                      attributes:attrsBackFill];

    NSTextAttachment* attmBackStroke = [[NSTextAttachment alloc] init];
    attmBackStroke.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle",
                                              _linear ? @"up" : @"left"]];
    NSMutableDictionary* attrsBackStroke = _pagingAttrs.mutableCopy;
    attrsBackStroke[NSAttachmentAttributeName] = attmBackStroke;
    _symbolBackStroke =
        [[NSAttributedString alloc] initWithString:attmCharacter
                                        attributes:attrsBackStroke];

    NSTextAttachment* attmForwardFill = [[NSTextAttachment alloc] init];
    attmForwardFill.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle.fill",
                                              _linear ? @"down" : @"right"]];
    NSMutableDictionary* attrsForwardFill = _pagingAttrs.mutableCopy;
    attrsForwardFill[NSAttachmentAttributeName] = attmForwardFill;
    _symbolForwardFill =
        [[NSAttributedString alloc] initWithString:attmCharacter
                                        attributes:attrsForwardFill];

    NSTextAttachment* attmForwardStroke = [[NSTextAttachment alloc] init];
    attmForwardStroke.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle",
                                              _linear ? @"down" : @"right"]];
    NSMutableDictionary* attrsForwardStroke = _pagingAttrs.mutableCopy;
    attrsForwardStroke[NSAttachmentAttributeName] = attmForwardStroke;
    _symbolForwardStroke =
        [[NSAttributedString alloc] initWithString:attmCharacter
                                        attributes:attrsForwardStroke];
  }
}

- (void)setParagraphStyle:(NSParagraphStyle*)paragraphStyle
    preeditParagraphStyle:(NSParagraphStyle*)preeditParagraphStyle
     pagingParagraphStyle:(NSParagraphStyle*)pagingParagraphStyle
     statusParagraphStyle:(NSParagraphStyle*)statusParagraphStyle {
  _paragraphStyle = paragraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
  _pagingParagraphStyle = pagingParagraphStyle;
  _statusParagraphStyle = statusParagraphStyle;
}

- (void)setSelectKeys:(NSString*)selectKeys
               labels:(NSArray<NSString*>*)labels
         directUpdate:(BOOL)update {
  _selectKeys = selectKeys;
  _labels = labels;
  _pageSize = labels.count;
  if (update && _candidateFormat) {
    [self updateCandidateFormats];
  }
}

- (void)setCandidateFormat:(NSString*)candidateFormat {
  _candidateFormat = candidateFormat;
  [self updateCandidateFormats];
  [self updateSeperatorAndSymbolAttrs];
}

- (void)updateCandidateFormats {
  // validate candidate format: must have enumerator '%c' before candidate '%@'
  NSMutableString* candidateFormat = _candidateFormat.mutableCopy;
  if (![candidateFormat containsString:@"%@"]) {
    [candidateFormat appendString:@"%@"];
  }
  NSRange labelRange = [candidateFormat rangeOfString:@"%c"
                                              options:NSLiteralSearch];
  if (labelRange.length == 0) {
    [candidateFormat insertString:@"%c" atIndex:0];
  }
  NSRange candidateRange = [candidateFormat rangeOfString:@"%@"
                                                  options:NSLiteralSearch];
  if (labelRange.location > candidateRange.location) {
    candidateFormat.string = kDefaultCandidateFormat;
  }

  NSMutableArray* labels = [_labels mutableCopy];
  NSRange enumRange = NSMakeRange(0, 0);
  NSCharacterSet* labelCharacters = [NSCharacterSet
      characterSetWithCharactersInString:[labels componentsJoinedByString:@""]];
  if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF10, 10)]
          isSupersetOfSet:labelCharacters]) {            // ０１..９
    if ([candidateFormat containsString:@"%c\u20E3"]) {  // 1︎⃣..9︎⃣0︎⃣
      enumRange = [candidateFormat rangeOfString:@"%c\u20E3"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S",
                             (const unichar[3]){[labels[i] characterAtIndex:0] -
                                                    0xFF10 + 0x0030,
                                                0xFE0E, 0x20E3}];
      }
    } else if ([candidateFormat containsString:@"%c\u20DD"]) {  // ①..⑨⓪
      enumRange = [candidateFormat rangeOfString:@"%c\u20DD"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[1]){
                                        [labels[i] characterAtIndex:0] == 0xFF10
                                            ? 0x24EA
                                            : [labels[i] characterAtIndex:0] -
                                                  0xFF11 + 0x2460}];
      }
    } else if ([candidateFormat containsString:@"(%c)"]) {  // ⑴..⑼⑽
      enumRange = [candidateFormat rangeOfString:@"(%c)"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[1]){
                                        [labels[i] characterAtIndex:0] == 0xFF10
                                            ? 0x247D
                                            : [labels[i] characterAtIndex:0] -
                                                  0xFF11 + 0x2474}];
      }
    } else if ([candidateFormat containsString:@"%c."]) {  // ⒈..⒐🄀
      enumRange = [candidateFormat rangeOfString:@"%c."];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[2]){
                                        [labels[i] characterAtIndex:0] == 0xFF10
                                            ? 0xD83C
                                            : [labels[i] characterAtIndex:0] -
                                                  0xFF11 + 0x2488,
                                        [labels[i] characterAtIndex:0] == 0xFF10
                                            ? 0xDD00
                                            : 0x0}];
      }
    } else if ([candidateFormat containsString:@"%c,"]) {  // 🄂..🄊🄁
      enumRange = [candidateFormat rangeOfString:@"%c,"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[2]){
                                        0xD83C, [labels[i] characterAtIndex:0] -
                                                    0xFF10 + 0xDD01}];
      }
    }
  } else if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF21, 26)]
                 isSupersetOfSet:labelCharacters]) {     // Ａ..Ｚ
    if ([candidateFormat containsString:@"%c\u20DD"]) {  // Ⓐ..Ⓩ
      enumRange = [candidateFormat rangeOfString:@"%c\u20DD"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S",
                             (const unichar[1]){[labels[i] characterAtIndex:0] -
                                                0xFF21 + 0x24B6}];
      }
    } else if ([candidateFormat containsString:@"(%c)"]) {  // 🄐..🄩
      enumRange = [candidateFormat rangeOfString:@"(%c)"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[2]){
                                        0xD83C, [labels[i] characterAtIndex:0] -
                                                    0xFF21 + 0xDD10}];
      }
    } else if ([candidateFormat containsString:@"%c\u20DE"]) {  // 🄰..🅉
      enumRange = [candidateFormat rangeOfString:@"%c\u20DE"];
      for (NSUInteger i = 0; i < labels.count; ++i) {
        labels[i] = [NSString
            stringWithFormat:@"%S", (const unichar[2]){
                                        0xD83C, [labels[i] characterAtIndex:0] -
                                                    0xFF21 + 0xDD30}];
      }
    }
  }
  if (enumRange.length > 0) {
    [candidateFormat replaceCharactersInRange:enumRange withString:@"%c"];
    _candidateFormat = candidateFormat.copy;
    _labels = labels.copy;
  }
  // make sure label font can render all label strings
  NSString* labelString = [labels componentsJoinedByString:@""];
  NSFont* labelFont = _labelAttrs[NSFontAttributeName];
  NSFont* substituteFont = CFBridgingRelease(
      CTFontCreateForString((CTFontRef)labelFont, (CFStringRef)labelString,
                            CFRangeMake(0, (CFIndex)labelString.length)));
  if ([substituteFont isNotEqualTo:labelFont]) {
    NSDictionary* monoDigitAttrs = @{
      NSFontFeatureSettingsAttribute : @[
        @{
          NSFontFeatureTypeIdentifierKey : @(kNumberSpacingType),
          NSFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
        },
        @{
          NSFontFeatureTypeIdentifierKey : @(kTextSpacingType),
          NSFontFeatureSelectorIdentifierKey : @(kHalfWidthTextSelector)
        }
      ]
    };
    NSFontDescriptor* substituteFontDescriptor = [substituteFont.fontDescriptor
        fontDescriptorByAddingAttributes:monoDigitAttrs];
    substituteFont = [NSFont fontWithDescriptor:substituteFontDescriptor
                                           size:labelFont.pointSize];
    NSMutableDictionary* labelAttrs = _labelAttrs.mutableCopy;
    NSMutableDictionary* labelHighlightedAttrs =
        _labelHighlightedAttrs.mutableCopy;
    labelAttrs[NSFontAttributeName] = substituteFont;
    labelHighlightedAttrs[NSFontAttributeName] = substituteFont;
    _labelAttrs = labelAttrs;
    _labelHighlightedAttrs = labelHighlightedAttrs;
    if (_linear) {
      NSMutableDictionary* pagingAttrs = _pagingAttrs.mutableCopy;
      NSMutableDictionary* pagingHighlightAttrs =
          _pagingHighlightedAttrs.mutableCopy;
      pagingAttrs[NSFontAttributeName] = substituteFont;
      pagingHighlightAttrs[NSFontAttributeName] = substituteFont;
      _pagingAttrs = pagingAttrs;
      _pagingHighlightedAttrs = pagingHighlightAttrs;
    }
  }

  candidateRange = [candidateFormat rangeOfString:@"%@"
                                          options:NSLiteralSearch];
  labelRange = NSMakeRange(0, candidateRange.location);
  NSRange commentRange =
      NSMakeRange(NSMaxRange(candidateRange),
                  candidateFormat.length - NSMaxRange(candidateRange));
  // parse markdown formats
  NSMutableAttributedString* format =
      [[NSMutableAttributedString alloc] initWithString:candidateFormat];
  NSMutableAttributedString* highlightedFormat = format.mutableCopy;
  [format addAttributes:_labelAttrs range:labelRange];
  [highlightedFormat addAttributes:_labelHighlightedAttrs range:labelRange];
  [format addAttributes:_attrs range:candidateRange];
  [highlightedFormat addAttributes:_highlightedAttrs range:candidateRange];
  if (commentRange.length > 0) {
    [format addAttributes:_commentAttrs range:commentRange];
    [highlightedFormat addAttributes:_commentHighlightedAttrs
                               range:commentRange];
  }
  [format formatMarkDown];
  [highlightedFormat formatMarkDown];
  // add placeholder for comment '%s'
  candidateRange = [format.mutableString rangeOfString:@"%@"
                                               options:NSLiteralSearch];
  commentRange = NSMakeRange(NSMaxRange(candidateRange),
                             format.length - NSMaxRange(candidateRange));
  if (commentRange.length > 0) {
    [format
        replaceCharactersInRange:commentRange
                      withString:[kTipSpecifier
                                     stringByAppendingString:
                                         [format.mutableString
                                             substringWithRange:commentRange]]];
    [highlightedFormat
        replaceCharactersInRange:commentRange
                      withString:[kTipSpecifier
                                     stringByAppendingString:
                                         [highlightedFormat.mutableString
                                             substringWithRange:commentRange]]];
  } else {
    [format appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:kTipSpecifier
                                           attributes:_commentAttrs]];
    [highlightedFormat
        appendAttributedString:[[NSAttributedString alloc]
                                   initWithString:kTipSpecifier
                                       attributes:_commentHighlightedAttrs]];
  }

  NSMutableArray* candidateFormats =
      [[NSMutableArray alloc] initWithCapacity:labels.count];
  NSMutableArray* candidateHighlightedFormats =
      [[NSMutableArray alloc] initWithCapacity:labels.count];
  enumRange = [format.mutableString rangeOfString:@"%c"
                                          options:NSLiteralSearch];
  for (NSString* label in labels) {
    NSMutableAttributedString* newFormat = format.mutableCopy;
    NSMutableAttributedString* newHighlightedFormat =
        highlightedFormat.mutableCopy;
    [newFormat replaceCharactersInRange:enumRange withString:label];
    [newHighlightedFormat replaceCharactersInRange:enumRange withString:label];
    [candidateFormats addObject:newFormat];
    [candidateHighlightedFormats addObject:newHighlightedFormat];
  }
  _candidateFormats = candidateFormats.copy;
  _candidateHighlightedFormats = candidateHighlightedFormats.copy;
}

- (void)setStatusMessageType:(NSString*)type {
  if ([type isEqualToString:@"long"]) {
    _statusMessageType = kStatusMessageTypeLong;
  } else if ([type isEqualToString:@"short"]) {
    _statusMessageType = kStatusMessageTypeShort;
  } else {
    _statusMessageType = kStatusMessageTypeMixed;
  }
}

- (void)setAnnotationHeight:(CGFloat)height {
  if (height > 0.1 && _linespace < height * 2) {
    _linespace = height * 2;
    NSMutableParagraphStyle* paragraphStyle = _paragraphStyle.mutableCopy;
    paragraphStyle.paragraphSpacingBefore = height;
    paragraphStyle.paragraphSpacing = height;
    _paragraphStyle = paragraphStyle;
  }
}

@end  // SquirrelTheme

#pragma mark - Typesetting extensions for TextKit 1 (Mac OSX 10.9 to MacOS 11)

@interface SquirrelLayoutManager : NSLayoutManager <NSLayoutManagerDelegate>
@end
@implementation SquirrelLayoutManager

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(NSPoint)origin {
  NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow
                                       actualGlyphRange:NULL];
  NSTextContainer* textContainer =
      [self textContainerForGlyphAtIndex:glyphsToShow.location
                          effectiveRange:NULL
                 withoutAdditionalLayout:YES];
  BOOL verticalOrientation = (BOOL)textContainer.layoutOrientation;
  CGContextRef context = NSGraphicsContext.currentContext.CGContext;
  CGContextResetClip(context);
  [self.textStorage
      enumerateAttributesInRange:charRange
                         options:
                             NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                      usingBlock:^(NSDictionary<NSAttributedStringKey,
                                                id>* _Nonnull attrs,
                                   NSRange range, BOOL* _Nonnull stop) {
                        NSRange glyphRange =
                            [self glyphRangeForCharacterRange:range
                                         actualCharacterRange:NULL];
                        NSRect lineRect = [self
                            lineFragmentRectForGlyphAtIndex:glyphRange.location
                                             effectiveRange:NULL
                                    withoutAdditionalLayout:YES];
                        CGContextSaveGState(context);
                        if (attrs[(id)kCTRubyAnnotationAttributeName]) {
                          CGContextScaleCTM(context, 1.0, -1.0);
                          NSUInteger glyphIndex = glyphRange.location;
                          CTLineRef line = CTLineCreateWithAttributedString(
                              (CFAttributedStringRef)[self.textStorage
                                  attributedSubstringFromRange:range]);
                          CFArrayRef runs = CTLineGetGlyphRuns(
                              (CTLineRef)CFAutorelease(line));
                          for (CFIndex i = 0; i < CFArrayGetCount(runs); ++i) {
                            CGPoint position =
                                [self locationForGlyphAtIndex:glyphIndex];
                            CTRunRef run =
                                (CTRunRef)CFArrayGetValueAtIndex(runs, i);
                            CGAffineTransform matrix = CTRunGetTextMatrix(run);
                            CGPoint glyphOrigin = [textContainer.textView
                                convertPointToBacking:
                                    CGPointMake(origin.x + lineRect.origin.x +
                                                    position.x,
                                                -origin.y - lineRect.origin.y -
                                                    position.y)];
                            glyphOrigin = [textContainer.textView
                                convertPointFromBacking:CGPointMake(
                                                            round(
                                                                glyphOrigin.x),
                                                            round(glyphOrigin
                                                                      .y))];
                            matrix.tx = glyphOrigin.x;
                            matrix.ty = glyphOrigin.y;
                            CGContextSetTextMatrix(context, matrix);
                            CTRunDraw(run, context, CFRangeMake(0, 0));
                            glyphIndex += (NSUInteger)CTRunGetGlyphCount(run);
                          }
                        } else {
                          NSPoint position = [self
                              locationForGlyphAtIndex:glyphRange.location];
                          position.x += lineRect.origin.x;
                          position.y += lineRect.origin.y;
                          NSPoint backingPosition = [textContainer.textView
                              convertPointToBacking:position];
                          position = [textContainer.textView
                              convertPointFromBacking:
                                  NSMakePoint(round(backingPosition.x),
                                              round(backingPosition.y))];
                          NSFont* runFont = attrs[NSFontAttributeName];
                          NSString* baselineClass =
                              attrs[(id)kCTBaselineClassAttributeName];
                          NSPoint offset = origin;
                          if (!verticalOrientation &&
                              ([baselineClass
                                   isEqualToString:
                                       (id)kCTBaselineClassIdeographicCentered] ||
                               [baselineClass
                                   isEqualToString:(id)kCTBaselineClassMath])) {
                            NSFont* refFont =
                                attrs[(id)kCTBaselineReferenceInfoAttributeName]
                                     [(id)kCTBaselineReferenceFont];
                            offset.y += runFont.ascender * 0.5 +
                                        runFont.descender * 0.5 -
                                        refFont.ascender * 0.5 -
                                        refFont.descender * 0.5;
                          } else if (verticalOrientation &&
                                     runFont.pointSize < 24 &&
                                     [runFont.fontName
                                         isEqualToString:@"AppleColorEmoji"]) {
                            NSInteger superscript =
                                [attrs[NSSuperscriptAttributeName]
                                    integerValue];
                            offset.x += runFont.capHeight - runFont.pointSize;
                            offset.y +=
                                (runFont.capHeight - runFont.pointSize) *
                                (superscript == 0
                                     ? 0.25
                                     : (superscript == 1 ? 0.5 / 0.55 : 0.0));
                          }
                          NSPoint glyphOrigin = [textContainer.textView
                              convertPointToBacking:NSMakePoint(
                                                        position.x + offset.x,
                                                        position.y + offset.y)];
                          glyphOrigin = [textContainer.textView
                              convertPointFromBacking:NSMakePoint(
                                                          round(glyphOrigin.x),
                                                          round(
                                                              glyphOrigin.y))];
                          [super drawGlyphsForGlyphRange:glyphRange
                                                 atPoint:NSMakePoint(
                                                             glyphOrigin.x -
                                                                 position.x,
                                                             glyphOrigin.y -
                                                                 position.y)];
                        }
                        CGContextRestoreGState(context);
                      }];
  CGContextClipToRect(context, textContainer.textView.superview.bounds);
}

- (BOOL)layoutManager:(NSLayoutManager*)layoutManager
    shouldSetLineFragmentRect:(inout NSRect*)lineFragmentRect
         lineFragmentUsedRect:(inout NSRect*)lineFragmentUsedRect
               baselineOffset:(inout CGFloat*)baselineOffset
              inTextContainer:(NSTextContainer*)textContainer
                forGlyphRange:(NSRange)glyphRange {
  BOOL verticalOrientation = (BOOL)textContainer.layoutOrientation;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                actualGlyphRange:NULL];
  NSFont* refFont = [layoutManager.textStorage
           attribute:(id)kCTBaselineReferenceInfoAttributeName
             atIndex:charRange.location
      effectiveRange:NULL][(id)kCTBaselineReferenceFont];
  NSParagraphStyle* rulerAttrs =
      [layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                   atIndex:charRange.location
                            effectiveRange:NULL];
  CGFloat lineHeightDelta = lineFragmentUsedRect->size.height -
                            rulerAttrs.minimumLineHeight -
                            rulerAttrs.lineSpacing;
  if (fabs(lineHeightDelta) > 0.1) {
    lineFragmentUsedRect->size.height =
        round(lineFragmentUsedRect->size.height - lineHeightDelta);
    lineFragmentRect->size.height =
        round(lineFragmentRect->size.height - lineHeightDelta);
  }
  *baselineOffset = floor(
      lineFragmentUsedRect->origin.y - lineFragmentRect->origin.y +
      rulerAttrs.minimumLineHeight * 0.5 +
      (verticalOrientation ? 0.0
                           : refFont.ascender * 0.5 + refFont.descender * 0.5));
  return YES;
}

- (BOOL)layoutManager:(NSLayoutManager*)layoutManager
    shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex {
  return charIndex <= 1 || [layoutManager.textStorage.mutableString
                               characterAtIndex:charIndex - 1] != '\t';
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager*)layoutManager
                          shouldUseAction:(NSControlCharacterAction)action
               forControlCharacterAtIndex:(NSUInteger)charIndex {
  if ([layoutManager.textStorage.mutableString characterAtIndex:charIndex] ==
          0x8B &&
      [layoutManager.textStorage attribute:(id)kCTRubyAnnotationAttributeName
                                   atIndex:charIndex
                            effectiveRange:NULL]) {
    return NSControlCharacterActionWhitespace;
  } else {
    return action;
  }
}

- (NSRect)layoutManager:(NSLayoutManager*)layoutManager
    boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex
                     forTextContainer:(NSTextContainer*)textContainer
                 proposedLineFragment:(NSRect)proposedRect
                        glyphPosition:(NSPoint)glyphPosition
                       characterIndex:(NSUInteger)charIndex {
  CGFloat width = 0.0;
  if ([layoutManager.textStorage.mutableString characterAtIndex:charIndex] ==
      0x8B) {
    NSRange rubyRange;
    id rubyAnnotation =
        [layoutManager.textStorage attribute:(id)kCTRubyAnnotationAttributeName
                                     atIndex:charIndex
                              effectiveRange:&rubyRange];
    if (rubyAnnotation) {
      NSAttributedString* rubyString =
          [layoutManager.textStorage attributedSubstringFromRange:rubyRange];
      CTLineRef line =
          CTLineCreateWithAttributedString((CFAttributedStringRef)rubyString);
      CGRect rubyRect =
          CTLineGetBoundsWithOptions((CTLineRef)CFAutorelease(line), 0);
      NSSize baseSize = rubyString.size;
      width = fdim(rubyRect.size.width, baseSize.width);
    }
  }
  return NSMakeRect(glyphPosition.x, 0.0, width, glyphPosition.y);
}

@end  // SquirrelLayoutManager

#pragma mark - Typesetting extensions for TextKit 2 (MacOS 12 or higher)

API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutFragment : NSTextLayoutFragment
@end
@implementation SquirrelTextLayoutFragment

- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)context {
  if (@available(macOS 14.0, *)) {
  } else {  // in macOS 12 and 13, textLineFragments.typographicBouonds are in
            // textContainer coordinates
    point.x -= self.layoutFragmentFrame.origin.x;
    point.y -= self.layoutFragmentFrame.origin.y;
  }
  BOOL verticalOrientation =
      (BOOL)self.textLayoutManager.textContainer.layoutOrientation;
  for (NSTextLineFragment* lineFrag in self.textLineFragments) {
    CGRect lineRect =
        CGRectOffset(lineFrag.typographicBounds, point.x, point.y);
    CGFloat baseline = NSMidY(lineRect);
    if (!verticalOrientation) {
      NSFont* refFont = [lineFrag.attributedString
               attribute:(id)kCTBaselineReferenceInfoAttributeName
                 atIndex:lineFrag.characterRange.location
          effectiveRange:NULL][(id)kCTBaselineReferenceFont];
      baseline += refFont.ascender * 0.5 + refFont.descender * 0.5;
    }
    CGPoint renderOrigin =
        CGPointMake(NSMinX(lineRect) + lineFrag.glyphOrigin.x,
                    floor(baseline) - lineFrag.glyphOrigin.y);
    CGPoint deviceOrigin =
        CGContextConvertPointToDeviceSpace(context, renderOrigin);
    renderOrigin = CGContextConvertPointToUserSpace(
        context, CGPointMake(round(deviceOrigin.x), round(deviceOrigin.y)));
    [lineFrag drawAtPoint:renderOrigin inContext:context];
  }
}

@end  // SquirrelTextLayoutFragment

API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutManager
    : NSTextLayoutManager <NSTextLayoutManagerDelegate>
@end
@implementation SquirrelTextLayoutManager

- (BOOL)textLayoutManager:(NSTextLayoutManager*)textLayoutManager
    shouldBreakLineBeforeLocation:(id<NSTextLocation>)location
                      hyphenating:(BOOL)hyphenating {
  NSTextContentStorage* contentStorage =
      textLayoutManager.textContainer.textView.textContentStorage;
  NSInteger charIndex =
      [contentStorage offsetFromLocation:contentStorage.documentRange.location
                              toLocation:location];
  return charIndex <= 1 ||
         [contentStorage.textStorage.mutableString
             characterAtIndex:(NSUInteger)charIndex - 1] != '\t';
}

- (NSTextLayoutFragment*)textLayoutManager:
                             (NSTextLayoutManager*)textLayoutManager
             textLayoutFragmentForLocation:(id<NSTextLocation>)location
                             inTextElement:(NSTextElement*)textElement {
  NSTextRange* textRange = [[NSTextRange alloc]
      initWithLocation:location
           endLocation:textElement.elementRange.endLocation];
  return [[SquirrelTextLayoutFragment alloc] initWithTextElement:textElement
                                                           range:textRange];
}

@end  // SquirrelTextLayoutManager

#pragma mark - View behind text, containing drawings of backgrounds and highlights

@interface SquirrelView : NSView

typedef struct {
  NSUInteger index;
  NSUInteger lineNum;
  NSUInteger tabNum;
} SquirrelTabularIndex;

@property(nonatomic, readonly, strong, nonnull) NSTextView* textView;
@property(nonatomic, readonly, strong, nonnull) NSTextStorage* textStorage;
@property(nonatomic, readonly, strong, nonnull) CAShapeLayer* shape;
@property(nonatomic, readonly, nullable) SquirrelTabularIndex* tabularIndices;
@property(nonatomic, readonly, nullable) NSRectArray candidateRects;
@property(nonatomic, readonly, nullable) NSRectArray sectionRects;
@property(nonatomic, readonly) NSRect contentRect;
@property(nonatomic, readonly) NSRect preeditBlock;
@property(nonatomic, readonly) NSRect candidateBlock;
@property(nonatomic, readonly) NSRect pagingBlock;
@property(nonatomic, readonly) NSRect deleteBackRect;
@property(nonatomic, readonly) NSRect expanderRect;
@property(nonatomic, readonly) NSRect pageUpRect;
@property(nonatomic, readonly) NSRect pageDownRect;
@property(nonatomic, readonly) SquirrelAppear appear;
@property(nonatomic, readonly) SquirrelIndex functionButton;
@property(nonatomic, readonly) NSEdgeInsets alignmentRectInsets;
@property(nonatomic, readonly) NSUInteger numCandidates;
@property(nonatomic, readonly) NSUInteger highlightedIndex;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange highlightedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, nullable) NSRange* candidateRanges;
@property(nonatomic, nullable) BOOL* truncated;
@property(nonatomic) BOOL expanded;

- (NSTextRange* _Nullable)getTextRangeFromCharRange:(NSRange)charRange
    API_AVAILABLE(macos(12.0));

- (NSRange)getCharRangeFromTextRange:(NSTextRange* _Nullable)textRange
    API_AVAILABLE(macos(12.0));

- (NSRect)blockRectForRange:(NSRange)range;

- (void)multilineRectForRange:(NSRange)charRange
                  leadingRect:(NSRectPointer _Nonnull)leadingRect
                     bodyRect:(NSRectPointer _Nonnull)bodyRect
                 trailingRect:(NSRectPointer _Nonnull)trailingRect;

- (void)drawViewWithInsets:(NSEdgeInsets)alignmentRectInsets
              numCandidates:(NSUInteger)numCandidates
           highlightedIndex:(NSUInteger)highlightedIndex
               preeditRange:(NSRange)preeditRange
    highlightedPreeditRange:(NSRange)highlightedPreeditRange
                pagingRange:(NSRange)pagingRange;

- (void)setPreeditRange:(NSRange)preeditRange
       highlightedRange:(NSRange)highlightedRange;

- (void)highlightCandidate:(NSUInteger)highlightedIndex;

- (void)highlightFunctionButton:(SquirrelIndex)functionButton;

- (SquirrelIndex)getIndexFromMouseSpot:(NSPoint)spot;

@end
@implementation SquirrelView

// Need flipped coordinate system, as required by textStorage
- (BOOL)isFlipped {
  return YES;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (SquirrelAppear)appear {
  if (@available(macOS 10.14, *)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    NSAppearance* effectiveAppearance =
        [((SquirrelPanel*)self.window).inputController.client
            performSelector:@selector(viewEffectiveAppearance)]
            ?: NSApp.effectiveAppearance;
#pragma clang diagnostic pop
    if ([effectiveAppearance bestMatchFromAppearancesWithNames:@[
          NSAppearanceNameAqua, NSAppearanceNameDarkAqua
        ]] == NSAppearanceNameDarkAqua) {
      return darkAppear;
    }
  }
  return defaultAppear;
}

- (SquirrelTheme*)selectTheme:(SquirrelAppear)appear {
  static SquirrelTheme* defaultTheme = [[SquirrelTheme alloc] init];
  if (@available(macOS 10.14, *)) {
    static SquirrelTheme* darkTheme = [[SquirrelTheme alloc] init];
    return appear == darkAppear ? darkTheme : defaultTheme;
  } else {
    return defaultTheme;
  }
}

- (SquirrelTheme*)currentTheme {
  return [self selectTheme:self.appear];
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.geometryFlipped = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;

    if (@available(macOS 12.0, *)) {
      SquirrelTextLayoutManager* textLayoutManager =
          [[SquirrelTextLayoutManager alloc] init];
      textLayoutManager.usesFontLeading = NO;
      textLayoutManager.usesHyphenation = NO;
      textLayoutManager.delegate = textLayoutManager;
      NSTextContainer* textContainer =
          [[NSTextContainer alloc] initWithSize:NSZeroSize];
      textContainer.lineFragmentPadding = 0;
      textLayoutManager.textContainer = textContainer;
      NSTextContentStorage* contentStorage =
          [[NSTextContentStorage alloc] init];
      [contentStorage addTextLayoutManager:textLayoutManager];
      _textView = [[NSTextView alloc] initWithFrame:frameRect
                                      textContainer:textContainer];
      _textStorage = _textView.textContentStorage.textStorage;
    } else {
      SquirrelLayoutManager* layoutManager =
          [[SquirrelLayoutManager alloc] init];
      layoutManager.backgroundLayoutEnabled = YES;
      layoutManager.usesFontLeading = NO;
      layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
      layoutManager.delegate = layoutManager;
      NSTextContainer* textContainer =
          [[NSTextContainer alloc] initWithContainerSize:NSZeroSize];
      textContainer.lineFragmentPadding = 0;
      [layoutManager addTextContainer:textContainer];
      _textStorage = [[NSTextStorage alloc] init];
      [_textStorage addLayoutManager:layoutManager];
      _textView = [[NSTextView alloc] initWithFrame:frameRect
                                      textContainer:textContainer];
    }
    _textView.drawsBackground = NO;
    _textView.selectable = NO;
    _textView.wantsLayer = YES;

    _shape = [[CAShapeLayer alloc] init];
  }
  return self;
}

- (NSTextRange*)getTextRangeFromCharRange:(NSRange)charRange
    API_AVAILABLE(macos(12.0)) {
  if (charRange.location == NSNotFound) {
    return nil;
  } else {
    NSTextContentStorage* contentStorage = _textView.textContentStorage;
    id<NSTextLocation> startLocation = [contentStorage
        locationFromLocation:contentStorage.documentRange.location
                  withOffset:(NSInteger)charRange.location];
    id<NSTextLocation> endLocation =
        [contentStorage locationFromLocation:startLocation
                                  withOffset:(NSInteger)charRange.length];
    return [[NSTextRange alloc] initWithLocation:startLocation
                                     endLocation:endLocation];
  }
}

- (NSRange)getCharRangeFromTextRange:(NSTextRange*)textRange
    API_AVAILABLE(macos(12.0)) {
  if (textRange == nil) {
    return NSMakeRange(NSNotFound, 0);
  } else {
    NSTextContentStorage* contentStorage = _textView.textContentStorage;
    NSInteger location =
        [contentStorage offsetFromLocation:contentStorage.documentRange.location
                                toLocation:textRange.location];
    NSInteger length =
        [contentStorage offsetFromLocation:textRange.location
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

// Get the rectangle containing the range of text, will first convert to glyph
// or text range, expensive to calculate
- (NSRect)blockRectForRange:(NSRange)range {
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [self getTextRangeFromCharRange:range];
    NSRect __block blockRect = NSZeroRect;
    [_textView.textLayoutManager
        enumerateTextSegmentsInRange:textRange
                                type:NSTextLayoutManagerSegmentTypeStandard
                             options:
                                 NSTextLayoutManagerSegmentOptionsRangeNotRequired
                          usingBlock:^BOOL(
                              NSTextRange* _Nullable segRange, CGRect segFrame,
                              CGFloat baseline,
                              NSTextContainer* _Nonnull textContainer) {
                            blockRect = NSUnionRect(blockRect, segFrame);
                            return YES;
                          }];
    return blockRect;
  } else {
    NSTextContainer* textContainer = _textView.textContainer;
    NSLayoutManager* layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:range
                                               actualCharacterRange:NULL];
    NSRange firstLineRange = NSMakeRange(NSNotFound, 0);
    NSRect firstLineRect =
        [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                            effectiveRange:&firstLineRange];
    if (NSMaxRange(glyphRange) <= NSMaxRange(firstLineRange)) {
      CGFloat headX =
          [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
      CGFloat tailX =
          NSMaxRange(glyphRange) < NSMaxRange(firstLineRange)
              ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
              : NSWidth(firstLineRect);
      return NSMakeRect(NSMinX(firstLineRect) + headX, NSMinY(firstLineRect),
                        tailX - headX, NSHeight(firstLineRect));
    } else {
      NSRect finalLineRect = [layoutManager
          lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                               effectiveRange:NULL];
      return NSMakeRect(NSMinX(firstLineRect), NSMinY(firstLineRect),
                        textContainer.size.width,
                        NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    }
  }
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect
// are incomplete line rectangle bodyRect is the complete line fragment in the
// middle if the range spans no less than one full line
- (void)multilineRectForRange:(NSRange)charRange
                  leadingRect:(NSRectPointer)leadingRect
                     bodyRect:(NSRectPointer)bodyRect
                 trailingRect:(NSRectPointer)trailingRect {
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [self getTextRangeFromCharRange:charRange];
    NSRect __block leadingLineRect = NSZeroRect;
    NSRect __block trailingLineRect = NSZeroRect;
    NSTextRange __block* leadingLineRange;
    NSTextRange __block* trailingLineRange;
    [_textView.textLayoutManager
        enumerateTextSegmentsInRange:textRange
                                type:NSTextLayoutManagerSegmentTypeStandard
                             options:
                                 NSTextLayoutManagerSegmentOptionsMiddleFragmentsExcluded
                          usingBlock:^BOOL(
                              NSTextRange* _Nullable segRange, CGRect segFrame,
                              CGFloat baseline,
                              NSTextContainer* _Nonnull textContainer) {
                            if (!NSIsEmptyRect(segFrame)) {
                              if (NSIsEmptyRect(leadingLineRect) ||
                                  NSMinY(segFrame) < NSMaxY(leadingLineRect)) {
                                leadingLineRect =
                                    NSUnionRect(segFrame, leadingLineRect);
                                leadingLineRange = [leadingLineRange
                                    textRangeByFormingUnionWithTextRange:
                                        segRange];
                              } else {
                                trailingLineRect =
                                    NSUnionRect(segFrame, trailingLineRect);
                                trailingLineRange = [trailingLineRange
                                    textRangeByFormingUnionWithTextRange:
                                        segRange];
                              }
                            }
                            return YES;
                          }];
    if (NSIsEmptyRect(trailingLineRect)) {
      *bodyRect = leadingLineRect;
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
      leadingLineRect.size.width = containerWidth - NSMinX(leadingLineRect);
      if (NSMaxX(trailingLineRect) == NSMaxX(leadingLineRect)) {
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect = NSUnionRect(leadingLineRect, trailingLineRect);
        } else {
          *leadingRect = leadingLineRect;
          *bodyRect =
              NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = trailingLineRect;
        if (NSMinX(leadingLineRect) == NSMinX(trailingLineRect)) {
          *bodyRect =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect = leadingLineRect;
          if (![trailingLineRange
                  containsLocation:leadingLineRange.endLocation]) {
            *bodyRect =
                NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                           NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
    }
  } else {
    NSLayoutManager* layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
                                               actualCharacterRange:NULL];
    NSRange leadingLineRange = NSMakeRange(NSNotFound, 0);
    NSRect leadingLineRect =
        [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphRange.location
                                            effectiveRange:&leadingLineRange];
    CGFloat headX =
        [layoutManager locationForGlyphAtIndex:glyphRange.location].x;
    if (NSMaxRange(leadingLineRange) >= NSMaxRange(glyphRange)) {
      CGFloat tailX =
          NSMaxRange(glyphRange) < NSMaxRange(leadingLineRange)
              ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
              : NSWidth(leadingLineRect);
      *bodyRect = NSMakeRect(headX, NSMinY(leadingLineRect), tailX - headX,
                             NSHeight(leadingLineRect));
    } else {
      CGFloat containerWidth = self.contentRect.size.width;
      NSRange trailingLineRange = NSMakeRange(NSNotFound, 0);
      NSRect trailingLineRect = [layoutManager
          lineFragmentUsedRectForGlyphAtIndex:NSMaxRange(glyphRange) - 1
                               effectiveRange:&trailingLineRange];
      CGFloat tailX =
          NSMaxRange(glyphRange) < NSMaxRange(trailingLineRange)
              ? [layoutManager locationForGlyphAtIndex:NSMaxRange(glyphRange)].x
              : NSWidth(trailingLineRect);
      if (NSMaxRange(trailingLineRange) == NSMaxRange(glyphRange)) {
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect =
              NSMakeRect(headX, NSMinY(leadingLineRect), containerWidth - headX,
                         NSHeight(leadingLineRect));
          *bodyRect =
              NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        *trailingRect = NSMakeRect(0.0, NSMinY(trailingLineRect), tailX,
                                   NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          *bodyRect =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          *leadingRect =
              NSMakeRect(headX, NSMinY(leadingLineRect), containerWidth - headX,
                         NSHeight(leadingLineRect));
          if (trailingLineRange.location > NSMaxRange(leadingLineRange)) {
            *bodyRect =
                NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                           NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
    }
  }
}

// Will triger - (void)updateLayer
- (void)drawViewWithInsets:(NSEdgeInsets)alignmentRectInsets
              numCandidates:(NSUInteger)numCandidates
           highlightedIndex:(NSUInteger)highlightedIndex
               preeditRange:(NSRange)preeditRange
    highlightedPreeditRange:(NSRange)highlightedPreeditRange
                pagingRange:(NSRange)pagingRange {
  _alignmentRectInsets = alignmentRectInsets;
  _numCandidates = numCandidates;
  _highlightedIndex = highlightedIndex;
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedPreeditRange;
  _pagingRange = pagingRange;
  _functionButton = kVoidSymbol;
  // invalidate Rect beyond bound of textview to clear any out-of-bound drawing
  // from last round
  self.needsDisplayInRect = self.bounds;
  _textView.needsDisplayInRect = self.bounds;
}

- (void)setPreeditRange:(NSRange)preeditRange
       highlightedRange:(NSRange)highlightedRange {
  if (_preeditRange.length != preeditRange.length) {
    for (NSUInteger i = 0; i < _numCandidates; ++i) {
      _candidateRanges[i].location +=
          preeditRange.length - _preeditRange.length;
    }
    if (_pagingRange.location != NSNotFound) {
      _pagingRange.location += preeditRange.length - _preeditRange.length;
    }
  }
  _preeditRange = preeditRange;
  _highlightedPreeditRange = highlightedRange;
  self.needsDisplayInRect = _preeditBlock;
  _textView.needsDisplayInRect = _preeditBlock;
  NSRect mirrorPreeditBlock = NSOffsetRect(
      _preeditBlock, 0, NSHeight(self.bounds) - NSHeight(_preeditBlock) * 2);
  self.needsDisplayInRect = mirrorPreeditBlock;
  _textView.needsDisplayInRect = mirrorPreeditBlock;
}

- (void)highlightCandidate:(NSUInteger)highlightedIndex {
  if (_expanded) {
    NSUInteger prevActivePage = _highlightedIndex / self.currentTheme.pageSize;
    NSUInteger newActivePage = highlightedIndex / self.currentTheme.pageSize;
    if (newActivePage != prevActivePage) {
      self.needsDisplayInRect = _sectionRects[prevActivePage];
      _textView.needsDisplayInRect = _sectionRects[prevActivePage];
    }
    self.needsDisplayInRect = _sectionRects[newActivePage];
    _textView.needsDisplayInRect = _sectionRects[newActivePage];
  } else {
    self.needsDisplayInRect = _candidateBlock;
    _textView.needsDisplayInRect = _candidateBlock;
  }
  _highlightedIndex = highlightedIndex;
}

- (void)highlightFunctionButton:(SquirrelIndex)functionButton {
  for (SquirrelIndex index :
       (SquirrelIndex[2]){_functionButton, functionButton}) {
    switch (index) {
      case kPageUpKey:
      case kHomeKey:
        self.needsDisplayInRect = _pageUpRect;
        _textView.needsDisplayInRect = _pageUpRect;
        break;
      case kPageDownKey:
      case kEndKey:
        self.needsDisplayInRect = _pageDownRect;
        _textView.needsDisplayInRect = _pageDownRect;
        break;
      case kBackSpaceKey:
      case kEscapeKey:
        self.needsDisplayInRect = _deleteBackRect;
        _textView.needsDisplayInRect = _deleteBackRect;
        break;
      case kExpandButton:
      case kCompressButton:
      case kLockButton:
        self.needsDisplayInRect = _expanderRect;
        _textView.needsDisplayInRect = _expanderRect;
        break;
    }
  }
  _functionButton = functionButton;
}

// Bezier cubic curve, which has continuous roundness
static NSBezierPath* squirclePath(NSPointArray vertices,
                                  NSInteger numVert,
                                  CGFloat radius) {
  if (vertices == NULL) {
    return nil;
  }
  NSBezierPath* path = NSBezierPath.bezierPath;
  NSPoint point = vertices[numVert - 1];
  NSPoint nextPoint = vertices[0];
  NSPoint startPoint;
  NSPoint endPoint;
  NSPoint controlPoint1;
  NSPoint controlPoint2;
  CGFloat arcRadius;
  CGVector nextDiff =
      CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
  CGVector lastDiff;
  if (fabs(nextDiff.dx) >= fabs(nextDiff.dy)) {
    endPoint = NSMakePoint(point.x + nextDiff.dx * 0.5, nextPoint.y);
  } else {
    endPoint = NSMakePoint(nextPoint.x, point.y + nextDiff.dy * 0.5);
  }
  [path moveToPoint:endPoint];
  for (NSInteger i = 0; i < numVert; ++i) {
    lastDiff = nextDiff;
    point = nextPoint;
    nextPoint = vertices[(i + 1) % numVert];
    nextDiff = CGVectorMake(nextPoint.x - point.x, nextPoint.y - point.y);
    if (fabs(nextDiff.dx) >= fabs(nextDiff.dy)) {
      arcRadius =
          fmin(radius, fmin(fabs(nextDiff.dx), fabs(lastDiff.dy)) * 0.5);
      point.y = nextPoint.y;
      startPoint =
          NSMakePoint(point.x, point.y - copysign(arcRadius, lastDiff.dy));
      controlPoint1 = NSMakePoint(
          point.x, point.y - copysign(arcRadius * 0.3, lastDiff.dy));
      endPoint =
          NSMakePoint(point.x + copysign(arcRadius, nextDiff.dx), nextPoint.y);
      controlPoint2 = NSMakePoint(
          point.x + copysign(arcRadius * 0.3, nextDiff.dx), nextPoint.y);
    } else {
      arcRadius =
          fmin(radius, fmin(fabs(nextDiff.dy), fabs(lastDiff.dx)) * 0.5);
      point.x = nextPoint.x;
      startPoint =
          NSMakePoint(point.x - copysign(arcRadius, lastDiff.dx), point.y);
      controlPoint1 = NSMakePoint(
          point.x - copysign(arcRadius * 0.3, lastDiff.dx), point.y);
      endPoint =
          NSMakePoint(nextPoint.x, point.y + copysign(arcRadius, nextDiff.dy));
      controlPoint2 = NSMakePoint(
          nextPoint.x, point.y + copysign(arcRadius * 0.3, nextDiff.dy));
    }
    [path lineToPoint:startPoint];
    [path curveToPoint:endPoint
         controlPoint1:controlPoint1
         controlPoint2:controlPoint2];
  }
  [path closePath];
  return path;
}

static void rectVertices(NSRect rect, NSPointArray vertices) {
  vertices[0] = rect.origin;
  vertices[1] = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height);
  vertices[2] = NSMakePoint(rect.origin.x + rect.size.width,
                            rect.origin.y + rect.size.height);
  vertices[3] = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y);
}

static void multilineRectVertices(NSRect leadingRect,
                                  NSRect bodyRect,
                                  NSRect trailingRect,
                                  NSPointArray vertices) {
  switch ((NSIsEmptyRect(leadingRect) << 2) + (NSIsEmptyRect(bodyRect) << 1) +
          (NSIsEmptyRect(trailingRect) << 0)) {
    case 0b011:
      rectVertices(leadingRect, vertices);
      break;
    case 0b110:
      rectVertices(trailingRect, vertices);
      break;
    case 0b101:
      rectVertices(bodyRect, vertices);
      break;
    case 0b001: {
      NSPoint leadingVertices[4], bodyVertices[4];
      rectVertices(leadingRect, leadingVertices);
      rectVertices(bodyRect, bodyVertices);
      vertices[0] = leadingVertices[0];
      vertices[1] = leadingVertices[1];
      vertices[2] = bodyVertices[0];
      vertices[3] = bodyVertices[1];
      vertices[4] = bodyVertices[2];
      vertices[5] = leadingVertices[3];
    } break;
    case 0b100: {
      NSPoint bodyVertices[4], trailingVertices[4];
      rectVertices(bodyRect, bodyVertices);
      rectVertices(trailingRect, trailingVertices);
      vertices[0] = bodyVertices[0];
      vertices[1] = trailingVertices[1];
      vertices[2] = trailingVertices[2];
      vertices[3] = trailingVertices[3];
      vertices[4] = bodyVertices[2];
      vertices[5] = bodyVertices[3];
    } break;
    case 0b010:
      if (NSMinX(leadingRect) <= NSMaxX(trailingRect)) {
        NSPoint leadingVertices[4], trailingVertices[4];
        rectVertices(leadingRect, leadingVertices);
        rectVertices(trailingRect, trailingVertices);
        vertices[0] = leadingVertices[0];
        vertices[1] = leadingVertices[1];
        vertices[2] = trailingVertices[0];
        vertices[3] = trailingVertices[1];
        vertices[4] = trailingVertices[2];
        vertices[5] = trailingVertices[3];
        vertices[6] = leadingVertices[2];
        vertices[7] = leadingVertices[3];
      } else {
        vertices = NULL;
      }
      break;
    case 0b000: {
      NSPoint leadingVertices[4], bodyVertices[4], trailingVertices[4];
      rectVertices(leadingRect, leadingVertices);
      rectVertices(bodyRect, bodyVertices);
      rectVertices(trailingRect, trailingVertices);
      vertices[0] = leadingVertices[0];
      vertices[1] = leadingVertices[1];
      vertices[2] = bodyVertices[0];
      vertices[3] = trailingVertices[1];
      vertices[4] = trailingVertices[2];
      vertices[5] = trailingVertices[3];
      vertices[6] = bodyVertices[2];
      vertices[7] = leadingVertices[3];
    } break;
    default:
      vertices = NULL;
      break;
  }
}

static NSColor* hooverColor(NSColor* color, SquirrelAppear appear) {
  if (color == nil) {
    return nil;
  }
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectRollover];
  } else {
    return appear == darkAppear ? [color highlightWithLevel:0.3]
                                : [color shadowWithLevel:0.3];
  }
}

static NSColor* disabledColor(NSColor* color, SquirrelAppear appear) {
  if (color == nil) {
    return nil;
  }
  if (@available(macOS 10.14, *)) {
    return [color colorWithSystemEffect:NSColorSystemEffectDisabled];
  } else {
    return appear == darkAppear ? [color shadowWithLevel:0.3]
                                : [color highlightWithLevel:0.3];
  }
}

- (CAShapeLayer*)getFunctionButtonLayer {
  SquirrelTheme* theme = self.currentTheme;
  NSColor* buttonColor;
  NSRect buttonRect = NSZeroRect;
  switch (_functionButton) {
    case kPageUpKey:
      buttonColor = hooverColor(theme.linear && !theme.tabular
                                    ? theme.highlightedCandidateBackColor
                                    : theme.highlightedPreeditBackColor,
                                self.appear);
      buttonRect = _pageUpRect;
      break;
    case kHomeKey:
      buttonColor = disabledColor(theme.linear && !theme.tabular
                                      ? theme.highlightedCandidateBackColor
                                      : theme.highlightedPreeditBackColor,
                                  self.appear);
      buttonRect = _pageUpRect;
      break;
    case kPageDownKey:
      buttonColor = hooverColor(theme.linear && !theme.tabular
                                    ? theme.highlightedCandidateBackColor
                                    : theme.highlightedPreeditBackColor,
                                self.appear);
      buttonRect = _pageDownRect;
      break;
    case kEndKey:
      buttonColor = disabledColor(theme.linear && !theme.tabular
                                      ? theme.highlightedCandidateBackColor
                                      : theme.highlightedPreeditBackColor,
                                  self.appear);
      buttonRect = _pageDownRect;
      break;
    case kExpandButton:
    case kCompressButton:
    case kLockButton:
      buttonColor = hooverColor(theme.highlightedPreeditBackColor, self.appear);
      buttonRect = _expanderRect;
      break;
    case kBackSpaceKey:
      buttonColor = hooverColor(theme.highlightedPreeditBackColor, self.appear);
      buttonRect = _deleteBackRect;
      break;
    case kEscapeKey:
      buttonColor =
          disabledColor(theme.highlightedPreeditBackColor, self.appear);
      buttonRect = _deleteBackRect;
      break;
    default:
      return nil;
      break;
  }
  if (!NSIsEmptyRect(buttonRect) && buttonColor) {
    CGFloat cornerRadius =
        fmin(theme.highlightedCornerRadius, NSHeight(buttonRect) * 0.5);
    NSPoint buttonVertices[4];
    rectVertices(buttonRect, buttonVertices);
    NSBezierPath* buttonPath = squirclePath(buttonVertices, 4, cornerRadius);
    CAShapeLayer* functionButtonLayer = [[CAShapeLayer alloc] init];
    functionButtonLayer.path = buttonPath.quartzPath;
    functionButtonLayer.fillColor = buttonColor.CGColor;
    return functionButtonLayer;
  }
  return nil;
}

// All draws happen here
- (void)updateLayer {
  SquirrelTheme* theme = self.currentTheme;
  NSRect panelRect = self.bounds;
  NSRect backgroundRect =
      [self backingAlignedRect:NSInsetRect(panelRect, theme.borderInset.width,
                                           theme.borderInset.height)
                       options:NSAlignAllEdgesNearest];
  CGFloat outerCornerRadius =
      fmin(theme.cornerRadius, NSHeight(panelRect) * 0.5);
  CGFloat innerCornerRadius =
      fmax(fmin(theme.highlightedCornerRadius, NSHeight(backgroundRect) * 0.5),
           outerCornerRadius -
               fmin(theme.borderInset.width, theme.borderInset.height));
  NSPoint panelVertices[4], backgroundVertices[4];
  rectVertices(panelRect, panelVertices);
  rectVertices(backgroundRect, backgroundVertices);
  NSBezierPath* panelPath = squirclePath(panelVertices, 4, outerCornerRadius);
  NSBezierPath* backgroundPath =
      squirclePath(backgroundVertices, 4, innerCornerRadius);
  NSBezierPath* borderPath = panelPath.copy;
  [borderPath appendBezierPath:backgroundPath];

  NSRange visibleRange;
  if (@available(macOS 12.0, *)) {
    visibleRange =
        [self getCharRangeFromTextRange:_textView.textLayoutManager
                                            .textViewportLayoutController
                                            .viewportRange];
  } else {
    NSRange containerGlyphRange = NSMakeRange(NSNotFound, 0);
    [_textView.layoutManager textContainerForGlyphAtIndex:0
                                           effectiveRange:&containerGlyphRange];
    visibleRange =
        [_textView.layoutManager characterRangeForGlyphRange:containerGlyphRange
                                            actualGlyphRange:NULL];
  }
  NSRange preeditRange = NSIntersectionRange(_preeditRange, visibleRange);
  NSRange candidateBlockRange;
  if (_numCandidates > 0) {
    NSRange endRange = theme.linear && _pagingRange.length > 0
                           ? _pagingRange
                           : _candidateRanges[_numCandidates - 1];
    candidateBlockRange = NSIntersectionRange(
        NSUnionRange(_candidateRanges[0], endRange), visibleRange);
  } else {
    candidateBlockRange = NSMakeRange(NSNotFound, 0);
  }
  NSRange pagingRange = NSIntersectionRange(_pagingRange, visibleRange);

  // Draw preedit Rect
  _preeditBlock = NSZeroRect;
  _deleteBackRect = NSZeroRect;
  NSBezierPath* highlightedPreeditPath;
  if (preeditRange.length > 0) {
    NSRect innerBox = [self blockRectForRange:preeditRange];
    _preeditBlock = NSMakeRect(
        backgroundRect.origin.x, backgroundRect.origin.y,
        backgroundRect.size.width,
        innerBox.size.height +
            (candidateBlockRange.length > 0 ? theme.preeditLinespace : 0.0));
    _preeditBlock = [self backingAlignedRect:_preeditBlock
                                     options:NSAlignAllEdgesNearest];

    // Draw highlighted part of preedit text
    NSRange highlightedPreeditRange =
        NSIntersectionRange(_highlightedPreeditRange, visibleRange);
    CGFloat cornerRadius =
        fmin(theme.highlightedCornerRadius,
             theme.preeditParagraphStyle.minimumLineHeight * 0.5);
    if (highlightedPreeditRange.length > 0 &&
        theme.highlightedPreeditBackColor) {
      CGFloat kerning = [theme.preeditAttrs[NSKernAttributeName] doubleValue];
      innerBox.origin.x += _alignmentRectInsets.left - kerning;
      innerBox.size.width =
          backgroundRect.size.width - theme.separatorWidth + kerning * 2;
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
      NSInteger numVert = 0;
      if (!NSIsEmptyRect(leadingRect)) {
        leadingRect.origin.x += _alignmentRectInsets.left - kerning;
        leadingRect.origin.y += _alignmentRectInsets.top;
        leadingRect.size.width += kerning * 2;
        leadingRect =
            [self backingAlignedRect:NSIntersectionRect(leadingRect, innerBox)
                             options:NSAlignAllEdgesNearest];
        numVert += 4;
      }
      if (!NSIsEmptyRect(bodyRect)) {
        bodyRect.origin.x += _alignmentRectInsets.left - kerning;
        bodyRect.origin.y += _alignmentRectInsets.top;
        bodyRect.size.width += kerning * 2;
        bodyRect =
            [self backingAlignedRect:NSIntersectionRect(bodyRect, innerBox)
                             options:NSAlignAllEdgesNearest];
        numVert += 2;
      }
      if (!NSIsEmptyRect(trailingRect)) {
        trailingRect.origin.x += _alignmentRectInsets.left - kerning;
        trailingRect.origin.y += _alignmentRectInsets.top;
        trailingRect.size.width += kerning * 2;
        trailingRect =
            [self backingAlignedRect:NSIntersectionRect(trailingRect, innerBox)
                             options:NSAlignAllEdgesNearest];
        numVert += 4;
      }

      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(bodyRect) && !NSIsEmptyRect(leadingRect) &&
          !NSIsEmptyRect(trailingRect) &&
          NSMaxX(trailingRect) < NSMinX(leadingRect)) {
        NSPoint leadingVertices[4], trailingVertices[4];
        rectVertices(leadingRect, leadingVertices);
        rectVertices(trailingRect, trailingVertices);
        highlightedPreeditPath = squirclePath(leadingVertices, 4, cornerRadius);
        [highlightedPreeditPath
            appendBezierPath:squirclePath(trailingVertices, 4, cornerRadius)];
      } else {
        numVert = numVert > 8 ? 8 : numVert < 4 ? 4 : numVert;
        ;
        NSPoint multilineVertices[numVert];
        multilineRectVertices(leadingRect, bodyRect, trailingRect,
                              multilineVertices);
        highlightedPreeditPath =
            squirclePath(multilineVertices, numVert, cornerRadius);
      }
    }
    _deleteBackRect =
        [self blockRectForRange:NSMakeRange(NSMaxRange(_preeditRange) - 1, 1)];
    _deleteBackRect.size.width += floor(theme.separatorWidth * 0.5);
    _deleteBackRect.origin.x =
        NSMaxX(backgroundRect) - NSWidth(_deleteBackRect);
    _deleteBackRect.origin.y += _alignmentRectInsets.top;
    _deleteBackRect = [self
        backingAlignedRect:NSIntersectionRect(_deleteBackRect, _preeditBlock)
                   options:NSAlignAllEdgesNearest];
  }

  // Draw candidate Rect
  _candidateBlock = NSZeroRect;
  _candidateRects = NULL;
  _sectionRects = NULL;
  _tabularIndices = NULL;
  NSBezierPath *candidateBlockPath, *highlightedCandidatePath;
  NSBezierPath *gridPath, *activePagePath;
  if (candidateBlockRange.length > 0) {
    _candidateBlock = [self blockRectForRange:candidateBlockRange];
    _candidateBlock.size.width = backgroundRect.size.width;
    if (theme.tabular) {
      _candidateBlock.size.width -= theme.expanderWidth + theme.separatorWidth;
    }
    _candidateBlock.origin.x = backgroundRect.origin.x;
    _candidateBlock.origin.y = preeditRange.length == 0 ? NSMinY(backgroundRect)
                                                        : NSMaxY(_preeditBlock);
    if (pagingRange.length == 0 || theme.linear) {
      _candidateBlock.size.height =
          NSMaxY(backgroundRect) - NSMinY(_candidateBlock);
    } else {
      _candidateBlock.size.height += theme.linespace;
    }
    _candidateBlock = [self
        backingAlignedRect:NSIntersectionRect(_candidateBlock, backgroundRect)
                   options:NSAlignAllEdgesNearest];
    NSPoint candidateBlockVertices[4];
    rectVertices(_candidateBlock, candidateBlockVertices);
    candidateBlockPath = squirclePath(
        candidateBlockVertices, 4,
        fmin(theme.highlightedCornerRadius, NSHeight(_candidateBlock) * 0.5));

    // Draw candidate highlight rect
    CGFloat cornerRadius = fmin(theme.highlightedCornerRadius,
                                theme.paragraphStyle.minimumLineHeight * 0.5);
    if (theme.linear) {
      _candidateRects = new NSRect[_numCandidates * 3];
      CGFloat gridOriginY;
      CGFloat tabInterval;
      NSUInteger lineNum = 0;
      NSRect sectionRect = _candidateBlock;
      if (theme.tabular) {
        _tabularIndices = new SquirrelTabularIndex[_numCandidates];
        _sectionRects = new NSRect[_numCandidates / theme.pageSize];
        gridPath = [NSBezierPath bezierPath];
        gridOriginY = NSMinY(_candidateBlock);
        tabInterval = theme.separatorWidth * 2;
        sectionRect.size.height = 0;
      }
      for (NSUInteger i = 0; i < _numCandidates; ++i) {
        NSRange candidateRange =
            NSIntersectionRange(_candidateRanges[i], visibleRange);
        if (candidateRange.length == 0) {
          _numCandidates = i;
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
          leadingRect.origin.y +=
              _alignmentRectInsets.top - ceil(theme.linespace * 0.5);
          leadingRect.size.height += ceil(theme.linespace * 0.5);
          leadingRect =
              [self backingAlignedRect:NSIntersectionRect(leadingRect,
                                                          _candidateBlock)
                               options:NSAlignAllEdgesNearest];
        }
        if (NSIsEmptyRect(trailingRect)) {
          bodyRect.size.height += floor(theme.linespace * 0.5);
        } else {
          trailingRect.origin.x += theme.borderInset.width;
          trailingRect.size.width += theme.tabular ? 0.0 : theme.separatorWidth;
          trailingRect.origin.y += _alignmentRectInsets.top;
          trailingRect.size.height += floor(theme.linespace * 0.5);
          trailingRect =
              [self backingAlignedRect:NSIntersectionRect(trailingRect,
                                                          _candidateBlock)
                               options:NSAlignAllEdgesNearest];
        }
        if (!NSIsEmptyRect(bodyRect)) {
          bodyRect.origin.x += theme.borderInset.width;
          if (_truncated[i]) {
            bodyRect.size.width = NSMaxX(_candidateBlock) - NSMinX(bodyRect);
          } else {
            bodyRect.size.width += theme.tabular && NSIsEmptyRect(trailingRect)
                                       ? 0.0
                                       : theme.separatorWidth;
          }
          bodyRect.origin.y += _alignmentRectInsets.top;
          bodyRect = [self
              backingAlignedRect:NSIntersectionRect(bodyRect, _candidateBlock)
                         options:NSAlignAllEdgesNearest];
        }
        if (theme.tabular) {
          if (self.expanded) {
            if (i % theme.pageSize == 0) {
              sectionRect.origin.y += NSHeight(sectionRect);
            } else if (i % theme.pageSize == theme.pageSize - 1) {
              sectionRect.size.height =
                  NSMaxY(NSIsEmptyRect(trailingRect) ? bodyRect
                                                     : trailingRect) -
                  NSMinY(sectionRect);
              NSUInteger sec = i / theme.pageSize;
              _sectionRects[sec] = sectionRect;
              if (sec == _highlightedIndex / theme.pageSize) {
                NSPoint activePageVertices[4];
                rectVertices(sectionRect, activePageVertices);
                activePagePath =
                    squirclePath(activePageVertices, 4,
                                 fmin(theme.highlightedCornerRadius,
                                      NSHeight(sectionRect) * 0.5));
              }
            }
          }
          CGFloat bottomEdge =
              NSMaxY(NSIsEmptyRect(trailingRect) ? bodyRect : trailingRect);
          if (fabs(bottomEdge - gridOriginY) > 2) {
            lineNum += i > 0 ? 1 : 0;
            if (fabs(bottomEdge - NSMaxY(_candidateBlock)) >
                2) {  // horizontal border except for the last line
              [gridPath
                  moveToPoint:NSMakePoint(NSMinX(_candidateBlock) +
                                              ceil(theme.separatorWidth * 0.5),
                                          bottomEdge)];
              [gridPath
                  lineToPoint:NSMakePoint(NSMaxX(_candidateBlock) -
                                              floor(theme.separatorWidth * 0.5),
                                          bottomEdge)];
            }
            gridOriginY = bottomEdge;
          }
          CGPoint headOrigin =
              (NSIsEmptyRect(leadingRect) ? bodyRect : leadingRect).origin;
          NSUInteger headTabColumn = (NSUInteger)round(
              (headOrigin.x - _alignmentRectInsets.left) / tabInterval);
          if (headOrigin.x >
              NSMinX(_candidateBlock) + theme.separatorWidth) {  // vertical bar
            [gridPath
                moveToPoint:NSMakePoint(headOrigin.x,
                                        headOrigin.y + cornerRadius * 0.8)];
            [gridPath lineToPoint:NSMakePoint(headOrigin.x,
                                              NSMaxY(NSIsEmptyRect(leadingRect)
                                                         ? bodyRect
                                                         : leadingRect) -
                                                  cornerRadius * 0.8)];
          }
          _tabularIndices[i] =
              (SquirrelTabularIndex){i, lineNum, headTabColumn};
        }
        _candidateRects[i * 3] = leadingRect;
        _candidateRects[i * 3 + 1] = bodyRect;
        _candidateRects[i * 3 + 2] = trailingRect;
      }
      NSInteger numVert =
          (NSIsEmptyRect(_candidateRects[_highlightedIndex * 3]) ? 0 : 4) +
          (NSIsEmptyRect(_candidateRects[_highlightedIndex * 3 + 1]) ? 0 : 2) +
          (NSIsEmptyRect(_candidateRects[_highlightedIndex * 3 + 2]) ? 0 : 4);
      // Handles the special case where containing boxes are separated
      if (numVert == 8 && NSMaxX(_candidateRects[_highlightedIndex * 3 + 2]) <
                              NSMinX(_candidateRects[_highlightedIndex * 3])) {
        NSPoint leadingVertices[4], trailingVertices[4];
        rectVertices(_candidateRects[_highlightedIndex * 3], leadingVertices);
        rectVertices(_candidateRects[_highlightedIndex * 3 + 2],
                     trailingVertices);
        highlightedCandidatePath =
            squirclePath(leadingVertices, 4, cornerRadius);
        [highlightedCandidatePath
            appendBezierPath:squirclePath(trailingVertices, 4, cornerRadius)];
      } else {
        numVert = numVert > 8 ? 8 : numVert < 4 ? 4 : numVert;
        NSPoint multilineVertices[numVert];
        multilineRectVertices(_candidateRects[_highlightedIndex * 3],
                              _candidateRects[_highlightedIndex * 3 + 1],
                              _candidateRects[_highlightedIndex * 3 + 2],
                              multilineVertices);
        highlightedCandidatePath =
            squirclePath(multilineVertices, numVert, cornerRadius);
      }
    } else {  // stacked layout
      _candidateRects = new NSRect[_numCandidates];
      for (NSUInteger i = 0; i < _numCandidates; ++i) {
        NSRange candidateRange =
            NSIntersectionRange(_candidateRanges[i], visibleRange);
        if (candidateRange.length == 0) {
          _numCandidates = i;
          break;
        }
        NSRect candidateRect = [self blockRectForRange:candidateRange];
        candidateRect.size.width = backgroundRect.size.width;
        candidateRect.origin.x = backgroundRect.origin.x;
        candidateRect.origin.y +=
            _alignmentRectInsets.top - ceil(theme.linespace * 0.5);
        candidateRect.size.height += theme.linespace;
        candidateRect =
            [self backingAlignedRect:NSIntersectionRect(candidateRect,
                                                        _candidateBlock)
                             options:NSAlignAllEdgesNearest];
        _candidateRects[i] = candidateRect;
      }
      NSPoint candidateVertices[4];
      rectVertices(_candidateRects[_highlightedIndex], candidateVertices);
      highlightedCandidatePath =
          squirclePath(candidateVertices, 4, cornerRadius);
    }
  }

  // Draw paging Rect
  _pagingBlock = NSZeroRect;
  _pageUpRect = NSZeroRect;
  _pageDownRect = NSZeroRect;
  _expanderRect = NSZeroRect;
  NSBezierPath *pageUpPath, *pageDownPath;
  if (theme.tabular && candidateBlockRange.length > 0) {
    _expanderRect =
        [self blockRectForRange:NSMakeRange(_textStorage.length - 1, 1)];
    _expanderRect.origin.x += theme.borderInset.width;
    _expanderRect.size.width = NSMaxX(backgroundRect) - NSMinX(_expanderRect);
    _expanderRect.size.height += theme.linespace;
    _expanderRect.origin.y +=
        _alignmentRectInsets.top - ceil(theme.linespace * 0.5);
    _expanderRect = [self
        backingAlignedRect:NSIntersectionRect(_expanderRect, backgroundRect)
                   options:NSAlignAllEdgesNearest];
    if (theme.showPaging && self.expanded &&
        _tabularIndices[_numCandidates - 1].lineNum > 0) {
      _pagingBlock =
          NSMakeRect(NSMaxX(_candidateBlock), NSMinY(_candidateBlock),
                     NSMaxX(backgroundRect) - NSMaxX(_candidateBlock),
                     NSMinY(_expanderRect) - NSMinY(_candidateBlock));
      CGFloat width =
          fmin(theme.paragraphStyle.minimumLineHeight, NSWidth(_pagingBlock));
      _pageUpRect = NSMakeRect(NSMidX(_pagingBlock) - width * 0.5,
                               NSMidY(_pagingBlock) - width, width, width);
      _pageDownRect = NSMakeRect(NSMidX(_pagingBlock) - width * 0.5,
                                 NSMidY(_pagingBlock), width, width);
      pageUpPath = [NSBezierPath
          bezierPathWithOvalInRect:NSInsetRect(_pageUpRect, width * 0.2,
                                               width * 0.2)];
      [pageUpPath
          moveToPoint:NSMakePoint(NSMinX(_pageUpRect) + ceil(width * 0.325),
                                  NSMaxY(_pageUpRect) - ceil(width * 0.4))];
      [pageUpPath
          lineToPoint:NSMakePoint(NSMidX(_pageUpRect),
                                  NSMinY(_pageUpRect) + ceil(width * 0.4))];
      [pageUpPath
          lineToPoint:NSMakePoint(NSMaxX(_pageUpRect) - ceil(width * 0.325),
                                  NSMaxY(_pageUpRect) - ceil(width * 0.4))];
      pageDownPath = [NSBezierPath
          bezierPathWithOvalInRect:NSInsetRect(_pageDownRect, width * 0.2,
                                               width * 0.2)];
      [pageDownPath
          moveToPoint:NSMakePoint(NSMinX(_pageDownRect) + ceil(width * 0.325),
                                  NSMinY(_pageDownRect) + ceil(width * 0.4))];
      [pageDownPath
          lineToPoint:NSMakePoint(NSMidX(_pageDownRect),
                                  NSMaxY(_pageDownRect) - ceil(width * 0.4))];
      [pageDownPath
          lineToPoint:NSMakePoint(NSMaxX(_pageDownRect) - ceil(width * 0.325),
                                  NSMinY(_pageDownRect) + ceil(width * 0.4))];
    }
  } else if (pagingRange.length > 0) {
    _pageUpRect = [self blockRectForRange:NSMakeRange(pagingRange.location, 1)];
    _pageDownRect =
        [self blockRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)];
    _pageDownRect.origin.x += _alignmentRectInsets.left;
    _pageDownRect.size.width += ceil(theme.separatorWidth * 0.5);
    _pageDownRect.origin.y += _alignmentRectInsets.top;
    _pageUpRect.origin.x += theme.borderInset.width;
    // bypass the bug of getting wrong glyph position when tab is presented
    _pageUpRect.size.width = NSWidth(_pageDownRect);
    _pageUpRect.origin.y += _alignmentRectInsets.top;
    if (theme.linear) {
      _pageUpRect.origin.y -= ceil(theme.linespace * 0.5);
      _pageUpRect.size.height += theme.linespace;
      _pageDownRect.origin.y -= ceil(theme.linespace * 0.5);
      _pageDownRect.size.height += theme.linespace;
      _pageUpRect = NSIntersectionRect(_pageUpRect, _candidateBlock);
      _pageDownRect = NSIntersectionRect(_pageDownRect, _candidateBlock);
    } else {
      _pagingBlock =
          NSMakeRect(NSMinX(backgroundRect), NSMaxY(_candidateBlock),
                     NSWidth(backgroundRect),
                     NSMaxY(backgroundRect) - NSMaxY(_candidateBlock));
      _pageUpRect = NSIntersectionRect(_pageUpRect, _pagingBlock);
      _pageDownRect = NSIntersectionRect(_pageDownRect, _pagingBlock);
    }
    _pageUpRect = [self backingAlignedRect:_pageUpRect
                                   options:NSAlignAllEdgesNearest];
    _pageDownRect = [self backingAlignedRect:_pageDownRect
                                     options:NSAlignAllEdgesNearest];
  }

  // Set layers
  _shape.path = panelPath.quartzPath;
  _shape.fillColor = NSColor.whiteColor.CGColor;
  self.layer.sublayers = nil;
  // layers of large background elements
  CALayer* BackLayers = [[CALayer alloc] init];
  CAShapeLayer* shapeLayer = [[CAShapeLayer alloc] init];
  shapeLayer.path = panelPath.quartzPath;
  shapeLayer.fillColor = NSColor.whiteColor.CGColor;
  BackLayers.mask = shapeLayer;
  if (@available(macOS 10.14, *)) {
    BackLayers.opacity = 1.0f - (float)theme.translucency;
    BackLayers.allowsGroupOpacity = YES;
  }
  [self.layer addSublayer:BackLayers];
  // background image (pattern style) layer
  if (theme.backImage.valid) {
    CAShapeLayer* backImageLayer = [[CAShapeLayer alloc] init];
    CGAffineTransform transform = theme.vertical
                                      ? CGAffineTransformMakeRotation(M_PI_2)
                                      : CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, -backgroundRect.origin.x,
                                           -backgroundRect.origin.y);
    backImageLayer.path =
        (CGPathRef)CFAutorelease(CGPathCreateCopyByTransformingPath(
            backgroundPath.quartzPath, &transform));
    backImageLayer.fillColor =
        [NSColor colorWithPatternImage:theme.backImage].CGColor;
    backImageLayer.affineTransform = CGAffineTransformInvert(transform);
    [BackLayers addSublayer:backImageLayer];
  }
  // background color layer
  CAShapeLayer* backColorLayer = [[CAShapeLayer alloc] init];
  if ((!NSIsEmptyRect(_preeditBlock) || !NSIsEmptyRect(_pagingBlock) ||
       !NSIsEmptyRect(_expanderRect)) &&
      theme.preeditBackColor) {
    if (candidateBlockPath) {
      NSBezierPath* nonCandidatePath = backgroundPath.copy;
      [nonCandidatePath appendBezierPath:candidateBlockPath];
      backColorLayer.path = nonCandidatePath.quartzPath;
      backColorLayer.fillRule = kCAFillRuleEvenOdd;
      backColorLayer.strokeColor = theme.preeditBackColor.CGColor;
      backColorLayer.lineWidth = 0.5;
      backColorLayer.fillColor = theme.preeditBackColor.CGColor;
      [BackLayers addSublayer:backColorLayer];
      // candidate block's background color layer
      CAShapeLayer* candidateLayer = [[CAShapeLayer alloc] init];
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
  // border layer
  CAShapeLayer* borderLayer = [[CAShapeLayer alloc] init];
  borderLayer.path = borderPath.quartzPath;
  borderLayer.fillRule = kCAFillRuleEvenOdd;
  borderLayer.fillColor = (theme.borderColor ?: theme.backColor).CGColor;
  [BackLayers addSublayer:borderLayer];
  // layers of small highlighting elements
  CALayer* ForeLayers = [[CALayer alloc] init];
  CAShapeLayer* maskLayer = [[CAShapeLayer alloc] init];
  maskLayer.path = backgroundPath.quartzPath;
  maskLayer.fillColor = NSColor.whiteColor.CGColor;
  ForeLayers.mask = maskLayer;
  [self.layer addSublayer:ForeLayers];
  // highlighted preedit layer
  if (highlightedPreeditPath && theme.highlightedPreeditBackColor) {
    CAShapeLayer* highlightedPreeditLayer = [[CAShapeLayer alloc] init];
    highlightedPreeditLayer.path = highlightedPreeditPath.quartzPath;
    highlightedPreeditLayer.fillColor =
        theme.highlightedPreeditBackColor.CGColor;
    [ForeLayers addSublayer:highlightedPreeditLayer];
  }
  // highlighted candidate layer
  if (highlightedCandidatePath && theme.highlightedCandidateBackColor) {
    if (activePagePath) {
      CAShapeLayer* activePageLayer = [[CAShapeLayer alloc] init];
      activePageLayer.path = activePagePath.quartzPath;
      activePageLayer.fillColor =
          [[theme.highlightedCandidateBackColor
               blendedColorWithFraction:0.8
                                ofColor:[theme.backColor
                                            colorWithAlphaComponent:1.0]]
              colorWithAlphaComponent:theme.backColor.alphaComponent]
              .CGColor;
      [BackLayers addSublayer:activePageLayer];
    }
    CAShapeLayer* highlightedCandidateLayer = [[CAShapeLayer alloc] init];
    highlightedCandidateLayer.path = highlightedCandidatePath.quartzPath;
    highlightedCandidateLayer.fillColor =
        theme.highlightedCandidateBackColor.CGColor;
    [ForeLayers addSublayer:highlightedCandidateLayer];
  }
  // function buttons (page up, page down, backspace) layer
  if (_functionButton != kVoidSymbol) {
    CAShapeLayer* functionButtonLayer = [self getFunctionButtonLayer];
    if (functionButtonLayer) {
      [ForeLayers addSublayer:functionButtonLayer];
    }
  }
  // grids (in candidate block) layer
  if (gridPath) {
    CAShapeLayer* gridLayer = [[CAShapeLayer alloc] init];
    gridLayer.path = gridPath.quartzPath;
    gridLayer.lineWidth = 1.0;
    gridLayer.strokeColor = [theme.commentAttrs[NSForegroundColorAttributeName]
                                blendedColorWithFraction:0.8
                                                 ofColor:theme.backColor]
                                .CGColor;
    [ForeLayers addSublayer:gridLayer];
  }
  // paging buttons in expanded tabular layout
  if (pageUpPath && pageDownPath) {
    CAShapeLayer* pageUpLayer = [[CAShapeLayer alloc] init];
    pageUpLayer.path = pageUpPath.quartzPath;
    pageUpLayer.fillColor = NSColor.clearColor.CGColor;
    pageUpLayer.lineWidth =
        ceil([theme.pagingAttrs[NSFontAttributeName] pointSize] * 0.05);
    NSDictionary* pageUpAttrs =
        _functionButton == kPageUpKey || _functionButton == kHomeKey
            ? theme.preeditHighlightedAttrs
            : theme.preeditAttrs;
    pageUpLayer.strokeColor =
        [pageUpAttrs[NSForegroundColorAttributeName] CGColor];
    [ForeLayers addSublayer:pageUpLayer];
    CAShapeLayer* pageDownLayer = [[CAShapeLayer alloc] init];
    pageDownLayer.path = pageDownPath.quartzPath;
    pageDownLayer.fillColor = NSColor.clearColor.CGColor;
    pageDownLayer.lineWidth =
        ceil([theme.pagingAttrs[NSFontAttributeName] pointSize] * 0.05);
    NSDictionary* pageDownAttrs =
        _functionButton == kPageDownKey || _functionButton == kEndKey
            ? theme.preeditHighlightedAttrs
            : theme.preeditAttrs;
    pageDownLayer.strokeColor =
        [pageDownAttrs[NSForegroundColorAttributeName] CGColor];
    [ForeLayers addSublayer:pageDownLayer];
  }
  // logo at the beginning for status message
  if (NSIsEmptyRect(_preeditBlock) && NSIsEmptyRect(_candidateBlock)) {
    CALayer* logoLayer = [[CALayer alloc] init];
    CGFloat height =
        [theme.statusAttrs[NSParagraphStyleAttributeName] minimumLineHeight];
    NSRect logoRect = NSMakeRect(backgroundRect.origin.x,
                                 backgroundRect.origin.y, height, height);
    logoLayer.frame = [self
        backingAlignedRect:NSInsetRect(logoRect, -0.1 * height, -0.1 * height)
                   options:NSAlignAllEdgesNearest];
    NSImage* logoImage = [NSImage imageNamed:NSImageNameApplicationIcon];
    logoImage.size = logoRect.size;
    CGFloat scaleFactor = [logoImage
        recommendedLayerContentsScale:self.window.backingScaleFactor];
    logoLayer.contents = logoImage;
    logoLayer.contentsScale = scaleFactor;
    logoLayer.affineTransform = theme.vertical
                                    ? CGAffineTransformMakeRotation(-M_PI_2)
                                    : CGAffineTransformIdentity;
    [ForeLayers addSublayer:logoLayer];
  }
}

- (SquirrelIndex)getIndexFromMouseSpot:(NSPoint)spot {
  NSPoint point = [self convertPoint:spot fromView:nil];
  if (NSMouseInRect(point, self.bounds, YES)) {
    if (NSMouseInRect(point, _preeditBlock, YES)) {
      return NSMouseInRect(point, _deleteBackRect, YES) ? kBackSpaceKey
                                                        : kCodeInputArea;
    }
    if (NSMouseInRect(point, _expanderRect, YES)) {
      return kExpandButton;
    }
    if (NSMouseInRect(point, _pageUpRect, YES)) {
      return kPageUpKey;
    }
    if (NSMouseInRect(point, _pageDownRect, YES)) {
      return kPageDownKey;
    }
    for (NSUInteger i = 0; i < _numCandidates; ++i) {
      if (self.currentTheme.linear
              ? (NSMouseInRect(point, _candidateRects[i * 3], YES) ||
                 NSMouseInRect(point, _candidateRects[i * 3 + 1], YES) ||
                 NSMouseInRect(point, _candidateRects[i * 3 + 2], YES))
              : NSMouseInRect(point, _candidateRects[i], YES)) {
        return i;
      }
    }
  }
  return NSNotFound;
}

@end  // SquirrelView

/* In order to put SquirrelPanel above client app windows,
 SquirrelPanel needs to be assigned a window level higher
 than kCGHelpWindowLevelKey that the system tooltips use.
 This class makes system-alike tooltips above SquirrelPanel
 */
@interface SquirrelToolTip : NSWindow

@property(nonatomic, strong, readonly) NSTimer* displayTimer;
@property(nonatomic, strong, readonly) NSTimer* hideTimer;

@end

@implementation SquirrelToolTip {
  NSVisualEffectView* _backView;
  NSTextField* _textView;
}

- (instancetype)init {
  self = [super initWithContentRect:NSZeroRect
                          styleMask:NSWindowStyleMaskNonactivatingPanel
                            backing:NSBackingStoreBuffered
                              defer:YES];
  if (self) {
    self.backgroundColor = NSColor.clearColor;
    self.opaque = YES;
    self.hasShadow = YES;
    NSView* contentView = [[NSView alloc] init];
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

- (void)showWithToolTip:(NSString*)toolTip withDelay:(BOOL)delay {
  if (toolTip.length == 0) {
    [self hide];
    return;
  }
  SquirrelPanel* panel = NSApp.squirrelAppDelegate.panel;
  self.level = panel.level + 1;
  self.appearanceSource = panel;

  _textView.stringValue = toolTip;
  _textView.font = [NSFont toolTipsFontOfSize:0];
  _textView.textColor = NSColor.windowFrameTextColor;
  [_textView sizeToFit];
  NSSize contentSize = _textView.fittingSize;

  NSPoint spot = NSEvent.mouseLocation;
  NSCursor* cursor = NSCursor.currentSystemCursor;
  spot.x += cursor.image.size.width - cursor.hotSpot.x;
  spot.y -= cursor.image.size.height - cursor.hotSpot.y;
  NSRect windowRect = NSMakeRect(spot.x, spot.y - contentSize.height,
                                 contentSize.width, contentSize.height);

  NSRect screenRect = panel.screen.visibleFrame;
  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = NSMaxX(screenRect) - NSWidth(windowRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = NSMinY(screenRect);
  }
  [self setFrame:[panel.screen backingAlignedRect:windowRect
                                          options:NSAlignAllEdgesNearest]
         display:NO];
  _textView.frame = self.contentView.bounds;
  _backView.frame = self.contentView.bounds;

  if (_displayTimer.valid) {
    [_displayTimer invalidate];
  }
  if (delay) {
    _displayTimer =
        [NSTimer scheduledTimerWithTimeInterval:3.0
                                         target:self
                                       selector:@selector(delayedDisplay:)
                                       userInfo:nil
                                        repeats:NO];
  } else {
    [self display];
    [self orderFrontRegardless];
  }
}

- (void)delayedDisplay:(NSTimer*)timer {
  [self display];
  [self orderFrontRegardless];
  if (_hideTimer.valid) {
    [_hideTimer invalidate];
  }
  _hideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                target:self
                                              selector:@selector(delayedHide:)
                                              userInfo:nil
                                               repeats:NO];
}

- (void)delayedHide:(NSTimer*)timer {
  [self hide];
}

- (void)hide {
  if (_displayTimer.valid) {
    [_displayTimer invalidate];
    _displayTimer = nil;
  }
  if (_hideTimer.valid) {
    [_hideTimer invalidate];
    _hideTimer = nil;
  }
  if (self.visible) {
    [self orderOut:nil];
  }
}

@end  // SquirrelToolTipView

#pragma mark - Panel window, dealing with text content and mouse interactions

@implementation SquirrelPanel {
  NSVisualEffectView* _back;
  SquirrelToolTip* _toolTip;
  SquirrelView* _view;
  NSScreen* _screen;
  NSTimer* _statusTimer;

  NSSize _maxSize;
  CGFloat _textWidthLimit;
  CGFloat _anchorOffset;
  BOOL _initPosition;

  NSRange _indexRange;
  NSUInteger _highlightedIndex;
  NSUInteger _functionButton;
  NSUInteger _caretPos;
  NSUInteger _pageNum;
  BOOL _caretAtHome;
  BOOL _finalPage;
}

- (BOOL)linear {
  return _view.currentTheme.linear;
}

- (BOOL)tabular {
  return _view.currentTheme.tabular;
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

- (BOOL)firstLine {
  return _view.tabularIndices
             ? _view.tabularIndices[_highlightedIndex].lineNum == 0
             : YES;
}

- (BOOL)expanded {
  return _view.expanded;
}

- (void)setExpanded:(BOOL)expanded {
  if (_view.currentTheme.tabular && !_locked && _view.expanded != expanded) {
    _view.expanded = expanded;
    _sectionNum = 0;
  }
}

- (void)setSectionNum:(NSUInteger)sectionNum {
  if (_view.currentTheme.tabular && _view.expanded &&
      _sectionNum != sectionNum) {
    NSUInteger maxSections = _view.currentTheme.vertical ? 2 : 4;
    _sectionNum = sectionNum < 0             ? 0
                  : sectionNum > maxSections ? maxSections
                                             : sectionNum;
  }
}

- (void)setLock:(BOOL)locked {
  if (_view.currentTheme.tabular && _locked != locked) {
    _locked = locked;
    SquirrelConfig* userConfig = [[SquirrelConfig alloc] init];
    if ([userConfig openUserConfig:@"user"]) {
      [userConfig setOption:@"var/option/_lock_tabular" withBool:locked];
      if (locked) {
        [userConfig setOption:@"var/option/_expand_tabular"
                     withBool:_view.expanded];
      }
    }
    [userConfig close];
  }
}

- (void)getLock {
  if (_view.currentTheme.tabular) {
    SquirrelConfig* userConfig = [[SquirrelConfig alloc] init];
    if ([userConfig openUserConfig:@"user"]) {
      _locked = [userConfig getBoolForOption:@"var/option/_lock_tabular"];
      if (_locked) {
        _view.expanded =
            [userConfig getBoolForOption:@"var/option/_expand_tabular"];
      }
    }
    [userConfig close];
    _sectionNum = 0;
  }
}

- (instancetype)init {
  self = [super initWithContentRect:_IbeamRect
                          styleMask:NSWindowStyleMaskNonactivatingPanel |
                                    NSWindowStyleMaskBorderless
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

    NSView* contentView = [[NSView alloc] init];
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
    [contentView addSubview:_back];
    [contentView addSubview:_view];
    [contentView addSubview:_view.textView];
    self.contentView = contentView;

    [self updateDisplayParameters];
    _candidates = [[NSMutableArray alloc] init];
    _comments = [[NSMutableArray alloc] init];
    _toolTip = [[SquirrelToolTip alloc] init];
  }
  return self;
}

- (void)windowDidChangeBackingProperties:(NSNotification*)notification {
  if ([notification.object isMemberOfClass:SquirrelPanel.class]) {
    [notification.object updateDisplayParameters];
  }
}

- (NSUInteger)candidateIndexOnDirection:(SquirrelIndex)arrowKey {
  if (!self.tabular || _indexRange.length == 0 ||
      _highlightedIndex == NSNotFound) {
    return NSNotFound;
  }
  NSUInteger pageSize = _view.currentTheme.pageSize;
  NSUInteger currentTab = _view.tabularIndices[_highlightedIndex].tabNum;
  NSUInteger currentLine = _view.tabularIndices[_highlightedIndex].lineNum;
  NSUInteger finalLine = _view.tabularIndices[_indexRange.length - 1].lineNum;
  if (arrowKey == (self.vertical ? kLeftKey : kDownKey)) {
    if (_highlightedIndex == _indexRange.length - 1 && _finalPage) {
      return NSNotFound;
    }
    if (currentLine == finalLine && !_finalPage) {
      return _highlightedIndex + pageSize + _indexRange.location;
    }
    NSUInteger newIndex = _highlightedIndex + 1;
    while (newIndex < _indexRange.length &&
           (_view.tabularIndices[newIndex].lineNum == currentLine ||
            (_view.tabularIndices[newIndex].lineNum == currentLine + 1 &&
             _view.tabularIndices[newIndex].tabNum <= currentTab))) {
      ++newIndex;
    }
    if (newIndex != _indexRange.length || _finalPage) {
      --newIndex;
    }
    return newIndex + _indexRange.location;
  } else if (arrowKey == (self.vertical ? kRightKey : kUpKey)) {
    if (currentLine == 0) {
      return _pageNum == 0 ? NSNotFound
                           : pageSize * (_pageNum - _sectionNum) - 1;
    }
    NSInteger newIndex = (NSInteger)_highlightedIndex - 1;
    while (newIndex > 0 &&
           (_view.tabularIndices[newIndex].lineNum == currentLine ||
            (_view.tabularIndices[newIndex].lineNum == currentLine - 1 &&
             _view.tabularIndices[newIndex].tabNum > currentTab))) {
      --newIndex;
    }
    return (NSUInteger)newIndex + _indexRange.location;
  }
  return NSNotFound;
}

// handle mouse interaction events
- (void)sendEvent:(NSEvent*)event {
  SquirrelTheme* theme = _view.currentTheme;
  static SquirrelIndex cursorIndex = NSNotFound;
  switch (event.type) {
    case NSEventTypeLeftMouseDown:
      if (event.clickCount == 1 && cursorIndex == kCodeInputArea) {
        NSPoint spot =
            [_view.textView convertPoint:self.mouseLocationOutsideOfEventStream
                                fromView:nil];
        NSUInteger inputIndex =
            [_view.textView characterIndexForInsertionAtPoint:spot];
        if (inputIndex == 0) {
          [self.inputController performAction:kPROCESS onIndex:kHomeKey];
        } else if (inputIndex < _caretPos) {
          [self.inputController moveCursor:_caretPos
                                toPosition:inputIndex
                             inlinePreedit:NO
                           inlineCandidate:NO];
        } else if (inputIndex >= _view.preeditRange.length) {
          [self.inputController performAction:kPROCESS onIndex:kEndKey];
        } else if (inputIndex > _caretPos + 1) {
          [self.inputController moveCursor:_caretPos
                                toPosition:inputIndex - 1
                             inlinePreedit:NO
                           inlineCandidate:NO];
        }
      }
      break;
    case NSEventTypeLeftMouseUp:
      if (event.clickCount == 1 && cursorIndex != NSNotFound) {
        if (cursorIndex == _highlightedIndex) {
          [self.inputController
              performAction:kSELECT
                    onIndex:cursorIndex + _indexRange.location];
        } else if (cursorIndex == _functionButton) {
          if (cursorIndex == kExpandButton) {
            if (_locked) {
              [self setLock:NO];
              [_view.textStorage
                  replaceCharactersInRange:NSMakeRange(
                                               _view.textStorage.length - 1, 1)
                      withAttributedString:_view.expanded ? theme.symbolCompress
                                                          : theme.symbolExpand];
              _view.textView.needsDisplayInRect = _view.expanderRect;
            } else {
              self.expanded = !_view.expanded;
              self.sectionNum = 0;
            }
          }
          [self.inputController performAction:kPROCESS onIndex:cursorIndex];
        }
      }
      break;
    case NSEventTypeRightMouseUp:
      if (event.clickCount == 1 && cursorIndex != NSNotFound) {
        if (cursorIndex == _highlightedIndex) {
          [self.inputController
              performAction:kDELETE
                    onIndex:cursorIndex + _indexRange.location];
        } else if (cursorIndex == _functionButton) {
          switch (_functionButton) {
            case kPageUpKey:
              [self.inputController performAction:kPROCESS onIndex:kHomeKey];
              break;
            case kPageDownKey:
              [self.inputController performAction:kPROCESS onIndex:kEndKey];
              break;
            case kExpandButton:
              [self setLock:!_locked];
              [_view.textStorage
                  replaceCharactersInRange:NSMakeRange(
                                               _view.textStorage.length - 1, 1)
                      withAttributedString:_locked ? theme.symbolLock
                                           : _view.expanded
                                               ? theme.symbolCompress
                                               : theme.symbolExpand];
              [_view.textStorage
                  addAttribute:NSForegroundColorAttributeName
                         value:theme.preeditHighlightedAttrs
                                   [NSForegroundColorAttributeName]
                         range:NSMakeRange(_view.textStorage.length - 1, 1)];
              _view.textView.needsDisplayInRect = _view.expanderRect;
              [self.inputController performAction:kPROCESS onIndex:kLockButton];
              break;
            case kBackSpaceKey:
              [self.inputController performAction:kPROCESS onIndex:kEscapeKey];
              break;
          }
        }
      }
      break;
    case NSEventTypeMouseMoved: {
      if ((event.modifierFlags &
           NSEventModifierFlagDeviceIndependentFlagsMask) ==
          NSEventModifierFlagControl) {
        return;
      }
      BOOL noDelay = (event.modifierFlags &
                      NSEventModifierFlagDeviceIndependentFlagsMask) ==
                     NSEventModifierFlagOption;
      cursorIndex =
          [_view getIndexFromMouseSpot:self.mouseLocationOutsideOfEventStream];
      if (cursorIndex != _highlightedIndex && cursorIndex != _functionButton) {
        [_toolTip hide];
      } else if (noDelay) {
        [_toolTip.displayTimer fire];
      }
      if (cursorIndex >= 0 && cursorIndex < _indexRange.length &&
          _highlightedIndex != cursorIndex) {
        [self highlightFunctionButton:kVoidSymbol delayToolTip:!noDelay];
        if (theme.linear && _view.truncated[cursorIndex]) {
          [_toolTip showWithToolTip:[_view.textStorage.mutableString
                                        substringWithRange:_view.candidateRanges
                                                               [cursorIndex]]
                          withDelay:NO];
        } else if (noDelay) {
          [_toolTip showWithToolTip:NSLocalizedString(@"candidate", nil)
                          withDelay:!noDelay];
        }
        self.sectionNum = cursorIndex / theme.pageSize;
        [self.inputController performAction:kHIGHLIGHT
                                    onIndex:cursorIndex + _indexRange.location];
      } else if ((cursorIndex == kPageUpKey || cursorIndex == kPageDownKey ||
                  cursorIndex == kExpandButton ||
                  cursorIndex == kBackSpaceKey) &&
                 _functionButton != cursorIndex) {
        [self highlightFunctionButton:cursorIndex delayToolTip:!noDelay];
      }
    } break;
    case NSEventTypeMouseExited:
      [_toolTip.displayTimer invalidate];
      break;
    case NSEventTypeLeftMouseDragged:
      // reset the remember_size references after moving the panel
      _maxSize = NSZeroSize;
      [self performWindowDragWithEvent:event];
      break;
    case NSEventTypeScrollWheel: {
      CGFloat scrollThreshold =
          [theme.attrs[NSParagraphStyleAttributeName] minimumLineHeight] +
          [theme.attrs[NSParagraphStyleAttributeName] lineSpacing];
      static NSPoint scrollLocus = NSZeroPoint;
      if (event.phase == NSEventPhaseBegan) {
        scrollLocus = NSZeroPoint;
      } else if ((event.phase == NSEventPhaseNone ||
                  event.momentumPhase == NSEventPhaseNone) &&
                 !isnan(scrollLocus.x) && !isnan(scrollLocus.y)) {
        // determine scrolling direction by confining to sectors within ±30º of
        // any axis
        if (fabs(event.scrollingDeltaX) >
            fabs(event.scrollingDeltaY) * sqrt(3.0)) {
          scrollLocus.x += event.scrollingDeltaX *
                           (event.hasPreciseScrollingDeltas ? 1 : 10);
        } else if (fabs(event.scrollingDeltaY) >
                   fabs(event.scrollingDeltaX) * sqrt(3.0)) {
          scrollLocus.y += event.scrollingDeltaY *
                           (event.hasPreciseScrollingDeltas ? 1 : 10);
        }
        // compare accumulated locus length against threshold and limit paging
        // to max once
        if (scrollLocus.x > scrollThreshold) {
          [self.inputController
              performAction:kPROCESS
                    onIndex:(theme.vertical ? kPageDownKey : kPageUpKey)];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.y > scrollThreshold) {
          [self.inputController performAction:kPROCESS onIndex:kPageUpKey];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.x < -scrollThreshold) {
          [self.inputController
              performAction:kPROCESS
                    onIndex:(theme.vertical ? kPageUpKey : kPageDownKey)];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.y < -scrollThreshold) {
          [self.inputController performAction:kPROCESS onIndex:kPageDownKey];
          scrollLocus = NSMakePoint(NAN, NAN);
        }
      }
    } break;
    default:
      [super sendEvent:event];
      break;
  }
}

- (void)highlightCandidate:(NSUInteger)highlightedIndex {
  SquirrelTheme* theme = _view.currentTheme;
  NSUInteger prevHighlightedIndex = _highlightedIndex;
  NSUInteger prevSectionNum = prevHighlightedIndex / theme.pageSize;
  _highlightedIndex = highlightedIndex;
  self.sectionNum = highlightedIndex / theme.pageSize;
  // apply new foreground colors
  for (NSUInteger i = 0; i < theme.pageSize; ++i) {
    NSUInteger prevIndex = i + prevSectionNum * theme.pageSize;
    if ((_sectionNum != prevSectionNum || prevIndex == prevHighlightedIndex) &&
        prevIndex < _indexRange.length) {
      NSRange prevRange = _view.candidateRanges[prevIndex];
      NSRange prevTextRange =
          [[_view.textStorage.mutableString substringWithRange:prevRange]
              rangeOfString:_candidates[prevIndex + _indexRange.location]];
      NSColor* labelColor = [theme.labelAttrs[NSForegroundColorAttributeName]
          blendedColorWithFraction:prevIndex == prevHighlightedIndex &&
                                           _sectionNum == prevSectionNum
                                       ? 0.0
                                       : 0.5
                           ofColor:NSColor.clearColor];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:labelColor
                 range:NSMakeRange(prevRange.location, prevTextRange.location)];
      if (prevIndex == prevHighlightedIndex) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.attrs[NSForegroundColorAttributeName]
                   range:NSMakeRange(
                             prevRange.location + prevTextRange.location,
                             prevTextRange.length)];
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.commentAttrs[NSForegroundColorAttributeName]
                   range:NSMakeRange(
                             prevRange.location + NSMaxRange(prevTextRange),
                             prevRange.length - NSMaxRange(prevTextRange))];
      }
    }
    NSUInteger newIndex = i + _sectionNum * theme.pageSize;
    if ((_sectionNum != prevSectionNum || newIndex == _highlightedIndex) &&
        newIndex < _indexRange.length) {
      NSRange newRange = _view.candidateRanges[newIndex];
      NSRange newTextRange =
          [[_view.textStorage.mutableString substringWithRange:newRange]
              rangeOfString:_candidates[newIndex + _indexRange.location]];
      NSColor* labelColor =
          (newIndex == _highlightedIndex
               ? theme.labelHighlightedAttrs
               : theme.labelAttrs)[NSForegroundColorAttributeName];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:labelColor
                 range:NSMakeRange(newRange.location, newTextRange.location)];
      NSColor* textColor = (newIndex == _highlightedIndex
                                ? theme.highlightedAttrs
                                : theme.attrs)[NSForegroundColorAttributeName];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:textColor
                 range:NSMakeRange(newRange.location + newTextRange.location,
                                   newTextRange.length)];
      NSColor* commentColor =
          (newIndex == _highlightedIndex
               ? theme.commentHighlightedAttrs
               : theme.commentAttrs)[NSForegroundColorAttributeName];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:commentColor
                 range:NSMakeRange(newRange.location + NSMaxRange(newTextRange),
                                   newRange.length - NSMaxRange(newTextRange))];
    }
  }
  [_view highlightCandidate:_highlightedIndex];
  [self displayIfNeeded];
}

- (void)highlightFunctionButton:(SquirrelIndex)functionButton
                   delayToolTip:(BOOL)delay {
  if (_functionButton == functionButton) {
    return;
  }
  SquirrelTheme* theme = _view.currentTheme;
  switch (_functionButton) {
    case kPageUpKey:
      if (!theme.tabular) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.pagingAttrs[NSForegroundColorAttributeName]
                   range:NSMakeRange(_view.pagingRange.location, 1)];
      }
      break;
    case kPageDownKey:
      if (!theme.tabular) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.pagingAttrs[NSForegroundColorAttributeName]
                   range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
      }
      break;
    case kExpandButton:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditAttrs[NSForegroundColorAttributeName]
                 range:NSMakeRange(_view.textStorage.length - 1, 1)];
      break;
    case kBackSpaceKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditAttrs[NSForegroundColorAttributeName]
                 range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
      break;
  }
  _functionButton = functionButton;
  switch (_functionButton) {
    case kPageUpKey:
      if (!theme.tabular) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.pagingHighlightedAttrs
                             [NSForegroundColorAttributeName]
                   range:NSMakeRange(_view.pagingRange.location, 1)];
      }
      functionButton = _pageNum == 0 ? kHomeKey : kPageUpKey;
      [_toolTip showWithToolTip:NSLocalizedString(
                                    _pageNum == 0 ? @"home" : @"page_up", nil)
                      withDelay:delay];
      break;
    case kPageDownKey:
      if (!theme.tabular) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.pagingHighlightedAttrs
                             [NSForegroundColorAttributeName]
                   range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
      }
      functionButton = _finalPage ? kEndKey : kPageDownKey;
      [_toolTip showWithToolTip:NSLocalizedString(
                                    _finalPage ? @"end" : @"page_down", nil)
                      withDelay:delay];
      break;
    case kExpandButton:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditHighlightedAttrs
                           [NSForegroundColorAttributeName]
                 range:NSMakeRange(_view.textStorage.length - 1, 1)];
      functionButton = _locked          ? kLockButton
                       : _view.expanded ? kCompressButton
                                        : kExpandButton;
      [_toolTip showWithToolTip:NSLocalizedString(_locked          ? @"unlock"
                                                  : _view.expanded ? @"compress"
                                                                   : @"expand",
                                                  nil)
                      withDelay:delay];
      break;
    case kBackSpaceKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditHighlightedAttrs
                           [NSForegroundColorAttributeName]
                 range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
      functionButton = _caretAtHome ? kEscapeKey : kBackSpaceKey;
      [_toolTip showWithToolTip:NSLocalizedString(
                                    _caretAtHome ? @"escape" : @"delete", nil)
                      withDelay:delay];
      break;
  }
  [_view highlightFunctionButton:functionButton];
  [self displayIfNeeded];
}

- (void)updateScreen {
  for (NSScreen* screen in NSScreen.screens) {
    if (NSPointInRect(_IbeamRect.origin, screen.frame)) {
      _screen = screen;
      return;
    }
  }
  _screen = NSScreen.mainScreen;
}

- (NSScreen*)screen {
  return _screen;
}

- (void)updateDisplayParameters {
  // repositioning the panel window
  _initPosition = YES;
  _maxSize = NSZeroSize;

  // size limits on textContainer
  NSRect screenRect = _screen.visibleFrame;
  SquirrelTheme* theme = _view.currentTheme;
  _view.textView.layoutOrientation = (NSTextLayoutOrientation)theme.vertical;
  // rotate the view, the core in vertical mode!
  self.contentView.boundsRotation = theme.vertical ? -90.0 : 0.0;
  _view.textView.boundsRotation = 0.0;
  _view.textView.boundsOrigin = NSZeroPoint;

  CGFloat textWidthRatio =
      fmin(0.8, 1.0 / (theme.vertical ? 4 : 3) +
                    [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit =
      (theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) *
          textWidthRatio -
      theme.separatorWidth - theme.borderInset.width * 2;
  if (theme.lineLength > 0) {
    _textWidthLimit = fmin(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabular) {
    CGFloat tabInterval = theme.separatorWidth * 2;
    _textWidthLimit = floor(_textWidthLimit / tabInterval) * tabInterval +
                      theme.expanderWidth;
  }
  CGFloat textHeightLimit =
      (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.8 -
      theme.borderInset.height * 2 -
      (theme.inlinePreedit ? ceil(theme.linespace * 0.5) : 0.0) -
      (theme.linear || !theme.showPaging ? floor(theme.linespace * 0.5) : 0.0);
  _view.textView.textContainer.size =
      NSMakeSize(_textWidthLimit, textHeightLimit);

  // resize background image, if any
  if (theme.backImage.valid) {
    CGFloat widthLimit = _textWidthLimit + theme.separatorWidth;
    NSSize backImageSize = theme.backImage.size;
    theme.backImage.resizingMode = NSImageResizingModeStretch;
    theme.backImage.size =
        theme.vertical
            ? NSMakeSize(
                  backImageSize.width / backImageSize.height * widthLimit,
                  widthLimit)
            : NSMakeSize(widthLimit, backImageSize.height /
                                         backImageSize.width * widthLimit);
  }
}

// Get the window size, it will be the dirtyRect in SquirrelView.drawRect
- (void)show {
  if (@available(macOS 10.14, *)) {
    NSAppearanceName appearanceName = _view.appear == darkAppear
                                          ? NSAppearanceNameDarkAqua
                                          : NSAppearanceNameAqua;
    NSAppearance* requestedAppearance =
        [NSAppearance appearanceNamed:appearanceName];
    if (self.appearance != requestedAppearance) {
      self.appearance = requestedAppearance;
    }
  }

  // Break line if the text is too long, based on screen size.
  SquirrelTheme* theme = _view.currentTheme;
  NSTextContainer* textContainer = _view.textView.textContainer;
  NSEdgeInsets insets = _view.alignmentRectInsets;
  CGFloat textWidthRatio =
      fmin(0.8, 1.0 / (theme.vertical ? 4 : 3) +
                    [theme.attrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = _screen.visibleFrame;

  // the sweep direction of the client app changes the behavior of adjusting
  // squirrel panel position
  BOOL sweepVertical = NSWidth(_IbeamRect) > NSHeight(_IbeamRect);
  NSRect contentRect = _view.contentRect;
  NSRect maxContentRect = contentRect;
  // fixed line length (text width), but not applicable to status message
  if (theme.lineLength > 0 && _statusMessage == nil) {
    maxContentRect.size.width = _textWidthLimit;
  }
  // remember panel size (fix the top leading anchor of the panel in screen
  // coordiantes) but only when the text would expand on the side of upstream
  // (i.e. towards the beginning of text)
  if (theme.rememberSize && _statusMessage == nil) {
    if (theme.lineLength == 0 &&
        (theme.vertical
             ? (sweepVertical
                    ? (NSMinY(_IbeamRect) -
                           fmax(NSWidth(maxContentRect), _maxSize.width) -
                           insets.right <
                       NSMinY(screenRect))
                    : (NSMinY(_IbeamRect) - kOffsetGap -
                           NSHeight(screenRect) * textWidthRatio - insets.left -
                           insets.right <
                       NSMinY(screenRect)))
             : (sweepVertical
                    ? (NSMinX(_IbeamRect) - kOffsetGap -
                           NSWidth(screenRect) * textWidthRatio - insets.left -
                           insets.right >=
                       NSMinX(screenRect))
                    : (NSMaxX(_IbeamRect) +
                           fmax(NSWidth(maxContentRect), _maxSize.width) +
                           insets.right >
                       NSMaxX(screenRect))))) {
      if (NSWidth(maxContentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(maxContentRect);
      } else {
        CGFloat textHeightLimit =
            (theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) *
                0.8 -
            insets.top - insets.bottom;
        maxContentRect.size.width = _maxSize.width;
        textContainer.size = NSMakeSize(_maxSize.width, textHeightLimit);
      }
    }
    CGFloat textHeight = fmax(NSHeight(maxContentRect), _maxSize.height) +
                         insets.top + insets.bottom;
    if (theme.vertical ? (NSMinX(_IbeamRect) - textHeight -
                              (sweepVertical ? kOffsetGap : 0) <
                          NSMinX(screenRect))
                       : (NSMinY(_IbeamRect) - textHeight -
                              (sweepVertical ? 0 : kOffsetGap) <
                          NSMinY(screenRect))) {
      if (NSHeight(maxContentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(maxContentRect);
      } else {
        maxContentRect.size.height = _maxSize.height;
      }
    }
  }

  NSRect windowRect;
  if (_statusMessage !=
      nil) {  // following system UI, middle-align status message with cursor
    _initPosition = YES;
    if (theme.vertical) {
      windowRect.size.width =
          NSHeight(maxContentRect) + insets.top + insets.bottom;
      windowRect.size.height =
          NSWidth(maxContentRect) + insets.left + insets.right;
    } else {
      windowRect.size.width =
          NSWidth(maxContentRect) + insets.left + insets.right;
      windowRect.size.height =
          NSHeight(maxContentRect) + insets.top + insets.bottom;
    }
    if (sweepVertical) {  // vertically centre-align (MidY) in screen
                          // coordinates
      windowRect.origin.x =
          NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
      windowRect.origin.y = NSMidY(_IbeamRect) - NSHeight(windowRect) * 0.5;
    } else {  // horizontally centre-align (MidX) in screen coordinates
      windowRect.origin.x = NSMidX(_IbeamRect) - NSWidth(windowRect) * 0.5;
      windowRect.origin.y =
          NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
    }
  } else {
    if (theme.vertical) {  // anchor is the top right corner in screen
                           // coordinates (MaxX, MaxY)
      windowRect =
          NSMakeRect(NSMaxX(self.frame) - NSHeight(maxContentRect) -
                         insets.top - insets.bottom,
                     NSMaxY(self.frame) - NSWidth(maxContentRect) -
                         insets.left - insets.right,
                     NSHeight(maxContentRect) + insets.top + insets.bottom,
                     NSWidth(maxContentRect) + insets.left + insets.right);
      _initPosition |= NSIntersectsRect(windowRect, _IbeamRect);
      if (_initPosition) {
        if (!sweepVertical) {
          // To avoid jumping up and down while typing, use the lower screen
          // when typing on upper, and vice versa
          if (NSMinY(_IbeamRect) - kOffsetGap -
                  NSHeight(screenRect) * textWidthRatio - insets.left -
                  insets.right <
              NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.y =
                NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
          }
          // Make the right edge of candidate block fixed at the left of cursor
          windowRect.origin.x =
              NSMinX(_IbeamRect) + insets.top - NSWidth(windowRect);
        } else {
          if (NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect) <
              NSMinX(screenRect)) {
            windowRect.origin.x = NSMaxX(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.x =
                NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
          }
          windowRect.origin.y =
              NSMinY(_IbeamRect) + insets.left - NSHeight(windowRect);
        }
      }
    } else {  // anchor is the top left corner in screen coordinates (MinX,
              // MaxY)
      windowRect =
          NSMakeRect(NSMinX(self.frame),
                     NSMaxY(self.frame) - NSHeight(maxContentRect) -
                         insets.top - insets.bottom,
                     NSWidth(maxContentRect) + insets.left + insets.right,
                     NSHeight(maxContentRect) + insets.top + insets.bottom);
      _initPosition |= NSIntersectsRect(windowRect, _IbeamRect);
      if (_initPosition) {
        if (sweepVertical) {
          // To avoid jumping left and right while typing, use the lefter screen
          // when typing on righter, and vice versa
          if (NSMinX(_IbeamRect) - kOffsetGap -
                  NSWidth(screenRect) * textWidthRatio - insets.left -
                  insets.right >=
              NSMinX(screenRect)) {
            windowRect.origin.x =
                NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
          } else {
            windowRect.origin.x = NSMaxX(_IbeamRect) + kOffsetGap;
          }
          windowRect.origin.y =
              NSMinY(_IbeamRect) + insets.top - NSHeight(windowRect);
        } else {
          if (NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect) <
              NSMinY(screenRect)) {
            windowRect.origin.y = NSMaxY(_IbeamRect) + kOffsetGap;
          } else {
            windowRect.origin.y =
                NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
          }
          windowRect.origin.x = NSMaxX(_IbeamRect) - insets.left;
        }
      }
    }
  }

  if (_view.preeditRange.length > 0) {
    if (_initPosition) {
      _anchorOffset = 0.0;
    }
    if (theme.vertical != sweepVertical) {
      CGFloat anchorOffset =
          NSHeight([_view blockRectForRange:_view.preeditRange]);
      if (theme.vertical) {
        windowRect.origin.x += anchorOffset - _anchorOffset;
      } else {
        windowRect.origin.y += anchorOffset - _anchorOffset;
      }
      _anchorOffset = anchorOffset;
    }
  }

  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x =
        (_initPosition && sweepVertical
             ? fmin(NSMinX(_IbeamRect) - kOffsetGap, NSMaxX(screenRect))
             : NSMaxX(screenRect)) -
        NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x =
        _initPosition && sweepVertical
            ? fmax(NSMaxX(_IbeamRect) + kOffsetGap, NSMinX(screenRect))
            : NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y =
        _initPosition && !sweepVertical
            ? fmax(NSMaxY(_IbeamRect) + kOffsetGap, NSMinY(screenRect))
            : NSMinY(screenRect);
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y =
        (_initPosition && !sweepVertical
             ? fmin(NSMinY(_IbeamRect) - kOffsetGap, NSMaxY(screenRect))
             : NSMaxY(screenRect)) -
        NSHeight(windowRect);
  }

  if (theme.vertical) {
    windowRect.origin.x += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.width -= NSHeight(maxContentRect) - NSHeight(contentRect);
  } else {
    windowRect.origin.y += NSHeight(maxContentRect) - NSHeight(contentRect);
    windowRect.size.height -= NSHeight(maxContentRect) - NSHeight(contentRect);
  }
  windowRect =
      [_screen backingAlignedRect:NSIntersectionRect(windowRect, screenRect)
                          options:NSAlignAllEdgesNearest];
  [self setFrame:windowRect display:YES];

  self.contentView.boundsOrigin =
      theme.vertical ? NSMakePoint(0.0, NSWidth(windowRect)) : NSZeroPoint;
  NSRect viewRect = self.contentView.bounds;
  _view.frame = viewRect;
  _view.textView.frame = NSMakeRect(
      NSMinX(viewRect) + insets.left - _view.textView.textContainerOrigin.x,
      NSMinY(viewRect) + insets.bottom - _view.textView.textContainerOrigin.y,
      NSWidth(viewRect) - insets.left - insets.right,
      NSHeight(viewRect) - insets.top - insets.bottom);
  if (@available(macOS 10.14, *)) {
    if (theme.translucency > 0.001) {
      _back.frame = viewRect;
      _back.hidden = NO;
    } else {
      _back.hidden = YES;
    }
  }
  self.alphaValue = theme.alpha;
  [self orderFront:nil];
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
  self.expanded = NO;
  self.sectionNum = 0;
}

- (BOOL)shouldBreakLineInsideRange:(NSRange)range {
  SquirrelTheme* theme = _view.currentTheme;
  [_view.textStorage fixFontAttributeInRange:range];
  CGFloat maxTextWidth =
      _textWidthLimit - (theme.tabular ? theme.expanderWidth : 0.0);
  NSUInteger __block lineCount = 0;
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [_view getTextRangeFromCharRange:range];
    [_view.textView.textLayoutManager
        enumerateTextSegmentsInRange:textRange
                                type:NSTextLayoutManagerSegmentTypeStandard
                             options:
                                 NSTextLayoutManagerSegmentOptionsRangeNotRequired
                          usingBlock:^BOOL(
                              NSTextRange* _Nullable segRange, CGRect segFrame,
                              CGFloat baseline,
                              NSTextContainer* _Nonnull textContainer) {
                            CGFloat endEdge = ceil(NSMaxX(segFrame));
                            if (theme.tabular) {
                              endEdge = ceil((endEdge + theme.separatorWidth) /
                                             (theme.separatorWidth * 2)) *
                                        theme.separatorWidth * 2;
                            }
                            lineCount += endEdge > maxTextWidth - 0.1 ? 2 : 1;
                            return lineCount <= 1;
                          }];
  } else {
    NSRange glyphRange =
        [_view.textView.layoutManager glyphRangeForCharacterRange:range
                                             actualCharacterRange:NULL];
    [_view.textView.layoutManager
        enumerateLineFragmentsForGlyphRange:glyphRange
                                 usingBlock:^(
                                     NSRect rect, NSRect usedRect,
                                     NSTextContainer* _Nonnull textContainer,
                                     NSRange lineRange, BOOL* _Nonnull stop) {
                                   CGFloat endEdge = ceil(NSMaxX(usedRect));
                                   if (theme.tabular) {
                                     endEdge =
                                         ceil((endEdge + theme.separatorWidth) /
                                              (theme.separatorWidth * 2)) *
                                         theme.separatorWidth * 2;
                                   }
                                   lineCount +=
                                       endEdge > maxTextWidth - 0.1 ? 2 : 1;
                                 }];
  }
  return lineCount > 1;
}

- (BOOL)shouldUseTabInRange:(NSRange)range
              maxLineLength:(CGFloat*)maxLineLength {
  SquirrelTheme* theme = _view.currentTheme;
  [_view.textStorage fixFontAttributeInRange:range];
  if (theme.lineLength > 0.1) {
    *maxLineLength = fmax(_textWidthLimit, _maxSize.width);
    return YES;
  }
  CGFloat __block rangeEndEdge;
  CGFloat containerWidth;
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [_view getTextRangeFromCharRange:range];
    NSTextLayoutManager* layoutManager = _view.textView.textLayoutManager;
    [layoutManager
        enumerateTextSegmentsInRange:textRange
                                type:NSTextLayoutManagerSegmentTypeStandard
                             options:
                                 NSTextLayoutManagerSegmentOptionsRangeNotRequired
                          usingBlock:^BOOL(
                              NSTextRange* _Nullable segRange, CGRect segFrame,
                              CGFloat baseline,
                              NSTextContainer* _Nonnull textContainer) {
                            rangeEndEdge = ceil(NSMaxX(segFrame));
                            return YES;
                          }];
    containerWidth = ceil(NSMaxX(layoutManager.usageBoundsForTextContainer));
  } else {
    NSLayoutManager* layoutManager = _view.textView.layoutManager;
    NSUInteger glyphIndex =
        [layoutManager glyphIndexForCharacterAtIndex:range.location];
    rangeEndEdge = ceil(
        NSMaxX([layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex
                                                   effectiveRange:NULL]));
    containerWidth = ceil(NSMaxX(
        [layoutManager usedRectForTextContainer:_view.textView.textContainer]));
  }
  if (theme.tabular) {
    containerWidth = ceil((containerWidth - theme.expanderWidth) /
                          (theme.separatorWidth * 2)) *
                         theme.separatorWidth * 2 +
                     theme.expanderWidth;
  }
  *maxLineLength =
      fmax(*maxLineLength,
           fmax(fmin(containerWidth, _textWidthLimit), _maxSize.width));
  return *maxLineLength > rangeEndEdge - 0.1;
}

- (NSMutableAttributedString*)getPageNumString:(NSUInteger)pageNum {
  SquirrelTheme* theme = _view.currentTheme;
  if (!theme.vertical) {
    return [[NSMutableAttributedString alloc]
        initWithString:[NSString stringWithFormat:@" %lu ", pageNum + 1]
            attributes:theme.pagingAttrs];
  }
  NSAttributedString* pageNumString = [[NSAttributedString alloc]
      initWithString:[NSString stringWithFormat:@"%lu", pageNum + 1]
          attributes:theme.pagingAttrs];
  NSFont* font = theme.pagingAttrs[NSFontAttributeName];
  CGFloat height = ceil(font.ascender - font.descender);
  CGFloat width = fmax(height, ceil(pageNumString.size.width));
  NSImage* pageNumImage = [NSImage
       imageWithSize:NSMakeSize(height, width)
             flipped:YES
      drawingHandler:^BOOL(NSRect dstRect) {
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, NSWidth(dstRect) * 0.5,
                              NSHeight(dstRect) * 0.5);
        CGContextRotateCTM(context, -M_PI_2);
        CGPoint origin = CGPointMake(
            -pageNumString.size.width / width * NSHeight(dstRect) * 0.5,
            -NSWidth(dstRect) * 0.5);
        [pageNumString drawAtPoint:origin];
        CGContextRestoreGState(context);
        return YES;
      }];
  pageNumImage.resizingMode = NSImageResizingModeStretch;
  pageNumImage.size = NSMakeSize(height, height);
  NSTextAttachment* pageNumAttm = [[NSTextAttachment alloc] init];
  pageNumAttm.image = pageNumImage;
  pageNumAttm.bounds = NSMakeRect(0, font.descender, height, height);
  NSMutableAttributedString* attmString = [[NSMutableAttributedString alloc]
      initWithString:[NSString stringWithFormat:@" %C ",
                                                (unichar)NSAttachmentCharacter]
          attributes:theme.pagingAttrs];
  [attmString addAttribute:NSAttachmentAttributeName
                     value:pageNumAttm
                     range:NSMakeRange(1, 1)];
  return attmString;
}

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString*)preedit
            selRange:(NSRange)selRange
            caretPos:(NSUInteger)caretPos
    candidateIndices:(NSRange)indexRange
    highlightedIndex:(NSUInteger)highlightedIndex
             pageNum:(NSUInteger)pageNum
           finalPage:(BOOL)finalPage
          didCompose:(BOOL)didCompose {
  if (!NSIntersectsRect(_IbeamRect, _screen.frame)) {
    [self updateScreen];
    [self updateDisplayParameters];
  }
  BOOL updateCandidates = didCompose || !NSEqualRanges(_indexRange, indexRange);
  _caretAtHome = caretPos == NSNotFound ||
                 (caretPos == selRange.location && selRange.location == 1);
  _caretPos = caretPos;
  _pageNum = pageNum;
  _finalPage = finalPage;
  _functionButton = kVoidSymbol;
  if (indexRange.length > 0 || preedit.length > 0) {
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

  SquirrelTheme* theme = _view.currentTheme;
  NSTextStorage* text = _view.textStorage;
  if (updateCandidates) {
    text.attributedString = [[NSAttributedString alloc] init];
    if (theme.lineLength > 0.1) {
      _maxSize.width = fmin(theme.lineLength, _textWidthLimit);
    }
    _indexRange = indexRange;
    _highlightedIndex = highlightedIndex;
    _view.candidateRanges =
        indexRange.length > 0 ? new NSRange[indexRange.length] : NULL;
    _view.truncated =
        indexRange.length > 0 ? new BOOL[indexRange.length] : NULL;
  }
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange highlightedPreeditRange = NSMakeRange(NSNotFound, 0);
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);

  NSUInteger candidateBlockStart;
  NSUInteger lineStart;
  NSMutableParagraphStyle* paragraphStyleCandidate;
  CGFloat tabInterval = theme.separatorWidth * 2;
  CGFloat textWidthLimit =
      _textWidthLimit -
      (theme.tabular ? theme.separatorWidth + theme.expanderWidth : 0.0);
  CGFloat maxLineLength = 0.0;

  // preedit
  if (preedit) {
    NSMutableAttributedString* preeditLine =
        [[NSMutableAttributedString alloc] initWithString:preedit
                                               attributes:theme.preeditAttrs];
    [preeditLine.mutableString
        appendString:updateCandidates ? kFullWidthSpace : @"\t"];
    if (selRange.length > 0) {
      [preeditLine addAttributes:theme.preeditHighlightedAttrs range:selRange];
      highlightedPreeditRange = selRange;
      CGFloat kerning = [theme.preeditAttrs[NSKernAttributeName] doubleValue];
      if (selRange.location > 0) {
        [preeditLine addAttribute:NSKernAttributeName
                            value:@(kerning * 2)
                            range:NSMakeRange(selRange.location - 1, 1)];
      }
      if (NSMaxRange(selRange) < preedit.length) {
        [preeditLine addAttribute:NSKernAttributeName
                            value:@(kerning * 2)
                            range:NSMakeRange(NSMaxRange(selRange) - 1, 1)];
      }
    }
    [preeditLine appendAttributedString:_caretAtHome ? theme.symbolDeleteStroke
                                                     : theme.symbolDeleteFill];
    // force caret to be rendered sideways, instead of uprights, in vertical
    // orientation
    if (theme.vertical && caretPos != NSNotFound) {
      [preeditLine
          addAttribute:NSVerticalGlyphFormAttributeName
                 value:@(NO)
                 range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)),
                                   1)];
    }
    preeditRange = NSMakeRange(0, preeditLine.length);
    if (updateCandidates) {
      [text appendAttributedString:preeditLine];
      if (indexRange.length > 0) {
        [text appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:@"\n"
                                             attributes:theme.preeditAttrs]];
      } else {
        self.sectionNum = 0;
        goto alignDelete;
      }
    } else {
      NSParagraphStyle* rulerStyle =
          [text attribute:NSParagraphStyleAttributeName
                     atIndex:0
              effectiveRange:NULL];
      [preeditLine addAttribute:NSParagraphStyleAttributeName
                          value:rulerStyle
                          range:NSMakeRange(0, preeditLine.length)];
      [text replaceCharactersInRange:_view.preeditRange
                withAttributedString:preeditLine];
      [_view setPreeditRange:preeditRange
            highlightedRange:highlightedPreeditRange];
    }
  }

  if (!updateCandidates) {
    [self highlightCandidate:highlightedIndex];
    return;
  }

  // candidate items
  candidateBlockStart = text.length;
  lineStart = text.length;
  if (theme.linear) {
    paragraphStyleCandidate = theme.paragraphStyle.copy;
  }
  for (NSUInteger idx = 0; idx < indexRange.length; ++idx) {
    NSUInteger col = idx % theme.pageSize;
    // attributed labels are already included in candidateFormats
    NSMutableAttributedString* item =
        idx == highlightedIndex
            ? theme.candidateHighlightedFormats[col].mutableCopy
            : theme.candidateFormats[col].mutableCopy;
    NSRange candidateField = [item.mutableString rangeOfString:@"%@"];
    // get the label size for indent
    NSRange labelRange = NSMakeRange(0, candidateField.location);
    CGFloat labelWidth =
        theme.linear
            ? 0.0
            : ceil([item attributedSubstringFromRange:labelRange].size.width);
    // hide labels in non-highlighted pages (no selection keys)
    if (idx / theme.pageSize != _sectionNum) {
      [item addAttribute:NSForegroundColorAttributeName
                   value:[theme.labelAttrs[NSForegroundColorAttributeName]
                             blendedColorWithFraction:0.5
                                              ofColor:NSColor.clearColor]
                   range:labelRange];
    }
    // plug in candidate texts and comments into the template
    [item replaceCharactersInRange:candidateField
                        withString:_candidates[idx + indexRange.location]];

    NSRange commentField = [item.mutableString rangeOfString:kTipSpecifier];
    if (_comments[idx + indexRange.location].length > 0) {
      [item replaceCharactersInRange:commentField
                          withString:[@" " stringByAppendingString:
                                               _comments[idx +
                                                         indexRange.location]]];
    } else {
      [item deleteCharactersInRange:commentField];
    }

    [item formatMarkDown];
    CGFloat annotationHeight =
        [item annotateRubyInRange:NSMakeRange(0, item.length)
              verticalOrientation:theme.vertical
                    maximumLength:_textWidthLimit];
    if (annotationHeight * 2 > theme.linespace) {
      [self setAnnotationHeight:annotationHeight];
      paragraphStyleCandidate = theme.paragraphStyle.copy;
      [text
          enumerateAttribute:NSParagraphStyleAttributeName
                     inRange:NSMakeRange(candidateBlockStart,
                                         text.length - candidateBlockStart)
                     options:
                         NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                  usingBlock:^(NSParagraphStyle* _Nullable value, NSRange range,
                               BOOL* _Nonnull stop) {
                    NSMutableParagraphStyle* style = value.mutableCopy;
                    style.paragraphSpacing = annotationHeight;
                    style.paragraphSpacingBefore = annotationHeight;
                    [text addAttribute:NSParagraphStyleAttributeName
                                 value:style
                                 range:range];
                  }];
    }
    if (_comments[idx + indexRange.location].length > 0 &&
        [item.mutableString hasSuffix:@" "]) {
      [item deleteCharactersInRange:NSMakeRange(item.length - 1, 1)];
    }
    if (!theme.linear) {
      paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
      paragraphStyleCandidate.headIndent = labelWidth;
    }
    [item addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, item.length)];

    // determine if the line is too wide and line break is needed, based on
    // screen size.
    if (lineStart != text.length) {
      NSUInteger separatorStart = text.length;
      // separator: linear = "　"; tabular = "　\t"; stacked = "\n"
      NSAttributedString* separator = theme.separator;
      [text appendAttributedString:separator];
      [text appendAttributedString:item];
      if (theme.linear &&
          (col == 0 || ceil(item.size.width) > textWidthLimit ||
           [self shouldBreakLineInsideRange:NSMakeRange(
                                                lineStart,
                                                text.length - lineStart)])) {
        NSRange replaceRange =
            theme.tabular ? NSMakeRange(separatorStart + separator.length, 0)
                          : NSMakeRange(separatorStart, 1);
        [text replaceCharactersInRange:replaceRange withString:@"\n"];
        lineStart = separatorStart + (theme.tabular ? 3 : 1);
      }
      if (theme.tabular) {
        _view.candidateRanges[idx - 1].length += 2;
      }
    } else {  // at the start of a new line, no need to determine line break
      [text appendAttributedString:item];
    }
    // for linear layout, middle-truncate candidates that are longer than one
    // line
    if (theme.linear && ceil(item.size.width) > textWidthLimit) {
      if (idx < indexRange.length - 1 || (theme.showPaging && !theme.tabular)) {
        [text appendAttributedString:[[NSAttributedString alloc]
                                         initWithString:@"\n"
                                             attributes:theme.commentAttrs]];
      }
      NSMutableParagraphStyle* paragraphStyleTruncating =
          paragraphStyleCandidate.mutableCopy;
      paragraphStyleTruncating.lineBreakMode = NSLineBreakByTruncatingMiddle;
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleTruncating
                   range:NSMakeRange(lineStart, item.length)];
      _view.truncated[idx] = YES;
      _view.candidateRanges[idx] =
          NSMakeRange(lineStart, text.length - lineStart);
      lineStart = text.length;
    } else {
      _view.truncated[idx] = NO;
      _view.candidateRanges[idx] =
          NSMakeRange(text.length - item.length, item.length);
    }
  }

  // paging indication
  if (theme.tabular) {
    [text appendAttributedString:theme.separator];
    _view.candidateRanges[indexRange.length - 1].length += 2;
    NSUInteger pagingStart = text.length;
    NSAttributedString* expander = _locked          ? theme.symbolLock
                                   : _view.expanded ? theme.symbolCompress
                                                    : theme.symbolExpand;
    [text appendAttributedString:expander];
    paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
    if ([self shouldUseTabInRange:NSMakeRange(pagingStart - 2, 3)
                    maxLineLength:&maxLineLength]) {
      [text replaceCharactersInRange:NSMakeRange(pagingStart, 0)
                          withString:@"\t"];
      paragraphStyleCandidate.tabStops = @[];
      CGFloat candidateEndPosition = NSMaxX(
          [_view blockRectForRange:NSMakeRange(lineStart,
                                               pagingStart - 1 - lineStart)]);
      NSUInteger numTabs = (NSUInteger)ceil(candidateEndPosition / tabInterval);
      for (NSUInteger i = 1; i <= numTabs; ++i) {
        [paragraphStyleCandidate
            addTabStop:[[NSTextTab alloc]
                           initWithTextAlignment:NSTextAlignmentLeft
                                        location:i * tabInterval
                                         options:@{}]];
      }
      [paragraphStyleCandidate
          addTabStop:[[NSTextTab alloc]
                         initWithTextAlignment:NSTextAlignmentLeft
                                      location:maxLineLength -
                                               theme.expanderWidth
                                       options:@{}]];
    }
    paragraphStyleCandidate.tailIndent = 0.0;
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(lineStart, text.length - lineStart)];
  } else if (theme.showPaging) {
    NSMutableAttributedString* paging = [self getPageNumString:_pageNum];
    [paging insertAttributedString:_pageNum > 0 ? theme.symbolBackFill
                                                : theme.symbolBackStroke
                           atIndex:0];
    [paging appendAttributedString:_finalPage ? theme.symbolForwardStroke
                                              : theme.symbolForwardFill];
    [text appendAttributedString:theme.separator];
    NSUInteger pagingStart = text.length;
    [text appendAttributedString:paging];
    if (theme.linear) {
      if ([self shouldBreakLineInsideRange:NSMakeRange(
                                               lineStart,
                                               text.length - lineStart)]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 0)
                            withString:@"\n"];
        lineStart = pagingStart;
        pagingStart += 1;
      }
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length)
                      maxLineLength:&maxLineLength] ||
          lineStart != candidateBlockStart) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart - 1, 1)
                            withString:@"\t"];
        paragraphStyleCandidate = theme.paragraphStyle.mutableCopy;
        paragraphStyleCandidate.tabStops =
            @[ [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                               location:maxLineLength
                                                options:@{}] ];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStyleCandidate
                   range:NSMakeRange(lineStart, text.length - lineStart)];
    } else {
      NSMutableParagraphStyle* paragraphStylePaging =
          theme.pagingParagraphStyle.mutableCopy;
      if ([self shouldUseTabInRange:NSMakeRange(pagingStart, paging.length)
                      maxLineLength:&maxLineLength]) {
        [text replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1)
                            withString:@"\t"];
        [text replaceCharactersInRange:NSMakeRange(
                                           pagingStart + paging.length - 2, 1)
                            withString:@"\t"];
        paragraphStylePaging.tabStops = @[
          [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter
                                          location:maxLineLength * 0.5
                                           options:@{}],
          [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                          location:maxLineLength
                                           options:@{}]
        ];
      }
      [text addAttribute:NSParagraphStyleAttributeName
                   value:paragraphStylePaging
                   range:NSMakeRange(pagingStart, paging.length)];
    }
    pagingRange = NSMakeRange(text.length - paging.length, paging.length);
  }

alignDelete:
  // right-align the backward delete symbol
  if (preedit &&
      [self shouldUseTabInRange:NSMakeRange(preeditRange.length - 2, 2)
                  maxLineLength:&maxLineLength]) {
    [text replaceCharactersInRange:NSMakeRange(preeditRange.length - 2, 1)
                        withString:@"\t"];
    NSMutableParagraphStyle* paragraphStylePreedit =
        theme.preeditParagraphStyle.mutableCopy;
    paragraphStylePreedit.tabStops =
        @[ [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentRight
                                           location:maxLineLength
                                            options:@{}] ];
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStylePreedit
                 range:preeditRange];
  }

  // text done!
  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  CGFloat topMargin = preedit ? 0.0 : ceil(theme.linespace * 0.5);
  CGFloat bottomMargin =
      indexRange.length > 0 && (theme.linear || !theme.showPaging)
          ? floor(theme.linespace * 0.5)
          : 0.0;
  NSEdgeInsets insets = NSEdgeInsetsMake(
      theme.borderInset.height + topMargin,
      theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
      theme.borderInset.height + bottomMargin,
      theme.borderInset.width + floor(theme.separatorWidth * 0.5));

  self.animationBehavior = caretPos == NSNotFound
                               ? NSWindowAnimationBehaviorUtilityWindow
                               : NSWindowAnimationBehaviorDefault;
  [_view drawViewWithInsets:insets
                numCandidates:indexRange.length
             highlightedIndex:highlightedIndex
                 preeditRange:preeditRange
      highlightedPreeditRange:highlightedPreeditRange
                  pagingRange:pagingRange];
  [self show];
}

- (void)updateStatusLong:(NSString*)messageLong
             statusShort:(NSString*)messageShort {
  switch (_view.currentTheme.statusMessageType) {
    case kStatusMessageTypeMixed:
      _statusMessage = messageShort ?: messageLong;
      break;
    case kStatusMessageTypeLong:
      _statusMessage = messageLong;
      break;
    case kStatusMessageTypeShort:
      _statusMessage =
          messageShort
              ?: messageLong
                 ? [messageLong
                       substringWithRange:
                           [messageLong
                               rangeOfComposedCharacterSequenceAtIndex:0]]
                 : nil;
      break;
  }
}

- (void)showStatus:(NSString*)message {
  SquirrelTheme* theme = _view.currentTheme;

  NSTextStorage* text = _view.textStorage;
  text.attributedString = [[NSAttributedString alloc]
      initWithString:[NSString
                         stringWithFormat:@"%@ %@", kFullWidthSpace, message]
          attributes:theme.statusAttrs];

  [text ensureAttributesAreFixedInRange:NSMakeRange(0, text.length)];
  NSEdgeInsets insets = NSEdgeInsetsMake(
      theme.borderInset.height,
      theme.borderInset.width + ceil(theme.separatorWidth * 0.5),
      theme.borderInset.height,
      theme.borderInset.width + floor(theme.separatorWidth * 0.5));

  // disable remember_size and fixed line_length for status messages
  _initPosition = YES;
  _maxSize = NSZeroSize;
  if (_statusTimer.valid) {
    [_statusTimer invalidate];
  }
  self.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
  [_view drawViewWithInsets:insets
                numCandidates:0
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

- (void)hideStatus:(NSTimer*)timer {
  [self hide];
}

static void updateCandidateListLayout(BOOL* isLinear,
                                      BOOL* isTabular,
                                      SquirrelConfig* config,
                                      NSString* prefix) {
  NSString* candidateListLayout =
      [config getStringForOption:
                  [prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([candidateListLayout isEqualToString:@"stacked"]) {
    *isLinear = NO;
    *isTabular = NO;
  } else if ([candidateListLayout isEqualToString:@"linear"]) {
    *isLinear = YES;
    *isTabular = NO;
  } else if ([candidateListLayout isEqualToString:@"tabular"]) {
    // `tabular` is a derived layout of `linear`; tabular implies linear
    *isLinear = YES;
    *isTabular = YES;
  } else {
    // Deprecated. Not to be confused with text_orientation: horizontal
    NSNumber* horizontal = [config
        getOptionalBoolForOption:[prefix
                                     stringByAppendingString:@"/horizontal"]];
    if (horizontal) {
      *isLinear = horizontal.boolValue;
      *isTabular = NO;
    }
  }
}

static void updateTextOrientation(BOOL* isVertical,
                                  SquirrelConfig* config,
                                  NSString* prefix) {
  NSString* textOrientation = [config
      getStringForOption:[prefix stringByAppendingString:@"/text_orientation"]];
  if ([textOrientation isEqualToString:@"horizontal"]) {
    *isVertical = NO;
  } else if ([textOrientation isEqualToString:@"vertical"]) {
    *isVertical = YES;
  } else {
    NSNumber* vertical = [config
        getOptionalBoolForOption:[prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVertical = vertical.boolValue;
    }
  }
}

- (void)setAnnotationHeight:(CGFloat)height {
  [[_view selectTheme:defaultAppear] setAnnotationHeight:height];
  if (@available(macOS 10.14, *)) {
    [[_view selectTheme:darkAppear] setAnnotationHeight:height];
  }
}

- (void)loadLabelConfig:(SquirrelConfig*)config directUpdate:(BOOL)update {
  SquirrelTheme* theme = [_view selectTheme:defaultAppear];
  [SquirrelPanel updateTheme:theme withLabelConfig:config directUpdate:update];
  if (@available(macOS 10.14, *)) {
    SquirrelTheme* darkTheme = [_view selectTheme:darkAppear];
    [SquirrelPanel updateTheme:darkTheme
               withLabelConfig:config
                  directUpdate:update];
  }
  if (update) {
    [self updateDisplayParameters];
  }
}

+ (void)updateTheme:(SquirrelTheme*)theme
    withLabelConfig:(SquirrelConfig*)config
       directUpdate:(BOOL)update {
  NSUInteger menuSize =
      (NSUInteger)[config getIntForOption:@"menu/page_size"] ?: 5;
  NSMutableArray* labels = [[NSMutableArray alloc] initWithCapacity:menuSize];
  NSString* selectKeys =
      [config getStringForOption:@"menu/alternative_select_keys"];
  NSArray* selectLabels =
      [config getListForOption:@"menu/alternative_select_labels"];
  if (selectLabels.count > 0) {
    for (NSUInteger i = 0; i < menuSize; ++i) {
      labels[i] = selectLabels[i];
    }
  }
  if (selectKeys) {
    if (selectLabels.count == 0) {
      NSString* keyCaps = [selectKeys.uppercaseString
          stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                            reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [keyCaps substringWithRange:NSMakeRange(i, 1)];
      }
    }
  } else {
    selectKeys = [@"1234567890" substringToIndex:menuSize];
    if (selectLabels.count == 0) {
      NSString* numerals = [selectKeys
          stringByApplyingTransform:NSStringTransformFullwidthToHalfwidth
                            reverse:YES];
      for (NSUInteger i = 0; i < menuSize; ++i) {
        labels[i] = [numerals substringWithRange:NSMakeRange(i, 1)];
      }
    }
  }
  [theme setSelectKeys:selectKeys labels:labels directUpdate:update];
}

- (void)loadConfig:(SquirrelConfig*)config {
  NSSet* styleOptions = [NSSet setWithArray:self.optionSwitcher.optionStates];
  SquirrelTheme* defaultTheme = [_view selectTheme:defaultAppear];
  [SquirrelPanel updateTheme:defaultTheme
                  withConfig:config
                styleOptions:styleOptions
               forAppearance:defaultAppear];
  if (@available(macOS 10.14, *)) {
    SquirrelTheme* darkTheme = [_view selectTheme:darkAppear];
    [SquirrelPanel updateTheme:darkTheme
                    withConfig:config
                  styleOptions:styleOptions
                 forAppearance:darkAppear];
  }
  [self getLock];
  [self updateDisplayParameters];
}

// functions for post-retrieve processing
double positive(double param) {
  return fmax(0.0, param);
}
double pos_round(double param) {
  return round(fmax(0.0, param));
}
double pos_ceil(double param) {
  return ceil(fmax(0.0, param));
}
double clamp_uni(double param) {
  return fmin(1.0, fmax(0.0, param));
}

+ (void)updateTheme:(SquirrelTheme*)theme
         withConfig:(SquirrelConfig*)config
       styleOptions:(NSSet<NSString*>*)styleOptions
      forAppearance:(SquirrelAppear)appear {
  // INTERFACE
  BOOL linear = NO;
  BOOL tabular = NO;
  BOOL vertical = NO;
  updateCandidateListLayout(&linear, &tabular, config, @"style");
  updateTextOrientation(&vertical, config, @"style");
  NSNumber* inlinePreedit =
      [config getOptionalBoolForOption:@"style/inline_preedit"];
  NSNumber* inlineCandidate =
      [config getOptionalBoolForOption:@"style/inline_candidate"];
  NSNumber* showPaging = [config getOptionalBoolForOption:@"style/show_paging"];
  NSNumber* rememberSize =
      [config getOptionalBoolForOption:@"style/remember_size"];
  NSString* statusMessageType =
      [config getStringForOption:@"style/status_message_type"];
  NSString* candidateFormat =
      [config getStringForOption:@"style/candidate_format"];
  // TYPOGRAPHY
  NSString* fontName = [config getStringForOption:@"style/font_face"];
  NSNumber* fontSize = [config getOptionalDoubleForOption:@"style/font_point"
                                          applyConstraint:pos_round];
  NSString* labelFontName =
      [config getStringForOption:@"style/label_font_face"];
  NSNumber* labelFontSize =
      [config getOptionalDoubleForOption:@"style/label_font_point"
                         applyConstraint:pos_round];
  NSString* commentFontName =
      [config getStringForOption:@"style/comment_font_face"];
  NSNumber* commentFontSize =
      [config getOptionalDoubleForOption:@"style/comment_font_point"
                         applyConstraint:pos_round];
  NSNumber* alpha = [config getOptionalDoubleForOption:@"style/alpha"
                                       applyConstraint:clamp_uni];
  NSNumber* translucency =
      [config getOptionalDoubleForOption:@"style/translucency"
                         applyConstraint:clamp_uni];
  NSNumber* cornerRadius =
      [config getOptionalDoubleForOption:@"style/corner_radius"
                         applyConstraint:positive];
  NSNumber* highlightedCornerRadius =
      [config getOptionalDoubleForOption:@"style/hilited_corner_radius"
                         applyConstraint:positive];
  NSNumber* borderHeight =
      [config getOptionalDoubleForOption:@"style/border_height"
                         applyConstraint:pos_ceil];
  NSNumber* borderWidth =
      [config getOptionalDoubleForOption:@"style/border_width"
                         applyConstraint:pos_ceil];
  NSNumber* lineSpacing =
      [config getOptionalDoubleForOption:@"style/line_spacing"
                         applyConstraint:pos_round];
  NSNumber* spacing = [config getOptionalDoubleForOption:@"style/spacing"
                                         applyConstraint:pos_round];
  NSNumber* baseOffset =
      [config getOptionalDoubleForOption:@"style/base_offset"];
  NSNumber* lineLength =
      [config getOptionalDoubleForOption:@"style/line_length"];
  // CHROMATICS
  NSColor* backColor;
  NSColor* borderColor;
  NSColor* preeditBackColor;
  NSColor* textColor;
  NSColor* candidateTextColor;
  NSColor* commentTextColor;
  NSColor* candidateLabelColor;
  NSColor* highlightedBackColor;
  NSColor* highlightedTextColor;
  NSColor* highlightedCandidateBackColor;
  NSColor* highlightedCandidateTextColor;
  NSColor* highlightedCommentTextColor;
  NSColor* highlightedCandidateLabelColor;
  NSImage* backImage;

  NSString* colorScheme;
  if (appear == darkAppear) {
    for (NSString* option in styleOptions) {
      if ((colorScheme = [config
               getStringForOption:
                   [NSString stringWithFormat:@"style/%@/color_scheme_dark",
                                              option]])) {
        break;
      }
    }
    colorScheme =
        colorScheme ?: [config getStringForOption:@"style/color_scheme_dark"];
  }
  if (!colorScheme) {
    for (NSString* option in styleOptions) {
      if ((colorScheme = [config
               getStringForOption:[NSString
                                      stringWithFormat:@"style/%@/color_scheme",
                                                       option]])) {
        break;
      }
    }
    colorScheme =
        colorScheme ?: [config getStringForOption:@"style/color_scheme"];
  }
  BOOL isNative = !colorScheme || [colorScheme isEqualToString:@"native"];
  NSArray* configPrefixes =
      isNative
          ? [@"style/" stringsByAppendingPaths:styleOptions.allObjects]
          : [@[ [@"preset_color_schemes/" stringByAppendingString:colorScheme] ]
                arrayByAddingObjectsFromArray:
                    [@"style/"
                        stringsByAppendingPaths:styleOptions.allObjects]];

  // get color scheme and then check possible overrides from styleSwitcher
  for (NSString* prefix in configPrefixes) {
    // CHROMATICS override
    config.colorSpace =
        [config
            getStringForOption:[prefix stringByAppendingString:@"/color_space"]]
            ?: config.colorSpace;
    backColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/back_color"]]
            ?: backColor;
    borderColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/border_color"]]
            ?: borderColor;
    preeditBackColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/preedit_back_color"]]
            ?: preeditBackColor;
    textColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/text_color"]]
            ?: textColor;
    candidateTextColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/candidate_text_color"]]
            ?: candidateTextColor;
    commentTextColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/comment_text_color"]]
            ?: commentTextColor;
    candidateLabelColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/label_color"]]
            ?: candidateLabelColor;
    highlightedBackColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/hilited_back_color"]]
            ?: highlightedBackColor;
    highlightedTextColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/hilited_text_color"]]
            ?: highlightedTextColor;
    highlightedCandidateBackColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_candidate_back_color"]]
            ?: highlightedCandidateBackColor;
    highlightedCandidateTextColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_candidate_text_color"]]
            ?: highlightedCandidateTextColor;
    highlightedCommentTextColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_comment_text_color"]]
            ?: highlightedCommentTextColor;
    // for backward compatibility, 'label_hilited_color' and
    // 'hilited_candidate_label_color' are both valid
    highlightedCandidateLabelColor = [config getColorForOption:[prefix stringByAppendingString:@"/label_hilited_color"]] ? :
                                     [config getColorForOption:[prefix stringByAppendingString:@"/hilited_candidate_label_color"]] ? : highlightedCandidateLabelColor;
    backImage =
        [config
            getImageForOption:[prefix stringByAppendingString:@"/back_image"]]
            ?: backImage;

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style'
    // section INTERFACE override
    updateCandidateListLayout(&linear, &tabular, config, prefix);
    updateTextOrientation(&vertical, config, prefix);
    inlinePreedit =
        [config getOptionalBoolForOption:
                    [prefix stringByAppendingString:@"/inline_preedit"]]
            ?: inlinePreedit;
    inlineCandidate =
        [config getOptionalBoolForOption:
                    [prefix stringByAppendingString:@"/inline_candidate"]]
            ?: inlineCandidate;
    showPaging = [config getOptionalBoolForOption:
                             [prefix stringByAppendingString:@"/show_paging"]]
                     ?: showPaging;
    rememberSize =
        [config getOptionalBoolForOption:
                    [prefix stringByAppendingString:@"/remember_size"]]
            ?: rememberSize;
    statusMessageType =
        [config getStringForOption:
                    [prefix stringByAppendingString:@"/status_message_type"]]
            ?: statusMessageType;
    candidateFormat =
        [config getStringForOption:
                    [prefix stringByAppendingString:@"/candidate_format"]]
            ?: candidateFormat;
    // TYPOGRAPHY override
    fontName =
        [config
            getStringForOption:[prefix stringByAppendingString:@"/font_face"]]
            ?: fontName;
    fontSize = [config getOptionalDoubleForOption:
                           [prefix stringByAppendingString:@"/font_point"]
                                  applyConstraint:pos_round]
                   ?: fontSize;
    labelFontName =
        [config
            getStringForOption:[prefix
                                   stringByAppendingString:@"/label_font_face"]]
            ?: labelFontName;
    labelFontSize =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/label_font_point"]
                           applyConstraint:pos_round]
            ?: labelFontSize;
    commentFontName =
        [config getStringForOption:
                    [prefix stringByAppendingString:@"/comment_font_face"]]
            ?: commentFontName;
    commentFontSize =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/comment_font_point"]
                           applyConstraint:pos_round]
            ?: commentFontSize;
    alpha =
        [config
            getOptionalDoubleForOption:[prefix
                                           stringByAppendingString:@"/alpha"]
                       applyConstraint:clamp_uni]
            ?: alpha;
    translucency = [config getOptionalDoubleForOption:
                               [prefix stringByAppendingString:@"/translucency"]
                                      applyConstraint:clamp_uni]
                       ?: translucency;
    cornerRadius =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/corner_radius"]
                           applyConstraint:positive]
            ?: cornerRadius;
    highlightedCornerRadius =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/hilited_corner_radius"]
                           applyConstraint:positive]
            ?: highlightedCornerRadius;
    borderHeight =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/border_height"]
                           applyConstraint:pos_ceil]
            ?: borderHeight;
    borderWidth = [config getOptionalDoubleForOption:
                              [prefix stringByAppendingString:@"/border_width"]
                                     applyConstraint:pos_ceil]
                      ?: borderWidth;
    lineSpacing = [config getOptionalDoubleForOption:
                              [prefix stringByAppendingString:@"/line_spacing"]
                                     applyConstraint:pos_round]
                      ?: lineSpacing;
    spacing =
        [config
            getOptionalDoubleForOption:[prefix
                                           stringByAppendingString:@"/spacing"]
                       applyConstraint:pos_round]
            ?: spacing;
    baseOffset = [config getOptionalDoubleForOption:
                             [prefix stringByAppendingString:@"/base_offset"]]
                     ?: baseOffset;
    lineLength = [config getOptionalDoubleForOption:
                             [prefix stringByAppendingString:@"/line_length"]]
                     ?: lineLength;
  }

  // TYPOGRAPHY refinement
  fontSize = fontSize ?: @(kDefaultFontSize);
  labelFontSize = labelFontSize ?: fontSize;
  commentFontSize = commentFontSize ?: fontSize;
  NSDictionary* monoDigitAttrs = @{
    NSFontFeatureSettingsAttribute : @[
      @{
        NSFontFeatureTypeIdentifierKey : @(kNumberSpacingType),
        NSFontFeatureSelectorIdentifierKey : @(kMonospacedNumbersSelector)
      },
      @{
        NSFontFeatureTypeIdentifierKey : @(kTextSpacingType),
        NSFontFeatureSelectorIdentifierKey : @(kHalfWidthTextSelector)
      }
    ]
  };

  NSFontDescriptor* fontDescriptor = getFontDescriptor(fontName);
  NSFont* font =
      [NSFont fontWithDescriptor:fontDescriptor
                                     ?: getFontDescriptor(
                                            [NSFont userFontOfSize:0].fontName)
                            size:fontSize.doubleValue];

  NSFontDescriptor* labelFontDescriptor =
      [(getFontDescriptor(labelFontName)
            ?: fontDescriptor) fontDescriptorByAddingAttributes:monoDigitAttrs];
  NSFont* labelFont =
      labelFontDescriptor
          ? [NSFont fontWithDescriptor:labelFontDescriptor
                                  size:labelFontSize.doubleValue]
          : [NSFont monospacedDigitSystemFontOfSize:labelFontSize.doubleValue
                                             weight:NSFontWeightRegular];

  NSFontDescriptor* commentFontDescriptor = getFontDescriptor(commentFontName);
  NSFont* commentFont =
      [NSFont fontWithDescriptor:commentFontDescriptor ?: fontDescriptor
                            size:commentFontSize.doubleValue];

  NSFont* pagingFont =
      [NSFont monospacedDigitSystemFontOfSize:labelFontSize.doubleValue
                                       weight:NSFontWeightRegular];

  CGFloat fontHeight = getLineHeight(font, vertical);
  CGFloat labelFontHeight = getLineHeight(labelFont, vertical);
  CGFloat commentFontHeight = getLineHeight(commentFont, vertical);
  CGFloat lineHeight =
      fmax(fontHeight, fmax(labelFontHeight, commentFontHeight));
  CGFloat separatorWidth = ceil(
      [kFullWidthSpace sizeWithAttributes:@{NSFontAttributeName : commentFont}]
          .width);
  spacing = spacing ?: @(0.0);
  lineSpacing = lineSpacing ?: @(0.0);

  NSMutableParagraphStyle* preeditParagraphStyle =
      theme.preeditParagraphStyle.mutableCopy;
  preeditParagraphStyle.minimumLineHeight = fontHeight;
  preeditParagraphStyle.maximumLineHeight = fontHeight;
  preeditParagraphStyle.paragraphSpacing = spacing.doubleValue;
  preeditParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle* paragraphStyle = theme.paragraphStyle.mutableCopy;
  paragraphStyle.minimumLineHeight = lineHeight;
  paragraphStyle.maximumLineHeight = lineHeight;
  paragraphStyle.paragraphSpacingBefore = ceil(lineSpacing.doubleValue * 0.5);
  paragraphStyle.paragraphSpacing = floor(lineSpacing.doubleValue * 0.5);
  paragraphStyle.tabStops = @[];
  paragraphStyle.defaultTabInterval = separatorWidth * 2;

  NSMutableParagraphStyle* pagingParagraphStyle =
      theme.pagingParagraphStyle.mutableCopy;
  pagingParagraphStyle.minimumLineHeight =
      ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.maximumLineHeight =
      ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle* statusParagraphStyle =
      theme.statusParagraphStyle.mutableCopy;
  statusParagraphStyle.minimumLineHeight = commentFontHeight;
  statusParagraphStyle.maximumLineHeight = commentFontHeight;

  NSMutableDictionary* attrs = theme.attrs.mutableCopy;
  NSMutableDictionary* highlightedAttrs = theme.highlightedAttrs.mutableCopy;
  NSMutableDictionary* labelAttrs = theme.labelAttrs.mutableCopy;
  NSMutableDictionary* labelHighlightedAttrs =
      theme.labelHighlightedAttrs.mutableCopy;
  NSMutableDictionary* commentAttrs = theme.commentAttrs.mutableCopy;
  NSMutableDictionary* commentHighlightedAttrs =
      theme.commentHighlightedAttrs.mutableCopy;
  NSMutableDictionary* preeditAttrs = theme.preeditAttrs.mutableCopy;
  NSMutableDictionary* preeditHighlightedAttrs =
      theme.preeditHighlightedAttrs.mutableCopy;
  NSMutableDictionary* pagingAttrs = theme.pagingAttrs.mutableCopy;
  NSMutableDictionary* pagingHighlightedAttrs =
      theme.pagingHighlightedAttrs.mutableCopy;
  NSMutableDictionary* statusAttrs = theme.statusAttrs.mutableCopy;

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

  NSFont* zhFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(
      kCTFontUIFontSystem, fontSize.doubleValue, CFSTR("zh")));
  NSFont* zhCommentFont =
      [NSFont fontWithDescriptor:zhFont.fontDescriptor
                            size:commentFontSize.doubleValue];
  CGFloat maxFontSize =
      fmax(fontSize.doubleValue,
           fmax(commentFontSize.doubleValue, labelFontSize.doubleValue));
  NSFont* refFont = [NSFont fontWithDescriptor:zhFont.fontDescriptor
                                          size:maxFontSize];

  attrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  highlightedAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  labelAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  labelHighlightedAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  commentAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  commentHighlightedAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont
  };
  preeditAttrs[(id)kCTBaselineReferenceInfoAttributeName] =
      @{(id)kCTBaselineReferenceFont : vertical ? zhFont.verticalFont : zhFont};
  preeditHighlightedAttrs[(id)kCTBaselineReferenceInfoAttributeName] =
      @{(id)kCTBaselineReferenceFont : vertical ? zhFont.verticalFont : zhFont};
  pagingAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont :
            linear ? (vertical ? refFont.verticalFont : refFont) : pagingFont
  };
  pagingHighlightedAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont :
            linear ? (vertical ? refFont.verticalFont : refFont) : pagingFont
  };
  statusAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? zhCommentFont.verticalFont
                                            : zhCommentFont
  };

  attrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  highlightedAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  labelAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;
  labelHighlightedAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;
  commentAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  commentHighlightedAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  preeditAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  preeditHighlightedAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  statusAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  pagingAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;
  pagingHighlightedAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;

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
  preeditHighlightedAttrs[NSParagraphStyleAttributeName] =
      preeditParagraphStyle;
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  labelHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  pagingHighlightedAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  // CHROMATICS refinement
  translucency = translucency ?: @(0.0);
  if (@available(macOS 10.14, *)) {
    if (translucency.doubleValue > 0.001 && !isNative && backColor != nil &&
        (appear == darkAppear ? backColor.luminanceComponent > 0.65
                              : backColor.luminanceComponent < 0.55)) {
      backColor = [backColor invertLuminanceWithAdjustment:0];
      borderColor = [borderColor invertLuminanceWithAdjustment:0];
      preeditBackColor = [preeditBackColor invertLuminanceWithAdjustment:0];
      textColor = [textColor invertLuminanceWithAdjustment:0];
      candidateTextColor = [candidateTextColor invertLuminanceWithAdjustment:0];
      commentTextColor = [commentTextColor invertLuminanceWithAdjustment:0];
      candidateLabelColor =
          [candidateLabelColor invertLuminanceWithAdjustment:0];
      highlightedBackColor =
          [highlightedBackColor invertLuminanceWithAdjustment:-1];
      highlightedTextColor =
          [highlightedTextColor invertLuminanceWithAdjustment:1];
      highlightedCandidateBackColor =
          [highlightedCandidateBackColor invertLuminanceWithAdjustment:-1];
      highlightedCandidateTextColor =
          [highlightedCandidateTextColor invertLuminanceWithAdjustment:1];
      highlightedCommentTextColor =
          [highlightedCommentTextColor invertLuminanceWithAdjustment:1];
      highlightedCandidateLabelColor =
          [highlightedCandidateLabelColor invertLuminanceWithAdjustment:1];
    }
  }

  backColor = backColor ?: NSColor.controlBackgroundColor;
  borderColor = borderColor ?: isNative ? NSColor.gridColor : nil;
  preeditBackColor = preeditBackColor
                         ?: isNative ? NSColor.windowBackgroundColor
                                     : nil;
  textColor = textColor ?: NSColor.textColor;
  candidateTextColor = candidateTextColor ?: NSColor.controlTextColor;
  commentTextColor = commentTextColor ?: NSColor.secondaryTextColor;
  candidateLabelColor = candidateLabelColor
                            ?: isNative
                               ? NSColor.accentColor
                               : blendColors(candidateTextColor, backColor);
  highlightedBackColor = highlightedBackColor
                             ?: isNative ? NSColor.selectedTextBackgroundColor
                                         : nil;
  highlightedTextColor = highlightedTextColor ?: NSColor.selectedTextColor;
  highlightedCandidateBackColor =
      highlightedCandidateBackColor
          ?: isNative ? NSColor.selectedContentBackgroundColor
                      : nil;
  highlightedCandidateTextColor =
      highlightedCandidateTextColor ?: NSColor.selectedMenuItemTextColor;
  highlightedCommentTextColor =
      highlightedCommentTextColor ?: NSColor.alternateSelectedControlTextColor;
  highlightedCandidateLabelColor =
      highlightedCandidateLabelColor
          ?: isNative ? NSColor.alternateSelectedControlTextColor
                      : blendColors(highlightedCandidateTextColor,
                                    highlightedCandidateBackColor);

  attrs[NSForegroundColorAttributeName] = candidateTextColor;
  highlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCandidateTextColor;
  labelAttrs[NSForegroundColorAttributeName] = candidateLabelColor;
  labelHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCandidateLabelColor;
  commentAttrs[NSForegroundColorAttributeName] = commentTextColor;
  commentHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCommentTextColor;
  preeditAttrs[NSForegroundColorAttributeName] = textColor;
  preeditHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedTextColor;
  pagingAttrs[NSForegroundColorAttributeName] =
      linear && !tabular ? candidateLabelColor : textColor;
  pagingHighlightedAttrs[NSForegroundColorAttributeName] =
      linear && !tabular ? highlightedCandidateLabelColor
                         : highlightedTextColor;
  statusAttrs[NSForegroundColorAttributeName] = commentTextColor;

  NSSize borderInset =
      vertical ? NSMakeSize(borderHeight.doubleValue, borderWidth.doubleValue)
               : NSMakeSize(borderWidth.doubleValue, borderHeight.doubleValue);

  [theme setCornerRadius:fmin(cornerRadius.doubleValue, lineHeight * 0.5)
      highlightedCornerRadius:fmin(highlightedCornerRadius.doubleValue,
                                   lineHeight * 0.5)
               separatorWidth:separatorWidth
                    linespace:lineSpacing.doubleValue
             preeditLinespace:spacing.doubleValue
                        alpha:alpha ? alpha.doubleValue : 1.0
                 translucency:translucency.doubleValue
                   lineLength:lineLength.doubleValue > 0.1
                                  ? fmax(ceil(lineLength.doubleValue),
                                         separatorWidth * 5)
                                  : 0.0
                  borderInset:borderInset
                   showPaging:showPaging.boolValue
                 rememberSize:rememberSize.boolValue
                      tabular:tabular
                       linear:linear
                     vertical:vertical
                inlinePreedit:inlinePreedit.boolValue
              inlineCandidate:inlineCandidate.boolValue];

  [theme setAttrs:attrs
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

  [theme setBackColor:backColor
      highlightedCandidateBackColor:highlightedCandidateBackColor
        highlightedPreeditBackColor:highlightedBackColor
                   preeditBackColor:preeditBackColor
                        borderColor:borderColor
                          backImage:backImage];

  [theme setCandidateFormat:candidateFormat ?: kDefaultCandidateFormat];
  [theme setStatusMessageType:statusMessageType];
}

@end  // SquirrelPanel
