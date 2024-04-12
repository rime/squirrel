#import "SquirrelPanel.hh"

#import "SquirrelApplicationDelegate.hh"
#import "SquirrelConfig.hh"
#import <QuartzCore/QuartzCore.h>

static NSString* const kDefaultCandidateFormat = @"%c. %@";
static NSString* const kTipSpecifier = @"%s";
static NSString* const kFullWidthSpace = @"　";
static const NSTimeInterval kShowStatusDuration = 2.0;
static const CGFloat kBlendedBackgroundColorFraction = 0.2;
static const CGFloat kDefaultFontSize = 24;
static const CGFloat kOffsetGap = 5;

@interface NSBezierPath (BezierPathQuartzUtilities)

@property(nonatomic, readonly) CGPathRef quartzPath;

@end

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

__attribute__((objc_direct_members))
@implementation
NSMutableAttributedString(NSMutableAttributedStringMarkDownFormatting)

- (void)superscriptionRange:(NSRange)range {
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

- (void)subscriptionRange:(NSRange)range {
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

static NSString* const kMarkDownPattern =
    @"((\\*{1,2}|\\^|~{1,2})|((?<=\\b)_{1,2})|<(b|strong|i|em|u|sup|sub|s)>)(.+"
    @"?)(\\2|\\3(?=\\b)|<\\/\\4>)";

- (void)formatMarkDown {
  NSRegularExpression* regex = [NSRegularExpression.alloc
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
                        [self superscriptionRange:[result rangeAtIndex:5]];
                      } else if ([tag isEqualToString:@"~"] ||
                                 [tag isEqualToString:@"<sub>"]) {
                        [self subscriptionRange:[result rangeAtIndex:5]];
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

static NSString* const kRubyPattern =
    @"(\uFFF9\\s*)(\\S+?)(\\s*\uFFFA(.+?)\uFFFB)";

- (CGFloat)annotateRubyInRange:(NSRange)range
           verticalOrientation:(BOOL)isVertical
                 maximumLength:(CGFloat)maxLength
                 scriptVariant:(NSString*)scriptVariant {
  NSRegularExpression* regex =
      [NSRegularExpression.alloc initWithPattern:kRubyPattern
                                         options:0
                                           error:nil];
  CGFloat __block rubyLineHeight;
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
                                (CFStringRef)scriptVariant));
                        CGFloat rubyScale = 0.5;
                        CFStringRef rubyString =
                            (__bridge CFStringRef)[self.mutableString
                                substringWithRange:[result rangeAtIndex:4]];

                        CGFloat height =
                            isVertical
                                ? (baseFont.verticalFont.ascender -
                                   baseFont.verticalFont.descender)
                                : (baseFont.ascender - baseFont.descender);
                        rubyLineHeight = ceil(height * rubyScale);
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
                        } else {  // use U+008B as placeholder for line-forward
                                  // spaces in case ruby is wider than base
                          [self replaceCharactersInRange:NSMakeRange(
                                                             NSMaxRange(
                                                                 baseRange),
                                                             0)
                                              withString:[NSString
                                                             stringWithFormat:
                                                                 @"%C", 0x8B]];
                        }
                        [self addAttributes:@{
                          (id)kCTRubyAnnotationAttributeName :
                              CFBridgingRelease(rubyAnnotation),
                          NSFontAttributeName : baseFont,
                          NSVerticalGlyphFormAttributeName : @(isVertical)
                        }
                                      range:baseRange];
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

__attribute__((objc_direct_members))
@implementation
NSAttributedString(NSAttributedStringHorizontalInVerticalForms)

- (NSAttributedString*)attributedStringHorizontalInVerticalForms {
  NSMutableDictionary<NSAttributedStringKey, id>* attrs =
      [[self attributesAtIndex:0 effectiveRange:NULL] mutableCopy];
  NSFont* font = attrs[NSFontAttributeName];
  CGFloat height = ceil(font.ascender - font.descender);
  CGFloat width = fmax(height, ceil(self.size.width));
  NSImage* image = [NSImage
       imageWithSize:NSMakeSize(height, width)
             flipped:YES
      drawingHandler:^BOOL(NSRect dstRect) {
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, NSWidth(dstRect) * 0.5,
                              NSHeight(dstRect) * 0.5);
        CGContextRotateCTM(context, -M_PI_2);
        CGPoint origin =
            CGPointMake(-self.size.width / width * NSHeight(dstRect) * 0.5,
                        -NSWidth(dstRect) * 0.5);
        [self drawAtPoint:origin];
        CGContextRestoreGState(context);
        return YES;
      }];
  image.resizingMode = NSImageResizingModeStretch;
  image.size = NSMakeSize(height, height);
  NSTextAttachment* attm = NSTextAttachment.alloc.init;
  attm.image = image;
  attm.bounds = NSMakeRect(0, font.descender, height, height);
  attrs[NSAttachmentAttributeName] = attm;
  return [NSAttributedString.alloc
      initWithString:[NSString
                         stringWithCharacters:(unichar[]){NSAttachmentCharacter}
                                       length:1]
          attributes:attrs];
}

@end  // NSAttributedString (NSAttributedStringHorizontalInVerticalForms)

__attribute__((objc_direct_members))
@implementation
NSColorSpace(labColorSpace)

+ (NSColorSpace*)labColorSpace {
  static NSColorSpace* labColorSpace;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    const CGFloat whitePoint[3] = {0.950489, 1.0, 1.088840};
    const CGFloat blackPoint[3] = {0.0, 0.0, 0.0};
    const CGFloat range[4] = {-127.0, 127.0, -127.0, 127.0};
    labColorSpace = [NSColorSpace.alloc
        initWithCGColorSpace:(CGColorSpaceRef)CFAutorelease(
                                 CGColorSpaceCreateLab(whitePoint, blackPoint,
                                                       range))];
  });
  return labColorSpace;
}

@end  // NSColorSpace (labColorSpace)

__attribute__((objc_direct_members))
@implementation
NSColor(semanticColors)

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

- (NSColor*)hooverColor {
  if (@available(macOS 10.14, *)) {
    return [self colorWithSystemEffect:NSColorSystemEffectRollover];
  } else {
    return [[NSAppearance.currentAppearance bestMatchFromAppearancesWithNames:@[
      NSAppearanceNameAqua, NSAppearanceNameDarkAqua
    ]] isEqualToString:NSAppearanceNameDarkAqua]
               ? [self highlightWithLevel:0.3]
               : [self shadowWithLevel:0.3];
  }
}

- (NSColor*)disabledColor {
  if (@available(macOS 10.14, *)) {
    return [self colorWithSystemEffect:NSColorSystemEffectDisabled];
  } else {
    return [[NSAppearance.currentAppearance bestMatchFromAppearancesWithNames:@[
      NSAppearanceNameAqua, NSAppearanceNameDarkAqua
    ]] isEqualToString:NSAppearanceNameDarkAqua]
               ? [self shadowWithLevel:0.3]
               : [self highlightWithLevel:0.3];
  }
}

@end  // NSColor (semanticColors)

__attribute__((objc_direct_members))
@interface NSColor (NSColorWithLabColorSpace)

@property(nonatomic, readonly) CGFloat luminanceComponent;
@property(nonatomic, readonly) CGFloat aGnRdComponent;
@property(nonatomic, readonly) CGFloat bBuYlComponent;

@end

@implementation NSColor (NSColorWithLabColorSpace)

typedef NS_ENUM(NSInteger, ColorInversionExtent) {
  kDefaultColorInversion = 0,
  kAugmentedColorInversion = 1,
  kModerateColorInversion = -1
};

+ (NSColor*)colorWithLabLuminance:(CGFloat)luminance
                            aGnRd:(CGFloat)aGnRd
                            bBuYl:(CGFloat)bBuYl
                            alpha:(CGFloat)alpha {
  CGFloat components[4];
  components[0] = fmax(fmin(luminance, 100.0), 0.0);
  components[1] = fmax(fmin(aGnRd, 127.0), -127.0);
  components[2] = fmax(fmin(bBuYl, 127.0), -127.0);
  components[3] = fmax(fmin(alpha, 1.0), 0.0);
  return [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                           components:components
                                count:4];
}

- (void)getLuminance:(CGFloat*)luminance
               aGnRd:(CGFloat*)aGnRd
               bBuYl:(CGFloat*)bBuYl
               alpha:(CGFloat*)alpha {
  static CGFloat luminanceComponent, aGnRdComponent, bBuYlComponent,
      alphaComponent;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
    [([self.colorSpace isEqualTo:NSColorSpace.labColorSpace]
          ? self
          : [self colorUsingColorSpace:NSColorSpace.labColorSpace])
        getComponents:components];
    luminanceComponent = components[0] / 100.0;
    aGnRdComponent = components[1] / 127.0;
    bBuYlComponent = components[2] / 127.0;
    alphaComponent = components[3];
  });
  if (luminance != NULL)
    *luminance = luminanceComponent;
  if (aGnRd != NULL)
    *aGnRd = aGnRdComponent;
  if (bBuYl != NULL)
    *bBuYl = bBuYlComponent;
  if (alpha != NULL)
    *alpha = alphaComponent;
}

- (CGFloat)luminanceComponent {
  CGFloat luminance;
  [self getLuminance:&luminance aGnRd:NULL bBuYl:NULL alpha:NULL];
  return luminance;
}

- (CGFloat)aGnRdComponent {
  CGFloat aGnRdComponent;
  [self getLuminance:NULL aGnRd:&aGnRdComponent bBuYl:NULL alpha:NULL];
  return aGnRdComponent;
}

- (CGFloat)bBuYlComponent {
  CGFloat bBuYlComponent;
  [self getLuminance:NULL aGnRd:NULL bBuYl:&bBuYlComponent alpha:NULL];
  return bBuYlComponent;
}

- (NSColor*)colorByInvertingLuminanceToExtent:(ColorInversionExtent)extent {
  NSColor* labColor = [self colorUsingColorSpace:NSColorSpace.labColorSpace];
  CGFloat components[4] = {0.0, 0.0, 0.0, 1.0};
  [labColor getComponents:components];
  BOOL isDark = components[0] < 60;
  switch (extent) {
    case kAugmentedColorInversion:
      components[0] = isDark ? 100.0 - components[0] * 2.0 / 3.0
                             : 150.0 - components[0] * 1.5;
      break;
    case kModerateColorInversion:
      components[0] =
          isDark ? 80.0 - components[0] / 3.0 : 135.0 - components[0] * 1.25;
      break;
    case kDefaultColorInversion:
      components[0] =
          isDark ? 90.0 - components[0] / 2.0 : 120.0 - components[0];
      break;
  }
  NSColor* invertedColor =
      [NSColor colorWithColorSpace:NSColorSpace.labColorSpace
                        components:components
                             count:4];
  return [invertedColor colorUsingColorSpace:self.colorSpace];
}

@end  // NSColor (colorWithLabColorSpace)

#pragma mark - Color scheme and other user configurations

__attribute__((objc_direct_members))
@interface SquirrelTheme : NSObject

typedef NS_ENUM(NSUInteger, SquirrelAppear) {
  defaultAppear = 0,
  lightAppear = 0,
  darkAppear = 1
};

typedef NS_ENUM(NSUInteger, SquirrelStatusMessageType) {
  kStatusMessageTypeMixed = 0,
  kStatusMessageTypeShort = 1,
  kStatusMessageTypeLong = 2
};

@property(nonatomic, strong, readonly, nonnull) NSColor* backColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* preeditForeColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* textForeColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* commentForeColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* labelForeColor;
@property(nonatomic, strong, readonly, nonnull)
    NSColor* hilitedPreeditForeColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* hilitedTextForeColor;
@property(nonatomic, strong, readonly, nonnull)
    NSColor* hilitedCommentForeColor;
@property(nonatomic, strong, readonly, nonnull) NSColor* hilitedLabelForeColor;
@property(nonatomic, strong, readonly, nullable) NSColor* dimmedLabelForeColor;
@property(nonatomic, strong, readonly, nullable)
    NSColor* hilitedCandidateBackColor;
@property(nonatomic, strong, readonly, nullable)
    NSColor* hilitedPreeditBackColor;
@property(nonatomic, strong, readonly, nullable) NSColor* preeditBackColor;
@property(nonatomic, strong, readonly, nullable) NSColor* borderColor;
@property(nonatomic, strong, readonly, nullable) NSImage* backImage;

@property(nonatomic, readonly) CGFloat cornerRadius;
@property(nonatomic, readonly) CGFloat hilitedCornerRadius;
@property(nonatomic, readonly) CGFloat fullWidth;
@property(nonatomic, readonly) CGFloat linespace;
@property(nonatomic, readonly) CGFloat preeditLinespace;
@property(nonatomic, readonly) CGFloat opacity;
@property(nonatomic, readonly) CGFloat translucency;
@property(nonatomic, readonly) CGFloat lineLength;
@property(nonatomic, readonly) NSSize borderInsets;
@property(nonatomic, readonly) BOOL showPaging;
@property(nonatomic, readonly) BOOL rememberSize;
@property(nonatomic, readonly) BOOL tabular;
@property(nonatomic, readonly) BOOL linear;
@property(nonatomic, readonly) BOOL vertical;
@property(nonatomic, readonly) BOOL inlinePreedit;
@property(nonatomic, readonly) BOOL inlineCandidate;

@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* textAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* labelAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* commentAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* preeditAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* pagingAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSDictionary<NSAttributedStringKey, id>* statusAttrs;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* candidateParagraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* preeditParagraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* statusParagraphStyle;
@property(nonatomic, strong, readonly, nonnull)
    NSParagraphStyle* pagingParagraphStyle;
@property(nonatomic, strong, readonly, nullable)
    NSParagraphStyle* truncatedParagraphStyle;

@property(nonatomic, strong, readonly, nonnull) NSAttributedString* separator;
@property(nonatomic, strong, readonly, nonnull)
    NSAttributedString* fullWidthPlaceholder;
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

@property(nonatomic, strong, readonly, nonnull) NSArray<NSString*>* labels;
@property(nonatomic, strong, readonly, nonnull)
    NSAttributedString* candidateTemplate;
@property(nonatomic, strong, readonly, nonnull)
    NSAttributedString* candidateHilitedTemplate;
@property(nonatomic, strong, readonly, nullable)
    NSAttributedString* candidateDimmedTemplate;
@property(nonatomic, strong, readonly, nonnull) NSString* selectKeys;
@property(nonatomic, strong, readonly, nonnull) NSString* candidateFormat;
@property(nonatomic, strong, readonly, nonnull) NSString* scriptVariant;
@property(nonatomic, readonly) SquirrelStatusMessageType statusMessageType;
@property(nonatomic, readonly) NSUInteger pageSize;

- (void)updateLabelsWithConfig:(SquirrelConfig* _Nonnull)config
                  directUpdate:(BOOL)update;

- (void)setSelectKeys:(NSString* _Nonnull)selectKeys
               labels:(NSArray<NSString*>* _Nonnull)labels
         directUpdate:(BOOL)update;

- (void)setCandidateFormat:(NSString* _Nonnull)candidateFormat;

- (void)setStatusMessageType:(NSString* _Nullable)type;

- (void)updateWithConfig:(SquirrelConfig* _Nonnull)config
            styleOptions:(NSSet<NSString*>* _Nonnull)styleOptions
           scriptVariant:(NSString* _Nonnull)scriptVariant
           forAppearance:(SquirrelAppear)appear;

- (void)setAnnotationHeight:(CGFloat)height;

- (void)setScriptVariant:(NSString* _Nonnull)scriptVariant;

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
  NSArray<NSString*>* fontNames = [fullname componentsSeparatedByString:@","];
  NSMutableArray<NSFontDescriptor*>* validFontDescriptors =
      [NSMutableArray.alloc initWithCapacity:fontNames.count];
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
  NSArray<NSFontDescriptor*>* fallbackDescriptors = [[validFontDescriptors
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
  NSArray<NSFontDescriptor*>* fallbackList =
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
  self = [super init];
  if (self) {
    NSMutableParagraphStyle* candidateParagraphStyle =
        NSMutableParagraphStyle.alloc.init;
    candidateParagraphStyle.alignment = NSTextAlignmentLeft;
    candidateParagraphStyle.lineBreakStrategy = NSLineBreakStrategyNone;
    // Use left-to-right marks to declare the default writing direction and
    // prevent strong right-to-left characters from setting the writing
    // direction in case the label are direction-less symbols
    candidateParagraphStyle.baseWritingDirection =
        NSWritingDirectionLeftToRight;
    NSMutableParagraphStyle* preeditParagraphStyle =
        candidateParagraphStyle.mutableCopy;
    NSMutableParagraphStyle* pagingParagraphStyle =
        candidateParagraphStyle.mutableCopy;
    NSMutableParagraphStyle* statusParagraphStyle =
        candidateParagraphStyle.mutableCopy;
    candidateParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    preeditParagraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    statusParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;

    NSFontDescriptor* userFontDesc =
        getFontDescriptor([NSFont userFontOfSize:0.0].fontName);
    NSFontDescriptor* monoFontDesc =
        getFontDescriptor([NSFont userFixedPitchFontOfSize:0.0].fontName);
    NSFont* userFont = [NSFont fontWithDescriptor:userFontDesc
                                             size:kDefaultFontSize];
    NSFont* userMonoFont = [NSFont fontWithDescriptor:monoFontDesc
                                                 size:kDefaultFontSize];
    NSFont* monoDigitFont =
        [NSFont monospacedDigitSystemFontOfSize:kDefaultFontSize
                                         weight:NSFontWeightRegular];

    NSMutableDictionary<NSAttributedStringKey, id>* textAttrs =
        NSMutableDictionary.alloc.init;
    textAttrs[NSForegroundColorAttributeName] = NSColor.controlTextColor;
    textAttrs[NSFontAttributeName] = userFont;
    // Use left-to-right embedding to prevent right-to-left text from changing
    // the layout of the candidate.
    textAttrs[NSWritingDirectionAttributeName] = @[ @(0) ];
    textAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;

    NSMutableDictionary<NSAttributedStringKey, id>* labelAttrs =
        textAttrs.mutableCopy;
    labelAttrs[NSForegroundColorAttributeName] = NSColor.accentColor;
    labelAttrs[NSFontAttributeName] = userMonoFont;
    labelAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;

    NSMutableDictionary<NSAttributedStringKey, id>* commentAttrs =
        NSMutableDictionary.alloc.init;
    commentAttrs[NSForegroundColorAttributeName] = NSColor.secondaryTextColor;
    commentAttrs[NSFontAttributeName] = userFont;
    commentAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;

    NSMutableDictionary<NSAttributedStringKey, id>* preeditAttrs =
        NSMutableDictionary.alloc.init;
    preeditAttrs[NSForegroundColorAttributeName] = NSColor.textColor;
    preeditAttrs[NSFontAttributeName] = userFont;
    preeditAttrs[NSLigatureAttributeName] = @(0);
    preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;

    NSMutableDictionary<NSAttributedStringKey, id>* pagingAttrs =
        NSMutableDictionary.alloc.init;
    pagingAttrs[NSFontAttributeName] = monoDigitFont;
    pagingAttrs[NSForegroundColorAttributeName] = NSColor.textColor;

    NSMutableDictionary<NSAttributedStringKey, id>* statusAttrs =
        commentAttrs.mutableCopy;
    statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

    _textAttrs = textAttrs;
    _labelAttrs = labelAttrs;
    _commentAttrs = commentAttrs;
    _preeditAttrs = preeditAttrs;
    _pagingAttrs = pagingAttrs;
    _statusAttrs = statusAttrs;

    _candidateParagraphStyle = candidateParagraphStyle;
    _preeditParagraphStyle = preeditParagraphStyle;
    _pagingParagraphStyle = pagingParagraphStyle;
    _statusParagraphStyle = statusParagraphStyle;

    _backColor = NSColor.controlBackgroundColor;
    _preeditForeColor = NSColor.textColor;
    _textForeColor = NSColor.controlTextColor;
    _commentForeColor = NSColor.secondaryTextColor;
    _labelForeColor = NSColor.accentColor;
    _hilitedPreeditForeColor = NSColor.selectedTextColor;
    _hilitedTextForeColor = NSColor.selectedMenuItemTextColor;
    _hilitedCommentForeColor = NSColor.alternateSelectedControlTextColor;
    _hilitedLabelForeColor = NSColor.alternateSelectedControlTextColor;

    _selectKeys = @"12345";
    _labels = @[ @"１", @"２", @"３", @"４", @"５" ];
    _pageSize = 5;
    _candidateFormat = kDefaultCandidateFormat;
    _scriptVariant = @"zh";
    [self updateCandidateFormatForAttributesOnly:NO];
    [self updateSeperatorAndSymbolAttrs];
  }
  return self;
}

- (void)updateSeperatorAndSymbolAttrs {
  NSMutableDictionary<NSAttributedStringKey, id>* sepAttrs =
      _commentAttrs.mutableCopy;
  sepAttrs[NSVerticalGlyphFormAttributeName] = @(NO);
  _separator = [NSAttributedString.alloc
      initWithString:_linear ? (_tabular ? @"\u3000\t\x1D" : @"\u3000\x1D")
                             : @"\n"
          attributes:sepAttrs];
  _fullWidthPlaceholder =
      [NSAttributedString.alloc initWithString:kFullWidthSpace
                                    attributes:_commentAttrs];
  // Symbols for function buttons
  NSString* attmCharacter =
      [NSString stringWithCharacters:(unichar[1]){NSAttachmentCharacter}
                              length:1];

  NSTextAttachment* attmDeleteFill = NSTextAttachment.alloc.init;
  attmDeleteFill.image = [NSImage imageNamed:@"Symbols/delete.backward.fill"];
  NSMutableDictionary<NSAttributedStringKey, id>* attrsDeleteFill =
      _preeditAttrs.mutableCopy;
  attrsDeleteFill[NSAttachmentAttributeName] = attmDeleteFill;
  attrsDeleteFill[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteFill = [NSAttributedString.alloc initWithString:attmCharacter
                                                    attributes:attrsDeleteFill];

  NSTextAttachment* attmDeleteStroke = NSTextAttachment.alloc.init;
  attmDeleteStroke.image = [NSImage imageNamed:@"Symbols/delete.backward"];
  NSMutableDictionary<NSAttributedStringKey, id>* attrsDeleteStroke =
      _preeditAttrs.mutableCopy;
  attrsDeleteStroke[NSAttachmentAttributeName] = attmDeleteStroke;
  attrsDeleteStroke[NSVerticalGlyphFormAttributeName] = @(NO);
  _symbolDeleteStroke =
      [NSAttributedString.alloc initWithString:attmCharacter
                                    attributes:attrsDeleteStroke];
  if (_tabular) {
    NSTextAttachment* attmCompress = NSTextAttachment.alloc.init;
    attmCompress.image =
        [NSImage imageNamed:@"Symbols/rectangle.compress.vertical"];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsCompress =
        _pagingAttrs.mutableCopy;
    attrsCompress[NSAttachmentAttributeName] = attmCompress;
    _symbolCompress = [NSAttributedString.alloc initWithString:attmCharacter
                                                    attributes:attrsCompress];

    NSTextAttachment* attmExpand = NSTextAttachment.alloc.init;
    attmExpand.image =
        [NSImage imageNamed:@"Symbols/rectangle.expand.vertical"];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsExpand =
        _pagingAttrs.mutableCopy;
    attrsExpand[NSAttachmentAttributeName] = attmExpand;
    _symbolExpand = [NSAttributedString.alloc initWithString:attmCharacter
                                                  attributes:attrsExpand];

    NSTextAttachment* attmLock = NSTextAttachment.alloc.init;
    attmLock.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/lock%@.fill",
                                              _vertical ? @".vertical" : @""]];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsLock =
        _pagingAttrs.mutableCopy;
    attrsLock[NSAttachmentAttributeName] = attmLock;
    _symbolLock = [NSAttributedString.alloc initWithString:attmCharacter
                                                attributes:attrsLock];
  } else {
    _symbolCompress = nil;
    _symbolExpand = nil;
    _symbolLock = nil;
  }
  if (_showPaging) {
    NSTextAttachment* attmBackFill = NSTextAttachment.alloc.init;
    attmBackFill.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle.fill",
                                              _linear ? @"up" : @"left"]];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsBackFill =
        _pagingAttrs.mutableCopy;
    attrsBackFill[NSAttachmentAttributeName] = attmBackFill;
    _symbolBackFill = [NSAttributedString.alloc initWithString:attmCharacter
                                                    attributes:attrsBackFill];

    NSTextAttachment* attmBackStroke = NSTextAttachment.alloc.init;
    attmBackStroke.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle",
                                              _linear ? @"up" : @"left"]];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsBackStroke =
        _pagingAttrs.mutableCopy;
    attrsBackStroke[NSAttachmentAttributeName] = attmBackStroke;
    _symbolBackStroke =
        [NSAttributedString.alloc initWithString:attmCharacter
                                      attributes:attrsBackStroke];

    NSTextAttachment* attmForwardFill = NSTextAttachment.alloc.init;
    attmForwardFill.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle.fill",
                                              _linear ? @"down" : @"right"]];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsForwardFill =
        _pagingAttrs.mutableCopy;
    attrsForwardFill[NSAttachmentAttributeName] = attmForwardFill;
    _symbolForwardFill =
        [NSAttributedString.alloc initWithString:attmCharacter
                                      attributes:attrsForwardFill];

    NSTextAttachment* attmForwardStroke = NSTextAttachment.alloc.init;
    attmForwardStroke.image = [NSImage
        imageNamed:[NSString stringWithFormat:@"Symbols/chevron.%@.circle",
                                              _linear ? @"down" : @"right"]];
    NSMutableDictionary<NSAttributedStringKey, id>* attrsForwardStroke =
        _pagingAttrs.mutableCopy;
    attrsForwardStroke[NSAttachmentAttributeName] = attmForwardStroke;
    _symbolForwardStroke =
        [NSAttributedString.alloc initWithString:attmCharacter
                                      attributes:attrsForwardStroke];
  } else {
    _symbolBackFill = nil;
    _symbolBackStroke = nil;
    _symbolForwardFill = nil;
    _symbolForwardStroke = nil;
  }
}

- (void)updateLabelsWithConfig:(SquirrelConfig*)config
                  directUpdate:(BOOL)update {
  NSUInteger menuSize =
      (NSUInteger)[config getIntForOption:@"menu/page_size"] ?: 5;
  NSMutableArray<NSString*>* labels =
      [NSMutableArray.alloc initWithCapacity:menuSize];
  NSString* selectKeys =
      [config getStringForOption:@"menu/alternative_select_keys"];
  NSArray<NSString*>* selectLabels =
      [config getListForOption:@"menu/alternative_select_labels"];
  if (selectLabels.count > 0) {
    [labels
        addObjectsFromArray:[selectLabels
                                subarrayWithRange:NSMakeRange(0, menuSize)]];
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
  [self setSelectKeys:selectKeys labels:labels directUpdate:update];
}

- (void)setSelectKeys:(NSString*)selectKeys
               labels:(NSArray<NSString*>*)labels
         directUpdate:(BOOL)update {
  _selectKeys = selectKeys;
  _labels = labels;
  _pageSize = labels.count;
  if (update) {
    [self updateCandidateFormatForAttributesOnly:YES];
  }
}

- (void)setCandidateFormat:(NSString*)candidateFormat {
  BOOL attrsOnly = [candidateFormat isEqualToString:_candidateFormat];
  if (!attrsOnly) {
    _candidateFormat = candidateFormat;
  }
  [self updateCandidateFormatForAttributesOnly:attrsOnly];
  [self updateSeperatorAndSymbolAttrs];
}

- (void)updateCandidateFormatForAttributesOnly:(BOOL)attrsOnly {
  NSMutableAttributedString* candTemplate;
  if (!attrsOnly) {
    // validate candidate format: must have enumerator '%c' before candidate
    // '%@'
    NSMutableString* candidateFormat = _candidateFormat.mutableCopy;
    if (![candidateFormat containsString:@"%@"]) {
      [candidateFormat appendString:@"%@"];
    }
    NSRange labelRange = [candidateFormat rangeOfString:@"%c"
                                                options:NSLiteralSearch];
    if (labelRange.length == 0) {
      [candidateFormat insertString:@"%c" atIndex:0];
    }
    NSRange textRange = [candidateFormat rangeOfString:@"%@"
                                               options:NSLiteralSearch];
    if (labelRange.location > textRange.location) {
      candidateFormat.string = kDefaultCandidateFormat;
    }

    NSMutableArray<NSString*>* labels = _labels.mutableCopy;
    NSRange enumRange = NSMakeRange(0, 0);
    NSCharacterSet* labelCharacters = [NSCharacterSet
        characterSetWithCharactersInString:[labels
                                               componentsJoinedByString:@""]];
    if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF10, 10)]
            isSupersetOfSet:labelCharacters]) {  // ０１..９
      if ((enumRange = [candidateFormat rangeOfString:@"%c\u20E3"
                                              options:NSLiteralSearch])
              .length > 0) {  // 1︎⃣..9︎⃣0︎⃣
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S", (const unichar[3]){
                                          [labels[i] characterAtIndex:0] -
                                              0xFF10 + 0x0030,
                                          0xFE0E, 0x20E3}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"%c\u20DD"
                                                     options:NSLiteralSearch])
                     .length > 0) {  // ①..⑨⓪
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[1]){
                                   [labels[i] characterAtIndex:0] == 0xFF10
                                       ? 0x24EA
                                       : [labels[i] characterAtIndex:0] -
                                             0xFF11 + 0x2460}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"(%c)"
                                                     options:NSLiteralSearch])
                     .length > 0) {  // ⑴..⑼⑽
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[1]){
                                   [labels[i] characterAtIndex:0] == 0xFF10
                                       ? 0x247D
                                       : [labels[i] characterAtIndex:0] -
                                             0xFF11 + 0x2474}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"%c."
                                                     options:NSLiteralSearch])
                     .length > 0) {  // ⒈..⒐🄀
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[2]){
                                   [labels[i] characterAtIndex:0] == 0xFF10
                                       ? 0xD83C
                                       : [labels[i] characterAtIndex:0] -
                                             0xFF11 + 0x2488,
                                   [labels[i] characterAtIndex:0] == 0xFF10
                                       ? 0xDD00
                                       : 0x0}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"%c,"
                                                     options:NSLiteralSearch])
                     .length > 0) {  // 🄂..🄊🄁
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[2]){
                                   0xD83C, [labels[i] characterAtIndex:0] -
                                               0xFF10 + 0xDD01}];
        }
      }
    } else if ([[NSCharacterSet characterSetWithRange:NSMakeRange(0xFF21, 26)]
                   isSupersetOfSet:labelCharacters]) {  // Ａ..Ｚ
      if ((enumRange = [candidateFormat rangeOfString:@"%c\u20DD"
                                              options:NSLiteralSearch])
              .length > 0) {  // Ⓐ..Ⓩ
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S", (const unichar[1]){
                                          [labels[i] characterAtIndex:0] -
                                          0xFF21 + 0x24B6}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"(%c)"
                                                     options:NSLiteralSearch])
                     .length > 0) {  // 🄐..🄩
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[2]){
                                   0xD83C, [labels[i] characterAtIndex:0] -
                                               0xFF21 + 0xDD10}];
        }
      } else if ((enumRange = [candidateFormat rangeOfString:@"%c\u20DE"
                                                     options:NSLiteralSearch])
                     .length > 0) {  // 🄰..🅉
        for (NSUInteger i = 0; i < labels.count; ++i) {
          labels[i] = [NSString
              stringWithFormat:@"%S",
                               (const unichar[2]){
                                   0xD83C, [labels[i] characterAtIndex:0] -
                                               0xFF21 + 0xDD30}];
        }
      }
    }
    if (enumRange.length > 0) {
      [candidateFormat replaceCharactersInRange:enumRange withString:@"%c"];
      _labels = labels;
    }
    candTemplate =
        [NSMutableAttributedString.alloc initWithString:candidateFormat];
  } else {
    candTemplate = _candidateTemplate.mutableCopy;
  }
  // make sure label font can render all label strings
  NSString* labelString = [_labels componentsJoinedByString:@""];
  NSMutableDictionary<NSAttributedStringKey, id>* labelAttrs =
      _labelAttrs.mutableCopy;
  NSFont* labelFont = labelAttrs[NSFontAttributeName];
  NSFont* substituteFont = CFBridgingRelease(
      CTFontCreateForString((CTFontRef)labelFont, (CFStringRef)labelString,
                            CFRangeMake(0, (CFIndex)labelString.length)));
  if ([substituteFont isNotEqualTo:labelFont]) {
    NSDictionary<NSFontDescriptorAttributeName, id>* monoDigitAttrs = @{
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
    labelAttrs[NSFontAttributeName] = substituteFont;
  }

  NSRange textRange =
      [candTemplate.mutableString rangeOfString:@"%@" options:NSLiteralSearch];
  NSRange labelRange = NSMakeRange(0, textRange.location);
  NSRange commentRange = NSMakeRange(
      NSMaxRange(textRange), candTemplate.length - NSMaxRange(textRange));
  [candTemplate setAttributes:_labelAttrs range:labelRange];
  [candTemplate setAttributes:_textAttrs range:textRange];
  if (commentRange.length > 0) {
    [candTemplate setAttributes:_commentAttrs range:commentRange];
  }
  // parse markdown formats
  if (!attrsOnly) {
    [candTemplate formatMarkDown];
    // add placeholder for comment '%s'
    textRange = [candTemplate.mutableString rangeOfString:@"%@"
                                                  options:NSLiteralSearch];
    labelRange = NSMakeRange(0, textRange.location);
    commentRange = NSMakeRange(NSMaxRange(textRange),
                               candTemplate.length - NSMaxRange(textRange));
    if (commentRange.length > 0) {
      [candTemplate replaceCharactersInRange:commentRange
                                  withString:[kTipSpecifier
                                                 stringByAppendingString:
                                                     [candTemplate.mutableString
                                                         substringWithRange:
                                                             commentRange]]];
    } else {
      [candTemplate appendAttributedString:[NSAttributedString.alloc
                                               initWithString:kTipSpecifier
                                                   attributes:_commentAttrs]];
    }
    commentRange.length += kTipSpecifier.length;
    if (!_linear) {
      [candTemplate replaceCharactersInRange:NSMakeRange(textRange.location, 0)
                                  withString:@"\t"];
      labelRange.length += 1;
      textRange.location += 1;
      commentRange.location += 1;
    }
  }
  // for stacked layout, calculate head indent
  NSMutableParagraphStyle* candidateParagraphStyle =
      _candidateParagraphStyle.mutableCopy;
  if (!_linear) {
    CGFloat indent = 0.0;
    NSAttributedString* labelFormat = [candTemplate
        attributedSubstringFromRange:NSMakeRange(0, labelRange.length - 1)];
    for (NSString* label in _labels) {
      NSMutableAttributedString* enumString = labelFormat.mutableCopy;
      [enumString.mutableString
          replaceOccurrencesOfString:@"%c"
                          withString:label
                             options:NSLiteralSearch
                               range:NSMakeRange(0, enumString.length)];
      [enumString addAttribute:NSVerticalGlyphFormAttributeName
                         value:@(_vertical)
                         range:NSMakeRange(0, enumString.length)];
      indent = fmax(indent, enumString.size.width);
    }
    indent = floor(indent) + 1.0;
    candidateParagraphStyle.tabStops =
        @[ [NSTextTab.alloc initWithTextAlignment:NSTextAlignmentLeft
                                         location:indent
                                          options:@{}] ];
    candidateParagraphStyle.headIndent = indent;
  } else {
    candidateParagraphStyle.tabStops = @[];
    candidateParagraphStyle.headIndent = 0.0;
    NSMutableParagraphStyle* truncatedParagraphStyle =
        candidateParagraphStyle.mutableCopy;
    truncatedParagraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    truncatedParagraphStyle.tighteningFactorForTruncation = 0.0;
    _truncatedParagraphStyle = truncatedParagraphStyle;
  }
  _candidateParagraphStyle = candidateParagraphStyle;

  NSMutableDictionary<NSAttributedStringKey, id>* textAttrs =
      _textAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* commentAttrs =
      _commentAttrs.mutableCopy;
  textAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
  commentAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
  labelAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
  _textAttrs = textAttrs;
  _commentAttrs = commentAttrs;
  _labelAttrs = labelAttrs;

  [candTemplate addAttribute:NSParagraphStyleAttributeName
                       value:candidateParagraphStyle
                       range:NSMakeRange(0, candTemplate.length)];
  _candidateTemplate = candTemplate;
  NSMutableAttributedString* candHilitedTemplate = candTemplate.mutableCopy;
  [candHilitedTemplate addAttribute:NSForegroundColorAttributeName
                              value:_hilitedLabelForeColor
                              range:labelRange];
  [candHilitedTemplate addAttribute:NSForegroundColorAttributeName
                              value:_hilitedTextForeColor
                              range:textRange];
  [candHilitedTemplate addAttribute:NSForegroundColorAttributeName
                              value:_hilitedCommentForeColor
                              range:commentRange];
  _candidateHilitedTemplate = candHilitedTemplate;
  if (_tabular) {
    NSMutableAttributedString* candDimmedTemplate = candTemplate.mutableCopy;
    [candDimmedTemplate addAttribute:NSForegroundColorAttributeName
                               value:_dimmedLabelForeColor
                               range:labelRange];
    _candidateDimmedTemplate = candDimmedTemplate;
  }
}

- (void)setStatusMessageType:(NSString*)type {
  if ([@"long" caseInsensitiveCompare:type] == NSOrderedSame) {
    _statusMessageType = kStatusMessageTypeLong;
  } else if ([@"short" caseInsensitiveCompare:type] == NSOrderedSame) {
    _statusMessageType = kStatusMessageTypeShort;
  } else {
    _statusMessageType = kStatusMessageTypeMixed;
  }
}

static void updateCandidateListLayout(BOOL* isLinear,
                                      BOOL* isTabular,
                                      SquirrelConfig* config,
                                      NSString* prefix) {
  NSString* candidateListLayout =
      [config getStringForOption:
                  [prefix stringByAppendingString:@"/candidate_list_layout"]];
  if ([@"stacked" caseInsensitiveCompare:candidateListLayout] ==
      NSOrderedSame) {
    *isLinear = NO;
    *isTabular = NO;
  } else if ([@"linear" caseInsensitiveCompare:candidateListLayout] ==
             NSOrderedSame) {
    *isLinear = YES;
    *isTabular = NO;
  } else if ([@"tabular" caseInsensitiveCompare:candidateListLayout] ==
             NSOrderedSame) {
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
  if ([@"horizontal" caseInsensitiveCompare:textOrientation] == NSOrderedSame) {
    *isVertical = NO;
  } else if ([@"vertical" caseInsensitiveCompare:textOrientation] ==
             NSOrderedSame) {
    *isVertical = YES;
  } else {
    NSNumber* vertical = [config
        getOptionalBoolForOption:[prefix stringByAppendingString:@"/vertical"]];
    if (vertical) {
      *isVertical = vertical.boolValue;
    }
  }
}

// functions for post-retrieve processing
static double inline positive(double param) {
  return param > 0.0 ? param : 0.0;
}
static double inline pos_round(double param) {
  return param > 0.0 ? round(param) : 0.0;
}
static double inline pos_ceil(double param) {
  return param > 0.0 ? ceil(param) : 0.0;
}
static double inline clamp_uni(double param) {
  return param > 0.0 ? (param < 1.0 ? param : 1.0) : 0.0;
}

- (void)updateWithConfig:(SquirrelConfig*)config
            styleOptions:(NSSet<NSString*>*)styleOptions
           scriptVariant:(NSString*)scriptVariant
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
  NSNumber* opacity = [config getOptionalDoubleForOption:@"style/opacity"
                                                   alias:@"alpha"
                                         applyConstraint:clamp_uni];
  NSNumber* translucency =
      [config getOptionalDoubleForOption:@"style/translucency"
                         applyConstraint:clamp_uni];
  NSNumber* cornerRadius =
      [config getOptionalDoubleForOption:@"style/corner_radius"
                         applyConstraint:positive];
  NSNumber* hilitedCornerRadius =
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
  NSColor* preeditForeColor;
  NSColor* textForeColor;
  NSColor* commentForeColor;
  NSColor* labelForeColor;
  NSColor* hilitedPreeditBackColor;
  NSColor* hilitedPreeditForeColor;
  NSColor* hilitedCandidateBackColor;
  NSColor* hilitedTextForeColor;
  NSColor* hilitedCommentForeColor;
  NSColor* hilitedLabelForeColor;
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
  BOOL isNative =
      !colorScheme ||
      [@"native" caseInsensitiveCompare:colorScheme] == NSOrderedSame;
  NSArray<NSString*>* configPrefixes =
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
    preeditForeColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/text_color"]]
            ?: preeditForeColor;
    textForeColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/candidate_text_color"]]
            ?: textForeColor;
    commentForeColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/comment_text_color"]]
            ?: commentForeColor;
    labelForeColor =
        [config
            getColorForOption:[prefix stringByAppendingString:@"/label_color"]]
            ?: labelForeColor;
    hilitedPreeditBackColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/hilited_back_color"]]
            ?: hilitedPreeditBackColor;
    hilitedPreeditForeColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/hilited_text_color"]]
            ?: hilitedPreeditForeColor;
    hilitedCandidateBackColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_candidate_back_color"]]
            ?: hilitedCandidateBackColor;
    hilitedTextForeColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_candidate_text_color"]]
            ?: hilitedTextForeColor;
    hilitedCommentForeColor =
        [config getColorForOption:[prefix stringByAppendingString:
                                              @"/hilited_comment_text_color"]]
            ?: hilitedCommentForeColor;
    // for backward compatibility, 'label_hilited_color' and
    // 'hilited_candidate_label_color' are both valid
    hilitedLabelForeColor =
        [config getColorForOption:
                    [prefix stringByAppendingString:@"/label_hilited_color"]
                            alias:@"hilited_candidate_label_color"]
            ?: hilitedLabelForeColor;
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
    opacity =
        [config
            getOptionalDoubleForOption:[prefix
                                           stringByAppendingString:@"/opacity"]
                                 alias:@"alpha"
                       applyConstraint:clamp_uni]
            ?: opacity;
    translucency = [config getOptionalDoubleForOption:
                               [prefix stringByAppendingString:@"/translucency"]
                                      applyConstraint:clamp_uni]
                       ?: translucency;
    cornerRadius =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/corner_radius"]
                           applyConstraint:positive]
            ?: cornerRadius;
    hilitedCornerRadius =
        [config getOptionalDoubleForOption:
                    [prefix stringByAppendingString:@"/hilited_corner_radius"]
                           applyConstraint:positive]
            ?: hilitedCornerRadius;
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
  NSDictionary<NSFontDescriptorAttributeName, id>* monoDigitAttrs = @{
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
  CGFloat fullWidth = ceil(
      [kFullWidthSpace sizeWithAttributes:@{NSFontAttributeName : commentFont}]
          .width);
  spacing = spacing ?: @(0.0);
  lineSpacing = lineSpacing ?: @(0.0);

  NSMutableParagraphStyle* preeditParagraphStyle =
      _preeditParagraphStyle.mutableCopy;
  preeditParagraphStyle.minimumLineHeight = fontHeight;
  preeditParagraphStyle.maximumLineHeight = fontHeight;
  preeditParagraphStyle.paragraphSpacing = spacing.doubleValue;
  preeditParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle* candidateParagraphStyle =
      _candidateParagraphStyle.mutableCopy;
  candidateParagraphStyle.alignment =
      linear ? NSTextAlignmentNatural : NSTextAlignmentLeft;
  candidateParagraphStyle.minimumLineHeight = lineHeight;
  candidateParagraphStyle.maximumLineHeight = lineHeight;
  candidateParagraphStyle.paragraphSpacingBefore =
      linear ? 0.0 : ceil(lineSpacing.doubleValue * 0.5);
  candidateParagraphStyle.paragraphSpacing =
      linear ? 0.0 : floor(lineSpacing.doubleValue * 0.5);
  candidateParagraphStyle.lineSpacing = linear ? lineSpacing.doubleValue : 0.0;
  candidateParagraphStyle.tabStops = @[];
  candidateParagraphStyle.defaultTabInterval = fullWidth * 2;

  NSMutableParagraphStyle* pagingParagraphStyle =
      _pagingParagraphStyle.mutableCopy;
  pagingParagraphStyle.minimumLineHeight =
      ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.maximumLineHeight =
      ceil(pagingFont.ascender - pagingFont.descender);
  pagingParagraphStyle.tabStops = @[];

  NSMutableParagraphStyle* statusParagraphStyle =
      _statusParagraphStyle.mutableCopy;
  statusParagraphStyle.minimumLineHeight = commentFontHeight;
  statusParagraphStyle.maximumLineHeight = commentFontHeight;

  NSMutableDictionary<NSAttributedStringKey, id>* textAttrs =
      _textAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* labelAttrs =
      _labelAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* commentAttrs =
      _commentAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* preeditAttrs =
      _preeditAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* pagingAttrs =
      _pagingAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* statusAttrs =
      _statusAttrs.mutableCopy;

  textAttrs[NSFontAttributeName] = font;
  labelAttrs[NSFontAttributeName] = labelFont;
  commentAttrs[NSFontAttributeName] = commentFont;
  preeditAttrs[NSFontAttributeName] = font;
  pagingAttrs[NSFontAttributeName] = pagingFont;
  statusAttrs[NSFontAttributeName] = commentFont;

  NSFont* zhFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(
      kCTFontUIFontSystem, fontSize.doubleValue, (CFStringRef)scriptVariant));
  NSFont* zhCommentFont =
      [NSFont fontWithDescriptor:zhFont.fontDescriptor
                            size:commentFontSize.doubleValue];
  CGFloat maxFontSize =
      fmax(fontSize.doubleValue,
           fmax(commentFontSize.doubleValue, labelFontSize.doubleValue));
  NSFont* refFont = [NSFont fontWithDescriptor:zhFont.fontDescriptor
                                          size:maxFontSize];

  NSDictionary* baselineRefInfo = @{
    (id)kCTBaselineReferenceFont : vertical ? refFont.verticalFont : refFont,
    (id)kCTBaselineClassIdeographicCentered :
        @(vertical ? 0.0 : refFont.ascender * 0.5 + refFont.descender * 0.5),
    (id)kCTBaselineClassRoman :
        @(vertical ? -refFont.verticalFont.ascender * 0.5 -
                         refFont.verticalFont.descender * 0.5
                   : 0.0),
    (id)kCTBaselineClassIdeographicLow :
        @(vertical ? refFont.verticalFont.descender * 0.5 -
                         refFont.verticalFont.ascender * 0.5
                   : refFont.descender)
  };

  textAttrs[(id)kCTBaselineReferenceInfoAttributeName] = baselineRefInfo;
  labelAttrs[(id)kCTBaselineReferenceInfoAttributeName] = baselineRefInfo;
  commentAttrs[(id)kCTBaselineReferenceInfoAttributeName] = baselineRefInfo;
  preeditAttrs[(id)kCTBaselineReferenceInfoAttributeName] =
      @{(id)kCTBaselineReferenceFont : vertical ? zhFont.verticalFont : zhFont};
  pagingAttrs[(id)kCTBaselineReferenceInfoAttributeName] =
      @{(id)kCTBaselineReferenceFont : pagingFont};
  statusAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : vertical ? zhCommentFont.verticalFont
                                            : zhCommentFont
  };

  textAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  labelAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;
  commentAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  preeditAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  statusAttrs[(id)kCTBaselineClassAttributeName] =
      vertical ? (id)kCTBaselineClassIdeographicCentered
               : (id)kCTBaselineClassRoman;
  pagingAttrs[(id)kCTBaselineClassAttributeName] =
      (id)kCTBaselineClassIdeographicCentered;

  textAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  labelAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  commentAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  preeditAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  statusAttrs[(id)kCTLanguageAttributeName] = scriptVariant;

  textAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  labelAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  commentAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  preeditAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  pagingAttrs[NSBaselineOffsetAttributeName] = baseOffset;
  statusAttrs[NSBaselineOffsetAttributeName] = baseOffset;

  preeditAttrs[NSParagraphStyleAttributeName] = preeditParagraphStyle;
  pagingAttrs[NSParagraphStyleAttributeName] = pagingParagraphStyle;
  statusAttrs[NSParagraphStyleAttributeName] = statusParagraphStyle;

  labelAttrs[NSVerticalGlyphFormAttributeName] = @(vertical);
  pagingAttrs[NSVerticalGlyphFormAttributeName] = @(NO);

  // CHROMATICS refinement
  translucency = translucency ?: @(0.0);
  if (@available(macOS 10.14, *)) {
    if (translucency.doubleValue > 0.001 && !isNative && backColor != nil &&
        (appear == darkAppear ? backColor.luminanceComponent > 0.65
                              : backColor.luminanceComponent < 0.55)) {
      backColor =
          [backColor colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      borderColor = [borderColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      preeditBackColor = [preeditBackColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      preeditForeColor = [preeditForeColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      textForeColor = [textForeColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      commentForeColor = [commentForeColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      labelForeColor = [labelForeColor
          colorByInvertingLuminanceToExtent:kDefaultColorInversion];
      hilitedPreeditBackColor = [hilitedPreeditBackColor
          colorByInvertingLuminanceToExtent:kModerateColorInversion];
      hilitedPreeditForeColor = [hilitedPreeditForeColor
          colorByInvertingLuminanceToExtent:kAugmentedColorInversion];
      hilitedCandidateBackColor = [hilitedCandidateBackColor
          colorByInvertingLuminanceToExtent:kModerateColorInversion];
      hilitedTextForeColor = [hilitedTextForeColor
          colorByInvertingLuminanceToExtent:kAugmentedColorInversion];
      hilitedCommentForeColor = [hilitedCommentForeColor
          colorByInvertingLuminanceToExtent:kAugmentedColorInversion];
      hilitedLabelForeColor = [hilitedLabelForeColor
          colorByInvertingLuminanceToExtent:kAugmentedColorInversion];
    }
  }

  backColor = backColor ?: NSColor.controlBackgroundColor;
  borderColor = borderColor ?: isNative ? NSColor.gridColor : nil;
  preeditBackColor = preeditBackColor
                         ?: isNative ? NSColor.windowBackgroundColor
                                     : nil;
  preeditForeColor = preeditForeColor ?: NSColor.textColor;
  textForeColor = textForeColor ?: NSColor.controlTextColor;
  commentForeColor = commentForeColor ?: NSColor.secondaryTextColor;
  labelForeColor = labelForeColor
                       ?: isNative ? NSColor.accentColor
                                   : blendColors(textForeColor, backColor);
  hilitedPreeditBackColor = hilitedPreeditBackColor
                                ?: isNative
                                   ? NSColor.selectedTextBackgroundColor
                                   : nil;
  hilitedPreeditForeColor =
      hilitedPreeditForeColor ?: NSColor.selectedTextColor;
  hilitedCandidateBackColor = hilitedCandidateBackColor
                                  ?: isNative
                                     ? NSColor.selectedContentBackgroundColor
                                     : nil;
  hilitedTextForeColor =
      hilitedTextForeColor ?: NSColor.selectedMenuItemTextColor;
  hilitedCommentForeColor =
      hilitedCommentForeColor ?: NSColor.alternateSelectedControlTextColor;
  hilitedLabelForeColor =
      hilitedLabelForeColor
          ?: isNative
             ? NSColor.alternateSelectedControlTextColor
             : blendColors(hilitedTextForeColor, hilitedCandidateBackColor);

  textAttrs[NSForegroundColorAttributeName] = textForeColor;
  labelAttrs[NSForegroundColorAttributeName] = labelForeColor;
  commentAttrs[NSForegroundColorAttributeName] = commentForeColor;
  preeditAttrs[NSForegroundColorAttributeName] = preeditForeColor;
  pagingAttrs[NSForegroundColorAttributeName] = preeditForeColor;
  statusAttrs[NSForegroundColorAttributeName] = commentForeColor;

  _cornerRadius = fmin(cornerRadius.doubleValue, lineHeight * 0.5);
  _hilitedCornerRadius =
      fmin(hilitedCornerRadius.doubleValue, lineHeight * 0.5);
  _fullWidth = fullWidth;
  _linespace = lineSpacing.doubleValue;
  _preeditLinespace = spacing.doubleValue;
  _opacity = opacity ? opacity.doubleValue : 1.0;
  _translucency = translucency.doubleValue;
  _lineLength = lineLength.doubleValue > 0.1
                    ? fmax(ceil(lineLength.doubleValue), fullWidth * 5)
                    : 0.0;
  _borderInsets =
      vertical ? NSMakeSize(borderHeight.doubleValue, borderWidth.doubleValue)
               : NSMakeSize(borderWidth.doubleValue, borderHeight.doubleValue);
  _showPaging = showPaging.boolValue;
  _rememberSize = rememberSize.boolValue;
  _tabular = tabular;
  _linear = linear;
  _vertical = vertical;
  _inlinePreedit = inlinePreedit.boolValue;
  _inlineCandidate = inlineCandidate.boolValue;

  _textAttrs = textAttrs;
  _labelAttrs = labelAttrs;
  _commentAttrs = commentAttrs;
  _preeditAttrs = preeditAttrs;
  _pagingAttrs = pagingAttrs;
  _statusAttrs = statusAttrs;

  _candidateParagraphStyle = candidateParagraphStyle;
  _preeditParagraphStyle = preeditParagraphStyle;
  _pagingParagraphStyle = pagingParagraphStyle;
  _statusParagraphStyle = statusParagraphStyle;

  _backImage = backImage;
  _backColor = backColor;
  _preeditBackColor = preeditBackColor;
  _hilitedPreeditBackColor = hilitedPreeditBackColor;
  _hilitedCandidateBackColor = hilitedCandidateBackColor;
  _borderColor = borderColor;
  _preeditForeColor = preeditForeColor;
  _textForeColor = textForeColor;
  _commentForeColor = commentForeColor;
  _labelForeColor = labelForeColor;
  _hilitedPreeditForeColor = hilitedPreeditForeColor;
  _hilitedTextForeColor = hilitedTextForeColor;
  _hilitedCommentForeColor = hilitedCommentForeColor;
  _hilitedLabelForeColor = hilitedLabelForeColor;
  _dimmedLabelForeColor =
      tabular ? [labelForeColor
                    colorWithAlphaComponent:labelForeColor.alphaComponent * 0.2]
              : nil;

  _scriptVariant = scriptVariant;
  [self setCandidateFormat:candidateFormat ?: kDefaultCandidateFormat];
  [self setStatusMessageType:statusMessageType];
}

- (void)setAnnotationHeight:(CGFloat)height {
  if (height > 0.1 && _linespace < height * 2) {
    _linespace = height * 2;
    NSMutableParagraphStyle* candidateParagraphStyle =
        _candidateParagraphStyle.mutableCopy;
    if (_linear) {
      candidateParagraphStyle.lineSpacing = height * 2;
      NSMutableParagraphStyle* truncatedParagraphStyle =
          candidateParagraphStyle.mutableCopy;
      truncatedParagraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
      truncatedParagraphStyle.tighteningFactorForTruncation = 0.0;
      _truncatedParagraphStyle = truncatedParagraphStyle;
    } else {
      candidateParagraphStyle.paragraphSpacingBefore = height;
      candidateParagraphStyle.paragraphSpacing = height;
    }
    _candidateParagraphStyle = candidateParagraphStyle;

    NSMutableDictionary<NSAttributedStringKey, id>* textAttrs =
        _textAttrs.mutableCopy;
    NSMutableDictionary<NSAttributedStringKey, id>* commentAttrs =
        _commentAttrs.mutableCopy;
    NSMutableDictionary<NSAttributedStringKey, id>* labelAttrs =
        _labelAttrs.mutableCopy;
    textAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
    commentAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
    labelAttrs[NSParagraphStyleAttributeName] = candidateParagraphStyle;
    _textAttrs = textAttrs;
    _commentAttrs = commentAttrs;
    _labelAttrs = labelAttrs;

    NSMutableAttributedString* candTemplate = _candidateTemplate.mutableCopy;
    [candTemplate addAttribute:NSParagraphStyleAttributeName
                         value:candidateParagraphStyle
                         range:NSMakeRange(0, candTemplate.length)];
    _candidateTemplate = candTemplate;
    NSMutableAttributedString* candHilitedTemplate =
        _candidateHilitedTemplate.mutableCopy;
    [candHilitedTemplate
        addAttribute:NSParagraphStyleAttributeName
               value:candidateParagraphStyle
               range:NSMakeRange(0, candHilitedTemplate.length)];
    _candidateHilitedTemplate = candHilitedTemplate;
    if (_tabular) {
      NSMutableAttributedString* candDimmedTemplate =
          _candidateDimmedTemplate.mutableCopy;
      [candDimmedTemplate
          addAttribute:NSParagraphStyleAttributeName
                 value:candidateParagraphStyle
                 range:NSMakeRange(0, candDimmedTemplate.length)];
      _candidateDimmedTemplate = candDimmedTemplate;
    }
  }
}

- (void)setScriptVariant:(NSString*)scriptVariant {
  if ([scriptVariant isEqualToString:_scriptVariant]) {
    return;
  }
  _scriptVariant = scriptVariant;

  NSMutableDictionary<NSAttributedStringKey, id>* textAttrs =
      _textAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* labelAttrs =
      _labelAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* commentAttrs =
      _commentAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* preeditAttrs =
      _preeditAttrs.mutableCopy;
  NSMutableDictionary<NSAttributedStringKey, id>* statusAttrs =
      _statusAttrs.mutableCopy;

  CGFloat fontSize = [textAttrs[NSFontAttributeName] pointSize];
  CGFloat commentFontSize = [commentAttrs[NSFontAttributeName] pointSize];
  CGFloat labelFontSize = [labelAttrs[NSFontAttributeName] pointSize];
  NSFont* zhFont = CFBridgingRelease(CTFontCreateUIFontForLanguage(
      kCTFontUIFontSystem, fontSize, (CFStringRef)scriptVariant));
  NSFont* zhCommentFont = [NSFont fontWithDescriptor:zhFont.fontDescriptor
                                                size:commentFontSize];
  CGFloat maxFontSize = fmax(fontSize, fmax(commentFontSize, labelFontSize));
  NSFont* refFont = [NSFont fontWithDescriptor:zhFont.fontDescriptor
                                          size:maxFontSize];

  textAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : _vertical ? refFont.verticalFont : refFont
  };
  labelAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : _vertical ? refFont.verticalFont : refFont
  };
  commentAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : _vertical ? refFont.verticalFont : refFont
  };
  preeditAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : _vertical ? zhFont.verticalFont : zhFont
  };
  statusAttrs[(id)kCTBaselineReferenceInfoAttributeName] = @{
    (id)kCTBaselineReferenceFont : _vertical ? zhCommentFont.verticalFont
                                             : zhCommentFont
  };

  textAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  labelAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  commentAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  preeditAttrs[(id)kCTLanguageAttributeName] = scriptVariant;
  statusAttrs[(id)kCTLanguageAttributeName] = scriptVariant;

  _textAttrs = textAttrs;
  _labelAttrs = labelAttrs;
  _commentAttrs = commentAttrs;
  _preeditAttrs = preeditAttrs;
  _statusAttrs = statusAttrs;
}

@end  // SquirrelTheme

#pragma mark - Typesetting extensions for TextKit 1 (Mac OSX 10.9 to MacOS 11)

__attribute__((objc_direct_members))
@interface SquirrelLayoutManager : NSLayoutManager<NSLayoutManagerDelegate>
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
  BOOL didModify = NO;
  BOOL verticalOrientation = (BOOL)textContainer.layoutOrientation;
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                actualGlyphRange:NULL];
  NSParagraphStyle* rulerAttrs =
      [layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                   atIndex:charRange.location
                            effectiveRange:NULL];
  CGFloat lineSpacing = rulerAttrs.lineSpacing;
  CGFloat lineHeight = rulerAttrs.minimumLineHeight;
  CGFloat baseline = lineHeight * 0.5;
  if (!verticalOrientation) {
    NSFont* refFont = [layoutManager.textStorage
             attribute:(id)kCTBaselineReferenceInfoAttributeName
               atIndex:charRange.location
        effectiveRange:NULL][(id)kCTBaselineReferenceFont];
    baseline += refFont.ascender * 0.5 + refFont.descender * 0.5;
  }
  CGFloat lineHeightDelta =
      lineFragmentUsedRect->size.height - lineHeight - lineSpacing;
  if (fabs(lineHeightDelta) > 0.1) {
    lineFragmentUsedRect->size.height =
        round(lineFragmentUsedRect->size.height - lineHeightDelta);
    lineFragmentRect->size.height =
        round(lineFragmentRect->size.height - lineHeightDelta);
    didModify |= YES;
  }
  // move half of the linespacing above the line fragment
  if (lineSpacing > 0.1) {
    baseline += lineSpacing * 0.5;
  }
  CGFloat newBaselineOffset = floor(lineFragmentUsedRect->origin.y -
                                    lineFragmentRect->origin.y + baseline);
  if (fabs(*baselineOffset - newBaselineOffset) > 0.1) {
    *baselineOffset = newBaselineOffset;
    didModify |= YES;
  }
  return didModify;
}

- (BOOL)layoutManager:(NSLayoutManager*)layoutManager
    shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex {
  if (charIndex <= 1) {
    return YES;
  } else {
    unichar charBeforeIndex = [layoutManager.textStorage.mutableString
        characterAtIndex:charIndex - 1];
    NSTextAlignment alignment =
        [[layoutManager.textStorage attribute:NSParagraphStyleAttributeName
                                      atIndex:charIndex
                               effectiveRange:NULL] alignment];
    if (alignment == NSTextAlignmentNatural) {  // candidates in linear layout
      return charBeforeIndex == 0x1D;
    } else {
      return charBeforeIndex != '\t';
    }
  }
}

- (NSControlCharacterAction)layoutManager:(NSLayoutManager*)layoutManager
                          shouldUseAction:(NSControlCharacterAction)action
               forControlCharacterAtIndex:(NSUInteger)charIndex {
  if (charIndex > 0 &&
      [layoutManager.textStorage.mutableString characterAtIndex:charIndex] ==
          0x8B &&
      [layoutManager.textStorage attribute:(id)kCTRubyAnnotationAttributeName
                                   atIndex:charIndex - 1
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
  if (charIndex > 0 && [layoutManager.textStorage.mutableString
                           characterAtIndex:charIndex] == 0x8B) {
    NSRange rubyRange;
    id rubyAnnotation =
        [layoutManager.textStorage attribute:(id)kCTRubyAnnotationAttributeName
                                     atIndex:charIndex - 1
                              effectiveRange:&rubyRange];
    if (rubyAnnotation) {
      NSAttributedString* rubyString =
          [layoutManager.textStorage attributedSubstringFromRange:rubyRange];
      CTLineRef line =
          CTLineCreateWithAttributedString((CFAttributedStringRef)rubyString);
      CGRect rubyRect =
          CTLineGetBoundsWithOptions((CTLineRef)CFAutorelease(line), 0);
      width = fdim(rubyRect.size.width, rubyString.size.width);
    }
  }
  return NSMakeRect(glyphPosition.x, 0.0, width, glyphPosition.y);
}

@end  // SquirrelLayoutManager

#pragma mark - Typesetting extensions for TextKit 2 (MacOS 12 or higher)

API_AVAILABLE(macos(12.0))
@interface SquirrelTextLayoutFragment : NSTextLayoutFragment

@property(nonatomic) CGFloat topMargin;

@end

@implementation SquirrelTextLayoutFragment

@synthesize topMargin;

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
    CGFloat lineSpacing =
        [[lineFrag.attributedString attribute:NSParagraphStyleAttributeName
                                      atIndex:lineFrag.characterRange.location
                               effectiveRange:NULL] lineSpacing];
    CGFloat baseline = CGRectGetMidY(lineRect) - lineSpacing * 0.5;
    if (!verticalOrientation) {
      NSFont* refFont = [lineFrag.attributedString
               attribute:(id)kCTBaselineReferenceInfoAttributeName
                 atIndex:lineFrag.characterRange.location
          effectiveRange:NULL][(id)kCTBaselineReferenceFont];
      baseline += refFont.ascender * 0.5 + refFont.descender * 0.5;
    }
    CGPoint renderOrigin =
        CGPointMake(NSMinX(lineRect) + lineFrag.glyphOrigin.x,
                    ceil(baseline) - lineFrag.glyphOrigin.y);
    CGPoint deviceOrigin =
        CGContextConvertPointToDeviceSpace(context, renderOrigin);
    renderOrigin = CGContextConvertPointToUserSpace(
        context, CGPointMake(round(deviceOrigin.x), round(deviceOrigin.y)));
    [lineFrag drawAtPoint:renderOrigin inContext:context];
  }
}

@end  // SquirrelTextLayoutFragment

__attribute__((objc_direct_members)) API_AVAILABLE(macos(12.0))
    @interface SquirrelTextLayoutManager
    : NSTextLayoutManager<NSTextLayoutManagerDelegate>
@end

@implementation SquirrelTextLayoutManager

- (BOOL)textLayoutManager:(NSTextLayoutManager*)textLayoutManager
    shouldBreakLineBeforeLocation:(id<NSTextLocation>)location
                      hyphenating:(BOOL)hyphenating {
  NSTextContentStorage* contentStorage =
      textLayoutManager.textContainer.textView.textContentStorage;
  NSUInteger charIndex = (NSUInteger)
      [contentStorage offsetFromLocation:contentStorage.documentRange.location
                              toLocation:location];
  if (charIndex <= 1) {
    return YES;
  } else {
    unichar charBeforeIndex = [contentStorage.textStorage.mutableString
        characterAtIndex:charIndex - 1];
    NSTextAlignment alignment =
        [[contentStorage.textStorage attribute:NSParagraphStyleAttributeName
                                       atIndex:charIndex
                                effectiveRange:NULL] alignment];
    if (alignment == NSTextAlignmentNatural) {  // candidates in linear layout
      return charBeforeIndex == 0x1D;
    } else {
      return charBeforeIndex != '\t';
    }
  }
}

- (NSTextLayoutFragment*)textLayoutManager:
                             (NSTextLayoutManager*)textLayoutManager
             textLayoutFragmentForLocation:(id<NSTextLocation>)location
                             inTextElement:(NSTextElement*)textElement {
  NSTextRange* textRange =
      [NSTextRange.alloc initWithLocation:location
                              endLocation:textElement.elementRange.endLocation];
  SquirrelTextLayoutFragment* fragment =
      [SquirrelTextLayoutFragment.alloc initWithTextElement:textElement
                                                      range:textRange];
  NSTextStorage* textStorage =
      textLayoutManager.textContainer.textView.textContentStorage.textStorage;
  if (textStorage.length > 0 &&
      [location isEqual:self.documentRange.location]) {
    fragment.topMargin = [[textStorage attribute:NSParagraphStyleAttributeName
                                         atIndex:0
                                  effectiveRange:NULL] lineSpacing];
  }
  return fragment;
}

@end  // SquirrelTextLayoutManager

#pragma mark - View behind text, containing drawings of backgrounds and highlights

__attribute__((objc_direct_members))
@interface SquirrelView : NSView

typedef struct {
  NSRect leading;
  NSRect body;
  NSRect trailing;
} SquirrelTextPolygon;

typedef struct {
  NSUInteger index;
  NSUInteger lineNum;
  NSUInteger tabNum;
} SquirrelTabularIndex;

// location and length (of candidate) are relative to the textStorage
// text/comment marks the start of text/comment relative to the candidate
typedef struct {
  NSUInteger location;
  NSUInteger length;
  NSUInteger text;
  NSUInteger comment;
} SquirrelCandidateRanges;

@property(nonatomic, readonly, strong, nonnull, class)
    SquirrelTheme* defaultTheme;
@property(nonatomic, readonly, strong, nonnull, class)
    API_AVAILABLE(macosx(10.14)) SquirrelTheme* darkTheme;
@property(nonatomic, readonly, strong, nonnull) SquirrelTheme* currentTheme;
@property(nonatomic, readonly, strong, nonnull) NSTextView* textView;
@property(nonatomic, readonly, strong, nonnull) NSTextStorage* textStorage;
@property(nonatomic, readonly, strong, nonnull) CAShapeLayer* shape;
@property(nonatomic, readonly, nullable) SquirrelTabularIndex* tabularIndices;
@property(nonatomic, readonly, nullable) SquirrelTextPolygon* candidatePolygons;
@property(nonatomic, readonly, nullable) NSRectArray sectionRects;
@property(nonatomic, readonly, nullable)
    SquirrelCandidateRanges* candidateRanges;
@property(nonatomic, readonly, nullable) BOOL* truncated;
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
@property(nonatomic, readonly) NSEdgeInsets marginInsets;
@property(nonatomic, readonly) NSUInteger candidateCount;
@property(nonatomic, readonly) NSUInteger hilitedIndex;
@property(nonatomic, readonly) NSRange preeditRange;
@property(nonatomic, readonly) NSRange hilitedPreeditRange;
@property(nonatomic, readonly) NSRange pagingRange;
@property(nonatomic, readonly) CGFloat trailPadding;
@property(nonatomic) BOOL expanded;

- (void)layoutContents;

- (NSRect)blockRectForRange:(NSRange)range;

- (SquirrelTextPolygon)textPolygonForRange:(NSRange)charRange;

- (void)estimateBoundsForPreedit:(NSRange)preeditRange
                      candidates:(SquirrelCandidateRanges*)candidateRanges
                      truncation:(BOOL*)truncated
                           count:(NSUInteger)candidateCount
                          paging:(NSRange)pagingRange;

- (void)drawViewWithInsets:(NSEdgeInsets)marginInsets
              hilitedIndex:(NSUInteger)hilitedIndex
       hilitedPreeditRange:(NSRange)hilitedPreeditRange;

- (void)setPreeditRange:(NSRange)preeditRange
    hilitedPreeditRange:(NSRange)hilitedPreeditRange;

- (void)highlightCandidate:(NSUInteger)hilitedIndex;

- (void)highlightFunctionButton:(SquirrelIndex)functionButton;

- (SquirrelIndex)getIndexFromMouseSpot:(NSPoint)spot;

@end

@implementation SquirrelView

static SquirrelTheme* _defaultTheme = SquirrelTheme.alloc.init;
static SquirrelTheme* _darkTheme API_AVAILABLE(macos(10.14)) =
    SquirrelTheme.alloc.init;

NS_INLINE NSUInteger NSMaxRange(SquirrelCandidateRanges ranges) {
  return (ranges.location + ranges.length);
}

// Need flipped coordinate system, as required by textStorage
- (BOOL)isFlipped {
  return YES;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

- (void)setAppear:(SquirrelAppear)appear {
  if (@available(macOS 10.14, *)) {
    if (_appear != appear) {
      _appear = appear;
      [self setValue:appear == darkAppear ? _darkTheme : _defaultTheme
              forKey:@"currentTheme"];
    }
  }
}

+ (SquirrelTheme*)defaultTheme {
  return _defaultTheme;
}

+ (SquirrelTheme*)darkTheme API_AVAILABLE(macos(10.14)) {
  return _darkTheme;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.geometryFlipped = YES;
    self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;

    if (@available(macOS 12.0, *)) {
      SquirrelTextLayoutManager* textLayoutManager =
          SquirrelTextLayoutManager.alloc.init;
      textLayoutManager.usesFontLeading = NO;
      textLayoutManager.usesHyphenation = NO;
      textLayoutManager.delegate = textLayoutManager;
      NSTextContainer* textContainer =
          [NSTextContainer.alloc initWithSize:NSZeroSize];
      textContainer.lineFragmentPadding = 0;
      textLayoutManager.textContainer = textContainer;
      NSTextContentStorage* contentStorage = NSTextContentStorage.alloc.init;
      _textStorage = contentStorage.textStorage;
      [contentStorage addTextLayoutManager:textLayoutManager];
      _textView = [NSTextView.alloc initWithFrame:frameRect
                                    textContainer:textContainer];
    } else {
      SquirrelLayoutManager* layoutManager = SquirrelLayoutManager.alloc.init;
      layoutManager.backgroundLayoutEnabled = YES;
      layoutManager.usesFontLeading = NO;
      layoutManager.typesetterBehavior = NSTypesetterLatestBehavior;
      layoutManager.delegate = layoutManager;
      NSTextContainer* textContainer =
          [NSTextContainer.alloc initWithContainerSize:NSZeroSize];
      textContainer.lineFragmentPadding = 0;
      [layoutManager addTextContainer:textContainer];
      _textStorage = NSTextStorage.alloc.init;
      [_textStorage addLayoutManager:layoutManager];
      _textView = [NSTextView.alloc initWithFrame:frameRect
                                    textContainer:textContainer];
    }
    _textView.drawsBackground = NO;
    _textView.selectable = NO;
    _textView.wantsLayer = YES;

    _appear = defaultAppear;
    _currentTheme = _defaultTheme;
    _shape = CAShapeLayer.alloc.init;
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
    return [NSTextRange.alloc initWithLocation:startLocation
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

// Get the rectangle containing entire contents
- (void)layoutContents {
  if (@available(macOS 12.0, *)) {
    [_textView.textLayoutManager
        ensureLayoutForRange:_textView.textContentStorage.documentRange];
    _contentRect = _textView.textLayoutManager.usageBoundsForTextContainer;
  } else {
    [_textView.layoutManager
        ensureLayoutForTextContainer:_textView.textContainer];
    _contentRect = [_textView.layoutManager
        usedRectForTextContainer:_textView.textContainer];
  }
  _contentRect.size =
      NSMakeSize(ceil(NSWidth(_contentRect)), ceil(NSHeight(_contentRect)));
}

// Get the rectangle containing the range of text, will first convert to glyph
// or text range, expensive to calculate
- (NSRect)blockRectForRange:(NSRange)charRange {
  if (charRange.location == NSNotFound) {
    return NSZeroRect;
  }
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [self getTextRangeFromCharRange:charRange];
    NSRect __block firstLineRect = CGRectNull;
    NSRect __block finalLineRect = CGRectNull;
    [_textView.textLayoutManager
        enumerateTextSegmentsInRange:textRange
                                type:NSTextLayoutManagerSegmentTypeStandard
                             options:
                                 NSTextLayoutManagerSegmentOptionsRangeNotRequired
                          usingBlock:^BOOL(
                              NSTextRange* _Nullable segRange, CGRect segFrame,
                              CGFloat baseline,
                              NSTextContainer* _Nonnull textContainer) {
                            if (!CGRectIsEmpty(segFrame)) {
                              if (NSIsEmptyRect(firstLineRect) ||
                                  CGRectGetMinY(segFrame) <
                                      NSMaxY(firstLineRect)) {
                                firstLineRect =
                                    NSUnionRect(segFrame, firstLineRect);
                              } else {
                                finalLineRect =
                                    NSUnionRect(segFrame, finalLineRect);
                              }
                            }
                            return YES;
                          }];
    if (_currentTheme.linear && _currentTheme.linespace > 0.1 &&
        _candidateCount > 0) {
      if (charRange.location >= _candidateRanges[0].location &&
          charRange.location <
              NSMaxRange(_candidateRanges[_candidateCount - 1])) {
        firstLineRect.size.height += _currentTheme.linespace;
        firstLineRect.origin.y -= _currentTheme.linespace;
      }
      if (!NSIsEmptyRect(finalLineRect) &&
          NSMaxRange(charRange) > _candidateRanges[0].location &&
          NSMaxRange(charRange) <=
              NSMaxRange(_candidateRanges[_candidateCount - 1])) {
        finalLineRect.size.height += _currentTheme.linespace;
        finalLineRect.origin.y -= _currentTheme.linespace;
      }
    }
    if (NSIsEmptyRect(finalLineRect)) {
      return firstLineRect;
    } else {
      return NSMakeRect(0.0, NSMinY(firstLineRect),
                        NSMaxX(_contentRect) - _trailPadding,
                        NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    }
  } else {
    NSLayoutManager* layoutManager = _textView.layoutManager;
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange
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
      return NSMakeRect(0.0, NSMinY(firstLineRect),
                        NSMaxX(_contentRect) - _trailPadding,
                        NSMaxY(finalLineRect) - NSMinY(firstLineRect));
    }
  }
}

// Calculate 3 boxes containing the text in range. leadingRect and trailingRect
// are incomplete line rectangle bodyRect is the complete line fragment in the
// middle if the range spans no less than one full line
- (SquirrelTextPolygon)textPolygonForRange:(NSRange)charRange {
  SquirrelTextPolygon textPolygon = {
      .leading = NSZeroRect, .body = NSZeroRect, .trailing = NSZeroRect};
  if (charRange.location == NSNotFound) {
    return textPolygon;
  }
  if (@available(macOS 12.0, *)) {
    NSTextRange* textRange = [self getTextRangeFromCharRange:charRange];
    NSRect __block leadingLineRect = CGRectNull;
    NSRect __block trailingLineRect = CGRectNull;
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
                            if (!CGRectIsEmpty(segFrame)) {
                              if (NSIsEmptyRect(leadingLineRect) ||
                                  CGRectGetMinY(segFrame) <
                                      NSMaxY(leadingLineRect)) {
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
    if (_currentTheme.linear && _currentTheme.linespace > 0.1 &&
        _candidateCount > 0) {
      if (charRange.location >= _candidateRanges[0].location &&
          charRange.location <
              NSMaxRange(_candidateRanges[_candidateCount - 1])) {
        leadingLineRect.size.height += _currentTheme.linespace;
        leadingLineRect.origin.y -= _currentTheme.linespace;
      }
    }

    if (NSIsEmptyRect(trailingLineRect)) {
      textPolygon.body = leadingLineRect;
    } else {
      if (_currentTheme.linear && _currentTheme.linespace > 0.1 &&
          _candidateCount > 0) {
        if (NSMaxRange(charRange) > _candidateRanges[0].location &&
            NSMaxRange(charRange) <=
                NSMaxRange(_candidateRanges[_candidateCount - 1])) {
          trailingLineRect.size.height += _currentTheme.linespace;
          trailingLineRect.origin.y -= _currentTheme.linespace;
        }
      }

      CGFloat containerWidth = NSMaxX(_contentRect) - _trailPadding;
      leadingLineRect.size.width = containerWidth - NSMinX(leadingLineRect);
      if (fabs(NSMaxX(trailingLineRect) - NSMaxX(leadingLineRect)) < 1) {
        if (fabs(NSMinX(leadingLineRect) - NSMinX(trailingLineRect)) < 1) {
          textPolygon.body = NSUnionRect(leadingLineRect, trailingLineRect);
        } else {
          textPolygon.leading = leadingLineRect;
          textPolygon.body =
              NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        textPolygon.trailing = trailingLineRect;
        if (fabs(NSMinX(leadingLineRect) - NSMinX(trailingLineRect)) < 1) {
          textPolygon.body =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          textPolygon.leading = leadingLineRect;
          if (![trailingLineRange
                  containsLocation:leadingLineRange.endLocation]) {
            textPolygon.body =
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
      textPolygon.body = NSMakeRect(headX, NSMinY(leadingLineRect),
                                    tailX - headX, NSHeight(leadingLineRect));
    } else {
      CGFloat containerWidth = NSMaxX(_contentRect) - _trailPadding;
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
          textPolygon.body =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          textPolygon.leading =
              NSMakeRect(headX, NSMinY(leadingLineRect), containerWidth - headX,
                         NSHeight(leadingLineRect));
          textPolygon.body =
              NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                         NSMaxY(trailingLineRect) - NSMaxY(leadingLineRect));
        }
      } else {
        textPolygon.trailing = NSMakeRect(0.0, NSMinY(trailingLineRect), tailX,
                                          NSHeight(trailingLineRect));
        if (glyphRange.location == leadingLineRange.location) {
          textPolygon.body =
              NSMakeRect(0.0, NSMinY(leadingLineRect), containerWidth,
                         NSMinY(trailingLineRect) - NSMinY(leadingLineRect));
        } else {
          textPolygon.leading =
              NSMakeRect(headX, NSMinY(leadingLineRect), containerWidth - headX,
                         NSHeight(leadingLineRect));
          if (trailingLineRange.location > NSMaxRange(leadingLineRange)) {
            textPolygon.body =
                NSMakeRect(0.0, NSMaxY(leadingLineRect), containerWidth,
                           NSMinY(trailingLineRect) - NSMaxY(leadingLineRect));
          }
        }
      }
    }
  }
  return textPolygon;
}

- (void)estimateBoundsForPreedit:(NSRange)preeditRange
                      candidates:(SquirrelCandidateRanges*)candidateRanges
                      truncation:(BOOL*)truncated
                           count:(NSUInteger)candidateCount
                          paging:(NSRange)pagingRange {
  _preeditRange = preeditRange;
  _candidateRanges = candidateRanges;
  _truncated = truncated;
  _candidateCount = candidateCount;
  _pagingRange = pagingRange;
  [self layoutContents];
  if (_currentTheme.linear && (candidateCount > 0 || preeditRange.length > 0)) {
    CGFloat width = 0.0;
    if (preeditRange.length > 0) {
      width = ceil(NSMaxX([self blockRectForRange:preeditRange]));
    }
    if (candidateCount > 0) {
      BOOL isTruncated = truncated[0];
      NSUInteger start = candidateRanges[0].location;
      for (NSUInteger i = 1; i <= candidateCount; ++i) {
        if (i == candidateCount || truncated[i] != isTruncated) {
          NSRect candidateRect = [self
              blockRectForRange:NSMakeRange(start,
                                            NSMaxRange(candidateRanges[i - 1]) -
                                                start)];
          width =
              fmax(width, ceil(NSMaxX(candidateRect)) -
                              (isTruncated ? 0.0 : _currentTheme.fullWidth));
          if (i < candidateCount) {
            isTruncated = truncated[i];
            start = candidateRanges[i].location;
          }
        }
      }
    }
    if (pagingRange.length > 0) {
      width = fmax(width, ceil(NSMaxX([self blockRectForRange:pagingRange])));
    }
    _trailPadding = fmax(NSMaxX(_contentRect) - width, 0.0);
  } else {
    _trailPadding = 0.0;
  }
}

// Will triger - (void)updateLayer
- (void)drawViewWithInsets:(NSEdgeInsets)marginInsets
              hilitedIndex:(NSUInteger)hilitedIndex
       hilitedPreeditRange:(NSRange)hilitedPreeditRange {
  _marginInsets = marginInsets;
  _hilitedIndex = hilitedIndex;
  _hilitedPreeditRange = hilitedPreeditRange;
  _functionButton = kVoidSymbol;
  // invalidate Rect beyond bound of textview to clear any out-of-bound drawing
  // from last round
  self.needsDisplayInRect = self.bounds;
  _textView.needsDisplayInRect = [self convertRect:self.bounds
                                            toView:_textView];
  [self layoutContents];
}

- (void)setPreeditRange:(NSRange)preeditRange
    hilitedPreeditRange:(NSRange)hilitedPreeditRange {
  if (_preeditRange.length != preeditRange.length) {
    for (NSUInteger i = 0; i < _candidateCount; ++i) {
      _candidateRanges[i].location +=
          preeditRange.length - _preeditRange.length;
    }
    if (_pagingRange.location != NSNotFound) {
      _pagingRange.location += preeditRange.length - _preeditRange.length;
    }
  }
  _preeditRange = preeditRange;
  _hilitedPreeditRange = hilitedPreeditRange;
  self.needsDisplayInRect = _preeditBlock;
  _textView.needsDisplayInRect = [self convertRect:_preeditBlock
                                            toView:_textView];
  [self layoutContents];
}

- (void)highlightCandidate:(NSUInteger)hilitedIndex {
  if (_expanded) {
    NSUInteger priorActivePage = _hilitedIndex / _currentTheme.pageSize;
    NSUInteger newActivePage = hilitedIndex / _currentTheme.pageSize;
    if (newActivePage != priorActivePage) {
      self.needsDisplayInRect = _sectionRects[priorActivePage];
      _textView.needsDisplayInRect =
          [self convertRect:_sectionRects[priorActivePage] toView:_textView];
    }
    self.needsDisplayInRect = _sectionRects[newActivePage];
    _textView.needsDisplayInRect =
        [self convertRect:_sectionRects[newActivePage] toView:_textView];
  } else {
    self.needsDisplayInRect = _candidateBlock;
    _textView.needsDisplayInRect = [self convertRect:_candidateBlock
                                              toView:_textView];
  }
  _hilitedIndex = hilitedIndex;
}

- (void)highlightFunctionButton:(SquirrelIndex)functionButton {
  for (SquirrelIndex index :
       (SquirrelIndex[2]){_functionButton, functionButton}) {
    switch (index) {
      case kPageUpKey:
      case kHomeKey:
        self.needsDisplayInRect = _pageUpRect;
        _textView.needsDisplayInRect = [self convertRect:_pageUpRect
                                                  toView:_textView];
        break;
      case kPageDownKey:
      case kEndKey:
        self.needsDisplayInRect = _pageDownRect;
        _textView.needsDisplayInRect = [self convertRect:_pageDownRect
                                                  toView:_textView];
        break;
      case kBackSpaceKey:
      case kEscapeKey:
        self.needsDisplayInRect = _deleteBackRect;
        _textView.needsDisplayInRect = [self convertRect:_deleteBackRect
                                                  toView:_textView];
        break;
      case kExpandButton:
      case kCompressButton:
      case kLockButton:
        self.needsDisplayInRect = _expanderRect;
        _textView.needsDisplayInRect = [self convertRect:_expanderRect
                                                  toView:_textView];
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

static void textPolygonVertices(SquirrelTextPolygon textPolygon,
                                NSPointArray vertices) {
  switch ((NSIsEmptyRect(textPolygon.leading) << 2) |
          (NSIsEmptyRect(textPolygon.body) << 1) |
          (NSIsEmptyRect(textPolygon.trailing) << 0)) {
    case 0b011:
      rectVertices(textPolygon.leading, vertices);
      break;
    case 0b110:
      rectVertices(textPolygon.trailing, vertices);
      break;
    case 0b101:
      rectVertices(textPolygon.body, vertices);
      break;
    case 0b001: {
      NSPoint leadingVertices[4], bodyVertices[4];
      rectVertices(textPolygon.leading, leadingVertices);
      rectVertices(textPolygon.body, bodyVertices);
      vertices[0] = leadingVertices[0];
      vertices[1] = leadingVertices[1];
      vertices[2] = bodyVertices[0];
      vertices[3] = bodyVertices[1];
      vertices[4] = bodyVertices[2];
      vertices[5] = leadingVertices[3];
    } break;
    case 0b100: {
      NSPoint bodyVertices[4], trailingVertices[4];
      rectVertices(textPolygon.body, bodyVertices);
      rectVertices(textPolygon.trailing, trailingVertices);
      vertices[0] = bodyVertices[0];
      vertices[1] = trailingVertices[1];
      vertices[2] = trailingVertices[2];
      vertices[3] = trailingVertices[3];
      vertices[4] = bodyVertices[2];
      vertices[5] = bodyVertices[3];
    } break;
    case 0b010:
      if (NSMinX(textPolygon.leading) <= NSMaxX(textPolygon.trailing)) {
        NSPoint leadingVertices[4], trailingVertices[4];
        rectVertices(textPolygon.leading, leadingVertices);
        rectVertices(textPolygon.trailing, trailingVertices);
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
      rectVertices(textPolygon.leading, leadingVertices);
      rectVertices(textPolygon.body, bodyVertices);
      rectVertices(textPolygon.trailing, trailingVertices);
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

- (CAShapeLayer*)getFunctionButtonLayer {
  NSColor* buttonColor;
  NSRect buttonRect = NSZeroRect;
  switch (_functionButton) {
    case kPageUpKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.hooverColor;
      buttonRect = _pageUpRect;
      break;
    case kHomeKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.disabledColor;
      buttonRect = _pageUpRect;
      break;
    case kPageDownKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.hooverColor;
      buttonRect = _pageDownRect;
      break;
    case kEndKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.disabledColor;
      buttonRect = _pageDownRect;
      break;
    case kExpandButton:
    case kCompressButton:
    case kLockButton:
      buttonColor = _currentTheme.hilitedPreeditBackColor.hooverColor;
      buttonRect = _expanderRect;
      break;
    case kBackSpaceKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.hooverColor;
      buttonRect = _deleteBackRect;
      break;
    case kEscapeKey:
      buttonColor = _currentTheme.hilitedPreeditBackColor.disabledColor;
      buttonRect = _deleteBackRect;
      break;
    default:
      return nil;
      break;
  }
  if (!NSIsEmptyRect(buttonRect) && buttonColor) {
    CGFloat cornerRadius =
        fmin(_currentTheme.hilitedCornerRadius, NSHeight(buttonRect) * 0.5);
    NSPoint buttonVertices[4];
    rectVertices(buttonRect, buttonVertices);
    NSBezierPath* buttonPath = squirclePath(buttonVertices, 4, cornerRadius);
    CAShapeLayer* functionButtonLayer = CAShapeLayer.alloc.init;
    functionButtonLayer.path = buttonPath.quartzPath;
    functionButtonLayer.fillColor = buttonColor.CGColor;
    return functionButtonLayer;
  }
  return nil;
}

// All draws happen here
- (void)updateLayer {
  SquirrelTheme* theme = _currentTheme;
  NSRect panelRect = self.bounds;
  NSRect backgroundRect = NSInsetRect(panelRect, theme.borderInsets.width,
                                      theme.borderInsets.height);
  backgroundRect = [self backingAlignedRect:backgroundRect
                                    options:NSAlignAllEdgesNearest];

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
  if (_candidateCount > 0) {
    NSUInteger candidateBlockLength =
        NSMaxRange(_candidateRanges[_candidateCount - 1]) -
        _candidateRanges[0].location;
    candidateBlockRange = NSIntersectionRange(
        NSMakeRange(_candidateRanges[0].location, candidateBlockLength),
        visibleRange);
  } else {
    candidateBlockRange = NSMakeRange(NSNotFound, 0);
  }
  NSRange pagingRange = NSIntersectionRange(_pagingRange, visibleRange);

  // Draw preedit Rect
  _preeditBlock = NSZeroRect;
  _deleteBackRect = NSZeroRect;
  NSBezierPath* hilitedPreeditPath;
  if (preeditRange.length > 0) {
    NSRect innerBox = [self blockRectForRange:preeditRange];
    _preeditBlock = NSMakeRect(
        backgroundRect.origin.x, backgroundRect.origin.y,
        backgroundRect.size.width,
        innerBox.size.height +
            (candidateBlockRange.length > 0 ? theme.preeditLinespace : 0.0));
    _preeditBlock = [self backingAlignedRect:_preeditBlock
                                     options:NSAlignAllEdgesNearest];

    // Draw hilited part of preedit text
    NSRange hilitedPreeditRange =
        NSIntersectionRange(_hilitedPreeditRange, visibleRange);
    CGFloat cornerRadius =
        fmin(theme.hilitedCornerRadius,
             theme.preeditParagraphStyle.minimumLineHeight * 0.5);
    if (hilitedPreeditRange.length > 0 && theme.hilitedPreeditBackColor) {
      CGFloat padding =
          ceil(theme.preeditParagraphStyle.minimumLineHeight * 0.05);
      innerBox.origin.x += _marginInsets.left - padding;
      innerBox.size.width =
          backgroundRect.size.width - theme.fullWidth + padding * 2;
      innerBox.origin.y += _marginInsets.top;
      innerBox = [self backingAlignedRect:innerBox
                                  options:NSAlignAllEdgesNearest];
      SquirrelTextPolygon textPolygon =
          [self textPolygonForRange:hilitedPreeditRange];
      NSInteger numVert = 0;
      if (!NSIsEmptyRect(textPolygon.leading)) {
        textPolygon.leading.origin.x += _marginInsets.left - padding;
        textPolygon.leading.origin.y += _marginInsets.top;
        textPolygon.leading.size.width += padding * 2;
        textPolygon.leading = [self
            backingAlignedRect:NSIntersectionRect(textPolygon.leading, innerBox)
                       options:NSAlignAllEdgesNearest];
        numVert += 4;
      }
      if (!NSIsEmptyRect(textPolygon.body)) {
        textPolygon.body.origin.x += _marginInsets.left - padding;
        textPolygon.body.origin.y += _marginInsets.top;
        textPolygon.body.size.width += padding;
        if (!NSIsEmptyRect(textPolygon.trailing) ||
            NSMaxRange(hilitedPreeditRange) + 2 == NSMaxRange(preeditRange)) {
          textPolygon.body.size.width += padding;
        }
        textPolygon.body = [self
            backingAlignedRect:NSIntersectionRect(textPolygon.body, innerBox)
                       options:NSAlignAllEdgesNearest];
        numVert += 2;
      }
      if (!NSIsEmptyRect(textPolygon.trailing)) {
        textPolygon.trailing.origin.x += _marginInsets.left - padding;
        textPolygon.trailing.origin.y += _marginInsets.top;
        textPolygon.trailing.size.width += padding;
        if (NSMaxRange(hilitedPreeditRange) + 2 == NSMaxRange(preeditRange)) {
          textPolygon.trailing.size.width += padding;
        }
        textPolygon.trailing =
            [self backingAlignedRect:NSIntersectionRect(textPolygon.trailing,
                                                        innerBox)
                             options:NSAlignAllEdgesNearest];
        numVert += 4;
      }

      // Handles the special case where containing boxes are separated
      if (NSIsEmptyRect(textPolygon.body) &&
          !NSIsEmptyRect(textPolygon.leading) &&
          !NSIsEmptyRect(textPolygon.trailing) &&
          NSMaxX(textPolygon.trailing) < NSMinX(textPolygon.leading)) {
        NSPoint leadingVertices[4], trailingVertices[4];
        rectVertices(textPolygon.leading, leadingVertices);
        rectVertices(textPolygon.trailing, trailingVertices);
        hilitedPreeditPath = squirclePath(leadingVertices, 4, cornerRadius);
        [hilitedPreeditPath
            appendBezierPath:squirclePath(trailingVertices, 4, cornerRadius)];
      } else {
        numVert = numVert > 8 ? 8 : numVert < 4 ? 4 : numVert;
        NSPoint polygonVertices[numVert];
        textPolygonVertices(textPolygon, polygonVertices);
        hilitedPreeditPath =
            squirclePath(polygonVertices, numVert, cornerRadius);
      }
    }
    _deleteBackRect =
        [self blockRectForRange:NSMakeRange(NSMaxRange(preeditRange) - 1, 1)];
    _deleteBackRect.size.width += floor(theme.fullWidth * 0.5);
    _deleteBackRect.origin.x =
        NSMaxX(backgroundRect) - NSWidth(_deleteBackRect);
    _deleteBackRect.origin.y += _marginInsets.top;
    _deleteBackRect = [self
        backingAlignedRect:NSIntersectionRect(_deleteBackRect, _preeditBlock)
                   options:NSAlignAllEdgesNearest];
  }

  // Draw candidate Rect
  _candidateBlock = NSZeroRect;
  _candidatePolygons = NULL;
  _sectionRects = NULL;
  _tabularIndices = NULL;
  NSBezierPath *candidateBlockPath, *hilitedCandidatePath;
  NSBezierPath *gridPath, *activePagePath;
  if (candidateBlockRange.length > 0) {
    _candidateBlock = [self blockRectForRange:candidateBlockRange];
    _candidateBlock.size.width = backgroundRect.size.width;
    _candidateBlock.origin.x = backgroundRect.origin.x;
    _candidateBlock.origin.y = preeditRange.length == 0 ? NSMinY(backgroundRect)
                                                        : NSMaxY(_preeditBlock);
    if (pagingRange.length == 0) {
      _candidateBlock.size.height =
          NSMaxY(backgroundRect) - NSMinY(_candidateBlock);
    } else if (!theme.linear) {
      _candidateBlock.size.height += theme.linespace;
    }
    _candidateBlock = [self
        backingAlignedRect:NSIntersectionRect(_candidateBlock, backgroundRect)
                   options:NSAlignAllEdgesNearest];
    NSPoint candidateBlockVertices[4];
    rectVertices(_candidateBlock, candidateBlockVertices);
    CGFloat blockCornerRadius =
        fmin(theme.hilitedCornerRadius, NSHeight(_candidateBlock) * 0.5);
    candidateBlockPath =
        squirclePath(candidateBlockVertices, 4, blockCornerRadius);

    // Draw candidate highlight rect
    CGFloat cornerRadius =
        fmin(theme.hilitedCornerRadius,
             theme.candidateParagraphStyle.minimumLineHeight * 0.5);
    _candidatePolygons = new SquirrelTextPolygon[_candidateCount];
    if (theme.linear) {
      CGFloat gridOriginY;
      CGFloat tabInterval;
      NSUInteger lineNum = 0;
      NSRect sectionRect = _candidateBlock;
      if (theme.tabular) {
        _tabularIndices = new SquirrelTabularIndex[_candidateCount];
        _sectionRects = new NSRect[_candidateCount / theme.pageSize];
        gridPath = NSBezierPath.bezierPath;
        gridOriginY = NSMinY(_candidateBlock);
        tabInterval = theme.fullWidth * 2;
        sectionRect.size.height = 0;
      }
      for (NSUInteger i = 0; i < _candidateCount; ++i) {
        NSRange candidateRange =
            NSIntersectionRange(NSMakeRange(_candidateRanges[i].location,
                                            _candidateRanges[i].length),
                                visibleRange);
        if (candidateRange.length == 0) {
          _candidateCount = i;
          break;
        }
        SquirrelTextPolygon candidatePolygon =
            [self textPolygonForRange:candidateRange];
        if (!NSIsEmptyRect(candidatePolygon.leading)) {
          candidatePolygon.leading.origin.x += theme.borderInsets.width;
          candidatePolygon.leading.size.width += theme.fullWidth;
          candidatePolygon.leading.origin.y += _marginInsets.top;
          candidatePolygon.leading = [self
              backingAlignedRect:NSIntersectionRect(candidatePolygon.leading,
                                                    _candidateBlock)
                         options:NSAlignAllEdgesNearest];
        }
        if (!NSIsEmptyRect(candidatePolygon.trailing)) {
          candidatePolygon.trailing.origin.x += theme.borderInsets.width;
          candidatePolygon.trailing.origin.y += _marginInsets.top;
          candidatePolygon.trailing = [self
              backingAlignedRect:NSIntersectionRect(candidatePolygon.trailing,
                                                    _candidateBlock)
                         options:NSAlignAllEdgesNearest];
        }
        if (!NSIsEmptyRect(candidatePolygon.body)) {
          candidatePolygon.body.origin.x += theme.borderInsets.width;
          if (_truncated[i]) {
            candidatePolygon.body.size.width =
                NSMaxX(_candidateBlock) - NSMinX(candidatePolygon.body);
          } else if (!NSIsEmptyRect(candidatePolygon.trailing)) {
            candidatePolygon.body.size.width += theme.fullWidth;
          }
          candidatePolygon.body.origin.y += _marginInsets.top;
          candidatePolygon.body =
              [self backingAlignedRect:NSIntersectionRect(candidatePolygon.body,
                                                          _candidateBlock)
                               options:NSAlignAllEdgesNearest];
        }
        if (theme.tabular) {
          if (_expanded) {
            if (i % theme.pageSize == 0) {
              sectionRect.origin.y += NSHeight(sectionRect);
            } else if (i % theme.pageSize == theme.pageSize - 1) {
              sectionRect.size.height =
                  NSMaxY(NSIsEmptyRect(candidatePolygon.trailing)
                             ? candidatePolygon.body
                             : candidatePolygon.trailing) -
                  NSMinY(sectionRect);
              NSUInteger sec = i / theme.pageSize;
              _sectionRects[sec] = sectionRect;
              if (sec == _hilitedIndex / theme.pageSize) {
                NSPoint activePageVertices[4];
                rectVertices(sectionRect, activePageVertices);
                CGFloat pageCornerRadius = fmin(theme.hilitedCornerRadius,
                                                NSHeight(sectionRect) * 0.5);
                activePagePath =
                    squirclePath(activePageVertices, 4, pageCornerRadius);
              }
            }
          }
          CGFloat bottomEdge = NSMaxY(NSIsEmptyRect(candidatePolygon.trailing)
                                          ? candidatePolygon.body
                                          : candidatePolygon.trailing);
          if (fabs(bottomEdge - gridOriginY) > 2) {
            lineNum += i > 0 ? 1 : 0;
            // horizontal border except for the last line
            if (fabs(bottomEdge - NSMaxY(_candidateBlock)) > 2) {
              [gridPath moveToPoint:NSMakePoint(NSMinX(_candidateBlock) +
                                                    ceil(theme.fullWidth * 0.5),
                                                bottomEdge)];
              [gridPath
                  lineToPoint:NSMakePoint(NSMaxX(_candidateBlock) -
                                              floor(theme.fullWidth * 0.5),
                                          bottomEdge)];
            }
            gridOriginY = bottomEdge;
          }
          NSPoint headOrigin = (NSIsEmptyRect(candidatePolygon.leading)
                                    ? candidatePolygon.body
                                    : candidatePolygon.leading)
                                   .origin;
          NSUInteger headTabColumn = (NSUInteger)round(
              (headOrigin.x - _marginInsets.left) / tabInterval);
          // vertical bar
          if (headOrigin.x > NSMinX(_candidateBlock) + theme.fullWidth) {
            [gridPath
                moveToPoint:NSMakePoint(headOrigin.x,
                                        headOrigin.y + cornerRadius * 0.8)];
            [gridPath
                lineToPoint:NSMakePoint(
                                headOrigin.x,
                                NSMaxY(NSIsEmptyRect(candidatePolygon.leading)
                                           ? candidatePolygon.body
                                           : candidatePolygon.leading) -
                                    cornerRadius * 0.8)];
          }
          _tabularIndices[i] = (SquirrelTabularIndex){
              .index = i, .lineNum = lineNum, .tabNum = headTabColumn};
        }
        _candidatePolygons[i] = candidatePolygon;
      }
      if (_hilitedIndex < _candidateCount) {
        NSInteger numVert =
            (NSIsEmptyRect(_candidatePolygons[_hilitedIndex].leading) ? 0 : 4) +
            (NSIsEmptyRect(_candidatePolygons[_hilitedIndex].body) ? 0 : 2) +
            (NSIsEmptyRect(_candidatePolygons[_hilitedIndex].trailing) ? 0 : 4);
        // Handles the special case where containing boxes are separated
        if (numVert == 8 &&
            NSMaxX(_candidatePolygons[_hilitedIndex].trailing) <
                NSMinX(_candidatePolygons[_hilitedIndex].leading)) {
          NSPoint leadingVertices[4], trailingVertices[4];
          rectVertices(_candidatePolygons[_hilitedIndex].leading,
                       leadingVertices);
          rectVertices(_candidatePolygons[_hilitedIndex].trailing,
                       trailingVertices);
          hilitedCandidatePath = squirclePath(leadingVertices, 4, cornerRadius);
          [hilitedCandidatePath
              appendBezierPath:squirclePath(trailingVertices, 4, cornerRadius)];
        } else {
          numVert = numVert > 8 ? 8 : numVert < 4 ? 4 : numVert;
          NSPoint polygonVertices[numVert];
          textPolygonVertices(_candidatePolygons[_hilitedIndex],
                              polygonVertices);
          hilitedCandidatePath =
              squirclePath(polygonVertices, numVert, cornerRadius);
        }
      }
    } else {  // stacked layout
      for (NSUInteger i = 0; i < _candidateCount; ++i) {
        NSRange candidateRange =
            NSIntersectionRange(NSMakeRange(_candidateRanges[i].location,
                                            _candidateRanges[i].length),
                                visibleRange);
        candidateRange = NSIntersectionRange(candidateRange, visibleRange);
        if (candidateRange.length == 0) {
          _candidateCount = i;
          break;
        }
        NSRect candidateRect = [self blockRectForRange:candidateRange];
        candidateRect.size.width = backgroundRect.size.width;
        candidateRect.origin.x = backgroundRect.origin.x;
        candidateRect.origin.y +=
            _marginInsets.top - ceil(theme.linespace * 0.5);
        candidateRect.size.height += theme.linespace;
        candidateRect =
            [self backingAlignedRect:NSIntersectionRect(candidateRect,
                                                        _candidateBlock)
                             options:NSAlignAllEdgesNearest];
        _candidatePolygons[i] =
            (SquirrelTextPolygon){NSZeroRect, candidateRect, NSZeroRect};
      }
      if (_hilitedIndex < _candidateCount) {
        NSPoint candidateVertices[4];
        rectVertices(_candidatePolygons[_hilitedIndex].body, candidateVertices);
        hilitedCandidatePath = squirclePath(candidateVertices, 4, cornerRadius);
      }
    }
  }

  // Draw paging Rect
  _pagingBlock = NSZeroRect;
  _pageUpRect = NSZeroRect;
  _pageDownRect = NSZeroRect;
  _expanderRect = NSZeroRect;
  if (pagingRange.length > 0) {
    if (theme.linear) {
      _pagingBlock = [self blockRectForRange:pagingRange];
      _pagingBlock.size.width += theme.fullWidth;
      _pagingBlock.origin.x = NSMaxX(backgroundRect) - NSWidth(_pagingBlock);
    } else {
      _pagingBlock = backgroundRect;
    }
    _pagingBlock.origin.y = NSMaxY(_candidateBlock);
    _pagingBlock.size.height = NSMaxY(backgroundRect) - NSMaxY(_candidateBlock);
    if (theme.showPaging) {
      _pageUpRect =
          [self blockRectForRange:NSMakeRange(pagingRange.location, 1)];
      _pageDownRect =
          [self blockRectForRange:NSMakeRange(NSMaxRange(pagingRange) - 1, 1)];
      _pageDownRect.origin.x += _marginInsets.left;
      _pageDownRect.size.width += ceil(theme.fullWidth * 0.5);
      _pageDownRect.origin.y += _marginInsets.top;
      _pageUpRect.origin.x += theme.borderInsets.width;
      // bypass the bug of getting wrong glyph position when tab is presented
      _pageUpRect.size.width = NSWidth(_pageDownRect);
      _pageUpRect.origin.y += _marginInsets.top;
      _pageUpRect =
          [self backingAlignedRect:NSIntersectionRect(_pageUpRect, _pagingBlock)
                           options:NSAlignAllEdgesNearest];
      _pageDownRect = [self
          backingAlignedRect:NSIntersectionRect(_pageDownRect, _pagingBlock)
                     options:NSAlignAllEdgesNearest];
    }
    if (theme.tabular) {
      _expanderRect =
          [self blockRectForRange:NSMakeRange(pagingRange.location +
                                                  pagingRange.length / 2,
                                              1)];
      _expanderRect.origin.x += theme.borderInsets.width;
      _expanderRect.size.width += theme.fullWidth;
      _expanderRect.origin.y += _marginInsets.top;
      _expanderRect = [self
          backingAlignedRect:NSIntersectionRect(_expanderRect, backgroundRect)
                     options:NSAlignAllEdgesNearest];
    }
  }

  // Draw borders
  CGFloat outerCornerRadius =
      fmin(theme.cornerRadius, NSHeight(panelRect) * 0.5);
  CGFloat innerCornerRadius =
      fmax(fmin(theme.hilitedCornerRadius, NSHeight(backgroundRect) * 0.5),
           outerCornerRadius -
               fmin(theme.borderInsets.width, theme.borderInsets.height));
  NSBezierPath *panelPath, *backgroundPath;
  if (!theme.linear || pagingRange.length == 0) {
    NSPoint panelVertices[4], backgroundVertices[4];
    rectVertices(panelRect, panelVertices);
    rectVertices(backgroundRect, backgroundVertices);
    panelPath = squirclePath(panelVertices, 4, outerCornerRadius);
    backgroundPath = squirclePath(backgroundVertices, 4, innerCornerRadius);
  } else {
    NSPoint panelVertices[6], backgroundVertices[6];
    NSRect mainPanelRect = panelRect;
    mainPanelRect.size.height -= NSHeight(_pagingBlock);
    NSRect tailPanelRect =
        NSInsetRect(NSOffsetRect(_pagingBlock, 0, theme.borderInsets.height),
                    -theme.borderInsets.width, 0);
    textPolygonVertices(
        (SquirrelTextPolygon){mainPanelRect, tailPanelRect, NSZeroRect},
        panelVertices);
    panelPath = squirclePath(panelVertices, 6, outerCornerRadius);
    NSRect mainBackgroundRect = backgroundRect;
    mainBackgroundRect.size.height -= NSHeight(_pagingBlock);
    textPolygonVertices(
        (SquirrelTextPolygon){mainBackgroundRect, _pagingBlock, NSZeroRect},
        backgroundVertices);
    backgroundPath = squirclePath(backgroundVertices, 6, innerCornerRadius);
  }
  NSBezierPath* borderPath = panelPath.copy;
  [borderPath appendBezierPath:backgroundPath];

  NSAffineTransform* flip = NSAffineTransform.transform;
  [flip translateXBy:0 yBy:NSHeight(panelRect)];
  [flip scaleXBy:1 yBy:-1];
  NSBezierPath* shapePath = [flip transformBezierPath:panelPath];

  // Set layers
  _shape.path = shapePath.quartzPath;
  _shape.fillColor = NSColor.whiteColor.CGColor;
  self.layer.sublayers = nil;
  // layers of large background elements
  CALayer* BackLayers = CALayer.alloc.init;
  CAShapeLayer* shapeLayer = CAShapeLayer.alloc.init;
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
    CAShapeLayer* backImageLayer = CAShapeLayer.alloc.init;
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
  CAShapeLayer* backColorLayer = CAShapeLayer.alloc.init;
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
      CAShapeLayer* candidateLayer = CAShapeLayer.alloc.init;
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
  CAShapeLayer* borderLayer = CAShapeLayer.alloc.init;
  borderLayer.path = borderPath.quartzPath;
  borderLayer.fillRule = kCAFillRuleEvenOdd;
  borderLayer.fillColor = (theme.borderColor ?: theme.backColor).CGColor;
  [BackLayers addSublayer:borderLayer];
  // layers of small highlighting elements
  CALayer* ForeLayers = CALayer.alloc.init;
  CAShapeLayer* maskLayer = CAShapeLayer.alloc.init;
  maskLayer.path = backgroundPath.quartzPath;
  maskLayer.fillColor = NSColor.whiteColor.CGColor;
  ForeLayers.mask = maskLayer;
  [self.layer addSublayer:ForeLayers];
  // highlighted preedit layer
  if (hilitedPreeditPath && theme.hilitedPreeditBackColor) {
    CAShapeLayer* hilitedPreeditLayer = CAShapeLayer.alloc.init;
    hilitedPreeditLayer.path = hilitedPreeditPath.quartzPath;
    hilitedPreeditLayer.fillColor = theme.hilitedPreeditBackColor.CGColor;
    [ForeLayers addSublayer:hilitedPreeditLayer];
  }
  // highlighted candidate layer
  if (hilitedCandidatePath && theme.hilitedCandidateBackColor) {
    if (activePagePath) {
      CAShapeLayer* activePageLayer = CAShapeLayer.alloc.init;
      activePageLayer.path = activePagePath.quartzPath;
      activePageLayer.fillColor =
          [[theme.hilitedCandidateBackColor
               blendedColorWithFraction:0.8
                                ofColor:[theme.backColor
                                            colorWithAlphaComponent:1.0]]
              colorWithAlphaComponent:theme.backColor.alphaComponent]
              .CGColor;
      [BackLayers addSublayer:activePageLayer];
    }
    CAShapeLayer* hilitedCandidateLayer = CAShapeLayer.alloc.init;
    hilitedCandidateLayer.path = hilitedCandidatePath.quartzPath;
    hilitedCandidateLayer.fillColor = theme.hilitedCandidateBackColor.CGColor;
    [ForeLayers addSublayer:hilitedCandidateLayer];
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
    CAShapeLayer* gridLayer = CAShapeLayer.alloc.init;
    gridLayer.path = gridPath.quartzPath;
    gridLayer.lineWidth = 1.0;
    gridLayer.strokeColor =
        [theme.commentForeColor blendedColorWithFraction:0.8
                                                 ofColor:theme.backColor]
            .CGColor;
    [ForeLayers addSublayer:gridLayer];
  }
  // logo at the beginning for status message
  if (NSIsEmptyRect(_preeditBlock) && NSIsEmptyRect(_candidateBlock)) {
    CALayer* logoLayer = CALayer.alloc.init;
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
    for (NSUInteger i = 0; i < _candidateCount; ++i) {
      if (NSMouseInRect(point, _candidatePolygons[i].body, YES) ||
          NSMouseInRect(point, _candidatePolygons[i].leading, YES) ||
          NSMouseInRect(point, _candidatePolygons[i].trailing, YES)) {
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

@property(nonatomic, strong, readonly, nullable, direct) NSTimer* displayTimer;
@property(nonatomic, strong, readonly, nullable, direct) NSTimer* hideTimer;

- (void)showWithToolTip:(NSString* _Nullable)toolTip
              withDelay:(BOOL)delay __attribute__((objc_direct));
- (void)delayedDisplay:(NSTimer* _Nonnull)timer;
- (void)delayedHide:(NSTimer* _Nonnull)timer;
- (void)hide __attribute__((objc_direct));

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
    NSView* contentView = NSView.alloc.init;
    _backView = NSVisualEffectView.alloc.init;
    _backView.material = NSVisualEffectMaterialToolTip;
    [contentView addSubview:_backView];
    _textView = NSTextField.alloc.init;
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
  SquirrelInputController __weak* _inputController;
  // Squirrel panel layouts
  NSVisualEffectView* _back;
  SquirrelToolTip* _toolTip;
  SquirrelView* _view;
  NSScreen* _screen;
  NSTimer* _statusTimer;
  NSSize _maxSize;
  CGFloat _textWidthLimit;
  CGFloat _anchorOffset;
  BOOL _initPosition;
  BOOL _needsRedraw;
  // Rime contents and actions
  NSRange _indexRange;
  NSUInteger _highlightedIndex;
  NSUInteger _functionButton;
  NSUInteger _caretPos;
  NSUInteger _pageNum;
  BOOL _caretAtHome;
  BOOL _finalPage;
}

@dynamic screen;

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

- (void)setLocked:(BOOL)locked {
  if (_view.currentTheme.tabular && _locked != locked) {
    _locked = locked;
    SquirrelConfig* userConfig = SquirrelConfig.alloc.init;
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

- (void)getLocked __attribute__((objc_direct)) {
  if (_view.currentTheme.tabular) {
    SquirrelConfig* userConfig = SquirrelConfig.alloc.init;
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

- (void)setIbeamRect:(NSRect)IbeamRect {
  if (!NSEqualRects(_IbeamRect, IbeamRect)) {
    _IbeamRect = IbeamRect;
    _needsRedraw |= YES;
    if (!NSIntersectsRect(IbeamRect, _screen.frame)) {
      [self willChangeValueForKey:@"screen"];
      [self updateScreen];
      [self didChangeValueForKey:@"screen"];
      [self updateDisplayParameters];
    }
  }
}

- (void)windowDidChangeBackingProperties:(NSNotification*)notification {
  if ([notification.object isEqualTo:self]) {
    [self updateDisplayParameters];
  }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id>*)change
                       context:(void*)context {
  if ([object isKindOfClass:SquirrelInputController.class] &&
      [keyPath isEqualToString:@"viewEffectiveAppearance"]) {
    _inputController = object;
    if (@available(macOS 10.14, *)) {
      NSAppearance* clientAppearance = change[NSKeyValueChangeNewKey];
      NSAppearanceName appearName =
          [clientAppearance bestMatchFromAppearancesWithNames:@[
            NSAppearanceNameAqua, NSAppearanceNameDarkAqua
          ]];
      SquirrelAppear appear =
          [appearName isEqualToString:NSAppearanceNameDarkAqua] ? darkAppear
                                                                : defaultAppear;
      if (appear != _view.appear) {
        _view.appear = appear;
        self.appearance = [NSAppearance appearanceNamed:appearName];
        _view.needsDisplay = YES;
        _view.textView.needsDisplay = YES;
        [self display];
      }
    }
  } else {
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
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

    NSView* contentView = NSView.alloc.init;
    _view = [SquirrelView.alloc initWithFrame:self.contentView.bounds];
    if (@available(macOS 10.14, *)) {
      _back = NSVisualEffectView.alloc.init;
      _back.blendingMode = NSVisualEffectBlendingModeBehindWindow;
      _back.material = NSVisualEffectMaterialHUDWindow;
      _back.state = NSVisualEffectStateActive;
      _back.emphasized = YES;
      _back.wantsLayer = YES;
      _back.layer.mask = _view.shape;
      [contentView addSubview:_back];
    }
    [contentView addSubview:_view];
    [contentView addSubview:_view.textView];
    self.contentView = contentView;

    _optionSwitcher = SquirrelOptionSwitcher.alloc.init;
    _toolTip = SquirrelToolTip.alloc.init;
    [self updateDisplayParameters];
    self.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
  }
  return self;
}

- (NSUInteger)candidateIndexOnDirection:(SquirrelIndex)arrowKey {
  if (!_view.currentTheme.tabular || _indexRange.length == 0 ||
      _highlightedIndex == NSNotFound) {
    return NSNotFound;
  }
  NSUInteger pageSize = _view.currentTheme.pageSize;
  NSUInteger currentTab = _view.tabularIndices[_highlightedIndex].tabNum;
  NSUInteger currentLine = _view.tabularIndices[_highlightedIndex].lineNum;
  NSUInteger finalLine = _view.tabularIndices[_indexRange.length - 1].lineNum;
  if (arrowKey == (_view.currentTheme.vertical ? kLeftKey : kDownKey)) {
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
  } else if (arrowKey == (_view.currentTheme.vertical ? kRightKey : kUpKey)) {
    if (currentLine == 0) {
      return _pageNum == 0 ? NSNotFound
                           : pageSize * (_pageNum - _sectionNum) - 1;
    }
    NSUInteger newIndex = _highlightedIndex - 1;
    while (newIndex > 0 &&
           (_view.tabularIndices[newIndex].lineNum == currentLine ||
            (_view.tabularIndices[newIndex].lineNum == currentLine - 1 &&
             _view.tabularIndices[newIndex].tabNum > currentTab))) {
      --newIndex;
    }
    return newIndex + _indexRange.location;
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
          [_inputController performAction:kPROCESS onIndex:kHomeKey];
        } else if (inputIndex < _caretPos) {
          [_inputController moveCursor:_caretPos
                            toPosition:inputIndex
                         inlinePreedit:NO
                       inlineCandidate:NO];
        } else if (inputIndex >= _view.preeditRange.length) {
          [_inputController performAction:kPROCESS onIndex:kEndKey];
        } else if (inputIndex > _caretPos + 1) {
          [_inputController moveCursor:_caretPos
                            toPosition:inputIndex - 1
                         inlinePreedit:NO
                       inlineCandidate:NO];
        }
      }
      break;
    case NSEventTypeLeftMouseUp:
      if (event.clickCount == 1 && cursorIndex != NSNotFound) {
        if (cursorIndex == _highlightedIndex) {
          [_inputController performAction:kSELECT
                                  onIndex:cursorIndex + _indexRange.location];
        } else if (cursorIndex == _functionButton) {
          if (cursorIndex == kExpandButton) {
            if (_locked) {
              self.locked = NO;
              [_view.textStorage
                  replaceCharactersInRange:NSMakeRange(
                                               _view.pagingRange.location +
                                                   _view.pagingRange.length / 2,
                                               1)
                      withAttributedString:_view.expanded ? theme.symbolCompress
                                                          : theme.symbolExpand];
              _view.textView.needsDisplayInRect = _view.expanderRect;
            } else {
              self.expanded = !_view.expanded;
              self.sectionNum = 0;
            }
          }
          [_inputController performAction:kPROCESS onIndex:cursorIndex];
        }
      }
      break;
    case NSEventTypeRightMouseUp:
      if (event.clickCount == 1 && cursorIndex != NSNotFound) {
        if (cursorIndex == _highlightedIndex) {
          [_inputController performAction:kDELETE
                                  onIndex:cursorIndex + _indexRange.location];
        } else if (cursorIndex == _functionButton) {
          switch (_functionButton) {
            case kPageUpKey:
              [_inputController performAction:kPROCESS onIndex:kHomeKey];
              break;
            case kPageDownKey:
              [_inputController performAction:kPROCESS onIndex:kEndKey];
              break;
            case kExpandButton:
              self.locked = !_locked;
              [_view.textStorage
                  replaceCharactersInRange:NSMakeRange(
                                               _view.pagingRange.location +
                                                   _view.pagingRange.length / 2,
                                               1)
                      withAttributedString:_locked ? theme.symbolLock
                                           : _view.expanded
                                               ? theme.symbolCompress
                                               : theme.symbolExpand];
              [_view.textStorage
                  addAttribute:NSForegroundColorAttributeName
                         value:theme.hilitedPreeditForeColor
                         range:NSMakeRange(_view.pagingRange.location +
                                               _view.pagingRange.length / 2,
                                           1)];
              _view.textView.needsDisplayInRect = _view.expanderRect;
              [_inputController performAction:kPROCESS onIndex:kLockButton];
              break;
            case kBackSpaceKey:
              [_inputController performAction:kPROCESS onIndex:kEscapeKey];
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
          [_toolTip
              showWithToolTip:
                  [_view.textStorage.mutableString
                      substringWithRange:NSMakeRange(
                                             _view.candidateRanges[cursorIndex]
                                                 .location,
                                             _view.candidateRanges[cursorIndex]
                                                 .length)]
                    withDelay:NO];
        } else if (noDelay) {
          [_toolTip showWithToolTip:NSLocalizedString(@"candidate", nil)
                          withDelay:!noDelay];
        }
        self.sectionNum = cursorIndex / theme.pageSize;
        [_inputController performAction:kHIGHLIGHT
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
          theme.candidateParagraphStyle.minimumLineHeight +
          theme.candidateParagraphStyle.lineSpacing;
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
          [_inputController
              performAction:kPROCESS
                    onIndex:(theme.vertical ? kPageDownKey : kPageUpKey)];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.y > scrollThreshold) {
          [_inputController performAction:kPROCESS onIndex:kPageUpKey];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.x < -scrollThreshold) {
          [_inputController
              performAction:kPROCESS
                    onIndex:(theme.vertical ? kPageUpKey : kPageDownKey)];
          scrollLocus = NSMakePoint(NAN, NAN);
        } else if (scrollLocus.y < -scrollThreshold) {
          [_inputController performAction:kPROCESS onIndex:kPageDownKey];
          scrollLocus = NSMakePoint(NAN, NAN);
        }
      }
    } break;
    default:
      [super sendEvent:event];
      break;
  }
}

- (void)highlightCandidate:(NSUInteger)highlightedIndex
    __attribute__((objc_direct)) {
  SquirrelTheme* theme = _view.currentTheme;
  NSUInteger priorHilitedIndex = _highlightedIndex;
  NSUInteger priorSectionNum = priorHilitedIndex / theme.pageSize;
  _highlightedIndex = highlightedIndex;
  self.sectionNum = highlightedIndex / theme.pageSize;
  // apply new foreground colors
  for (NSUInteger i = 0; i < theme.pageSize; ++i) {
    NSUInteger priorIndex = i + priorSectionNum * theme.pageSize;
    if ((_sectionNum != priorSectionNum || priorIndex == priorHilitedIndex) &&
        priorIndex < _indexRange.length) {
      NSColor* labelColor =
          priorIndex == priorHilitedIndex && _sectionNum == priorSectionNum
              ? theme.labelForeColor
              : theme.dimmedLabelForeColor;
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:labelColor
                 range:NSMakeRange(_view.candidateRanges[priorIndex].location,
                                   _view.candidateRanges[priorIndex].text)];
      if (priorIndex == priorHilitedIndex) {
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.textForeColor
                   range:NSMakeRange(
                             _view.candidateRanges[priorIndex].location +
                                 _view.candidateRanges[priorIndex].text,
                             _view.candidateRanges[priorIndex].comment -
                                 _view.candidateRanges[priorIndex].text)];
        [_view.textStorage
            addAttribute:NSForegroundColorAttributeName
                   value:theme.commentForeColor
                   range:NSMakeRange(
                             _view.candidateRanges[priorIndex].location +
                                 _view.candidateRanges[priorIndex].comment,
                             _view.candidateRanges[priorIndex].length -
                                 _view.candidateRanges[priorIndex].comment)];
      }
    }
    NSUInteger newIndex = i + _sectionNum * theme.pageSize;
    if ((_sectionNum != priorSectionNum || newIndex == _highlightedIndex) &&
        newIndex < _indexRange.length) {
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:newIndex == _highlightedIndex
                           ? theme.hilitedLabelForeColor
                           : theme.labelForeColor
                 range:NSMakeRange(_view.candidateRanges[newIndex].location,
                                   _view.candidateRanges[newIndex].text)];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:newIndex == _highlightedIndex
                           ? theme.hilitedTextForeColor
                           : theme.textForeColor
                 range:NSMakeRange(_view.candidateRanges[newIndex].location +
                                       _view.candidateRanges[newIndex].text,
                                   _view.candidateRanges[newIndex].comment -
                                       _view.candidateRanges[newIndex].text)];
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:newIndex == _highlightedIndex
                           ? theme.hilitedCommentForeColor
                           : theme.commentForeColor
                 range:NSMakeRange(
                           _view.candidateRanges[newIndex].location +
                               _view.candidateRanges[newIndex].comment,
                           _view.candidateRanges[newIndex].length -
                               _view.candidateRanges[newIndex].comment)];
    }
  }
  [_view highlightCandidate:_highlightedIndex];
}

- (void)highlightFunctionButton:(SquirrelIndex)functionButton
                   delayToolTip:(BOOL)delay __attribute__((objc_direct)) {
  if (_functionButton == functionButton) {
    return;
  }
  SquirrelTheme* theme = _view.currentTheme;
  switch (_functionButton) {
    case kPageUpKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditForeColor
                 range:NSMakeRange(_view.pagingRange.location, 1)];
      break;
    case kPageDownKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditForeColor
                 range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
      break;
    case kExpandButton:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditForeColor
                 range:NSMakeRange(_view.pagingRange.location +
                                       _view.pagingRange.length / 2,
                                   1)];
      break;
    case kBackSpaceKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.preeditForeColor
                 range:NSMakeRange(NSMaxRange(_view.preeditRange) - 1, 1)];
      break;
  }
  _functionButton = functionButton;
  switch (_functionButton) {
    case kPageUpKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.hilitedPreeditForeColor
                 range:NSMakeRange(_view.pagingRange.location, 1)];
      functionButton = _pageNum == 0 ? kHomeKey : kPageUpKey;
      [_toolTip showWithToolTip:NSLocalizedString(
                                    _pageNum == 0 ? @"home" : @"page_up", nil)
                      withDelay:delay];
      break;
    case kPageDownKey:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.hilitedPreeditForeColor
                 range:NSMakeRange(NSMaxRange(_view.pagingRange) - 1, 1)];
      functionButton = _finalPage ? kEndKey : kPageDownKey;
      [_toolTip showWithToolTip:NSLocalizedString(
                                    _finalPage ? @"end" : @"page_down", nil)
                      withDelay:delay];
      break;
    case kExpandButton:
      [_view.textStorage
          addAttribute:NSForegroundColorAttributeName
                 value:theme.hilitedPreeditForeColor
                 range:NSMakeRange(_view.pagingRange.location +
                                       _view.pagingRange.length / 2,
                                   1)];
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
                 value:theme.hilitedPreeditForeColor
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

- (void)updateScreen __attribute__((objc_direct)) {
  for (NSScreen* screen in NSScreen.screens) {
    if (NSPointInRect(_IbeamRect.origin, screen.frame)) {
      _screen = screen;
      return;
    }
  }
  _screen = NSScreen.mainScreen;
}

- (void)updateDisplayParameters __attribute__((objc_direct)) {
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
                    [theme.textAttrs[NSFontAttributeName] pointSize] / 144.0);
  _textWidthLimit =
      ceil((theme.vertical ? NSHeight(screenRect) : NSWidth(screenRect)) *
               textWidthRatio -
           theme.borderInsets.width * 2 - theme.fullWidth);
  if (theme.lineLength > 0.1) {
    _textWidthLimit = fmin(theme.lineLength, _textWidthLimit);
  }
  if (theme.tabular) {
    _textWidthLimit =
        floor((_textWidthLimit + theme.fullWidth) / (theme.fullWidth * 2)) *
            (theme.fullWidth * 2) -
        theme.fullWidth;
  }
  CGFloat textHeightLimit =
      ceil((theme.vertical ? NSWidth(screenRect) : NSHeight(screenRect)) * 0.8 -
           theme.borderInsets.height * 2 - theme.linespace);
  _view.textView.textContainer.size =
      NSMakeSize(_textWidthLimit, textHeightLimit);

  // resize background image, if any
  if (theme.backImage.valid) {
    CGFloat widthLimit = _textWidthLimit + theme.fullWidth;
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
- (void)show __attribute__((objc_direct)) {
  if (!_needsRedraw && !_initPosition) {
    self.visible ? [self display] : [self orderFront:nil];
    return;
  }
  // Break line if the text is too long, based on screen size.
  SquirrelTheme* theme = _view.currentTheme;
  NSEdgeInsets insets = _view.marginInsets;
  CGFloat textWidthRatio =
      fmin(0.8, 1.0 / (theme.vertical ? 4 : 3) +
                    [theme.textAttrs[NSFontAttributeName] pointSize] / 144.0);
  NSRect screenRect = _screen.visibleFrame;

  // the sweep direction of the client app changes the behavior of adjusting
  // squirrel panel position
  BOOL sweepVertical = NSWidth(_IbeamRect) > NSHeight(_IbeamRect);
  NSRect contentRect = _view.contentRect;
  contentRect.size.width -= _view.trailPadding;
  // fixed line length (text width), but not applicable to status message
  if (theme.lineLength > 0.1 && _statusMessage == nil) {
    contentRect.size.width = _textWidthLimit;
  }
  // remember panel size (fix the top leading anchor of the panel in screen
  // coordiantes) but only when the text would expand on the side of upstream
  // (i.e. towards the beginning of text)
  if (theme.rememberSize && _statusMessage == nil) {
    if (theme.lineLength < 0.1 &&
        (theme.vertical
             ? (sweepVertical
                    ? (NSMinY(_IbeamRect) -
                           fmax(NSWidth(contentRect), _maxSize.width) -
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
                           fmax(NSWidth(contentRect), _maxSize.width) +
                           insets.right >
                       NSMaxX(screenRect))))) {
      if (NSWidth(contentRect) >= _maxSize.width) {
        _maxSize.width = NSWidth(contentRect);
      } else {
        contentRect.size.width = _maxSize.width;
      }
    }
    CGFloat textHeight = fmax(NSHeight(contentRect), _maxSize.height) +
                         insets.top + insets.bottom;
    if (theme.vertical ? (NSMinX(_IbeamRect) - textHeight -
                              (sweepVertical ? kOffsetGap : 0) <
                          NSMinX(screenRect))
                       : (NSMinY(_IbeamRect) - textHeight -
                              (sweepVertical ? 0 : kOffsetGap) <
                          NSMinY(screenRect))) {
      if (NSHeight(contentRect) >= _maxSize.height) {
        _maxSize.height = NSHeight(contentRect);
      } else {
        contentRect.size.height = _maxSize.height;
      }
    }
  }

  NSRect windowRect;
  if (_statusMessage != nil) {
    // following system UI, middle-align status message with cursor
    _initPosition = YES;
    if (theme.vertical) {
      windowRect.size.width =
          NSHeight(contentRect) + insets.top + insets.bottom;
      windowRect.size.height =
          NSWidth(contentRect) + insets.left + insets.right;
    } else {
      windowRect.size.width = NSWidth(contentRect) + insets.left + insets.right;
      windowRect.size.height =
          NSHeight(contentRect) + insets.top + insets.bottom;
    }
    if (sweepVertical) {
      // vertically centre-align (MidY) in screen coordinates
      windowRect.origin.x =
          NSMinX(_IbeamRect) - kOffsetGap - NSWidth(windowRect);
      windowRect.origin.y = NSMidY(_IbeamRect) - NSHeight(windowRect) * 0.5;
    } else {
      // horizontally centre-align (MidX) in screen coordinates
      windowRect.origin.x = NSMidX(_IbeamRect) - NSWidth(windowRect) * 0.5;
      windowRect.origin.y =
          NSMinY(_IbeamRect) - kOffsetGap - NSHeight(windowRect);
    }
  } else {
    if (theme.vertical) {
      // anchor is the top right corner in screen coordinates (MaxX, MaxY)
      windowRect =
          NSMakeRect(NSMaxX(self.frame) - NSHeight(contentRect) - insets.top -
                         insets.bottom,
                     NSMaxY(self.frame) - NSWidth(contentRect) - insets.left -
                         insets.right,
                     NSHeight(contentRect) + insets.top + insets.bottom,
                     NSWidth(contentRect) + insets.left + insets.right);
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
    } else {
      // anchor is the top left corner in screen coordinates (MinX, MaxY)
      windowRect =
          NSMakeRect(NSMinX(self.frame),
                     NSMaxY(self.frame) - NSHeight(contentRect) - insets.top -
                         insets.bottom,
                     NSWidth(contentRect) + insets.left + insets.right,
                     NSHeight(contentRect) + insets.top + insets.bottom);
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
    windowRect.origin.x += NSHeight(contentRect) - NSHeight(_view.contentRect);
    windowRect.size.width -=
        NSHeight(contentRect) - NSHeight(_view.contentRect);
  } else {
    windowRect.origin.y += NSHeight(contentRect) - NSHeight(_view.contentRect);
    windowRect.size.height -=
        NSHeight(contentRect) - NSHeight(_view.contentRect);
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
  self.alphaValue = theme.opacity;
  [self orderFront:nil];
  // reset to initial position after showing status message
  _initPosition = _statusMessage != nil;
  _needsRedraw = NO;
  // voila !
}

- (void)hide __attribute__((objc_direct)) {
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

// Main function to add attributes to text output from librime
- (void)showPreedit:(NSString*)preeditString
            selRange:(NSRange)selRange
            caretPos:(NSUInteger)caretPos
    candidateIndices:(NSRange)indexRange
    highlightedIndex:(NSUInteger)highlightedIndex
             pageNum:(NSUInteger)pageNum
           finalPage:(BOOL)finalPage
          didCompose:(BOOL)didCompose {
  BOOL updateCandidates = didCompose || !NSEqualRanges(_indexRange, indexRange);
  _caretAtHome = caretPos == NSNotFound ||
                 (caretPos == selRange.location && selRange.location == 1);
  _caretPos = caretPos;
  _pageNum = pageNum;
  _finalPage = finalPage;
  _functionButton = kVoidSymbol;
  if (indexRange.length > 0 || preeditString.length > 0) {
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
  NSTextStorage* contents = _view.textStorage;
  NSParagraphStyle* rulerAttrsPreedit;
  NSSize priorSize = contents.length > 0 ? _view.contentRect.size : NSZeroSize;
  if ((indexRange.length == 0 && preeditString &&
       _view.preeditRange.length > 0) ||
      !updateCandidates) {
    rulerAttrsPreedit = [contents attribute:NSParagraphStyleAttributeName
                                    atIndex:0
                             effectiveRange:NULL];
  }
  SquirrelCandidateRanges* candidateRanges;
  BOOL* truncated;
  if (updateCandidates) {
    contents.attributedString = NSAttributedString.alloc.init;
    if (theme.lineLength > 0.1) {
      _maxSize.width = fmin(theme.lineLength, _textWidthLimit);
    }
    _indexRange = indexRange;
    _highlightedIndex = highlightedIndex;
    candidateRanges = indexRange.length > 0
                          ? new SquirrelCandidateRanges[indexRange.length]
                          : NULL;
    truncated = indexRange.length > 0 ? new BOOL[indexRange.length] : NULL;
  }
  NSRange preeditRange = NSMakeRange(NSNotFound, 0);
  NSRange pagingRange = NSMakeRange(NSNotFound, 0);
  NSUInteger candidatesStart = 0;
  NSUInteger pagingStart = 0;

  // preedit
  if (preeditString) {
    NSMutableAttributedString* preedit =
        [NSMutableAttributedString.alloc initWithString:preeditString
                                             attributes:theme.preeditAttrs];
    [preedit.mutableString
        appendString:rulerAttrsPreedit ? @"\t" : kFullWidthSpace];
    if (selRange.length > 0) {
      [preedit addAttribute:NSForegroundColorAttributeName
                      value:theme.hilitedPreeditForeColor
                      range:selRange];
      NSNumber* padding =
          @(ceil(theme.preeditParagraphStyle.minimumLineHeight * 0.05));
      if (selRange.location > 0) {
        [preedit addAttribute:NSKernAttributeName
                        value:padding
                        range:NSMakeRange(selRange.location - 1, 1)];
      }
      if (NSMaxRange(selRange) < preedit.length) {
        [preedit addAttribute:NSKernAttributeName
                        value:padding
                        range:NSMakeRange(NSMaxRange(selRange) - 1, 1)];
      }
    }
    [preedit appendAttributedString:_caretAtHome ? theme.symbolDeleteStroke
                                                 : theme.symbolDeleteFill];
    // force caret to be rendered sideways, instead of uprights, in vertical
    // orientation
    if (theme.vertical && caretPos != NSNotFound) {
      [preedit
          addAttribute:NSVerticalGlyphFormAttributeName
                 value:@(NO)
                 range:NSMakeRange(caretPos - (caretPos < NSMaxRange(selRange)),
                                   1)];
    }
    preeditRange = NSMakeRange(0, preedit.length);
    if (rulerAttrsPreedit) {
      [preedit addAttribute:NSParagraphStyleAttributeName
                      value:rulerAttrsPreedit
                      range:preeditRange];
    }

    if (updateCandidates) {
      [contents appendAttributedString:preedit];
      if (indexRange.length > 0) {
        [contents.mutableString appendString:@"\n"];
      } else {
        self.sectionNum = 0;
        goto AdjustAlignment;
      }
    } else {
      [contents replaceCharactersInRange:_view.preeditRange
                    withAttributedString:preedit];
      [_view setPreeditRange:preeditRange hilitedPreeditRange:selRange];
    }
  }

  if (!updateCandidates) {
    if (_highlightedIndex != highlightedIndex) {
      [self highlightCandidate:highlightedIndex];
    }
    NSSize newSize = _view.contentRect.size;
    _needsRedraw |= !NSEqualSizes(priorSize, newSize);
    [self show];
    return;
  }

  // candidate items
  candidatesStart = contents.length;
  for (NSUInteger idx = 0; idx < indexRange.length; ++idx) {
    NSUInteger col = idx % theme.pageSize;
    NSMutableAttributedString* candidate =
        idx / theme.pageSize != _sectionNum
            ? theme.candidateDimmedTemplate.mutableCopy
        : idx == highlightedIndex ? theme.candidateHilitedTemplate.mutableCopy
                                  : theme.candidateTemplate.mutableCopy;
    // plug in enumerator, candidate text and comment into the template
    NSRange enumRange = [candidate.mutableString rangeOfString:@"%c"];
    [candidate replaceCharactersInRange:enumRange withString:theme.labels[col]];

    NSRange textRange = [candidate.mutableString rangeOfString:@"%@"];
    NSString* text = _inputController.candidateTexts[idx + indexRange.location];
    [candidate replaceCharactersInRange:textRange withString:text];

    NSRange commentRange =
        [candidate.mutableString rangeOfString:kTipSpecifier];
    NSString* comment =
        _inputController.candidateComments[idx + indexRange.location];
    if (comment.length > 0) {
      [candidate
          replaceCharactersInRange:commentRange
                        withString:[@"\u00A0" stringByAppendingString:comment]];
    } else {
      [candidate deleteCharactersInRange:commentRange];
    }
    // parse markdown and ruby annotation
    [candidate formatMarkDown];
    CGFloat annotationHeight =
        [candidate annotateRubyInRange:NSMakeRange(0, candidate.length)
                   verticalOrientation:theme.vertical
                         maximumLength:_textWidthLimit
                         scriptVariant:_optionSwitcher.currentScriptVariant];
    if (annotationHeight * 2 > theme.linespace) {
      [self setAnnotationHeight:annotationHeight];
      [candidate addAttribute:NSParagraphStyleAttributeName
                        value:theme.candidateParagraphStyle
                        range:NSMakeRange(0, candidate.length)];
      if (idx > 0) {
        if (theme.linear) {
          BOOL isTruncated = truncated[0];
          NSUInteger start = candidateRanges[0].location;
          for (NSUInteger i = 1; i <= idx; ++i) {
            if (i == idx || truncated[i] != isTruncated) {
              [contents
                  addAttribute:NSParagraphStyleAttributeName
                         value:isTruncated ? theme.truncatedParagraphStyle
                                           : theme.candidateParagraphStyle
                         range:NSMakeRange(
                                   start,
                                   NSMaxRange(candidateRanges[i - 1]) - start)];
              if (i < idx) {
                isTruncated = truncated[i];
                start = candidateRanges[i].location;
              }
            }
          }
        } else {
          [contents
              addAttribute:NSParagraphStyleAttributeName
                     value:theme.candidateParagraphStyle
                     range:NSMakeRange(candidatesStart,
                                       contents.length - candidatesStart)];
        }
      }
    }
    // store final in-candidate locations of label, text, and comment
    textRange = [candidate.mutableString rangeOfString:text];

    if (idx > 0 && (!theme.linear || !truncated[idx - 1])) {
      // separator: linear = "\u3000\x1D"; tabular = "\u3000\t\x1D"; stacked =
      // "\n"
      [contents appendAttributedString:theme.separator];
      if (theme.linear && col == 0) {
        [contents.mutableString appendString:@"\n"];
      }
    }
    NSUInteger candidateStart = contents.length;
    SquirrelCandidateRanges ranges = {.location = candidateStart,
                                      .text = textRange.location,
                                      .comment = NSMaxRange(textRange)};
    [contents appendAttributedString:candidate];
    // for linear layout, middle-truncate candidates that are longer than one
    // line
    if (theme.linear &&
        ceil(candidate.size.width) >
            _textWidthLimit - theme.fullWidth * (theme.tabular ? 2 : 1) - 0.1) {
      truncated[idx] = YES;
      ranges.length = contents.length - candidateStart;
      candidateRanges[idx] = ranges;
      if (idx < indexRange.length - 1 || theme.tabular || theme.showPaging) {
        [contents.mutableString appendString:@"\n"];
      }
      [contents addAttribute:NSParagraphStyleAttributeName
                       value:theme.truncatedParagraphStyle
                       range:NSMakeRange(candidateStart,
                                         contents.length - candidateStart)];
    } else {
      truncated[idx] = NO;
      ranges.length = candidate.length + (theme.tabular  ? 3
                                          : theme.linear ? 2
                                                         : 0);
      candidateRanges[idx] = ranges;
    }
  }

  // paging indication
  if (theme.tabular || theme.showPaging) {
    NSMutableAttributedString* paging;
    if (theme.tabular) {
      paging = [NSMutableAttributedString.alloc
          initWithAttributedString:_locked          ? theme.symbolLock
                                   : _view.expanded ? theme.symbolCompress
                                                    : theme.symbolExpand];
    } else {
      NSAttributedString* pageNumString = [NSAttributedString.alloc
          initWithString:[NSString stringWithFormat:@"%lu", pageNum + 1]
              attributes:theme.pagingAttrs];
      if (theme.vertical) {
        paging = [NSMutableAttributedString.alloc
            initWithAttributedString:
                [pageNumString attributedStringHorizontalInVerticalForms]];
      } else {
        paging = [NSMutableAttributedString.alloc
            initWithAttributedString:pageNumString];
      }
    }
    if (theme.showPaging) {
      [paging insertAttributedString:_pageNum > 0 ? theme.symbolBackFill
                                                  : theme.symbolBackStroke
                             atIndex:0];
      [paging.mutableString insertString:kFullWidthSpace atIndex:1];
      [paging.mutableString appendString:kFullWidthSpace];
      [paging appendAttributedString:_finalPage ? theme.symbolForwardStroke
                                                : theme.symbolForwardFill];
    }
    if (!theme.linear || !truncated[indexRange.length - 1]) {
      [contents appendAttributedString:theme.separator];
      if (theme.linear) {
        [contents replaceCharactersInRange:NSMakeRange(contents.length, 0)
                                withString:@"\n"];
      }
    }
    pagingStart = contents.length;
    if (theme.linear) {
      [contents appendAttributedString:[NSAttributedString.alloc
                                           initWithString:kFullWidthSpace
                                               attributes:theme.pagingAttrs]];
    }
    [contents appendAttributedString:paging];
    pagingRange = NSMakeRange(contents.length - paging.length, paging.length);
  } else if (theme.linear && !truncated[indexRange.length - 1]) {
    [contents appendAttributedString:theme.separator];
  }

AdjustAlignment:
  [_view estimateBoundsForPreedit:preeditRange
                       candidates:candidateRanges
                       truncation:truncated
                            count:indexRange.length
                           paging:pagingRange];
  CGFloat textWidth =
      fmin(fmax(NSMaxX(_view.contentRect) - _view.trailPadding, _maxSize.width),
           _textWidthLimit);
  // right-align the backward delete symbol
  if (preeditRange.length > 0 &&
      NSMaxX([_view blockRectForRange:NSMakeRange(preeditRange.length - 1,
                                                  1)]) < textWidth - 0.1) {
    [contents replaceCharactersInRange:NSMakeRange(preeditRange.length - 2, 1)
                            withString:@"\t"];
    NSMutableParagraphStyle* rulerAttrs =
        theme.preeditParagraphStyle.mutableCopy;
    rulerAttrs.tabStops =
        @[ [NSTextTab.alloc initWithTextAlignment:NSTextAlignmentRight
                                         location:textWidth
                                          options:@{}] ];
    [contents addAttribute:NSParagraphStyleAttributeName
                     value:rulerAttrs
                     range:preeditRange];
  }
  if (pagingRange.length > 0 &&
      NSMaxX([_view blockRectForRange:pagingRange]) < textWidth - 0.1) {
    NSMutableParagraphStyle* rulerAttrsPaging =
        theme.pagingParagraphStyle.mutableCopy;
    if (theme.linear) {
      [contents replaceCharactersInRange:NSMakeRange(pagingStart, 1)
                              withString:@"\t"];
      rulerAttrsPaging.tabStops =
          @[ [NSTextTab.alloc initWithTextAlignment:NSTextAlignmentRight
                                           location:textWidth
                                            options:@{}] ];
    } else {
      [contents replaceCharactersInRange:NSMakeRange(pagingStart + 1, 1)
                              withString:@"\t"];
      [contents replaceCharactersInRange:NSMakeRange(contents.length - 2, 1)
                              withString:@"\t"];
      rulerAttrsPaging.tabStops = @[
        [NSTextTab.alloc initWithTextAlignment:NSTextAlignmentCenter
                                      location:textWidth * 0.5
                                       options:@{}],
        [NSTextTab.alloc initWithTextAlignment:NSTextAlignmentRight
                                      location:textWidth
                                       options:@{}]
      ];
    }
    [contents
        addAttribute:NSParagraphStyleAttributeName
               value:rulerAttrsPaging
               range:NSMakeRange(pagingStart, contents.length - pagingStart)];
  }

  // text done!
  CGFloat topMargin =
      preeditString || theme.linear ? 0.0 : ceil(theme.linespace * 0.5);
  CGFloat bottomMargin =
      !theme.linear && indexRange.length > 0 && pagingRange.length == 0
          ? floor(theme.linespace * 0.5)
          : 0.0;
  NSEdgeInsets insets =
      NSEdgeInsetsMake(theme.borderInsets.height + topMargin,
                       theme.borderInsets.width + ceil(theme.fullWidth * 0.5),
                       theme.borderInsets.height + bottomMargin,
                       theme.borderInsets.width + floor(theme.fullWidth * 0.5));

  self.animationBehavior = caretPos == NSNotFound
                               ? NSWindowAnimationBehaviorUtilityWindow
                               : NSWindowAnimationBehaviorDefault;
  [_view drawViewWithInsets:insets
               hilitedIndex:highlightedIndex
        hilitedPreeditRange:selRange];
  NSSize newSize = _view.contentRect.size;
  _needsRedraw |= !NSEqualSizes(priorSize, newSize);
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

- (void)showStatus:(NSString*)message __attribute__((objc_direct)) {
  SquirrelTheme* theme = _view.currentTheme;
  NSTextStorage* contents = _view.textStorage;
  NSSize priorSize = contents.length > 0 ? _view.contentRect.size : NSZeroSize;

  contents.attributedString = [NSAttributedString.alloc
      initWithString:[NSString stringWithFormat:@"\u3000\u2002%@", message]
          attributes:theme.statusAttrs];

  [_view estimateBoundsForPreedit:NSMakeRange(NSNotFound, 0)
                       candidates:NULL
                       truncation:NULL
                            count:0
                           paging:NSMakeRange(NSNotFound, 0)];
  NSEdgeInsets insets =
      NSEdgeInsetsMake(theme.borderInsets.height,
                       theme.borderInsets.width + ceil(theme.fullWidth * 0.5),
                       theme.borderInsets.height,
                       theme.borderInsets.width + floor(theme.fullWidth * 0.5));

  // disable remember_size and fixed line_length for status messages
  _initPosition = YES;
  _maxSize = NSZeroSize;
  if (_statusTimer.valid) {
    [_statusTimer invalidate];
  }
  self.animationBehavior = NSWindowAnimationBehaviorUtilityWindow;
  [_view drawViewWithInsets:insets
               hilitedIndex:NSNotFound
        hilitedPreeditRange:NSMakeRange(NSNotFound, 0)];
  NSSize newSize = _view.contentRect.size;
  _needsRedraw |= !NSEqualSizes(priorSize, newSize);
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

- (void)setAnnotationHeight:(CGFloat)height __attribute__((objc_direct)) {
  [SquirrelView.defaultTheme setAnnotationHeight:height];
  if (@available(macOS 10.14, *)) {
    [SquirrelView.darkTheme setAnnotationHeight:height];
  }
}

- (void)loadLabelConfig:(SquirrelConfig*)config directUpdate:(BOOL)update {
  [SquirrelView.defaultTheme updateLabelsWithConfig:config directUpdate:update];
  if (@available(macOS 10.14, *)) {
    [SquirrelView.darkTheme updateLabelsWithConfig:config directUpdate:update];
  }
  if (update) {
    [self updateDisplayParameters];
  }
}

- (void)loadConfig:(SquirrelConfig*)config {
  [SquirrelView.defaultTheme
      updateWithConfig:config
          styleOptions:_optionSwitcher.optionStates
         scriptVariant:_optionSwitcher.currentScriptVariant
         forAppearance:defaultAppear];
  if (@available(macOS 10.14, *)) {
    [SquirrelView.darkTheme
        updateWithConfig:config
            styleOptions:_optionSwitcher.optionStates
           scriptVariant:_optionSwitcher.currentScriptVariant
           forAppearance:darkAppear];
  }
  [self getLocked];
  [self updateDisplayParameters];
}

- (void)updateScriptVariant {
  [SquirrelView.defaultTheme
      setScriptVariant:_optionSwitcher.currentScriptVariant];
  if (@available(macOS 10.14, *)) {
    [SquirrelView.darkTheme
        setScriptVariant:_optionSwitcher.currentScriptVariant];
  }
}

@end  // SquirrelPanel
