
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

-(bool)useUSKeyboardLayout
{
  return _useUSKeyboardLayout;
}

-(void)loadConfig
{
  RimeConfig config;
  if (!RimeConfigOpen("squirrel", &config)) {
    NSLog(@"Error opening squirrel config.");
    return;
  }
  _useUSKeyboardLayout = FALSE;
  Bool value;
  if (RimeConfigGetBool(&config, "us_keyboard_layout", &value)) {
    _useUSKeyboardLayout = (BOOL)value;
  }
  
  SquirrelUIStyle style = { FALSE, nil, 0 };
  if (RimeConfigGetBool(&config, "style/horizontal", &value)) {
    style.horizontal = (BOOL)value;
  }
  char font_face[100] = {0};
  if (RimeConfigGetString(&config, "style/font_face", font_face, sizeof(font_face))) {
    style.fontName = [[NSString alloc] initWithUTF8String:font_face];
  }
  RimeConfigGetInt(&config, "style/font_point", &style.fontSize);
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
