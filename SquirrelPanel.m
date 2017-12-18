#import "SquirrelPanel.h"

#import "SquirrelConfig.h"

static const int kOffsetHeight = 5;
static const int kDefaultFontSize = 24;
static const NSTimeInterval kShowStatusDuration = 1.2;
static NSString *const kDefaultCandidateFormat = @"%c. %@";

@interface SquirrelView : NSView

@property(nonatomic, readonly) NSAttributedString *text;
@property(nonatomic, readonly) NSRect highlightedRect;
@property(nonatomic, readonly) NSSize contentSize;

@property(nonatomic, strong) NSColor *backgroundColor;
@property(nonatomic, assign) double cornerRadius;
@property(nonatomic, assign) NSSize edgeInset;
@property(nonatomic, strong) NSColor *highlightedStripColor;

- (void)setText:(NSAttributedString *)text
  hilightedRect:(NSRect)rect;

@end

@implementation SquirrelView

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
  }
  return self;
}

- (NSSize)contentSize {
  return _text ? _text.size : NSMakeSize(0, 0);
}

- (void)setText:(NSAttributedString *)text
  hilightedRect:(NSRect)rect {
  _text = [text copy];
  _highlightedRect = rect;
  self.needsDisplay = YES;
}

- (void)setBackgroundColor:(NSColor *)backgroundColor {
  _backgroundColor = (backgroundColor != nil ? backgroundColor : [NSColor windowBackgroundColor]);
  self.layer.backgroundColor = _backgroundColor.CGColor;
}

- (void) setCornerRadius:(double)cornerRadius {
  _cornerRadius = cornerRadius;
  self.layer.cornerRadius = _cornerRadius;
}

- (void)drawRect:(NSRect)dirtyRect {
  if (self.highlightedStripColor && !NSIsEmptyRect(self.highlightedRect)) {
    CGFloat edgeWidth = self.edgeInset.width + 1;
    CGFloat edgeHeight = self.edgeInset.height + 1;
    NSRect stripRect = self.highlightedRect;
    if (NSMinX(stripRect) - FLT_EPSILON < 0) {
      stripRect.size.width += edgeWidth;
    } else {
      stripRect.origin.x += edgeWidth;
    }
    if (NSMaxX(stripRect) + FLT_EPSILON > NSWidth(self.bounds) - edgeWidth) {
      stripRect.size.width += edgeWidth;
    }
    if (NSMinY(stripRect) - FLT_EPSILON < 0) {
      stripRect.size.height += edgeHeight;
    } else {
      stripRect.origin.y += edgeHeight;
    }
    if (NSMaxY(stripRect) + FLT_EPSILON > NSHeight(self.bounds) - edgeHeight) {
      stripRect.size.height += edgeHeight;
    }
    [self.highlightedStripColor setFill];
    NSRectFill(stripRect);
  }

  [_text drawAtPoint:NSMakePoint(self.edgeInset.width, self.edgeInset.height)];
}

@end

@implementation SquirrelPanel {
  NSWindow *_window;
  SquirrelView *_view;

  NSString *_candidateFormat;
  NSMutableDictionary *_attrs;
  NSMutableDictionary *_highlightedAttrs;
  NSMutableDictionary *_labelAttrs;
  NSMutableDictionary *_labelHighlightedAttrs;
  NSMutableDictionary *_commentAttrs;
  NSMutableDictionary *_commentHighlightedAttrs;
  NSMutableDictionary *_preeditAttrs;
  NSMutableDictionary *_preeditHighlightedAttrs;
  NSParagraphStyle *_paragraphStyle;
  NSParagraphStyle *_preeditParagraphStyle;

  NSString *_statusMessage;
  NSTimer *_statusTimer;
}

- (void)initializeUIStyle {
  _candidateFormat = kDefaultCandidateFormat;

  _attrs = [[NSMutableDictionary alloc] init];
  _attrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  _attrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];
  
  _highlightedAttrs = [[NSMutableDictionary alloc] init];
  _highlightedAttrs[NSForegroundColorAttributeName] = [NSColor selectedControlTextColor];
  //_highlightedAttrs[NSBackgroundColorAttributeName] = [NSColor selectedTextBackgroundColor];
  _highlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];
  
  _labelAttrs = [_attrs mutableCopy];
  _labelHighlightedAttrs = [_highlightedAttrs mutableCopy];
  
  _commentAttrs = [[NSMutableDictionary alloc] init];
  _commentAttrs[NSForegroundColorAttributeName] = [NSColor disabledControlTextColor];
  _commentAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];
  
  _commentHighlightedAttrs = [_commentAttrs mutableCopy];
  //_commentHighlightedAttrs[NSBackgroundColorAttributeName] =
  //    [NSColor selectedTextBackgroundColor];
  
  _preeditAttrs = [[NSMutableDictionary alloc] init];
  _preeditAttrs[NSForegroundColorAttributeName] = [NSColor disabledControlTextColor];
  _preeditAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];
  
  _preeditHighlightedAttrs = [[NSMutableDictionary alloc] init];
  _preeditHighlightedAttrs[NSForegroundColorAttributeName] = [NSColor controlTextColor];
  _preeditHighlightedAttrs[NSFontAttributeName] = [NSFont userFontOfSize:kDefaultFontSize];

  _paragraphStyle = [NSParagraphStyle defaultParagraphStyle];
  _preeditParagraphStyle = [NSParagraphStyle defaultParagraphStyle];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _window = [[NSWindow alloc] initWithContentRect:_position
                                          styleMask:NSBorderlessWindowMask
                                            backing:NSBackingStoreBuffered
                                              defer:YES];
    _window.alphaValue = 1.0;
    // _window.level = NSScreenSaverWindowLevel + 1;
    // 我不确定这么写有没有别的问题，但是全屏游戏里可以正常使用了。
    _window.level = CGShieldingWindowLevel();
    _window.hasShadow = YES;
    _window.opaque = NO;
    _window.backgroundColor = [NSColor clearColor];
    _view = [[SquirrelView alloc] initWithFrame:_window.contentView.frame];
    _window.contentView = _view;

    [self initializeUIStyle];
  }
  return self;
}

- (void)show {
  NSRect windowRect;
  windowRect.size = NSMakeSize(_view.contentSize.width + _view.edgeInset.width * 2,
                               _view.contentSize.height + _view.edgeInset.height * 2);
  windowRect.origin = NSMakePoint(NSMinX(_position),
                                  NSMinY(_position) - kOffsetHeight - NSHeight(windowRect));
  // fit in current screen
  NSRect screenRect = [NSScreen mainScreen].frame;
  NSArray *screens = [NSScreen screens];
  NSUInteger i;
  for (i = 0; i < screens.count; ++i) {
    NSRect rect = [screens[i] frame];
    if (NSPointInRect(_position.origin, rect)) {
      screenRect = rect;
      break;
    }
  }
  if (NSMaxX(windowRect) > NSMaxX(screenRect)) {
    windowRect.origin.x = NSMaxX(screenRect) - NSWidth(windowRect);
  }
  if (NSMinX(windowRect) < NSMinX(screenRect)) {
    windowRect.origin.x = NSMinX(screenRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = NSMaxY(_position) + kOffsetHeight;
  }
  if (NSMaxY(windowRect) > NSMaxY(screenRect)) {
    windowRect.origin.y = NSMaxY(screenRect) - NSHeight(windowRect);
  }
  if (NSMinY(windowRect) < NSMinY(screenRect)) {
    windowRect.origin.y = NSMinY(screenRect);
  }
  // voila !
  [_window setFrame:windowRect display:YES];
  [_window orderFront:nil];
}

- (void)hide {
  if (_statusTimer) {
    [_statusTimer invalidate];
    _statusTimer = nil;
  }
  [_window orderOut:nil];
}

- (void)showPreedit:(NSString *)preedit
           selRange:(NSRange)selRange
           caretPos:(NSUInteger)caretPos
         candidates:(NSArray *)candidates
           comments:(NSArray *)comments
             labels:(NSString *)labels
        highlighted:(NSUInteger)index {
  NSUInteger numCandidates = candidates.count;
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

  NSRange labelRange, labelRange2, pureCandidateRange;
  NSString *labelFormat, *labelFormat2, *pureCandidateFormat;
  {
    // in our candiate format, everything other than '%@' is
    // considered as a part of the label

    labelRange = [_candidateFormat rangeOfString:@"%c"];
    if (labelRange.location == NSNotFound) {
      labelRange2 = labelRange;
      labelFormat2 = labelFormat = nil;

      pureCandidateRange = NSMakeRange(0, _candidateFormat.length);
      pureCandidateFormat = _candidateFormat;
    } else {
      pureCandidateRange = [_candidateFormat rangeOfString:@"%@"];
      if (pureCandidateRange.location == NSNotFound) {
        // this should never happen, but just ensure that Squirrel
        // would not crash when such edge case occurs...

        labelFormat = _candidateFormat;

        labelRange2 = pureCandidateRange;
        labelFormat2 = nil;

        pureCandidateFormat = @"";
      } else {
        if (NSMaxRange(pureCandidateRange) >= _candidateFormat.length) {
          // '%@' is at the end, so label2 does not exist
          labelRange2 = NSMakeRange(NSNotFound, 0);
          labelFormat2 = nil;

          // fix label1, everything other than '%@' is label1
          labelRange.location = 0;
          labelRange.length = pureCandidateRange.location;
        } else {
          labelRange = NSMakeRange(0, pureCandidateRange.location);
          labelRange2 = NSMakeRange(NSMaxRange(pureCandidateRange),
                                    _candidateFormat.length -
                                        NSMaxRange(pureCandidateRange));

          labelFormat2 = [_candidateFormat substringWithRange:labelRange2];
        }

        pureCandidateFormat = @"%@";
        labelFormat = [_candidateFormat substringWithRange:labelRange];
      }
    }
  }

  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] init];
  NSUInteger candidateStartPos = 0;

  // preedit
  if (preedit) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
    if (selRange.location > 0) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[preedit substringToIndex:selRange.location]
                        attributes:_preeditAttrs]];
    }
    if (selRange.length > 0) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[preedit substringWithRange:selRange]
                        attributes:_preeditHighlightedAttrs]];
    }
    if (selRange.location + selRange.length < preedit.length) {
      [line
          appendAttributedString:
              [[NSAttributedString alloc]
                  initWithString:[preedit substringFromIndex:selRange.location +
                                                             selRange.length]
                      attributes:_preeditAttrs]];
    }
    [text appendAttributedString:line];

    if (numCandidates) {
      [text appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:@"\n"
                                           attributes:_preeditAttrs]];
    }
    [text addAttribute:NSParagraphStyleAttributeName
                 value:_preeditParagraphStyle
                 range:NSMakeRange(0, text.length)];

    candidateStartPos = text.length;
  }

  NSRect highlightedRect = NSZeroRect;
  CGFloat separatorWidth = 0;

  // candidates
  NSUInteger i;
  for (i = 0; i < candidates.count; ++i) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];

    // default: 1. 2. 3... custom: A. B. C...
    char label_character = (i < labels.length) ? [labels characterAtIndex:i]
                                               : ((i + 1) % 10 + '0');

    NSDictionary *attrs = (i == index) ? _highlightedAttrs : _attrs;
    NSDictionary *labelAttrs =
        (i == index) ? _labelHighlightedAttrs : _labelAttrs;
    NSDictionary *commentAttrs =
        (i == index) ? _commentHighlightedAttrs : _commentAttrs;

    if (labelRange.location != NSNotFound) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[NSString stringWithFormat:labelFormat,
                                                              label_character]
                        attributes:labelAttrs]];
    }

    // Use left-to-right marks to prevent right-to-left text from changing the
    // layout of non-candidate text.
    NSString *candidate = [NSString stringWithFormat:@"\u200E%@\u200E", candidates[i]];

    [line appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:candidate
                                         attributes:attrs]];

    if (labelRange2.location != NSNotFound) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[NSString stringWithFormat:labelFormat2,
                                                              label_character]
                        attributes:labelAttrs]];
    }

    if (i < comments.count && [comments[i] length] != 0) {
      [line appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:@" "
                                           attributes:_attrs]];
      [line appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:comments[i]
                                           attributes:commentAttrs]];
    }

    if (i > 0) {
      NSAttributedString *separator = [[NSAttributedString alloc]
                                          initWithString:(_horizontal ? @"  " : @"\n")
                                              attributes:_attrs];
      if (_horizontal && separatorWidth == 0) {
        separatorWidth = separator.size.width;
      }
      [text appendAttributedString:separator];
    }

    [text appendAttributedString:line];

    if (i == index) {
      CGFloat left = 0;
      CGFloat bottom = 0;
      NSRange candidateRange = NSMakeRange(candidateStartPos, text.length - candidateStartPos);
      if (_horizontal) {
        NSAttributedString *candidateText = [text attributedSubstringFromRange:candidateRange];
        left = candidateText.size.width - line.size.width;
      } else {
        [text addAttribute:NSParagraphStyleAttributeName
                     value:_paragraphStyle
                     range:candidateRange];
        bottom = -text.size.height;
        [text removeAttribute:NSParagraphStyleAttributeName range:candidateRange];
      }
      highlightedRect = NSMakeRect(left, bottom, line.size.width, line.size.height);
    }
  }
  [text addAttribute:NSParagraphStyleAttributeName
               value:_paragraphStyle
               range:NSMakeRange(candidateStartPos,
                                 text.length - candidateStartPos)];

  if (!NSIsEmptyRect(highlightedRect)) {
    if (_horizontal) {
      if (preedit) {
        highlightedRect.size.height += _preeditParagraphStyle.paragraphSpacing / 2;
      }
      if (index > 0) {
        highlightedRect.origin.x -= separatorWidth / 2;
        highlightedRect.size.width += separatorWidth / 2;
      }
      if (index < numCandidates - 1) {
        highlightedRect.size.width += separatorWidth / 2;
      } else if (preedit) {
        // in case the preedit line is longer than the candidate list,
        // the highlight region for the last candidate should include empty space on the right.
        highlightedRect.size.width = text.size.width - highlightedRect.origin.x;
      }
    } else {
      NSSize fullSize = text.size;
      highlightedRect.origin.y += fullSize.height;
      highlightedRect.size.width = fullSize.width;
      if (index == 0) {
        if (preedit) {
          highlightedRect.size.height += MIN(_preeditParagraphStyle.paragraphSpacing,
                                             _paragraphStyle.paragraphSpacing) / 2;
        }
      } else {
        highlightedRect.size.height += _paragraphStyle.paragraphSpacing / 2;
      }
      if (index < numCandidates - 1) {
        highlightedRect.origin.y -= _paragraphStyle.paragraphSpacing / 2;
        highlightedRect.size.height += _paragraphStyle.paragraphSpacing / 2;
      }
    }
  }
  [_view setText:text hilightedRect:highlightedRect];
  [self show];
}

- (void)updateStatus:(NSString *)message {
  _statusMessage = message;
}

- (void)showStatus:(NSString *)message {
  NSAttributedString *text = [[NSAttributedString alloc] initWithString:message
                                                             attributes:_commentAttrs];
  [_view setText:text hilightedRect:NSZeroRect];
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
  if (!backgroundColor) {
    // return foregroundColor;
    backgroundColor = [NSColor lightGrayColor];
  }

  struct {
    CGFloat r, g, b, a;
  } f, b;

  [[foregroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace]
      getRed:&f.r
       green:&f.g
        blue:&f.b
       alpha:&f.a];
  //NSLog(@"fg: %f %f %f %f", f.r, f.g, f.b, f.a);

  [[backgroundColor colorUsingColorSpaceName:NSDeviceRGBColorSpace]
      getRed:&b.r
       green:&b.g
        blue:&b.b
       alpha:&b.a];
  //NSLog(@"bg: %f %f %f %f", b.r, b.g, b.b, b.a);

#define blend_value(f, b) (((f)*2.0 + (b)) / 3.0)
  return [NSColor colorWithDeviceRed:blend_value(f.r, b.r)
                               green:blend_value(f.g, b.g)
                                blue:blend_value(f.b, b.b)
                               alpha:f.a];
#undef blend_value
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
      [validFontDescriptors addObject:[NSFontDescriptor fontDescriptorWithName:fontName
                                                                          size:0.0]];
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

-(void)updateConfig:(SquirrelConfig *)config {
  _horizontal = [config getBool:@"style/horizontal"];
  _inlinePreedit = [config getBool:@"style/inline_preedit"];
  NSString *candidateFormat = [config getString:@"style/candidate_format"];
  _candidateFormat = candidateFormat ? candidateFormat : kDefaultCandidateFormat;

  NSString *fontName = [config getString:@"style/font_face"];
  NSInteger fontSize = [config getInt:@"style/font_point"];
  NSString *labelFontName = [config getString:@"style/label_font_face"];
  NSInteger labelFontSize = [config getInt:@"style/label_font_point"];
  NSColor *candidateLabelColor = [config getColor:@"style/label_color"];
  NSColor *highlightedCandidateLabelColor = [config getColor:@"style/label_hilited_color"];
  CGFloat alpha = fmin(fmax([config getDouble:@"style/alpha"], 0.0), 1.0);
  CGFloat cornerRadius = [config getDouble:@"style/corner_radius"];
  CGFloat borderHeight = [config getDouble:@"style/border_height"];
  CGFloat borderWidth = [config getDouble:@"style/border_width"];
  CGFloat lineSpacing = [config getDouble:@"style/line_spacing"];
  CGFloat spacing = [config getDouble:@"style/spacing"];

  NSColor *backgroundColor;
  NSColor *textColor;
  NSColor *highlightedTextColor;
  NSColor *highlightedBackColor;
  NSColor *candidateTextColor;
  NSColor *highlightedCandidateTextColor;
  NSColor *highlightedCandidateBackColor;
  NSColor *commentTextColor;
  NSColor *highlightedCommentTextColor;

  NSString *colorScheme = [config getString:@"style/color_scheme"];
  if (colorScheme) {
      NSString *prefix = [@"preset_color_schemes/" stringByAppendingString:colorScheme];

      backgroundColor = [config getColor:[prefix stringByAppendingString:@"/back_color"]];
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

      NSNumber *horizontalOverridden =
          [config getOptionalBool:[prefix stringByAppendingString:@"/horizontal"]];
      if (horizontalOverridden) {
        _horizontal = horizontalOverridden.boolValue;
      }
      NSNumber *inlinePreeditOverridden =
          [config getOptionalBool:[prefix stringByAppendingString:@"/inline_preedit"]];
      if (inlinePreeditOverridden) {
        _inlinePreedit = inlinePreeditOverridden.boolValue;
      }
      NSString *candidateFormatOverridden =
          [config getString:[prefix stringByAppendingString:@"/candidate_format"]];
      if (candidateFormatOverridden) {
        _candidateFormat = candidateFormatOverridden;
      }

      NSString *fontNameOverridden =
          [config getString:[prefix stringByAppendingString:@"/font_face"]];
      if (fontNameOverridden) {
        fontName = fontNameOverridden;
      }
      NSNumber *fontSizeOverridden =
          [config getOptionalInt:[prefix stringByAppendingString:@"/font_point"]];
      if (fontSizeOverridden) {
        fontSize = fontSizeOverridden.integerValue;
      }
      NSString *labelFontNameOverridden =
          [config getString:[prefix stringByAppendingString:@"/label_font_face"]];
      if (labelFontNameOverridden) {
        labelFontName = labelFontNameOverridden;
      }
      NSNumber *labelFontSizeOverridden =
          [config getOptionalInt:[prefix stringByAppendingString:@"/label_font_point"]];
      if (labelFontSizeOverridden) {
        labelFontSize = labelFontSizeOverridden.integerValue;
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
  }

  if (fontSize == 0) { // default size
    fontSize = kDefaultFontSize;
  }
  if (labelFontSize == 0) {
    labelFontSize = fontSize;
  }
  NSFontDescriptor *fontDescriptor = nil;
  NSFont *font = nil;
  if (fontName != nil) {
    fontDescriptor = getFontDescriptor(fontName);
    if (fontDescriptor != nil) {
      font = [NSFont fontWithDescriptor:fontDescriptor size:fontSize];
    }
  }
  if (font == nil) {
    // use default font
    font = [NSFont userFontOfSize:fontSize];
  }
  NSFontDescriptor *labelFontDescriptor = nil;
  NSFont *labelFont = nil;
  if (labelFontName != nil) {
    labelFontDescriptor = getFontDescriptor(labelFontName);
    if (labelFontDescriptor == nil) {
      labelFontDescriptor = fontDescriptor;
    }
    if (labelFontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:labelFontDescriptor size:labelFontSize];
    }
  }
  if (labelFont == nil) {
    if (fontDescriptor != nil) {
      labelFont = [NSFont fontWithDescriptor:fontDescriptor size:labelFontSize];
    } else {
      labelFont = [NSFont fontWithName:font.fontName size:labelFontSize];
    }
  }
  _attrs[NSFontAttributeName] = font;
  _highlightedAttrs[NSFontAttributeName] = font;
  _labelAttrs[NSFontAttributeName] = labelFont;
  _labelHighlightedAttrs[NSFontAttributeName] = labelFont;
  _commentAttrs[NSFontAttributeName] = font;
  _commentHighlightedAttrs[NSFontAttributeName] = font;
  _preeditAttrs[NSFontAttributeName] = font;
  _preeditHighlightedAttrs[NSFontAttributeName] = font;

  // can be nil.
  _view.backgroundColor = backgroundColor;

  _attrs[NSForegroundColorAttributeName] =
      candidateTextColor ? candidateTextColor : [NSColor controlTextColor];

  _labelAttrs[NSForegroundColorAttributeName] =
      candidateLabelColor ? candidateLabelColor
          : blendColors(_attrs[NSForegroundColorAttributeName], backgroundColor);

  _highlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCandidateTextColor ? highlightedCandidateTextColor
                                    : [NSColor selectedControlTextColor];

  //_highlightedAttrs[NSBackgroundColorAttributeName] =
  //    highlightedCandidateBackColor ? highlightedCandidateBackColor
  //                                  : [NSColor selectedTextBackgroundColor];

  _view.highlightedStripColor =
      highlightedCandidateBackColor ? highlightedCandidateBackColor
                                    : [NSColor selectedTextBackgroundColor];

  _labelHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCandidateLabelColor ? highlightedCandidateLabelColor
          : blendColors(_highlightedAttrs[NSForegroundColorAttributeName],
                        _highlightedAttrs[NSBackgroundColorAttributeName]);

  //_labelHighlightedAttrs[NSBackgroundColorAttributeName] =
  //    _highlightedAttrs[NSBackgroundColorAttributeName];

  _commentAttrs[NSForegroundColorAttributeName] =
      commentTextColor ? commentTextColor : [NSColor disabledControlTextColor];

  _commentHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedCommentTextColor ? highlightedCommentTextColor
                                  : _commentAttrs[NSForegroundColorAttributeName];

  //_commentHighlightedAttrs[NSBackgroundColorAttributeName] =
  //    _highlightedAttrs[NSBackgroundColorAttributeName];

  _preeditAttrs[NSForegroundColorAttributeName] =
      textColor ? textColor : [NSColor disabledControlTextColor];

  _preeditHighlightedAttrs[NSForegroundColorAttributeName] =
      highlightedTextColor ? highlightedTextColor : [NSColor controlTextColor];

  if (highlightedBackColor != nil) {
    _preeditHighlightedAttrs[NSBackgroundColorAttributeName] = highlightedBackColor;
  } else {
    [_preeditHighlightedAttrs removeObjectForKey:NSBackgroundColorAttributeName];
  }

  _view.cornerRadius = cornerRadius;
  _view.edgeInset = NSMakeSize(MAX(borderWidth, cornerRadius), MAX(borderHeight, cornerRadius));

  _window.alphaValue = (alpha == 0) ? 1.0 : alpha;

  NSMutableParagraphStyle *paragraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.paragraphSpacing = lineSpacing;
  _paragraphStyle = paragraphStyle;

  NSMutableParagraphStyle *preeditParagraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.paragraphSpacing = spacing;
  _preeditParagraphStyle = preeditParagraphStyle;
}

@end
