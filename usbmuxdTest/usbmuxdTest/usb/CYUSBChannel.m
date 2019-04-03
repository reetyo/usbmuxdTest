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

@interface CYUSBChannel ()

@property (nonatomic,strong) dispatch_io_t io;
@property (nonatomic,strong) dispatch_queue_t queue;
@property (nonatomic,assign) dispatch_fd_t fileDescriptpr;

@end

@implementation CYUSBChannel

- (instancetype)init{
    if(self = [super init]){
        
    }
    return self;
}

- (void)setup{
    self.queue = dispatch_queue_create("usbchannel", DISPATCH_QUEUE_SERIAL);
}

- (void)connect{
    dispatch_fd_t usbmuxdFile = socket(AF_UNIX,SOCK_STREAM,0);
    if (usbmuxdFile == -1) {
        NSLog(@"CYUSBChannel : create file failed");
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
        return;
    }
    
    self.io = dispatch_io_create(DISPATCH_IO_STREAM, usbmuxdFile, self.queue, ^(int error) {
        NSLog(@"CYUSBChannel : io create failed with error: %d",error);
    });
    self.fileDescriptpr = usbmuxdFile;
    
}

- (void)readPack{
    struct usbmux_packet ref_upacket;
    dispatch_io_read(self.io, 0, sizeof(ref_upacket.size), self.queue, ^(bool done, dispatch_data_t  _Nullable data, int error) {
        if (!done){
            return;
        }
        
        if (error) {
            NSLog(@"CYUSBChannel : read pack with error: %d",error);
        }
        
        uint32_t upacket_len = 0;
        
        char *buffer = NULL;
        size_t buffer_size = 0;
        dispatch_data_t map_data = dispatch_data_create_map(data, (const void **)&buffer, &buffer_size);
        if(map_data == nil){
            NSLog(@"CYUSBChannel : read pack failed");
        }
        memcpy((void *)&(upacket_len), (const void *)buffer, buffer_size);
        uint32_t payloadLength = upacket_len - (uint32_t)sizeof(usbmux_packet);

    });
}



@end
