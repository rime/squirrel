#import "SquirrelApplicationDelegate.h"
#import "SquirrelPanel.h"
#import <Growl/Growl.h>
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

-(BOOL)enableNotifications
{
  return _enableNotifications;
}

-(NSDictionary*)appOptions
{
  return _appOptions;
}

-(IBAction)deploy:(id)sender
{
  NSLog(@"Start maintenace...");
  // restart
  RimeFinalize();
  [self startRimeWithFullCheck:YES];
  [self loadSquirrelConfig];
}

-(IBAction)syncUserDicts:(id)sender
{
  NSLog(@"Sync user dicts");
  RimeSyncUserDict();
}

-(IBAction)configure:(id)sender
{
  [[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Rime" stringByStandardizingPath]];
}

-(IBAction)openWiki:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/rimeime/w/list"]];
}

void show_message(const char* msg_text, const char* msg_id) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Squirrel", nil)
                              description:NSLocalizedString([NSString stringWithUTF8String:msg_text], nil)
                         notificationName:@"Squirrel"
                                 iconData:[NSData dataWithData:[[NSImage imageNamed:@"zhung"] TIFFRepresentation]]
                                 priority:0
                                 isSticky:NO
                             clickContext:nil
                               identifier:[NSString stringWithUTF8String:msg_id]];
  [pool release];
}

void notification_handler(void* context_object, RimeSessionId session_id,
                          const char* message_type, const char* message_value) {
  if (!strcmp(message_type, "deploy")) {
    if (!strcmp(message_value, "start")) {
      show_message("deploy_start", message_type);
    }
    else if (!strcmp(message_value, "success")) {
      show_message("deploy_success", message_type);
    }
    else if (!strcmp(message_value, "failure")) {
      show_message("deploy_failure", message_type);
    }
    return;
  }
  // off?
  id app_delegate = (id)context_object;
  if (app_delegate && ![app_delegate enableNotifications]) {
    return;
  }
  // schema change
  if (!strcmp(message_type, "schema")) {
    const char* schema_name = strchr(message_value, '/');
    if (schema_name)
      show_message(++schema_name, message_type);
    return;
  }
  // builtin notifications suck! avoid bubble flood
  if ([GrowlApplicationBridge isMistEnabled]) {
    static time_t previous_notify_time = 0;
    time_t now = time(NULL);
    bool is_cool = now - previous_notify_time > 5;
    if (!is_cool)
      return;  // too soon
    previous_notify_time = now;
  }
  // option change
  if (!strcmp(message_type, "option")) {
    if (!strcmp(message_value, "ascii_mode") || !strcmp(message_value, "!ascii_mode")) {
      static bool was_ascii_mode = false;
      bool is_ascii_mode = (message_value[0] != '!');
      if (is_ascii_mode != was_ascii_mode) {
        was_ascii_mode = is_ascii_mode;
        show_message(message_value, message_type);
      }
    }
    else if (!strcmp(message_value, "full_shape") || !strcmp(message_value, "!full_shape")) {
      show_message(message_value, message_type);
    }
    else if (!strcmp(message_value, "simplification") || !strcmp(message_value, "!simplification")) {
      show_message(message_value, message_type);
    }
  }
}

-(void)startRimeWithFullCheck:(BOOL)fullCheck
{
  NSString* userDataDir = [@"~/Library/Rime" stringByStandardizingPath];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:userDataDir]) {
    if (![fileManager createDirectoryAtPath:userDataDir withIntermediateDirectories:YES attributes:nil error:NULL]) {
      NSLog(@"Error creating user data directory: %@", userDataDir);
    }
  }
  RimeSetNotificationHandler(notification_handler, self);
  RimeTraits squirrel_traits;
  squirrel_traits.shared_data_dir = [[[NSBundle mainBundle] sharedSupportPath] UTF8String];
  squirrel_traits.user_data_dir = [userDataDir UTF8String];
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version = [[[[NSBundle mainBundle] infoDictionary] 
                                           objectForKey:@"CFBundleVersion"] UTF8String];
  NSLog(@"Initializing la rime...");
  RimeInitialize(&squirrel_traits);
  // check for configuration updates
  if (RimeStartMaintenance((Bool)fullCheck)) {
    // update squirrel config
    RimeDeployConfigFile("squirrel.yaml", "config_version");
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
  
  _enableNotifications = YES;
  _enableBuitinNotifcations = NO;
  char str[100] = {0};
  if (RimeConfigGetString(&config, "show_notifications_when", str, sizeof(str))) {
    if (!strcmp(str, "always")) {
      _enableNotifications = _enableBuitinNotifcations = YES;
    }
    else if (!strcmp(str, "never")) {
      _enableNotifications = _enableBuitinNotifcations = NO;
    }
  }
  [GrowlApplicationBridge setShouldUseBuiltInNotifications:_enableBuitinNotifcations];

  [self updateUIStyle:&config];
  [self loadAppOptionsFromConfig:&config];
  
  RimeConfigClose(&config);
}

-(void)updateUIStyle:(RimeConfig*)config
{
  SquirrelUIStyle style = { NO, nil, 0, 1.0, 0.0, 0.0, 0.0, nil, nil, nil, nil, nil, nil };
  
  Bool value = False;
  if (RimeConfigGetBool(config, "style/horizontal", &value)) {
    style.horizontal = (BOOL)value;
  }
  
  char font_face[100] = {0};
  if (RimeConfigGetString(config, "style/font_face", font_face, sizeof(font_face))) {
    style.fontName = [[NSString alloc] initWithUTF8String:font_face];
  }
  RimeConfigGetInt(config, "style/font_point", &style.fontSize);
  
  RimeConfigGetDouble(config, "style/alpha", &style.alpha);
  if (style.alpha > 1.0) {
    style.alpha = 1.0;
  } else if (style.alpha < 0.1) {
    style.alpha = 0.1;
  }
  
  RimeConfigGetDouble(config, "style/corner_radius", &style.cornerRadius);
  RimeConfigGetDouble(config, "style/border_height", &style.borderHeight);
  RimeConfigGetDouble(config, "style/border_width", &style.borderWidth);
  
  char color_scheme[100] = {0};
  if (RimeConfigGetString(config, "style/color_scheme", color_scheme, sizeof(color_scheme))) {
    NSMutableString* key = [[NSMutableString alloc] initWithString:@"preset_color_schemes/"];
    [key appendString:[NSString stringWithUTF8String:color_scheme]];
    NSUInteger prefix_length = [key length];
    // 0xaabbggrr or 0xbbggrr
    char color[20] = {0};
    [key appendString:@"/back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.backgroundColor = [[NSString alloc] initWithUTF8String:color];
    }
    NSString* fallback_text_color = nil;
    NSString* fallback_hilited_text_color = nil;
    NSString* fallback_hilited_back_color = nil;
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      fallback_text_color = [[NSString alloc] initWithUTF8String:color];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      fallback_hilited_text_color = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      fallback_hilited_text_color = [fallback_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      fallback_hilited_back_color = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      fallback_hilited_back_color = [style.backgroundColor retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/candidate_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.candidateTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      // weasel panel has an additional line at the top to show preedit text, that `text_color` is for.
      // if not otherwise specified, candidate text is rendered in this color.
      // in other words, `candidate_text_color` inherits this. 
      style.candidateTextColor = [fallback_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      style.highlightedCandidateTextColor = [fallback_hilited_text_color retain];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateBackColor = [[NSString alloc] initWithUTF8String:color];
    }
    else {
      style.highlightedCandidateBackColor = [fallback_hilited_back_color retain];
    }
    // new in squirrel
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/comment_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.commentTextColor = [[NSString alloc] initWithUTF8String:color];
    }
    
    [key release];
    [fallback_text_color release];
    [fallback_hilited_text_color release];
    [fallback_hilited_back_color release];
  }
  
  char format[100] = {0};
  if (RimeConfigGetString(config, "style/candidate_format", format, sizeof(format))) {
    style.candidateFormat = [[NSString alloc] initWithUTF8String:format];
  }
  
  [_panel updateUIStyle:&style];
  
  [style.fontName release];
  [style.backgroundColor release];
  [style.candidateTextColor release];
  [style.highlightedCandidateTextColor release];
  [style.highlightedCandidateBackColor release];
  [style.commentTextColor release];
  [style.candidateFormat release];
}

-(void)loadAppOptionsFromConfig:(RimeConfig*)config
{
  //NSLog(@"updateAppOptionsFromConfig:");
  NSMutableDictionary* appOptions = [[NSMutableDictionary alloc] init];
  [_appOptions release];
  _appOptions = appOptions;
  RimeConfigIterator app_iter;
  RimeConfigIterator option_iter;
  RimeConfigBeginMap(&app_iter, config, "app_options");
  while (RimeConfigNext(&app_iter)) {
    //NSLog(@"DEBUG app[%d]: %s (%s)", app_iter.index, app_iter.key, app_iter.path);
    NSMutableDictionary* options = [[NSMutableDictionary alloc] init];
    [appOptions setValue:options forKey:[NSString stringWithUTF8String:app_iter.key]];
    RimeConfigBeginMap(&option_iter, config, app_iter.path);
    while (RimeConfigNext(&option_iter)) {
      //NSLog(@"DEBUG option[%d]: %s (%s)", option_iter.index, option_iter.key, option_iter.path);
      Bool value = False;
      if (RimeConfigGetBool(config, option_iter.path, &value)) {
        [options setValue:[NSNumber numberWithBool:value] forKey:[NSString stringWithUTF8String:option_iter.key]];
      }
    }
    RimeConfigEnd(&option_iter);
  }
  RimeConfigEnd(&app_iter);
}

// prevent freezing the system when squirrel suffers crashes and thus is launched repeatedly by IMK.
-(BOOL)problematicLaunchDetected
{
  BOOL detected = NO;
  NSString* logfile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"squirrel_launch.dat"];
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

-(void)workspaceWillPowerOff:(NSNotification *)aNotification
{
  NSLog(@"Finalizing before logging out.");
  RimeFinalize();
}

//add an awakeFromNib item so that we can set the action method.  Note that 
//any menuItems without an action will be disabled when displayed in the Text 
//Input Menu.
-(void)awakeFromNib
{
  //NSLog(@"SquirrelApplicationDelegate awakeFromNib");
  
  NSNotificationCenter* center = [[NSWorkspace sharedWorkspace] notificationCenter];
  [center addObserver:self
             selector:@selector(workspaceWillPowerOff:)
                 name:@"NSWorkspaceWillPowerOffNotification"
               object:nil];
}

-(void)dealloc 
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_appOptions release];
  [super dealloc];
}

@end  //SquirrelApplicationDelegate
