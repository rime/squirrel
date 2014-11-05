#import "SquirrelApplicationDelegate.h"
#import "SquirrelPanel.h"
#import <Growl/Growl.h>

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

-(BOOL)preferNotificationCenter
{
  return _preferNotificationCenter;
}

-(NSDictionary*)appOptions
{
  return _appOptions;
}

-(NSTimeInterval)chordDuration
{
  return _chordDuration;
}

-(IBAction)deploy:(id)sender
{
  NSLog(@"Start maintenace...");
  // restart
  RimeFinalize();
  [self startRimeWithFullCheck:YES];
  [self loadSquirrelConfig];
}

-(IBAction)syncUserData:(id)sender
{
  NSLog(@"Sync user data");
  RimeSyncUserData();
}

-(IBAction)configure:(id)sender
{
  [[NSWorkspace sharedWorkspace] openFile:[@"~/Library/Rime" stringByStandardizingPath]];
}

-(IBAction)openWiki:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/rimeime/w/list"]];
}

static void show_message_growl(const char* msg_text, const char* msg_id) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Squirrel", nil)
                              description:NSLocalizedString([NSString stringWithUTF8String:msg_text], nil)
                         notificationName:@"Squirrel"
                                 iconData:[NSData dataWithData:[[NSImage imageNamed:@"squirrel-app"] TIFFRepresentation]]
                                 priority:0
                                 isSticky:NO
                             clickContext:nil
                               identifier:[NSString stringWithUTF8String:msg_id]];
  [pool release];
}

static void show_message_notification_center(const char* msg_text, const char* msg_id) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id notification = [[NSClassFromString(@"NSUserNotification") alloc] init];
  [notification performSelector:@selector(setTitle:) withObject:NSLocalizedString(@"Squirrel", nil)];
  [notification performSelector:@selector(setSubtitle:) withObject:NSLocalizedString([NSString stringWithUTF8String:msg_text], nil)];
  id notificationCenter = [(id)NSClassFromString(@"NSUserNotificationCenter") performSelector:@selector(defaultUserNotificationCenter)];
  [notificationCenter performSelector:@selector(removeAllDeliveredNotifications)];
  [notificationCenter performSelector:@selector(deliverNotification:) withObject:notification];
  [notification release];
  [pool release];
}

static void show_status_message(const char* msg_text, const char* msg_id) {
  SquirrelPanel* panel = [(SquirrelApplicationDelegate *)[NSApp delegate] panel];
  if (panel) {
    [panel updateMessage:NSLocalizedString([NSString stringWithUTF8String:msg_text], nil)];
  }
}

void (*show_message)(const char* msg_text, const char* msg_id) = show_message_growl;
static void select_show_message(BOOL preferNotificationCenter) {
  if (preferNotificationCenter) {
      show_message = show_message_notification_center;
  }
  else {
      show_message = show_message_growl;
  }
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
    if (schema_name) {
      ++schema_name;
//      show_message(schema_name, message_type);
      show_status_message(schema_name, message_type);
    }
    return;
  }
//  // builtin notifications suck! avoid bubble flood
//  if ([GrowlApplicationBridge isMistEnabled]) {
//    static time_t previous_notify_time = 0;
//    time_t now = time(NULL);
//    bool is_cool = now - previous_notify_time > 5;
//    if (!is_cool)
//      return;  // too soon
//    previous_notify_time = now;
//  }
  // option change
  if (!strcmp(message_type, "option")) {
    if (!strcmp(message_value, "ascii_mode") || !strcmp(message_value, "!ascii_mode")) {
      static bool was_ascii_mode = false;
      bool is_ascii_mode = (message_value[0] != '!');
      if (is_ascii_mode != was_ascii_mode) {
        was_ascii_mode = is_ascii_mode;
//        show_message(message_value, message_type);
        show_status_message(message_value, message_type);
      }
    }
    else if (!strcmp(message_value, "full_shape") || !strcmp(message_value, "!full_shape")) {
      //      show_message(message_value, message_type);
      show_status_message(message_value, message_type);
    }
    else if (!strcmp(message_value, "ascii_punct") || !strcmp(message_value, "!ascii_punct")) {
      //      show_message(message_value, message_type);
      show_status_message(message_value, message_type);
    }
    else if (!strcmp(message_value, "simplification") || !strcmp(message_value, "!simplification")) {
//      show_message(message_value, message_type);
      show_status_message(message_value, message_type);
    }
    else if (!strcmp(message_value, "extended_charset") || !strcmp(message_value, "!extended_charset")) {
//      show_message(message_value, message_type);
      show_status_message(message_value, message_type);
    }
  }
}

-(void)setupRime
{
  NSString* userDataDir = [@"~/Library/Rime" stringByStandardizingPath];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:userDataDir]) {
    if (![fileManager createDirectoryAtPath:userDataDir withIntermediateDirectories:YES attributes:nil error:NULL]) {
      NSLog(@"Error creating user data directory: %@", userDataDir);
    }
  }
  RimeSetNotificationHandler(notification_handler, self);
  RIME_STRUCT(RimeTraits, squirrel_traits);
  squirrel_traits.shared_data_dir = [[[NSBundle mainBundle] sharedSupportPath] UTF8String];
  squirrel_traits.user_data_dir = [userDataDir UTF8String];
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version = [[[[NSBundle mainBundle] infoDictionary]
                                           objectForKey:@"CFBundleVersion"] UTF8String];
  squirrel_traits.app_name = "rime.squirrel";
  RimeSetup(&squirrel_traits);
}

-(void)startRimeWithFullCheck:(BOOL)fullCheck
{
  NSLog(@"Initializing la rime...");
  RimeInitialize(NULL);
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

  _chordDuration = 0.1;
  double duration;
  if (RimeConfigGetDouble(&config, "chord_duration", &duration)) {
    if (duration > 0)
      _chordDuration = duration;
  }

  _enableNotifications = YES;
  _enableBuitinNotifcations = YES;
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

  _preferNotificationCenter = NO;
  if (RimeConfigGetBool(&config, "show_notifications_via_notification_center", &value)) {
    BOOL isAtLeastMountainLion = NO;
    {
      SInt32 versionMajor, versionMinor;
      if (Gestalt(gestaltSystemVersionMajor, &versionMajor) == noErr &&
          Gestalt(gestaltSystemVersionMinor, &versionMinor) == noErr) {
        isAtLeastMountainLion = (versionMajor >= 10) && (versionMinor >= 8);
      }
    }

    _preferNotificationCenter = (BOOL)value && isAtLeastMountainLion;
  }

  select_show_message(_preferNotificationCenter);

  [self updateUIStyle:&config initialize:YES];
  [self loadAppOptionsFromConfig:&config];

  RimeConfigClose(&config);
}

#define FONT_FACE_BUFSIZE (200)
#define COLOR_BUFSIZE (20)
#define COLOR_SCHEME_BUFSIZE (100)
#define FORMAT_BUFSIZE (100)

-(void)updateUIStyle:(RimeConfig*)config initialize:(BOOL)initializing
{
  SquirrelUIStyle *style;
  if (initializing) {
    style = [[SquirrelUIStyle alloc] init];
  }
  else {
    style = [_baseStyle copy];
  }

  Bool bool_value;
  if (RimeConfigGetBool(config, "style/horizontal", &bool_value)) {
    style.horizontal = (BOOL)bool_value;
  }
  
  if (RimeConfigGetBool(config, "style/inline_preedit", &bool_value)) {
    style.inlinePreedit = (BOOL)bool_value;
  }
  
  char label_font_face[FONT_FACE_BUFSIZE] = {0};
  if (RimeConfigGetString(config, "style/label_font_face", label_font_face, sizeof(label_font_face))) {
    style.labelFontName = [NSString stringWithUTF8String:label_font_face];
  }
  
  int int_value;
  if (RimeConfigGetInt(config, "style/label_font_point", &int_value)) {
    style.labelFontSize = int_value;
  }

  char label_color[COLOR_BUFSIZE] = {0};
  if (RimeConfigGetString(config, "style/label_color", label_color, sizeof(label_color))) {
    style.candidateLabelColor = [NSString stringWithUTF8String:label_color];
  }
  if (RimeConfigGetString(config, "style/label_hilited_color", label_color, sizeof(label_color))) {
    style.highlightedCandidateLabelColor = [NSString stringWithUTF8String:label_color];
  }

  char font_face[FONT_FACE_BUFSIZE] = {0};
  if (RimeConfigGetString(config, "style/font_face", font_face, sizeof(font_face))) {
    style.fontName = [NSString stringWithUTF8String:font_face];
  }
  
  if (RimeConfigGetInt(config, "style/font_point", &int_value)) {
    style.fontSize = int_value;
  }

  double double_value;
  if (RimeConfigGetDouble(config, "style/alpha", &double_value)) {
    style.alpha = fmax(fmin(double_value, 1.0), 0.0);
  }

  if (RimeConfigGetDouble(config, "style/corner_radius", &double_value)) {
    style.cornerRadius = double_value;
  }
  if (RimeConfigGetDouble(config, "style/border_height", &double_value)) {
    style.borderHeight = double_value;
  }
  if (RimeConfigGetDouble(config, "style/border_width", &double_value)) {
    style.borderWidth = double_value;
  }
  if (RimeConfigGetDouble(config, "style/line_spacing", &double_value)) {
    style.lineSpacing = double_value;
  }
  if (RimeConfigGetDouble(config, "style/spacing", &double_value)) {
    style.spacing = double_value;
  }

  char format[FORMAT_BUFSIZE] = {0};
  if (RimeConfigGetString(config, "style/candidate_format", format, sizeof(format))) {
      style.candidateFormat = [NSString stringWithUTF8String:format];
  }

  char color_scheme[COLOR_SCHEME_BUFSIZE] = {0};
  if (initializing &&  // not applicable to per schema configuration
      RimeConfigGetString(config, "style/color_scheme", color_scheme, sizeof(color_scheme))) {
    NSMutableString* key = [NSMutableString stringWithString:@"preset_color_schemes/"];
    [key appendString:[NSString stringWithUTF8String:color_scheme]];
    NSUInteger prefix_length = [key length];
    // 0xaabbggrr or 0xbbggrr
    char color[COLOR_BUFSIZE] = {0};
    [key appendString:@"/back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.backgroundColor = [NSString stringWithUTF8String:color];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.textColor = [NSString stringWithUTF8String:color];
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedTextColor = [NSString stringWithUTF8String:color];
    }
    else {
      style.highlightedTextColor = style.textColor;
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedBackColor = [NSString stringWithUTF8String:color];
    }
    else {
      style.highlightedBackColor = nil;
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/candidate_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.candidateTextColor = [NSString stringWithUTF8String:color];
    }
    else {
      // in non-inline mode, 'text_color' is for rendering preedit text.
      // if not otherwise specified, candidate text is also rendered in this color.
      style.candidateTextColor = style.textColor;
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateTextColor = [NSString stringWithUTF8String:color];
    }
    else {
      style.highlightedCandidateTextColor = style.highlightedTextColor;
    }
    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_back_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCandidateBackColor = [NSString stringWithUTF8String:color];
    }
    else {
      style.highlightedCandidateBackColor = style.highlightedBackColor;
    }

    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/comment_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.commentTextColor = [NSString stringWithUTF8String:color];
    }

    [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_comment_text_color"];
    if (RimeConfigGetString(config, [key UTF8String], color, sizeof(color))) {
      style.highlightedCommentTextColor = [NSString stringWithUTF8String:color];
    }

    // the following per-color-scheme configurations, if exist, will
    // override configurations with the same name under the global 'style' section
    {
      Bool overridden_value;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/horizontal"];
      if (RimeConfigGetBool(config, [key UTF8String], &overridden_value)) {
        style.horizontal = (BOOL)overridden_value;
      }
      
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/inline_preedit"];
      if (RimeConfigGetBool(config, [key UTF8String], &overridden_value)) {
        style.inlinePreedit = (BOOL)overridden_value;
      }

      char overridden_label_font_face[FONT_FACE_BUFSIZE] = {0};
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/label_font_face"];
      if (RimeConfigGetString(config, [key UTF8String], overridden_label_font_face, sizeof(overridden_label_font_face))) {
        style.labelFontName = [NSString stringWithUTF8String:overridden_label_font_face];
      }

      int overridden_label_font_size;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/label_font_point"];
      if (RimeConfigGetInt(config, [key UTF8String], &overridden_label_font_size)) {
        style.labelFontSize = overridden_label_font_size;
      }

      char overridden_label_color[COLOR_BUFSIZE] = {0};
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/label_color"];
      if (RimeConfigGetString(config, [key UTF8String], overridden_label_color, sizeof(overridden_label_color))) {
        style.candidateLabelColor = [NSString stringWithUTF8String:overridden_label_color];
      }
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/label_hilited_color"];
      if (RimeConfigGetString(config, [key UTF8String], overridden_label_color, sizeof(overridden_label_color))) {
        style.highlightedCandidateLabelColor = [NSString stringWithUTF8String:overridden_label_color];
      }
      else {
        // 'label_hilited_color' does not quite fit the styles under each color scheme,
        // but for backward compatibility, 'label_hilited_color' and 'hilited_candidate_label_color' are both
        // valid
        [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/hilited_candidate_label_color"];
        if (RimeConfigGetString(config, [key UTF8String], overridden_label_color, sizeof(overridden_label_color))) {
          style.highlightedCandidateLabelColor = [NSString stringWithUTF8String:overridden_label_color];
        }
      }

      char overridden_font_face[FONT_FACE_BUFSIZE] = {0};
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/font_face"];
      if (RimeConfigGetString(config, [key UTF8String], overridden_font_face, sizeof(overridden_font_face))) {
        style.fontName = [NSString stringWithUTF8String:overridden_font_face];
      }
      int overridden_font_size;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/font_point"];
      if (RimeConfigGetInt(config, [key UTF8String], &overridden_font_size)) {
        style.fontSize = overridden_font_size;
      }

      double overridden_alpha;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/alpha"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_alpha)) {
        style.alpha = fmax(fmin(overridden_alpha, 1.0), 0.1);
      }

      double overridden_corner_radius;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/corner_radius"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_corner_radius)) {
        style.cornerRadius = overridden_corner_radius;
      }

      double overridden_border_height;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/border_height"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_border_height)) {
        style.borderHeight = overridden_border_height;
      }

      double overridden_border_width;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/border_width"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_border_width)) {
        style.borderWidth = overridden_border_width;
      }

      double overridden_line_spacing;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"line_spacing"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_line_spacing)) {
        style.lineSpacing = overridden_line_spacing;
      }

      double overridden_spacing;
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"spacing"];
      if (RimeConfigGetDouble(config, [key UTF8String], &overridden_spacing)) {
        style.spacing = overridden_spacing;
      }

      char overridden_format[FORMAT_BUFSIZE] = {0};
      [key replaceCharactersInRange:NSMakeRange(prefix_length, [key length] - prefix_length) withString:@"/candidate_format"];
      if (RimeConfigGetString(config, [key UTF8String], overridden_format, sizeof(overridden_format))) {
        style.candidateFormat = [NSString stringWithUTF8String:overridden_format];
      }
    }
  }

  [_panel updateUIStyle:style];
  
  if (initializing) {
    _baseStyle = [style retain];
  }
  [style release];
}

-(void)loadAppOptionsFromConfig:(RimeConfig*)config
{
  //NSLog(@"updateAppOptionsFromConfig:");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSMutableDictionary* appOptions = [[NSMutableDictionary alloc] init];
  [_appOptions release];
  _appOptions = appOptions;
  RimeConfigIterator app_iter;
  RimeConfigIterator option_iter;
  RimeConfigBeginMap(&app_iter, config, "app_options");
  while (RimeConfigNext(&app_iter)) {
    //NSLog(@"DEBUG app[%d]: %s (%s)", app_iter.index, app_iter.key, app_iter.path);
    NSMutableDictionary* options = [[[NSMutableDictionary alloc] init] autorelease];
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
  [pool release];
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

-(void)rimeNeedsReload:(NSNotification *)aNotification
{
  NSLog(@"Reloading rime on demand.");
  [self deploy:nil];
}

-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  NSLog(@"Squirrel is quitting.");
  RimeCleanupAllSessions();
  return NSTerminateNow;
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
                 name:NSWorkspaceWillPowerOffNotification
               object:nil];

  NSDistributedNotificationCenter* notifCenter = [NSDistributedNotificationCenter defaultCenter];
  [notifCenter addObserver:self
                  selector:@selector(rimeNeedsReload:)
                      name:@"SquirrelReloadNotification"
                    object:nil];

}

-(void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
  if (_panel) {
    [_panel hideStatus:nil];
  }
  [_appOptions release];
  [_baseStyle release];
  [super dealloc];
}

@end  //SquirrelApplicationDelegate
