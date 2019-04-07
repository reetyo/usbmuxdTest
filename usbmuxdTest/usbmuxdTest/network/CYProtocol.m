//
//  CYProtocol.m
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYProtocol.h"
#import "PTData.h"

static const uint32_t PTProtocolVersion1 = 1;
NSString * const PTProtocolErrorDomain;

enum {
    PTExampleFrameTypeDeviceInfo = 100,
    PTExampleFrameTypeTextMessage = 101,
    PTExampleFrameTypePing = 102,
    PTExampleFrameTypePong = 103,
};

typedef struct _PTExampleTextFrame {
    uint32_t length;
    uint8_t utf8text[0];
} PTExampleTextFrame;

// This is what we send as the header for each frame.
typedef struct _PTFrame {
    // The version of the frame and protocol.
    uint32_t version;
    
    // Type of frame
    uint32_t type;
    
    // Unless zero, a tag is retained in frames that are responses to previous
    // frames. Applications can use this to build transactions or request-response
    // logic.
    uint32_t tag;
    
    // If payloadSize is larger than zero, *payloadSize* number of bytes are
    // following, constituting application-specific data.
    uint32_t payloadSize;
    
} PTFrame;

static dispatch_data_t PTExampleTextDispatchDataWithString(NSString *message) {
    // Use a custom struct
    const char *utf8text = [message cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen(utf8text);
    PTExampleTextFrame *textFrame = CFAllocatorAllocate(nil, sizeof(PTExampleTextFrame) + length, 0);
    memcpy(textFrame->utf8text, utf8text, length); // Copy bytes to utf8text array
    textFrame->length = htonl(length); // Convert integer to network byte order
    
    // Wrap the textFrame in a dispatch data object
    return dispatch_data_create((const void*)textFrame, sizeof(PTExampleTextFrame)+length, nil, ^{
        CFAllocatorDeallocate(nil, textFrame);
    });
}
#define WeakSelf(type) __weak __typeof__(self) target = self;

@interface CYProtocol ()

@property (nonatomic,copy) TextMessageCallback textMessageCallback;
@property (nonatomic,copy) DeviceInfoCallback deviceInfoCallback;

@end

@implementation CYProtocol

#pragma mark - read

- (void)readFrameOverChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue onFinish:(void(^)(void))finishCallback{
    __block dispatch_data_t allData = NULL;
    WeakSelf(target);
    dispatch_io_read(channel, 0, sizeof(PTFrame), queue, ^(bool done, dispatch_data_t data, int error) {
        NSLog(@"dispatch_io_read: done=%d data=%p error=%d", done, data, error);
        size_t dataSize = data ? dispatch_data_get_size(data) : 0;
        
        if (dataSize) {
            if (!allData) {
                allData = data;
            } else {
                allData = dispatch_data_create_concat(allData, data);
            }
        }
        
        if (done) {
            if (error != 0) {
                return;
            }
            
            if (dataSize == 0) {
                return;
            }
            
            if (!allData || dispatch_data_get_size(allData) < sizeof(PTFrame)) {
                return;
            }
            
            PTFrame *frame = NULL;
            size_t size = 0;
            
            dispatch_data_t contiguousData = dispatch_data_create_map(allData, (const void **)&frame, &size); // precise lifetime guarantees bytes in frame will stay valid till the end of scope
            if (!contiguousData) {
                return;
            }
            
            frame->version = ntohl(frame->version);
            if (frame->version != PTProtocolVersion1) {
            } else {
                frame->type = ntohl(frame->type);
                frame->tag = ntohl(frame->tag);
                frame->payloadSize = ntohl(frame->payloadSize);
                
                [target readPayloadOfSize:frame->payloadSize queue:queue overChannel:channel callback:^(NSError *error, dispatch_data_t contiguousData, const uint8_t *buffer, size_t bufferSize){
                    PTData *payload = [[PTData alloc] initWithMappedDispatchData:contiguousData data:(void*)buffer length:bufferSize];

                    if(frame->type == PTExampleFrameTypeTextMessage){
                        PTExampleTextFrame *textFrame = (PTExampleTextFrame*)payload.data;
                        textFrame->length = ntohl(textFrame->length);
                        NSString *message = [[NSString alloc] initWithBytes:textFrame->utf8text length:textFrame->length encoding:NSUTF8StringEncoding];
                        if(target.textMessageCallback){
                            target.textMessageCallback(message);
                        }
                        
                    }
                    else if(frame->type == PTExampleFrameTypeDeviceInfo){
                        NSDictionary *deviceInfo = [CYProtocol dictionaryWithContentsOfDispatchData:payload.dispatchData];
                        if(self.deviceInfoCallback){
                            target.deviceInfoCallback(deviceInfo);
                        }
                    }
                    
                    finishCallback();
                }];
            }
        }
    });
}

-(void)readPayloadOfSize:(size_t)payloadSize queue:(dispatch_queue_t)queue overChannel:(dispatch_io_t)channel callback:(void(^)(NSError *error, dispatch_data_t contiguousData, const uint8_t *buffer, size_t bufferSize))callback {
    __block dispatch_data_t allData = NULL;
    dispatch_io_read(channel, 0, payloadSize, queue, ^(bool done, dispatch_data_t data, int error) {
        NSLog(@"dispatch_io_read: done=%d data=%p error=%d", done, data, error);
        size_t dataSize = dispatch_data_get_size(data);
        
        if (dataSize) {
            if (!allData) {
                allData = data;
            } else {
                allData = dispatch_data_create_concat(allData, data);
            }
        }
        
        if (done) {
            if (error != 0) {
                callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:error userInfo:nil], NULL, NULL, 0);
                return;
            }
            
            if (dataSize == 0) {
                callback(nil, NULL, NULL, 0);
                return;
            }
            
            uint8_t *buffer = NULL;
            size_t bufferSize = 0;
             dispatch_data_t contiguousData = NULL;
            
            if (allData) {
                contiguousData = dispatch_data_create_map(allData, (const void **)&buffer, &bufferSize);
                if (!contiguousData) {
                    callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil], NULL, NULL, 0);
                    return;
                }
            }
            callback(nil, contiguousData, buffer, bufferSize);
        }
    });
}

- (void)startReadingOnChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue{
    [self readFrameOverChannel:channel queue:queue onFinish:^{
        [self startReadingOnChannel:channel queue:queue];
    }];
}

#pragma mark - write

- (void)sendText:(NSString*)text tag:(uint32_t)tag overChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue{
    dispatch_data_t payload = PTExampleTextDispatchDataWithString(text);
    dispatch_data_t frame = [self createDispatchDataWithFrameOfType:PTExampleFrameTypeTextMessage frameTag:tag payload:payload queue:queue];
    dispatch_io_write(channel, 0, frame, queue, ^(bool done, dispatch_data_t data, int _errno){
        
    });
}

#pragma mark - read handler

- (void)registerTextMessageHandler:(TextMessageCallback)callback{
    if(callback){
        self.textMessageCallback = callback;
    }
}

- (void)registerDeviceInfoHandler:(DeviceInfoCallback)callback{
    if(callback){
        self.deviceInfoCallback = callback;
    }
}

#pragma mark - util
+ (NSDictionary*)dictionaryWithContentsOfDispatchData:(dispatch_data_t)data {
    if (!data) {
        return nil;
    }
    uint8_t *buffer = NULL;
    size_t bufferSize = 0;
    dispatch_data_t contiguousData = dispatch_data_create_map(data, (const void **)&buffer, &bufferSize);
    if (!contiguousData) {
        return nil;
    }
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:[NSData dataWithBytesNoCopy:(void*)buffer length:bufferSize freeWhenDone:NO] options:NSPropertyListImmutable format:NULL error:nil];
    return dict;
}

- (dispatch_data_t)createDispatchDataWithFrameOfType:(uint32_t)type frameTag:(uint32_t)frameTag payload:(dispatch_data_t)payload queue:(dispatch_queue_t)queue{
    PTFrame *frame = CFAllocatorAllocate(kCFAllocatorDefault, sizeof(PTFrame), 0);
    frame->version = htonl(PTProtocolVersion1);
    frame->type = htonl(type);
    frame->tag = htonl(frameTag);
    
    if (payload) {
        size_t payloadSize = dispatch_data_get_size(payload);
        assert(payloadSize <= UINT32_MAX);
        frame->payloadSize = htonl((uint32_t)payloadSize);
    } else {
        frame->payloadSize = 0;
    }
    
    dispatch_data_t frameData = dispatch_data_create((const void*)frame, sizeof(PTFrame), queue, ^{
        CFAllocatorDeallocate(kCFAllocatorDefault, (void*)frame);
    });
    
    if (payload && frame->payloadSize != 0) {
        // chain frame + payload
        dispatch_data_t data = dispatch_data_create_concat(frameData, payload);
        frameData = data;
    }
    
    return frameData;
}


@end
