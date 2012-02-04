
#import "SquirrelApplicationDelegate.h"

@implementation SquirrelApplicationDelegate

//this method is added so that our controllers can access the shared NSMenu.
-(NSMenu*)menu
{
    return _menu;
}

//add an awakeFromNib item so that we can set the action method.  Note that 
//any menuItems without an action will be disabled when displayed in the Text 
//Input Menu.
-(void)awakeFromNib
{
}

-(void)dealloc 
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end  //SquirrelApplicationDelegate
