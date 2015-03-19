
#include <string.h>
#include <math.h>

#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#include <windows.h>

#include "GUI.h"

using namespace System;
using namespace System::Runtime::InteropServices;
using namespace Microsoft::Win32;

using namespace ExtIO_RedPitaya;

//---------------------------------------------------------------------------

#define EXTIO_API __declspec(dllexport) __stdcall

#define TCP_PORT 1001
#define UDP_PORT 1002
#define TCP_ADDR "192.168.1.4"

SOCKET gCtrlSock = 0, gDataSock = 0;
struct sockaddr_in gCtrlAddr, gDataAddr;

char gBuffer[4096];
int gOffset = 0;

long gRate = 100000;

long gFreq = 600000;
long gFreqMin = 100000;
long gFreqMax = 50000000;

bool gInitHW = false;

bool gExitThread = false;
bool gThreadRunning = false;

//---------------------------------------------------------------------------

ref class ManagedGlobals
{
  public:
    static GUI ^gGUI = nullptr;
    static RegistryKey ^gKey = nullptr;
};

//---------------------------------------------------------------------------

void (*ExtIOCallback)(int, int, float, void *) = 0;

static void SetBandwidth(UInt32);

//---------------------------------------------------------------------------

DWORD WINAPI GeneratorThreadProc(__in LPVOID lpParameter)
{
  unsigned long size = 0;

  while(!gExitThread)
  {
    SleepEx(1, FALSE );
    if(gExitThread) break;

    ioctlsocket(gDataSock, FIONREAD, &size);

    while(size >= 1024)
    {
      recv(gDataSock, gBuffer + gOffset, 1024, 0);

      gOffset += 1024;
      if(gOffset == 4096)
      {
        gOffset = 0;
        if(ExtIOCallback) (*ExtIOCallback)(512, 0, 0.0, gBuffer);
      }

      ioctlsocket(gDataSock, FIONREAD, &size);
    }
  }
  gExitThread = false;
  gThreadRunning = false;
  return 0;
}

//---------------------------------------------------------------------------

static void StopThread()
{
  if(gThreadRunning)
  {
    gExitThread = true;
    while(gThreadRunning)
    {
      SleepEx(10, FALSE);
    }
  }
}

//---------------------------------------------------------------------------

static void StartThread()
{
  gExitThread = false;
  gThreadRunning = true;
  CreateThread(NULL, (SIZE_T)(64 * 1024), GeneratorThreadProc, NULL, 0, NULL);
}

//---------------------------------------------------------------------------

extern "C" int EXTIO_API SetHWLO(long LOfreq);

//---------------------------------------------------------------------------

extern "C"
bool EXTIO_API InitHW(char *name, char *model, int &type)
{
  String ^addrString;
  UInt32 bwIndex = 0;

  type = 6;

  strcpy(name, "Red Pitaya SDR");
  strcpy(model, "");

  if(!gInitHW)
  {
    ManagedGlobals::gKey = Registry::CurrentUser->OpenSubKey("Software\\ExtIO_RedPitaya", true);
    if(!ManagedGlobals::gKey)
    {
      ManagedGlobals::gKey = Registry::CurrentUser->CreateSubKey("Software\\ExtIO_RedPitaya");
      ManagedGlobals::gKey->SetValue("IP Address", TCP_ADDR);
      ManagedGlobals::gKey->SetValue("Bandwidth", bwIndex);
    }

    ManagedGlobals::gGUI = gcnew GUI;
    addrString = ManagedGlobals::gKey->GetValue("IP Address")->ToString();
    ManagedGlobals::gGUI->addrValue->Text = addrString;

    bwIndex = Convert::ToUInt32(ManagedGlobals::gKey->GetValue("Bandwidth"));
    if(bwIndex < 0 || bwIndex > 1)
    {
      bwIndex = 0;
      ManagedGlobals::gKey->SetValue("Bandwidth", bwIndex);
    }
    ManagedGlobals::gGUI->bwValue->SelectedIndex = bwIndex;
    ManagedGlobals::gGUI->bwCallback = SetBandwidth;

    gInitHW = true;
  }

  return gInitHW;
}

//---------------------------------------------------------------------------

extern "C"
bool EXTIO_API OpenHW()
{
  return gInitHW;
}

//---------------------------------------------------------------------------

extern "C"
int EXTIO_API StartHW(long LOfreq)
{
  WSADATA wsaData;
  struct sockaddr_in addr;
  String ^addrString;
  char *buffer;

  if(!gInitHW) return 0;

  WSAStartup(MAKEWORD(2, 2), &wsaData);

  gDataSock = socket(AF_INET, SOCK_DGRAM, 0);

  memset(&addr, 0, sizeof(gDataAddr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(UDP_PORT);

  bind(gDataSock, (struct sockaddr *)&addr, sizeof(addr));

  gCtrlSock = socket(AF_INET, SOCK_STREAM, 0);

  addrString = ManagedGlobals::gGUI->addrValue->Text;
  ManagedGlobals::gKey->SetValue("IP Address", addrString);

  buffer = (char*)Marshal::StringToHGlobalAnsi(addrString).ToPointer();

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = inet_addr(buffer);
  addr.sin_port = htons(TCP_PORT);

  connect(gCtrlSock, (struct sockaddr *)&addr, sizeof(addr));

  Marshal::FreeHGlobal(IntPtr(buffer));

  StopThread();
  gFreq = LOfreq;
  SetBandwidth(ManagedGlobals::gGUI->bwValue->SelectedIndex);
  StartThread();

  return 512;
}

//---------------------------------------------------------------------------

extern "C"
void EXTIO_API StopHW()
{
  StopThread();

  closesocket(gCtrlSock);

  gCtrlSock = 0;

  WSACleanup();
}

//---------------------------------------------------------------------------

extern "C"
void EXTIO_API CloseHW()
{
  gInitHW = false;
}

//---------------------------------------------------------------------------

extern "C"
void EXTIO_API SetCallback(void (*callback)(int, int, float, void *))
{
  ExtIOCallback = callback;
}

//---------------------------------------------------------------------------

extern "C"
int EXTIO_API SetHWLO(long LOfreq)
{
  long rc = 0;

  gFreq = LOfreq;

  // check limits
  if(gFreq < gFreqMin)
  {
    gFreq = gFreqMin;
    rc = -gFreqMin;
  }
  else if(gFreq > gFreqMax)
  {
    gFreq = gFreqMax;
    rc = gFreqMax;
  }

  gFreq = (long)floor(floor(gFreq/125.0e6*(1<<30)+0.5)*125e6/(1<<30)+0.5);

  if(gFreq != LOfreq && ExtIOCallback) (*ExtIOCallback)(-1, 101, 0.0, 0);

  if(gCtrlSock) send(gCtrlSock, (char *)&gFreq, 4, 0);

  return rc;
}

//---------------------------------------------------------------------------

static void SetBandwidth(UInt32 bwIndex)
{
  switch(bwIndex)
  {
    case 0: gRate = 100000; gFreqMin = 100000; break;
    case 1: gRate = 500000; gFreqMin = 300000; break;
  }
  
  if(ManagedGlobals::gKey) ManagedGlobals::gKey->SetValue("Bandwidth", bwIndex);

  if(ExtIOCallback) (*ExtIOCallback)(-1, 100, 0.0, 0);

  bwIndex |= 1<<31;
  if(gCtrlSock) send(gCtrlSock, (char *)&bwIndex, 4, 0);

  SetHWLO(gFreq);
}

//---------------------------------------------------------------------------

extern "C"
long EXTIO_API GetHWLO()
{
  return gFreq;
}

//---------------------------------------------------------------------------

extern "C"
long EXTIO_API GetHWSR()
{
  return gRate;
}

//---------------------------------------------------------------------------

extern "C"
int EXTIO_API GetStatus()
{
  return 0;
}

//---------------------------------------------------------------------------

extern "C"
void EXTIO_API ShowGUI()
{
  if(ManagedGlobals::gGUI) ManagedGlobals::gGUI->ShowDialog();
}
