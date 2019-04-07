//
//  CYUsbPort.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYUsbPort.h"
#import "CYUSBChannel.h"
#import "CYUSBMuxdDefind.h"

static NSString *kPlistPacketTypeListen = @"Listen";
static NSString *kPlistPacketTypeConnect = @"Connect";
static const int PTExampleProtocolIPv4PortNumber = 2345;
NSString * const CYUSBPortErrorDomain = @"CYUSBPortError";

@interface CYUsbPort()

@property(nonatomic,strong) CYUSBChannel* eventChannel;
@property(nonatomic,strong) CYUSBChannel* dataChannel;

@property(nonatomic,copy) ConnectCallback connectCallback;

@end

@implementation CYUsbPort

- (instancetype)init{
    if(self = [super init]){
        [self setup];
    }
    
    return self;
}

- (void)setup{
    self.eventChannel = [[CYUSBChannel alloc] init];
    [self.eventChannel connect:^(NSError *error) {
        [self.eventChannel registerBroadcastPackHandler:^(NSDictionary *dic) {
            [self handleEventChannelBroadcastPack:dic];
        }];
        
        [self requestListen];
    }];
}

#pragma mark - broadcast handler
- (void)handleEventChannelBroadcastPack:(NSDictionary*)dic{
    NSString *messageType = [dic objectForKey:@"MessageType"];
    if([messageType isEqualToString:@"Attached"]){
        CYUSBChannel* channel = [[CYUSBChannel alloc] init];
        self.dataChannel = channel;
        [self requestConnectWithDeviceInfo:dic channel:self.dataChannel];
    }
    else if([messageType isEqualToString:@"Detached"]){
        //TODO:clean up
    }
}

- (void)handleDataChannelBroadcastPack:(NSDictionary*)dic{
    
}

#pragma mark - connect

- (void)requestConnectWithDeviceInfo:(NSDictionary*)deviceInfoDict channel:(CYUSBChannel*)channel{
    NSNumber* deviceID = [deviceInfoDict objectForKey:@"DeviceID"];
    uint32_t port = PTExampleProtocolIPv4PortNumber;

    [channel connect:^(NSError *error) {
        if(error != nil){
            return;
        }
        else{
            uint32_t newPort = ((port<<8) & 0xFF00) | (port>>8);
            NSDictionary *packet = [CYUsbPort packetDictionaryWithPacketType:kPlistPacketTypeConnect
                                                                     payload:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                              deviceID, @"DeviceID",
                                                                              @(newPort), @"PortNumber",
                                                                              nil]];
            [self.dataChannel sendPacket:packet callback:^(NSError *error_, NSDictionary *dic) {
                NSError *error = error_;
                [self errorFromPlistResponse:dic error:&error];
                NSLog(@"usbport connect status : %@",[dic objectForKey:@"Number"]);
                if(error == nil){
                    if(self.connectCallback){
                        self.connectCallback([self.dataChannel transferBackingChannel]);
                    }
                }
                else{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self requestConnectWithDeviceInfo:deviceInfoDict channel:channel];
                    });
                }
            }];
        }
    }];
}

#pragma mark - listen

-(void)requestListen{
      NSDictionary *packet = [CYUsbPort packetDictionaryWithPacketType:kPlistPacketTypeListen payload:nil];
    
    [self.eventChannel sendPacket:packet callback:nil];
}

#pragma mark - helper
+ (NSDictionary*)packetDictionaryWithPacketType:(NSString*)messageType payload:(NSDictionary*)payload {
    NSDictionary *packet = nil;
    
    static NSString *bundleName = nil;
    static NSString *bundleVersion = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *infoDict = [NSBundle mainBundle].infoDictionary;
        if (infoDict) {
            bundleName = [infoDict objectForKey:@"CFBundleName"];
            bundleVersion = [[infoDict objectForKey:@"CFBundleVersion"] description];
        }
    });
    
    if(bundleName == nil){
        bundleName = @"usbmuxdTest";
        bundleVersion = @"1";
    }
    
    if (bundleName) {
        packet = [NSDictionary dictionaryWithObjectsAndKeys:
                  messageType, @"MessageType",
                  bundleName, @"ProgName",
                  bundleVersion, @"ClientVersionString",
                  nil];
    } else {
        packet = [NSDictionary dictionaryWithObjectsAndKeys:messageType, @"MessageType", nil];
    }
    
    if (payload) {
        NSMutableDictionary *mpacket = [NSMutableDictionary dictionaryWithDictionary:payload];
        [mpacket addEntriesFromDictionary:packet];
        packet = mpacket;
    }
    
    return packet;
}

- (BOOL)errorFromPlistResponse:(NSDictionary*)packet error:(NSError**)error {
    if (!*error) {
        NSNumber *n = [packet objectForKey:@"Number"];
        
        if (!n) {
            *error = [NSError errorWithDomain:CYUSBPortErrorDomain code:(n ? n.integerValue : 0) userInfo:nil];
            return NO;
        }
        
        USBMuxReplyCode replyCode = (USBMuxReplyCode)n.integerValue;
        if (replyCode != 0) {
            NSString *errmessage = @"Unspecified error";
            switch (replyCode) {
                case USBMuxReplyCodeBadCommand: errmessage = @"illegal command"; break;
                case USBMuxReplyCodeBadDevice: errmessage = @"unknown device"; break;
                case USBMuxReplyCodeConnectionRefused: errmessage = @"connection refused"; break;
                case USBMuxReplyCodeBadVersion: errmessage = @"invalid version"; break;
                default: break;
            }
            *error = [NSError errorWithDomain:CYUSBPortErrorDomain code:replyCode userInfo:[NSDictionary dictionaryWithObject:errmessage forKey:NSLocalizedDescriptionKey]];
            return NO;
        }
    }
    return YES;
}

#pragma mark
- (void)registerConnectCallback:(ConnectCallback) callback{
    if(callback != nil){
        self.connectCallback = callback;
    }
}

@end
