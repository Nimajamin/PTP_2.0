#include <inttypes.h>
#include <avr/pgmspace.h>

#include <avrpins.h>
#include <max3421e.h>
#include <usbhost.h>
#include <usb_ch9.h>
#include <Usb.h>
#include <usbhub.h>
#include <address.h>

#include <message.h>
#include <parsetools.h>

#include <ptp.h>
#include <ptpdebug.h>
#include <canonps.h>
#include <simpletimer.h>
#include "pseventparser.h"
#include "ptpobjinfoparser.h"

class CamStateHandlers : public PSStateHandlers
{
      enum CamStates { stInitial, stDisconnected, stConnected };
      CamStates stateConnected;
    
public:
      CamStateHandlers() : stateConnected(stInitial) {};
      
      virtual void OnDeviceDisconnectedState(PTP *ptp);
      virtual void OnDeviceInitializedState(PTP *ptp);
} CamStates;

USB                 Usb;
USBHub              Hub1(&Usb);
CanonPS             Ps(&Usb, &CamStates);

SimpleTimer  eventTimer, captureTimer;

void CamStateHandlers::OnDeviceDisconnectedState(PTP *ptp)
{
    if (stateConnected == stConnected || stateConnected == stInitial)
    {
        stateConnected = stDisconnected;
        eventTimer.Disable();
        captureTimer.Disable();
        
        Notify(PSTR("Camera disconnected\r\n"));
    }
}

void CamStateHandlers::OnDeviceInitializedState(PTP *ptp)
{
    if (stateConnected == stDisconnected || stateConnected == stInitial)
    {
        stateConnected = stConnected;
        Notify(PSTR("Camera connected\r\n"));
        eventTimer.Enable();
        captureTimer.Enable();
    }
}

void setup() 
{
  Serial.begin( 115200 );
  Serial.println("Start");

    if (Usb.Init() == -1)
        Serial.println("OSC did not start.");

  eventTimer.Set(&OnEventTimer, 200);
  captureTimer.Set(&OnCaptureTimer, 5000);
  delay( 200 );
}

void loop() 
{
    eventTimer.Run();
    captureTimer.Run();
    Usb.Task();
}

void OnCaptureTimer()
{
    Ps.SetDevicePropValue(PS_DPC_CaptureTransferMode, (uint16_t)0x0D);
            
    uint16_t rc = Ps.Capture();
    
    if (rc != PTP_RC_OK)
        ErrorMessage<uint16_t>("Error", rc);
}

void OnEventTimer()
{
    PSEventParser  prs;
    Ps.EventCheck(&prs);
    
    if (uint32_t handle = prs.GetObjHandle())
    {
                PTPObjInfoParser     inf;
                Ps.GetObjectInfo(handle, &inf);
    }
}


