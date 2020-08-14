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
@property(nonatomic, assign) double hilitedCornerRadius;
@property(nonatomic, assign) NSSize edgeInset;
@property(nonatomic, strong) NSColor *highlightedStripColor;
@property(nonatomic, assign) CGFloat baseOffset;
@property(nonatomic, assign) Boolean horizontal;

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
  NSColor * _backgroundColor = (backgroundColor != nil ? backgroundColor : [NSColor windowBackgroundColor]);
  self.layer.backgroundColor = _backgroundColor.CGColor;
}

- (void) setCornerRadius:(double)cornerRadius {
  _cornerRadius = cornerRadius;
  self.layer.cornerRadius = _cornerRadius;
}

- (void)drawRect:(NSRect)dirtyRect {
  if (self.highlightedStripColor && !NSIsEmptyRect(self.highlightedRect)) {
    // setFrame rounds up floating point numbers in window bounds.
    // Add extra width and height to overcome rounding errors and ensure
    // highlighted area fully covers paddings near right and top edges.
    const CGFloat ROUND_UP = 1;
    CGFloat corner = self.hilitedCornerRadius / 2;
    CGFloat edgeWidth = self.edgeInset.width;
    CGFloat edgeHeight = self.edgeInset.height;
    NSRect stripRect = self.highlightedRect;
    if (!_horizontal) {
      stripRect.origin.x = dirtyRect.origin.x;
      stripRect.size.width = dirtyRect.size.width - self.edgeInset.width * 2;
    }
    if (NSMinX(stripRect) < FLT_EPSILON) {
      if (corner == 0) {
        stripRect.size.width += edgeWidth;
      } else {
        stripRect.size.width += corner;
        stripRect.origin.x += edgeWidth - corner;
      }
    } else {
      stripRect.size.width += corner;
      stripRect.origin.x += edgeWidth - corner;
    }
    if (NSMaxX(stripRect) + edgeWidth + ROUND_UP > NSWidth(self.bounds)) {
      if (corner == 0) {
        stripRect.size.width += edgeWidth + ROUND_UP;
      } else {
        stripRect.size.width += corner;
      }
    }
    if (NSMinY(stripRect) < FLT_EPSILON) {
      if (corner == 0) {
        stripRect.size.height += edgeHeight;
      } else {
        stripRect.size.height += corner;
        stripRect.origin.y += edgeHeight - corner;
      }
    } else {
      stripRect.origin.y += edgeHeight;
    }
    if (NSMaxY(stripRect) + edgeHeight + ROUND_UP > NSHeight(self.bounds)) {
      if (corner == 0) {
        stripRect.size.height += edgeHeight + ROUND_UP;
      } else {
        stripRect.size.height += corner;
      }
    }
    [self.highlightedStripColor setFill];
    if (self.hilitedCornerRadius > 0) {
      [[NSBezierPath bezierPathWithRoundedRect:stripRect
                                       xRadius:self.hilitedCornerRadius
                                       yRadius:self.hilitedCornerRadius] fill];
    } else {
      NSRectFill(stripRect);
    }
  }

  NSRect textField = NSZeroRect;
  textField.origin = NSMakePoint(dirtyRect.origin.x + self.edgeInset.width, dirtyRect.origin.y - self.edgeInset.height);
  textField.size = NSMakeSize(dirtyRect.size.width - self.edgeInset.width * 2,
                             dirtyRect.size.height);
  [_text drawInRect:textField];
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
  NSMutableParagraphStyle *_paragraphStyle;
  NSMutableParagraphStyle *_preeditParagraphStyle;

  NSString *_statusMessage;
  NSTimer *_statusTimer;
}

- (void)convertToVerticalGlyph:(NSMutableAttributedString *)originalText {
  const NSAttributedString *cjkChar = [[NSAttributedString alloc] initWithString:@"　" attributes:[originalText attributesAtIndex:originalText.length-1 effectiveRange:NULL]];
  const NSSize cjkSize = [cjkChar boundingRectWithSize:NSMakeSize(0, 0) options:NSStringDrawingUsesLineFragmentOrigin].size;
  const NSAttributedString *hangulChar = [[NSAttributedString alloc] initWithString:@"한" attributes:[originalText attributesAtIndex:originalText.length-1 effectiveRange:NULL]];
  const NSSize hangulSize = [hangulChar boundingRectWithSize:NSMakeSize(0, 0) options:NSStringDrawingUsesLineFragmentOrigin].size;
  NSUInteger i = 0;
  while (i < originalText.length) {
    NSRange range = [originalText.string rangeOfComposedCharacterSequenceAtIndex:i];
    i = range.location + range.length;
    NSSize charSize = [[originalText attributedSubstringFromRange:range] boundingRectWithSize:NSMakeSize(0, 0) options:NSStringDrawingUsesLineFragmentOrigin].size;
    if ((charSize.width >= cjkSize.width) || (charSize.width >= hangulSize.width)) {
      [originalText addAttributes:@{NSVerticalGlyphFormAttributeName:@(1), NSBaselineOffsetAttributeName:@(_view.baseOffset - (charSize.width - cjkSize.width) / cjkSize.width * 7)
      } range:range];
    } else {
      [originalText addAttributes:@{NSBaselineOffsetAttributeName:@(_view.baseOffset * 0.3 + (charSize.width - cjkSize.width) / cjkSize.width * 4)} range:range];
    }
  }
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

  _paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  _preeditParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _window = [[NSWindow alloc] initWithContentRect:_position
                                          styleMask:NSWindowStyleMaskBorderless
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
  if (_vertical) {
    windowRect.size = NSMakeSize(_view.contentSize.height + _view.edgeInset.height * 2,
                                 _view.contentSize.width + _view.edgeInset.width * 2);
  } else {
    windowRect.size = NSMakeSize(_view.contentSize.width + _view.edgeInset.width * 2,
                                 _view.contentSize.height + _view.edgeInset.height * 2);
  }
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

  if (_vertical && (windowRect.size.height > NSHeight(screenRect) / 3)) {
    windowRect.size.height = NSHeight(screenRect) / 3;
    windowRect.size.width = [_view.text boundingRectWithSize:NSMakeSize(windowRect.size.height - _view.edgeInset.height * 2, windowRect.size.width - _view.edgeInset.width * 2) options:NSStringDrawingUsesLineFragmentOrigin].size.height + _view.edgeInset.height * 2;
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
  if (_vertical) {
    _view.boundsRotation = -90.0;
    [_view setBoundsOrigin:NSMakePoint(_view.contentSize.width + _view.edgeInset.width * 2, _view.edgeInset.height * 2)];
  } else {
    _view.boundsRotation = 0;
    [_view setBoundsOrigin:NSMakePoint(0, 0)];
  }
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

  NSRect screenRect = [NSScreen mainScreen].frame;
  CGFloat height = 0.0;
  
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
    if (_vertical) {
      [self convertToVerticalGlyph:text];
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

    CGFloat labelWidth = 0.0;
    if (labelRange.location != NSNotFound) {
      [line appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[NSString stringWithFormat:labelFormat,
                                                              label_character]
                        attributes:labelAttrs]];
      if (_vertical) {
        [self convertToVerticalGlyph:line];
        labelWidth = [line boundingRectWithSize:NSMakeSize(0.0, 0.0) options:NSStringDrawingUsesLineFragmentOrigin].size.width;
      }
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
      NSMutableAttributedString *separator = [[NSMutableAttributedString alloc]
                                          initWithString:(_horizontal ? @"  " : @"\n")
                                              attributes:_attrs];
      if (_horizontal && separatorWidth == 0) {
        separatorWidth = separator.size.width;
      }
      [text appendAttributedString:separator];
    }
    
    if (_vertical) {
      [self convertToVerticalGlyph:line];
    }
    NSMutableParagraphStyle *paragraphStyleCandidate = [_paragraphStyle mutableCopy];
    paragraphStyleCandidate.headIndent = labelWidth;
    [line addAttribute:NSParagraphStyleAttributeName
                 value:paragraphStyleCandidate
                 range:NSMakeRange(0, line.length)];
    [text appendAttributedString:line];

    if (i == index) {
      CGFloat left = 0;
      CGFloat bottom = 0;
      
      height = text.size.width;
      if (height + _view.edgeInset.width * 2 > NSHeight(screenRect) / 3) {
        height = NSHeight(screenRect) / 3 - _view.edgeInset.width * 2;
      }
      
      NSSize lineSize = [line boundingRectWithSize:NSMakeSize(height, 0.0) options:NSStringDrawingUsesLineFragmentOrigin].size;
      NSSize textSize = [text boundingRectWithSize:NSMakeSize(height, 0.0) options:NSStringDrawingUsesLineFragmentOrigin].size;
      
      if (_horizontal) {
        NSRange candidateRange = NSMakeRange(candidateStartPos, text.length - candidateStartPos);
        NSAttributedString *candidateText = [text attributedSubstringFromRange:candidateRange];
        left = candidateText.size.width - line.size.width;
        height = line.size.height;
      } else if (_vertical) {
        height = lineSize.height;
        bottom = -textSize.height + _view.edgeInset.width * 2;
      } else {
        height = line.size.height;
        bottom = -text.size.height;
      }
      highlightedRect = NSMakeRect(left, bottom, line.size.width, height);
    }
  }

  if (!NSIsEmptyRect(highlightedRect)) {
    if (_horizontal) {
      if (preedit) {
        highlightedRect.size.height += _preeditParagraphStyle.paragraphSpacing;
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
      if (_vertical) {
        height = fullSize.width;
        if (height + _view.edgeInset.width * 2 > NSHeight(screenRect) / 3) {
          height = NSHeight(screenRect) / 3 - _view.edgeInset.width * 2;
        }
        fullSize = [text boundingRectWithSize:NSMakeSize(height, 0.0) options:NSStringDrawingUsesLineFragmentOrigin].size;
      }
      
      highlightedRect.origin.y += fullSize.height;
      if (index == 0) {
        if (preedit) {
          highlightedRect.size.height += MIN(_preeditParagraphStyle.paragraphSpacing,
                                             _paragraphStyle.paragraphSpacing);
        }
      } else {
        highlightedRect.size.height += _paragraphStyle.paragraphSpacing;
      }
      if (index < numCandidates - 1) {
        highlightedRect.origin.y -= _paragraphStyle.paragraphSpacing;
        highlightedRect.size.height += _paragraphStyle.paragraphSpacing;
        if (!_vertical && !_horizontal) {
          highlightedRect.origin.y -= _view.cornerRadius / 4;
          highlightedRect.size.height -= _view.cornerRadius / 4;
        }
      } else if (_vertical) {
        highlightedRect.origin.y -= _view.cornerRadius / 4;
        highlightedRect.size.height += _view.cornerRadius / 4;
      }
    }
  }
  if (!_vertical) {
    [text addAttribute:NSBaselineOffsetAttributeName value:@(_view.baseOffset) range:NSMakeRange(0, text.length)];
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

  [[foregroundColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]]
      getRed:&f.r
       green:&f.g
        blue:&f.b
       alpha:&f.a];
  //NSLog(@"fg: %f %f %f %f", f.r, f.g, f.b, f.a);

  [[backgroundColor colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]]
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
  _vertical = [config getBool:@"style/vertical"];
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
  CGFloat hilitedCornerRadius = [config getDouble:@"style/hilited_corner_radius"];
  CGFloat borderHeight = [config getDouble:@"style/border_height"];
  CGFloat borderWidth = [config getDouble:@"style/border_width"];
  CGFloat lineSpacing = [config getDouble:@"style/line_spacing"];
  CGFloat spacing = [config getDouble:@"style/spacing"];
  CGFloat baseOffset = [config getDouble:@"style/base_offset"];

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
      NSNumber *verticalOverridden =
          [config getOptionalBool:[prefix stringByAppendingString:@"/vertical"]];
      if (verticalOverridden) {
        _vertical = verticalOverridden.boolValue;
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
      NSNumber *hilitedCornerRadiusOverridden =
          [config getOptionalDouble:[prefix stringByAppendingString:@"/hilited_corner_radius"]];
      if (hilitedCornerRadiusOverridden) {
        hilitedCornerRadius = hilitedCornerRadiusOverridden.doubleValue;
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
      NSNumber *baseOffsetOverridden =
          [config getOptionalDouble:[prefix stringByAppendingString:@"/base_offset"]];
      if (baseOffsetOverridden) {
        baseOffset = baseOffsetOverridden.doubleValue;
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
  _view.hilitedCornerRadius = hilitedCornerRadius;
  _view.edgeInset = NSMakeSize(MAX(borderWidth, cornerRadius), MAX(borderHeight, cornerRadius));
  _view.baseOffset = baseOffset;
  _view.horizontal = _horizontal;

  _window.alphaValue = (alpha == 0) ? 1.0 : alpha;

  NSMutableParagraphStyle *paragraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  paragraphStyle.paragraphSpacing = lineSpacing / 2;
  paragraphStyle.paragraphSpacingBefore = lineSpacing / 2;
  _paragraphStyle = paragraphStyle;

  NSMutableParagraphStyle *preeditParagraphStyle =
      [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  preeditParagraphStyle.paragraphSpacing = spacing / 2;
  preeditParagraphStyle.paragraphSpacingBefore = spacing / 2;
  _preeditParagraphStyle = preeditParagraphStyle;
}

@end
