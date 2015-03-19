#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define TCP_PORT 1001
#define UDP_PORT 1002

int interrupted = 0;

void signal_handler(int sig)
{
  interrupted = 1;
}

int main(int argc, char *argv[])
{
  int file, sockServer, sockClient;
  int pos, limit, start;
  pid_t pid;
  void *cfg, *sts, *ram;
  char *name = "/dev/mem";
  unsigned long size = 0;
  struct sockaddr_in addrServer, addrClient;
  socklen_t lenClient;
  uint32_t command = 600000;
  uint32_t freqMin = 100000;
  uint32_t freqMax = 50000000;
  int yes = 1;

  if((file = open(name, O_RDWR)) < 1)
  {
    perror("open");
    return 1;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40000000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40001000);
  ram = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, file, 0x40002000);

  /* enter reset mode */
  *((uint32_t *)(cfg + 0)) &= ~7;

  /* set default phase increment */
  *((uint32_t *)(cfg + 4)) = (uint32_t)floor(600000/125.0e6*(1<<30)+0.5);

  if((sockServer = socket(AF_INET, SOCK_STREAM, 0)) < 1)
  {
    perror("socket");
    return 1;
  }

  setsockopt(sockServer, SOL_SOCKET, SO_REUSEADDR, (void *)&yes , sizeof(yes));

  /* set up server address */
  memset(&addrServer, 0, sizeof(addrServer));
  addrServer.sin_family = AF_INET;
  addrServer.sin_addr.s_addr = htonl(INADDR_ANY);
  addrServer.sin_port=htons(TCP_PORT);

  if(bind(sockServer, (struct sockaddr *)&addrServer, sizeof(addrServer)) < 0)
  {
    perror("bind");
    return 1;
  }

  listen(sockServer, 1024);

  lenClient = sizeof(addrClient);

  limit = 128;

  while(!interrupted)
  {
    sockClient = accept(sockServer, (struct sockaddr *)&addrClient, &lenClient);

    pid = fork();
    if(pid == 0)
    {
      /* child process */
      int sockData;
      struct sockaddr_in addrData;
      int pos, limit, start;
      if((sockData = socket(AF_INET, SOCK_DGRAM, 0)) < 1)
      {
        perror("socket");
        return 1;
      }

      /* set up destination address */
      memset(&addrData, 0, sizeof(addrData));
      addrData.sin_family = AF_INET;
      addrData.sin_addr = addrClient.sin_addr;
      addrData.sin_port = htons(UDP_PORT);

      signal(SIGINT, signal_handler);

      limit = 128;
      while(!interrupted)
      {
        /* read ram writer position */
        pos = *((uint32_t *)(sts + 0));

        /* send 1024 bytes if ready, otherwise sleep 0.5 ms */
        if((limit > 0 && pos > limit) || (limit == 0 && pos < 384))
        {
          start = limit > 0 ? limit*8 - 1024 : 3072;
          send(sockData, ram + start, 1024, 0);
          limit += 128;
          if(limit == 512) limit = 0;
        }
        else
        {
          usleep(100);
        }
      }

      close(sockData);
    }
    else if(pid > 0)
    {
      /* parent process */

      /* enter normal operating mode */
      *((uint32_t *)(cfg + 0)) |= 7;

      while(!interrupted)
      {
        if(recv(sockClient, (char *)&command, 4, 0) == 0) break;

        switch(command>>30)
        {
          case 0:
            /* set phase increment */
            if(command < freqMin || command > freqMax) continue;
            *((uint32_t *)(cfg + 4)) = (uint32_t)floor(command/125.0e6*(1<<30)+0.5);
            break;
          case 1:
            /* set bandwidth */
            *((uint32_t *)(cfg + 0)) &= ~7;
            switch(command & 1)
            {
              case 0: *((uint32_t *)(cfg + 0)) |= 7; break;
              case 1: *((uint32_t *)(cfg + 0)) |= 7; break;
            }
            break;
        }
      }

      close(sockClient);

      /* enter reset mode */
      *((uint32_t *)(cfg + 0)) &= ~7;
    }
  }

  /* enter reset mode */
  *((uint32_t *)(cfg + 0)) &= ~7;

  return 0;
}
