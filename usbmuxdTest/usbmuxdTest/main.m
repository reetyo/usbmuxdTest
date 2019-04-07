//
//  main.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CYUsbPort.h"
#import "CYNetworkChannel.h"


void start(){
    CYUsbPort* port = [[CYUsbPort alloc] init];
    __block CYNetworkChannel* channel;
    [port registerConnectCallback:^(dispatch_io_t io) {
        channel = [[CYNetworkChannel alloc] initWithIO:io];
    }];
    
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        //[[NSRunLoop currentRunLoop] run];
        start();
        [NSRunLoop.currentRunLoop run];
    }
    
    return 0;
}
