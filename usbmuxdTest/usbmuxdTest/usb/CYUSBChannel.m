//
//  CYUSBChannel.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYUSBChannel.h"
#import <dispatch/dispatch.h>
#import <netinet/in.h>
#import <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/un.h>
#include <err.h>
#import "CYCommonDefind.h"
#import "CYUSBMuxdDefind.h"

NSString * const CYUSBChannelErrorDomain = @"CYUSBChannelError";

#pragma mark - packet

static const uint32_t kUsbmuxPacketMaxPayloadSize = UINT32_MAX - (uint32_t)sizeof(Usbmux_packet);
static Usbmux_packet *usbmux_packet_alloc(uint32_t payloadSize) {
    assert(payloadSize <= kUsbmuxPacketMaxPayloadSize);
    uint32_t upacketSize = sizeof(Usbmux_packet) + payloadSize;
    Usbmux_packet *upacket = CFAllocatorAllocate(kCFAllocatorDefault, upacketSize, 0);
    memset(upacket, 0, sizeof(Usbmux_packet));
    upacket->size = upacketSize;
    return upacket;
}
static void usbmux_packet_free(Usbmux_packet *upacket) {
    CFAllocatorDeallocate(kCFAllocatorDefault, upacket);
}

static uint32_t usbmux_packet_payload_size(Usbmux_packet *upacket) {
    return upacket->size - sizeof(Usbmux_packet);
}

static void *usbmux_packet_payload(Usbmux_packet *upacket) {
    return (void*)upacket->data;
}

static void usbmux_packet_set_payload(Usbmux_packet *upacket,
                                      const void *payload,
                                      uint32_t payloadLength)
{
    memcpy(usbmux_packet_payload(upacket), payload, payloadLength);
}

static Usbmux_packet *usbmux_packet_create(USBMuxPacketProtocol protocol,
                                             USBMuxPacketType type,
                                             uint32_t tag,
                                             const void *payload,
                                             uint32_t payloadSize)
{
    Usbmux_packet *upacket = usbmux_packet_alloc(payloadSize);
    if (!upacket) {
        return NULL;
    }
    
    upacket->protocol = protocol;
    upacket->type = type;
    upacket->tag = tag;
    
    if (payload && payloadSize) {
        usbmux_packet_set_payload(upacket, payload, (uint32_t)payloadSize);
    }
    
    return upacket;
}

#pragma mark  block define

typedef void(^SendPacketCallback)(NSError *, NSDictionary *);

#pragma mark - channel

@interface CYUSBChannel ()

@property (nonatomic,strong) dispatch_io_t io;
@property (nonatomic,strong) dispatch_queue_t ioQueue;
@property (nonatomic,strong) dispatch_queue_t ReadingQueue;
@property (nonatomic,assign) dispatch_fd_t fileDescriptpr;

@property (nonatomic,strong) NSMutableDictionary<NSNumber*,SendPacketCallback>* callbackDictionary;
@property (nonatomic,strong) BroadcastCallback broadcastCallback;

//pack
@property (nonatomic,assign) uint32_t packetTag;

@end

@implementation CYUSBChannel

- (instancetype)init{
    if(self = [super init]){
        [self setup];
    }
    return self;
}

- (void)setup{
    self.callbackDictionary = [[NSMutableDictionary alloc] init];
    self.packetTag = 0;
    self.ioQueue = dispatch_queue_create("usbChannelIO", DISPATCH_QUEUE_CONCURRENT);
    self.ReadingQueue = dispatch_queue_create("usbChannelRead", DISPATCH_QUEUE_CONCURRENT);
}

#pragma mark - connect

- (void)connect:(void(^)(NSError*))callback{
    
    dispatch_fd_t usbmuxdFile = socket(AF_UNIX,SOCK_STREAM,0);
    if (usbmuxdFile == -1) {
        NSLog(@"CYUSBChannel : create file failed");
        callback([[NSError alloc] initWithDomain:CYUSBChannelErrorDomain code:1 userInfo:@{
                                                                                           NSLocalizedDescriptionKey:@"Create file failed"}]);
        return;
    }
    
    int on = 1;
    setsockopt(usbmuxdFile, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    
    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, "/var/run/usbmuxd");
    socklen_t socklen = sizeof(addr);
    if (connect(usbmuxdFile, (struct sockaddr*)&addr, socklen) == -1) {
        NSLog(@"CYUSBChannel : connect usbmuxd failed");
        callback([[NSError alloc] initWithDomain:CYUSBChannelErrorDomain code:1 userInfo:@{
                                                                                           NSLocalizedDescriptionKey:@"connect usbmuxd failed"}]);
        return;
    }
    
    self.fileDescriptpr = usbmuxdFile;
    self.io = dispatch_io_create(DISPATCH_IO_STREAM, usbmuxdFile, self.ioQueue, ^(int error) {
        // do clean up;
    });
    
    [self periodicityReadUsbmuxdPacks];
    
    callback(nil);
}

#pragma mark - read

- (void)periodicityReadUsbmuxdPacks{
    [self readPackWithCallback:^(NSError *error, NSDictionary *dic, uint32_t tag) {
        if(tag == 0){
            //广播包
            if(self.broadcastCallback){
                self.broadcastCallback(dic);
            }
            return;
        }
        [self handleCallBackWithTag:tag error:error pack:dic];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), self.ReadingQueue, ^{
            [self periodicityReadUsbmuxdPacks];
        });
    }];
}

- (void)readPackWithCallback:(void(^)(NSError*, NSDictionary*, uint32_t))callback{
    Usbmux_packet ref_upacket;
    if(self.io == NULL){
        return;
    }
    dispatch_io_read(self.io, 0, sizeof(ref_upacket.size), self.ioQueue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
        if (!done){
            return;
        }
        
        if (error) {
            NSLog(@"CYUSBChannel : read pack with error: %d",error);
            callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:error userInfo:nil], nil, 0);
            return;
        }
        
        uint32_t upacket_len = 0;
        
        char *buffer = NULL;
        size_t buffer_size = 0;
        dispatch_data_t map_data = dispatch_data_create_map(data, (const void **)&buffer, &buffer_size);
        if(map_data == nil){
            NSLog(@"CYUSBChannel : read pack failed");
        }
        memcpy((void *)&(upacket_len), (const void *)buffer, buffer_size);
        
        off_t offset = sizeof(ref_upacket.size);
        uint32_t payloadLength = upacket_len - (uint32_t)sizeof(Usbmux_packet);
        
        Usbmux_packet *upacket = usbmux_packet_alloc(payloadLength);
        
        dispatch_io_read(self.io, offset,upacket->size - offset , self.ioQueue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
            if(!done){
                return ;
            }
            
            if(error){
                callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:error userInfo:nil], nil, 0);
                usbmux_packet_free(upacket);
                return;
            }
            
            if (upacket_len > kUsbmuxPacketMaxPayloadSize) {
                callback(
                         [[NSError alloc] initWithDomain:CYUSBChannelErrorDomain code:1 userInfo:@{
                                                                                               NSLocalizedDescriptionKey:@"Received a packet that is too large"}],
                         nil,
                         0
                         );
                usbmux_packet_free(upacket);
                return;
            }
            
            // Copy read bytes onto our usbmux_packet_t
            char *buffer = NULL;
            size_t buffer_size = 0;
            dispatch_data_t map_data = dispatch_data_create_map(data, (const void **)&buffer, &buffer_size);
            if(map_data == nil){
                NSLog(@"CYUSBChannel : read pack failed");
            }
            assert(buffer_size == upacket->size - offset);
            memcpy(((void *)(upacket))+offset, (const void *)buffer, buffer_size);
            
            // We only support plist protocol
            if (upacket->protocol != USBMuxPacketProtocolPlist) {
                callback([[NSError alloc] initWithDomain:CYUSBChannelErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:@"Unexpected package protocol" forKey:NSLocalizedDescriptionKey]], nil, upacket->tag);
                usbmux_packet_free(upacket);
                return;
            }
            
            // Only one type of packet in the plist protocol
            if (upacket->type != USBMuxPacketTypePlistPayload) {
                callback([[NSError alloc] initWithDomain:CYUSBChannelErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:@"Unexpected package type" forKey:NSLocalizedDescriptionKey]], nil, upacket->tag);
                usbmux_packet_free(upacket);
                return;
            }
            
            // Try to decode any payload as plist
            NSError *err = nil;
            NSDictionary *dict = nil;
            if (usbmux_packet_payload_size(upacket)) {
                dict = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytesNoCopy:usbmux_packet_payload(upacket) length:usbmux_packet_payload_size(upacket) freeWhenDone:NO] options:NSPropertyListImmutable format:NULL error:&err];
            }
            
            // Invoke callback
            callback(err, dict, upacket->tag);
            usbmux_packet_free(upacket);
        });
    });
}

#pragma mark - write
- (void)sendPacket:(NSDictionary*)packet callback:(void(^)(NSError*,NSDictionary*))callback {
    NSError *error = nil;
    // NSPropertyListBinaryFormat_v1_0
    uint32_t tag = [self nextTag];
    [self setTagCallback:tag callBack:callback];
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:packet format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    if (!plistData) {
        [self handleCallBackWithTag:tag error:error pack:nil];
    } else {
        [self sendPacketOfType:USBMuxPacketTypePlistPayload overProtocol:USBMuxPacketProtocolPlist tag:tag payload:plistData];
    }
}

- (void)sendPacketOfType:(USBMuxPacketType)type
            overProtocol:(USBMuxPacketProtocol)protocol
                     tag:(uint32_t)tag
                 payload:(NSData*)payload
{
    assert(payload.length <= kUsbmuxPacketMaxPayloadSize);
    Usbmux_packet *upacket = usbmux_packet_create(
                                                    protocol,
                                                    type,
                                                    tag,
                                                    payload ? payload.bytes : nil,
                                                    (uint32_t)(payload ? payload.length : 0)
                                                    );
    dispatch_data_t data = dispatch_data_create((const void*)upacket, upacket->size, self.ioQueue, ^{
        // Free packet when data is freed
        usbmux_packet_free(upacket);
    });
    [self sendDispatchData:data tag:tag];
}

- (void)sendDispatchData:(dispatch_data_t)data tag:(uint32_t)tag{
    off_t offset = 0;
    dispatch_io_write(self.io, offset, data, self.ioQueue, ^(bool done, dispatch_data_t data, int _errno) {
        if (!done){
            return;
        }
        NSError *err = nil;
        if (_errno) {
            err = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:_errno userInfo:nil];
            [self handleCallBackWithTag:tag error:err pack:nil];
        }
    });
}

#pragma mark - util

- (uint32_t)nextTag{
    self.packetTag += 1;
    return self.packetTag;
}

- (void)registerBroadcastPackHandler:(BroadcastCallback)callback{
    self.broadcastCallback = callback;
}

- (void)handleCallBackWithTag:(uint32_t)tag error:(NSError*)error pack:(NSDictionary*)dic{
    SendPacketCallback callback = (SendPacketCallback)[self.callbackDictionary objectForKey:@(tag)];
    if(!callback){
        return;
    }
    
    [self.callbackDictionary removeObjectForKey:@(tag)];
    callback(error,dic);
}

- (void)setTagCallback:(int)tag callBack:(SendPacketCallback)callback{
    if(!callback){
        return;
    }
    [self.callbackDictionary setObject:callback forKey:@(tag)];
}

- (dispatch_io_t)transferBackingChannel{
    dispatch_io_t result = self.io;
    self.io = NULL;
    return result;
}

@end
