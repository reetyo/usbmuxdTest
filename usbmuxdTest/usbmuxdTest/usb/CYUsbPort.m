//
//  CYUsbPort.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYUsbPort.h"
#import "CYUSBChannel.h"

@interface CYUsbPort()

@property(nonatomic,strong) CYUSBChannel* usbChannel;

@end

@implementation CYUsbPort

- (instancetype)init{
    if(self = [super init]){
        self.usbChannel = [[CYUSBChannel alloc] init];
    }
    
    return self;
}

- (void)scheduleListenBoardcastPack{
    
}

- (void)readPack{
    
}

@end
