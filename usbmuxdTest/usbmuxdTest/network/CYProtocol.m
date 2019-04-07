//
//  CYProtocol.m
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "CYProtocol.h"

static const uint32_t PTProtocolVersion1 = 1;
NSString * const PTProtocolErrorDomain;


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

@implementation CYProtocol

#pragma mark - read

- (void)readFrameOverChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue callback:(void(^)(NSError *error, uint32_t frameType, uint32_t frameTag, uint32_t payloadSize))callback {
    __block dispatch_data_t allData = NULL;
    
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
                callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:error userInfo:nil], 0, 0, 0);
                return;
            }
            
            if (dataSize == 0) {
                callback(nil, PTFrameTypeEndOfStream, 0, 0);
                return;
            }
            
            if (!allData || dispatch_data_get_size(allData) < sizeof(PTFrame)) {
                callback([[NSError alloc] initWithDomain:PTProtocolErrorDomain code:0 userInfo:nil], 0, 0, 0);
                return;
            }
            
            PTFrame *frame = NULL;
            size_t size = 0;
            
            dispatch_data_t contiguousData = dispatch_data_create_map(allData, (const void **)&frame, &size); // precise lifetime guarantees bytes in frame will stay valid till the end of scope
            if (!contiguousData) {
                callback([[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:ENOMEM userInfo:nil], 0, 0, 0);
                return;
            }
            
            frame->version = ntohl(frame->version);
            if (frame->version != PTProtocolVersion1) {
                callback([[NSError alloc] initWithDomain:PTProtocolErrorDomain code:0 userInfo:nil], 0, 0, 0);
            } else {
                frame->type = ntohl(frame->type);
                frame->tag = ntohl(frame->tag);
                frame->payloadSize = ntohl(frame->payloadSize);
                callback(nil, frame->type, frame->tag, frame->payloadSize);
            }
        }
    });
}

- (void)readFramesOverChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue onFrame:(void(^)(NSError*, uint32_t, uint32_t, uint32_t, dispatch_block_t))onFrame {
    [self readFrameOverChannel:channel queue:queue callback:^(NSError *error, uint32_t type, uint32_t tag, uint32_t payloadSize) {
        onFrame(error, type, tag, payloadSize, ^{
            if (type != PTFrameTypeEndOfStream) {
                [self readFramesOverChannel:channel queue:queue onFrame:onFrame];
            }
        });
    }];
}

@end
