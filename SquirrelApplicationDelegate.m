
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
  RimeConfig config;
  RimeConfigOpen("default.custom", &config);
  // schedule a workspace update
  RimeConfigUpdateSignature(&config, "Squirrel");
  RimeConfigClose(&config);
  // restart
  RimeFinalize();
  [self startRimeWithFullCheck:TRUE];
  [self loadSquirrelConfig];
}

-(void)startRimeWithFullCheck:(BOOL)fullCheck
{
  RimeTraits squirrel_traits;
  squirrel_traits.shared_data_dir = [[[NSBundle mainBundle] sharedSupportPath] UTF8String];
  squirrel_traits.user_data_dir = [[@"~/Library/Rime" stringByStandardizingPath] UTF8String];
  squirrel_traits.distribution_code_name = "Squirrel";
  squirrel_traits.distribution_name = "鼠鬚管";
  squirrel_traits.distribution_version = "0.9.3";
  NSLog(@"Initializing la rime...");
  RimeInitialize(&squirrel_traits);
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
  _useUSKeyboardLayout = FALSE;
  Bool value;
  if (RimeConfigGetBool(&config, "us_keyboard_layout", &value)) {
    _useUSKeyboardLayout = (BOOL)value;
  }
  
  SquirrelUIStyle style = { FALSE, nil, 0, 1.0 };
  if (RimeConfigGetBool(&config, "style/horizontal", &value)) {
    style.horizontal = (BOOL)value;
  }
  char font_face[100] = {0};
  if (RimeConfigGetString(&config, "style/font_face", font_face, sizeof(font_face))) {
    style.fontName = [[NSString alloc] initWithUTF8String:font_face];
  }
  RimeConfigGetInt(&config, "style/font_point", &style.fontSize);
  RimeConfigGetDouble(&config, "style/alpha", &style.alpha);
  if (style.alpha > 1.0)
    style.alpha = 1.0;
  else if (style.alpha < 0.1)
    style.alpha = 0.1;
  RimeConfigClose(&config);
  
  [_panel updateUIStyle:&style];
  [style.fontName release];
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
