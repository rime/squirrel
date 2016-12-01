
#import <Foundation/Foundation.h>
#import "SquirrelDomainServer.h"


#import <rime_api.h>
#import <sys/socket.h>
#import <sys/un.h>

#define QLEN 8
@implementation SquirrelDomainServer{

  RimeSessionId _session;
  NSString *_currentApp;
  SquirrelInputController* _lastInputController;


}


#pragma mark Singleton Methods

+ (id)sharedInstance {
    static SquirrelDomainServer *sharedMyInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyInstance = [[self alloc] init];
    });
    return sharedMyInstance;
}

- (id)init {
    if (self = [super init]) {
      NSThread *domainServerThread = [ [NSThread alloc] initWithTarget:self
                                                     selector:@selector( domainServer )
                                                       object:nil ];
      [domainServerThread start ];
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

-(int)updateLastSession:(SquirrelInputController*)inputController session:(RimeSessionId)session app:(NSString*)currentApp{
  _lastInputController=inputController;
  _session=session;
  _currentApp=currentApp;
  // NSLog(@"update app=%@\n",_currentApp);

}
-(void)destroySession:(RimeSessionId)session{
  if (session==_session) {
    _session=0;
  }
}
// start an unix domain socket to talk with command line tool
// you can control squirrel by command line
-(int)domainServer{
  int fd, clifd, n;
  struct sockaddr_un un;
  char buf[512];
  char *ptr;
  char *token;
  char *domainSocketPath="/tmp/squirrel.sock";


  if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
    NSLog(@"domainServer().socket() error");
    return 1;
  }

  memset(&un, 0, sizeof(un));
  un.sun_family = AF_UNIX;
  strncpy(un.sun_path, domainSocketPath, sizeof(un.sun_path) - 1);
  unlink(domainSocketPath);

  if (bind(fd, (struct sockaddr *) &un, sizeof(un)) < 0) {
    NSLog(@"domainServer().bind() error");
    return 2;
  }

  NSLog(@"UNIX Domain Socket bound at:%s\n",domainSocketPath);

  memset(&buf, 0, sizeof(buf));

  if (listen(fd, QLEN) < 0) {
    NSLog(@"UNIX Domain Socket listen error\n");
    return 3;
  }

  while (1) {
    if ((clifd = accept(fd, NULL, NULL)) == -1) {
      NSLog(@"UNIX Domain Socket accept error\n");
      continue;
    }
    token=NULL;
    ptr=NULL;


    // while ((n = read(clifd, buf, sizeof(buf))) > 0) {
    n = read(clifd, buf, sizeof(buf)) ;
    if (n == -1) {
      continue;
    }else if (n>=sizeof(buf)){ // buf is full (it should not)
      close(clifd);
      continue;
    }else{
      buf[n]='\0';
    }
    // NSLog(@"%s %ld %d %d\n",buf,sizeof(buf),strlen(buf),n);
    if (strlen(buf)<1) {
      close(clifd);
      continue;
    }

    if (_session) {
      ptr=buf;
      token=strsep( &ptr,",");
      while(token!=NULL){
        if (strcmp("--set" ,token)==0) { // set option
          token=strsep( &ptr,",");
          if (token!=NULL) {
            rime_get_api()->set_option(_session, token, True);
          }

          token=strsep( &ptr,",");
        }else if (strcmp("--unset" ,token)==0) { // unset option
          token=strsep( &ptr,",");
          if (token!=NULL) {
            rime_get_api()->set_option(_session, token, False);
          }
          token=strsep( &ptr,",");
        }else if (strcmp("--toggle" ,token)==0) { // toggle option
          token=strsep( &ptr,",");
          if (token!=NULL) {
            rime_get_api()->set_option(_session, token, !(rime_get_api()->get_option(_session,token)));
          }
          token=strsep( &ptr,",");
        }else if (strcmp("--clear" ,token)==0) { // clear
          [_lastInputController clearComposition];
          token=strsep( &ptr,",");
        // if (strcmp("--commit_code" ,token)==0) { // commit_code
        //   RIME_STRUCT(RimeContext, ctx);
        //   if (rime_get_api()->get_context(_session, &ctx)) {
        //     ctx->ClearNonConfirmedComposition();
        //     ctx->Commit();
        //     rime_get_api()->free_context(&ctx);
        //   }
        // token=strsep( &ptr,",");

        //   continue;
        // }
        // if (strcmp("--commit_text" ,token)==0) { // commit_text
        //   RIME_STRUCT(RimeContext, ctx);
        //   if (rime_get_api()->get_context(_session, &ctx)) {
        //     ctx->ConfirmCurrentSelection();
        //     rime_get_api()->free_context(&ctx);
        //   }
        // token=strsep( &ptr,",");
        //   continue;
        // }

        }else{
          token=strsep( &ptr,",");
        }

      }
      [_lastInputController rimeUpdate];
    }
    close(clifd);
  }
  NSLog(@"thread shutdown\n");


  return 0;

}



@end
