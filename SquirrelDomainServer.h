#import <Foundation/Foundation.h>
#import "SquirrelInputController.h"

#import <rime_api.h>

@interface SquirrelDomainServer : NSObject


+ (id)sharedInstance;

- (instancetype)init __attribute__((unavailable("Cannot use init for this class, use +(SquirrelDomainServer*)sharedInstance instead!")));
// NOTE: __attribute__ unavailable can NOT lead compile error of dynamic invocation @selector(performSelector:) of Class

// -(int)updateLastSession:(RimeSessionId)session app:(NSString*)currentApp;
-(void)updateLastSession:(SquirrelInputController*)inputController session:(RimeSessionId)session app:(NSString*)currentApp;
-(void)destroySession:(RimeSessionId)session;

@end

