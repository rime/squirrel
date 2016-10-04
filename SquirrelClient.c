/* -*- coding:utf-8-unix -*- */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <getopt.h>

char *socket_path="/tmp/squirrel.sock";

void usage(char **argv){
  printf ("%s\n",argv[0]);

  printf ("set option:\n");
  printf ("    -s option_name \n\n");

  printf ("unset option:\n");
  printf ("    -u option_name\n\n");

  printf ("toggle option:\n");
  printf ("    -t option_name\n\n");

  printf ("clear composition:\n");
  printf ("    -c or --clear\n\n");

  printf("options: ascii_mode,full_shape,ascii_punct,simplification,extended_charset\n");
  printf ("demo: -s ascii_mode\n");
  printf ("      -u ascii_mode\n");
  printf ("      -t ascii_mode\n");
  printf ("      -t ascii_mode --clear\n");



}

/* send cmd by unix domain socket to squirrel */
int sendCmd(char *buf){
  int fd;
  int n;
  struct sockaddr_un un;

  if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
    perror("socket error");
    return 1;
  }

  memset(&un, 0, sizeof(un));
  un.sun_family = AF_UNIX;
  strncpy(un.sun_path, socket_path, sizeof(un.sun_path) - 1);

  if (connect(fd, (struct sockaddr *) &un, sizeof(un)) < 0) {
    perror("connect error");
    close(fd);
    return 2;
  }

  n=write(fd, buf, strlen(buf)) ;
  if  (n<0){
    perror("write error");
    close(fd);
    return 3;
  }
  /* printf ("write%d\n",n); */
  close(fd);

  return 0;
}

#define BUF_LEN 512

char* const short_options = "s:t:u:c";
struct option long_options[] = {
  { "set",         required_argument,   NULL,    's'     },
  { "toggle",      required_argument,   NULL,    't'     },
  { "unset",       required_argument,   NULL,    'u'     },
  /* { "commit_code", no_argument,         NULL,    'D'     }, */
  /* { "commit_text", no_argument,         NULL,    'T'     }, */
  { "clear",       no_argument,         NULL,    'c'     },
  { NULL,          0,                   NULL,     0      }
};

int main(int argc, char **argv) {
  char buf[BUF_LEN];
  int ch;
  int handled=0;

  opterr = 0;
  if (argc == 1){
    usage(argv);
    exit(0);
  }
  buf[0]='\0';
  while((ch = getopt_long (argc, argv, short_options, long_options, NULL)) != -1){
    handled=0;
    switch(ch) {
    case 's':
      strcpy(buf+strlen(buf), "--set,");
      strncpy(buf+strlen(buf), optarg, sizeof(buf)-strlen(buf) - 1);
      /* printf ("--set: %s\n",buf); */
      handled=1;
      break;
    case 'u':
      strcpy(buf+strlen(buf), "--unset,");
      strncpy(buf+strlen(buf), optarg, sizeof(buf)-strlen(buf) - 1);
      /* printf ("--unset: %s\n",buf); */
      handled=1;
      break;
    case 't':
      strcpy(buf+strlen(buf), "--toggle,");
      strncpy(buf+strlen(buf), optarg, sizeof(buf)-strlen(buf) - 1);
      /* printf ("--toggle: %s\n",buf); */
      handled=1;
      break;
    /* case 'D': */
    /*   strncpy(buf+strlen(buf), "--commit_code", sizeof(buf)-strlen(buf) - 1); */
    /*   /\* printf ("--commit_code: %s\n",buf); *\/ */
    /*   handled=1; */
    /*   break; */
    /* case 'T': */
    /*   strncpy(buf+strlen(buf), "--commit_text", sizeof(buf)-strlen(buf) - 1); */
    /*   /\* printf ("--commit_text: %s\n",buf); *\/ */
    /*   handled=1; */
    /*   break; */
    case 'c':

      strncpy(buf+strlen(buf), "--clear", sizeof(buf)-strlen(buf) - 1);
      /* printf ("--clear: %s\n",buf); */
      handled=1;
      break;
    default:
      printf("unknow option :%c\n", ch);
      usage(argv);
      exit(-1);
    }
    if(handled){
      strcpy(buf+strlen(buf), ",");
    }
  }
  if(strlen(buf)>0){
    strcpy(buf+strlen(buf)-1, "\0"); /* 去除末尾的分隔符 */
    if(strlen(buf)>0){
      /* printf ("%s\n",buf); */
      sendCmd(buf);
    }
  }

}
