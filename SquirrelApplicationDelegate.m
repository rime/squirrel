
#import "SquirrelApplicationDelegate.h"
#import "SquirrelPanel.h"
#import <rime_api.h>

@implementation SquirrelApplicationDelegate

-(NSMenu*)menu
{
  return _menu;
}

-(SquirrelPanel*)panel
{
  return _panel;
}

-(id)updater
{
  return _updater;
}

-(BOOL)useUSKeyboardLayout
{
  return _useUSKeyboardLayout;
}

-(IBAction)deploy:(id)sender
{
  NSLog(@"Start maintenace...");
  // restart
  RimeFinalize();
  [self startRimeWithFullCheck:YES];
  [self loadSquirrelConfig];
}

-(IBAction)configure:(id)sender
{
  [[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Rime" stringByStandardizingPath]];
}

-(IBAction)openWiki:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/rimeime/w/list"]];
}

-(void)startRimeWithFullCheck:(BOOL)fullCheck
{
  RimeTraits squirrel_traits;
  squirrel_traits.shared_data_dir = [[[NSBundle mainBundle] sharedSupportPath] UTF8String];
  squirrel_traits.user_data_dir = [[@"~/Library/Rime" stringByStandardizingPath] UTF8String];
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version = [[[[NSBundle mainBundle] infoDictionary] 
                                           objectForKey:@"CFBundleVersion"] UTF8String];
  NSLog(@"Initializing la rime...");
  RimeInitialize(&squirrel_traits);
  if (fullCheck) {
    // update squirrel config
    RimeDeployConfigFile("squirrel.yaml", "config_version");
  }
  // check for configuration updates
  if (RimeStartMaintenance((Bool)fullCheck)) {
    // TODO: notification
    NSArray* args = [NSArray arrayWithObjects:@"Preparing Rime for updates; patience.", nil];
    [NSTask launchedTaskWithLaunchPath:@"/usr/bin/say" arguments:args];
  }
}

-(void)loadSquirrelConfig
{
  RimeConfig config;
  if (!RimeConfigOpen("squirrel", &config)) {
    return;
  }
  NSLog(@"Loading squirrel specific config...");
  
  _useUSKeyboardLayout = NO;
  Bool value;
  if (RimeConfigGetBool(&config, "us_keyboard_layout", &value)) {
    _useUSKeyboardLayout = (BOOL)value;
  }
  
  SquirrelUIStyle style = { NO, nil, 0, 1.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil };
  if (RimeConfigGetBool(&config, "style/horizontal", &value)) {
    style.horizontal = (BOOL)value;
  }
  
  char font_face[100] = {0};
  if (RimeConfigGetString(&config, "style/font_face", font_face, sizeof(font_face))) {
    style.fontName = [[NSString alloc] initWithUTF8String:font_face];
  }
  RimeConfigGetInt(&config, "style/font_point", &style.fontSize);
  
  RimeConfigGetDouble(&config, "style/alpha", &style.alpha);
  if (style.alpha > 1.0) {
    style.alpha = 1.0;
  } else if (style.alpha < 0.1) {
    style.alpha = 0.1;
  }
  
  RimeConfigGetDouble(&config, "style/corner_radius", &style.cornerRadius);
  RimeConfigGetDouble(&config, "style/border_height", &style.borderHeight);
  RimeConfigGetDouble(&config, "style/border_width", &style.borderWidth);
  
  char color_scheme[100] = {0};
  if (RimeConfigGetString(&config, "style/color_scheme", color_scheme, sizeof(color_scheme))) {
    NSMutableString* key = [[NSMutableString alloc] initWithString:@"preset_color_schemes/"];
    [key appendString:[NSString stringWithUTF8String:color_scheme]];
    NSUInteger prefix_length = [key length];
    // 0xaabbggrr or 0xbbggrr
    char color[20] = {0};
    [key appendString:@"/back_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      style.backgroundColor = [[NSString alloc] initWithUTF8String:color];
    }
    NSString* fallback_text_color = nil;
    NSString* fallback_hilited_text_color = nil;
    NSString* fallback_hilited_back_color = nil;
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/text_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      fallback_text_color = [[NSString alloc] initWithUTF8String:color];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_text_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      fallback_hilited_text_color = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      fallback_hilited_text_color = [fallback_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_back_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      fallback_hilited_back_color = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      fallback_hilited_back_color = [style.backgroundColor retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/candidate_text_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      style.candidateTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      // weasel panel has an additional line at the top to show preedit text, that `text_color` is for.
      // if not otherwise specified, candidate text is rendered in this color.
      // in other words, `candidate_text_color` inherits this. 
      style.candidateTextColor = [fallback_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_text_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      style.highlightedCandidateTextColor = [fallback_hilited_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_back_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateBackColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      style.highlightedCandidateBackColor = [fallback_hilited_back_color retain];
    }
    // new in squirrel
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/comment_text_color"];
    if (RimeConfigGetString(&config, [key UTF8String], color, sizeof(color))) {
      style.commentTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    
    [key release];
    [fallback_text_color release];
    [fallback_hilited_text_color release];
    [fallback_hilited_back_color release];
  }
  
  RimeConfigClose(&config);
  
  [_panel updateUIStyle:&style];
  [style.fontName release];
  [style.backgroundColor release];
  [style.candidateTextColor release];
  [style.highlightedCandidateTextColor release];
  [style.highlightedCandidateBackColor release];
  [style.commentTextColor release];
}

// prevent freezing the system when squirrel suffers crashes and thus is launched repeatedly by IMK.
-(BOOL)problematicLaunchDetected
{
  BOOL detected = NO;
  NSString* logfile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"launch.dat"];
  //NSLog(@"[DEBUG] archive: %@", logfile);
  NSData* archive = [NSData dataWithContentsOfFile:logfile options:NSDataReadingUncached error:nil];
  if (archive) {
    NSDate* previousLaunch = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
    if (previousLaunch && [previousLaunch timeIntervalSinceNow] >= -2) {
      detected = YES;
    }
  }
  NSDate* now = [NSDate date];
  NSData* record = [NSKeyedArchiver archivedDataWithRootObject:now];
  [record writeToFile:logfile atomically:NO];
  return detected;
}

//add an awakeFromNib item so that we can set the action method.  Note that 
//any menuItems without an action will be disabled when displayed in the Text 
//Input Menu.
-(void)awakeFromNib
{
  //NSLog(@"SquirrelApplicationDelegate awakeFromNib");
}

-(void)dealloc 
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

@end  //SquirrelApplicationDelegate
