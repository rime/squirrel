
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
                                                            selector:@selector(unixDomainServer)
                                                              object:nil ];
    [domainServerThread start ];
  }
  return self;
}

- (void)dealloc {
  // Should never be called, but just here for clarity really.
}

-(void)updateLastSession:(SquirrelInputController*)inputController session:(RimeSessionId)session app:(NSString*)currentApp{
  _lastInputController=inputController;
  _session=session;
  _currentApp=currentApp;
  // NSLog(@"update app=%@\n",_currentApp);

}
-(void)destroySession:(RimeSessionId)session{
  if (session==_session) {
    _session=0;
    _lastInputController=NULL;
  }
}
// start an unix domain socket to talk with command line tool
// you can control squirrel by command line
-(int)unixDomainServer{
  int fd, clifd;
  struct sockaddr_un un;
  char *domainSocketPath="/tmp/squirrel.sock";


  if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
    printf("unixDomainServer().socket() error");
    return 1;
  }

  memset(&un, 0, sizeof(un));
  un.sun_family = AF_UNIX;
  strncpy(un.sun_path, domainSocketPath, sizeof(un.sun_path) - 1);
  unlink(domainSocketPath);

  if (bind(fd, (struct sockaddr *) &un, sizeof(un)) < 0) {
    printf("unixDomainServer().bind() error");
    return 2;
  }

  printf("UNIX Domain Socket bound at:%s\n",domainSocketPath);


  if (listen(fd, QLEN) < 0) {
    printf("UNIX Domain Socket listen error\n");
    return 3;
  }

  while (1) {
    if ((clifd = accept(fd, NULL, NULL)) == -1) {
      printf("UNIX Domain Socket accept error\n");
      continue;
    }
    [self handleClient:clifd];
    close(clifd);
  }
  printf("thread shutdown\n");
  return 0;
}

-(void)handleClient:(int)clifd{
  int n;
  char buf[512];
  char *ptr=NULL;
  char *token=NULL;

  memset(&buf, 0, sizeof(buf));

  // while ((n = read(clifd, buf, sizeof(buf))) > 0) {
  n = read(clifd, buf, sizeof(buf)) ;
  if (n == -1||n>=sizeof(buf)) {
    return;
  }
  if (strlen(buf)<1) {
    return;
  }
  // printf("%s %ld %d %d\n",buf,sizeof(buf),strlen(buf),n);

  if (_session) {
    ptr=buf;
    token=strsep( &ptr,",");    // buf=a,b,c,d
    while(token!=NULL){
      if (strcmp("--set" ,token)==0) { // set option
        token=strsep( &ptr,",");       // get next token
        if (token!=NULL) {
          rime_get_api()->set_option(_session, token, True);
        }
      }else if (strcmp("--unset" ,token)==0) { // unset option
        token=strsep( &ptr,",");
        if (token!=NULL) {
          rime_get_api()->set_option(_session, token, False);
        }
      }else if (strcmp("--toggle" ,token)==0) { // toggle option
        token=strsep( &ptr,",");
        if (token!=NULL) {
          rime_get_api()->set_option(_session, token, !(rime_get_api()->get_option(_session,token)));
        }
      }else if (strcmp("--clear" ,token)==0) { // clear
        [_lastInputController clearComposition];
        // if (strcmp("--commit_code" ,token)==0) { // commit_code
        // token=strsep( &ptr,",");
        //   return;
        // }
        // if (strcmp("--commit_text" ,token)==0) { // commit_text
        // token=strsep( &ptr,",");
        //   return;
        // }

        // }else{
        //   token=strsep( &ptr,",");
      }

      token=strsep( &ptr,",");
    }
    [_lastInputController rimeUpdate];
  }
}


@end
