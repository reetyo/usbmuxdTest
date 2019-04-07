//
//  CYNetworkChannel.m
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYNetworkChannel.h"
#import "CYProtocol.h"

@interface CYNetworkChannel ()

@property (nonatomic,strong) dispatch_io_t channel;
@property (nonatomic,strong) CYProtocol* protocolLayer;
@property (nonatomic,strong) dispatch_queue_t workingQueue;

@end

@implementation CYNetworkChannel

- (instancetype)initWithIO:(dispatch_io_t)channel{
    if(self = [super init]){
        self.channel = channel;
        self.protocolLayer = [[CYProtocol alloc] init];
        self.workingQueue = dispatch_queue_create("cynetworkchannel working queue", DISPATCH_QUEUE_CONCURRENT);
        [self setUp];
    }
    
    return self;
}

- (void)setUp{
    [self registerFrameProcessHandler];
}

- (void)registerFrameProcessHandler{
    [self.protocolLayer readFramesOverChannel:self.channel queue:self.workingQueue onFrame:^(NSError * error, uint32_t type, uint32_t tag, uint32_t payloadSize, dispatch_block_t resumeReadingFrames) {
        
    }];
}

@end
