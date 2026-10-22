#import <Cocoa/Cocoa.h>
#import <InstallerPlugins/InstallerPlugins.h>

// Installer-only choice page. First installations skip the section; updates
// publish the selected method for the preinstall helper running as the same user.

static BOOL HasInstalledSquirrel(void) {
    // Keep this consistent with the helper's snapshot() check for partial installations.
    NSBundle *bundle = [NSBundle bundleWithPath:@"/Library/Input Methods/Squirrel.app"];
    return [bundle.bundleIdentifier isEqualToString:@"im.rime.inputmethod.Squirrel"] &&
        bundle.executablePath &&
        [[NSFileManager defaultManager] isExecutableFileAtPath:bundle.executablePath];
}

@interface SquirrelInstallPane : InstallerPane
@end

@implementation SquirrelInstallPane {
    NSButton *_hot;
    NSButton *_login;
    NSTextField *_description;
}

- (NSString *)text:(NSString *)key {
    return [[NSBundle bundleForClass:self.class] localizedStringForKey:key
                                                               value:nil
                                                               table:nil];
}

- (NSString *)title {
    return [self text:@"METHOD_TITLE"];
}

- (instancetype)initWithSection:(id)section {
    self = [super initWithSection:section];
    if (!self) {
        return nil;
    }

    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 300)];
    NSArray *keys = @[@"HOT_UPDATE_TITLE", @"LOGIN_TITLE"];
    for (NSUInteger i = 0; i < 2; i++) {
        NSButton *button = [NSButton radioButtonWithTitle:[self text:keys[i]]
                                                  target:self
                                                  action:@selector(selectMethod:)];
        button.frame = NSMakeRect(20, 230 - i * 70, 480, 24);
        [view addSubview:button];

        if (i == 0) {
            _hot = button;
        } else {
            _login = button;
        }
    }

    _description = [NSTextField wrappingLabelWithString:@""];
    _description.frame = NSMakeRect(40, 70, 460, 70);
    _description.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [view addSubview:_description];

    _hot.enabled = HasInstalledSquirrel();
    [self selectMethod:_hot.enabled ? _hot : _login];
    self.contentView = view;
    return self;
}

- (void)selectMethod:(NSButton *)sender {
    BOOL hotUpdate = sender == _hot && _hot.enabled;
    _hot.state = hotUpdate ? NSControlStateValueOn : NSControlStateValueOff;
    _login.state = hotUpdate ? NSControlStateValueOff : NSControlStateValueOn;
    _description.stringValue = [self text:hotUpdate
        ? @"HOT_UPDATE_DESCRIPTION"
        : @"LOGIN_DESCRIPTION"];

    // Publish the choice before the separate preinstall process reads this user's defaults.
    NSUserDefaults *defaults = [[NSUserDefaults alloc]
        initWithSuiteName:@"im.rime.inputmethod.Squirrel.Installer"];
    [defaults setBool:hotUpdate forKey:@"HotUpdate"];
    [defaults synchronize];
}

@end

@interface SquirrelInstallSection : InstallerSection
@end

@implementation SquirrelInstallSection {
    InstallerPane *_pane;
}

- (BOOL)shouldLoad {
    return HasInstalledSquirrel();
}

- (InstallerPane *)firstPane {
    if (!_pane) {
        _pane = [[SquirrelInstallPane alloc] initWithSection:self];
    }
    return _pane;
}

- (NSString *)title {
    return [[NSBundle bundleForClass:self.class] localizedStringForKey:@"METHOD_TITLE"
                                                               value:nil
                                                               table:nil];
}

@end
