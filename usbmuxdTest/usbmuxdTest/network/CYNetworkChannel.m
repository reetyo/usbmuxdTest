//
//  CYNetworkChannel.m
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYNetworkChannel.h"
#import "CYProtocol.h"

#define WeakSelf(type) __weak __typeof__(self) target = self;

@interface CYNetworkChannel ()

@property (nonatomic,strong) dispatch_io_t channel;
@property (nonatomic,strong) CYProtocol* protocolLayer;
@property (nonatomic,strong) dispatch_queue_t workingQueue;

@property (nonatomic,assign) uint32_t tag;

@end

@implementation CYNetworkChannel

- (instancetype)initWithIO:(dispatch_io_t)channel{
    if(self = [super init]){
        self.tag = 0;
        self.channel = channel;
        self.protocolLayer = [[CYProtocol alloc] init];
        self.workingQueue = dispatch_queue_create("cynetworkchannel working queue", DISPATCH_QUEUE_CONCURRENT);
        [self setUp];
    }
    
    return self;
}

- (void)setUp{
    [self.protocolLayer startReadingOnChannel:self.channel queue:self.workingQueue];
    WeakSelf(target);
    [self.protocolLayer registerTextMessageHandler:^(NSString *text) {
        [target handleTextMessage:text];
    }];
    [self.protocolLayer registerDeviceInfoHandler:^(NSDictionary *dic) {
        [target handleDeviceInfo:dic];
    }];
}

- (void)handleTextMessage:(NSString*)message{
    NSLog(@"CYNetworkChannel : get message : %@",message);
    if([message isEqualToString:@"send"]){
        [self sendMessage:@"receive"];
    }
}

- (void)handleDeviceInfo:(NSDictionary*)deviceInfo{
    NSLog(@"CYNetworkChannel : get device info : %@",deviceInfo);
}

- (void)sendMessage:(NSString*)message{
    [self.protocolLayer sendText:message tag:[self nextTag] overChannel:self.channel queue:self.workingQueue];
}

- (uint32_t)nextTag{
    self.tag += 1;
    return self.tag;
}

@end
