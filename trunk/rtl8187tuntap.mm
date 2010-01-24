//
//  main.m
//  rtl8187tuntap
//
//  Created by Geordie on Wed Jan 20 2010
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "USBJack.h"
#import "rtl8187.h"
#import <pcap.h>
#include "stdio.h"
#import "namedpipe.h"

#define RTAP_HDR_LEN 64

#define ieee80211chan2mhz(x) \
(((x) <= 14) ? \
(((x) == 14) ? 2484 : ((x) * 5) + 2407) : \
((x) + 1000) * 5)

typedef struct {
	u_int8_t        it_version;
	u_int8_t        it_pad;
	u_int16_t       it_len;
	u_int32_t       it_present;
	u_int8_t		rate;
	u_int8_t		pad1;
	u_int16_t		frequency;
	u_int16_t		flags;
	u_int8_t		signal;
	u_int8_t		pad2;
	UInt8			data[MAX_FRAME_BYTES];
} RTAP_PKT;

int rateFromKmRate(int KMRate) {
	switch (KMRate) {
		case 0:
			return 1;
		case 1:
			return 2;
		case 2:
			return 5.5;
		case 3:
			return 11;
		case 4:
			return 6;
		case 5:
			return 9;
		case 6:
			return 12;
		case 7:
			return 18;
		case 8:
			return 24;
		case 9:
			return 36;
		case 10:
			return 48;
		case 11:
			return 54;
		default:
			return 0;
	}
}

uint8 rateIsGRate(int KMRate) {
	if (KMRate < 4) {
		return 0x20;
	} else {
		return 0x40;
	}
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	USBJack *_driver;
	int newChannel = 1;
	
		
	if(!_driver)
	{
		_driver = new RTL8187Jack;
		_driver->startMatching();
		NSLog(@"Matching finished\n");
		if (!(_driver->deviceMatched()))
			return NO;
		
		if(_driver->_init() != kIOReturnSuccess)
			return NO;
	}
	
	if(_driver)
    {
        //if the usb device is not there, see if we can find it
        if(!_driver->devicePresent())
        {
			NSLog(@"Device not present");
        }
        if (_driver->startCapture(newChannel))
		{
			NSLog(@"Capture started");
		}
    }
	
	
	int fd = open("/dev/tap0", O_RDWR);
	if (fd < 0) {
		NSLog(@"Tap open failed");
		return 2;
	}
	
	system("/sbin/ifconfig tap0 0.0.0.0 up"); // must do this the right way
	//ioctl( socket, SIOCSIFADDR, ... )
	
	namedpipe *np = [namedpipe alloc];
	[NSThread detachNewThreadSelector:@selector(namedPipe:) toTarget:np withObject:[NSValue valueWithPointer:_driver]];
	
	
	RTAP_PKT *pkt = (RTAP_PKT *)malloc(sizeof(RTAP_PKT)); 
	pkt->it_version = 0;
	pkt->it_len = 16;
	pkt->it_present = 0x0000002C;
	
	NSLog(@"Now recieving frames");
	while (1) {
		KFrame *f = NULL;
		f = _driver->receiveFrame();
		
		memcpy(pkt->data, f->data, f->ctrl.len); 
		
		int pktlen = f->ctrl.len + 16;
				
		pkt->frequency = ieee80211chan2mhz(f->ctrl.channel);
		pkt->rate = rateFromKmRate(f->ctrl.rate)*2;
		pkt->flags = rateIsGRate(f->ctrl.rate) | 0x80;
		pkt->signal = f->ctrl.signal;
		
		int written = write(fd, pkt, pktlen);
		if (written != pktlen) {
			NSLog(@"Error writing frame: %i", written);
			return 2;
		}
	}
	
    [pool drain];
    return 1;
}