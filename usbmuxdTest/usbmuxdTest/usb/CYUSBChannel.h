//
//  CYUSBChannel.h
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//  与 usbmuxd 的通讯通道

#import <Foundation/Foundation.h>

typedef void(^BroadcastCallback)(NSDictionary*);

@interface CYUSBChannel : NSObject

- (void)connect:(void(^)(NSError*))callback;

- (void)sendPacket:(NSDictionary*)packet callback:(void(^)(NSError*,NSDictionary*))callback;

- (void)registerBroadcastPackHandler:(BroadcastCallback)callback;

- (dispatch_io_t)transferBackingChannel;

@end
