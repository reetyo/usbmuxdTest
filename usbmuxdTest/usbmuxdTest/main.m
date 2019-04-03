//
//  main.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CYUSBChannel.h"

void start();

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        start();
    }
    
    return 0;
}

void start(){
    CYUSBChannel* channel = [[CYUSBChannel alloc] init];
    [channel connect];
}
