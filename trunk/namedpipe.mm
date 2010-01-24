//
//  namedpipe.m
//  rtl8187tuntap
//
//  Created by gm on 21/01/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "namedpipe.h"
#include <sys/types.h>
#include <sys/stat.h>

@implementation namedpipe

- (id) namedPipe:(NSValue *)drvrptr {
	
	USBJack *_driver = (USBJack*)[drvrptr pointerValue];
	mkfifo("/tmp/rtl8187_channel", 0666);
	FILE *f = fopen("/tmp/rtl8187_channel", "r");
	char number[16];
	int channel;
	while(1) {
		if (fgets(number,15,f) > 0) {
			//printf("%s",number);
			channel = atoi(number);
			if (channel > 0 && channel < 15) {
				printf("ch %i\n", channel);
				_driver->setChannel(channel);
			}
		}
	}
}

@end
