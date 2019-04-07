//
//  CYUsbPort.h
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/3.
//  Copyright © 2019 Cairo. All rights reserved.
//  管理与 usbmux 的通信

#import <Foundation/Foundation.h>

typedef void(^ConnectCallback)(dispatch_io_t channel);

@interface CYUsbPort : NSObject

- (void)registerConnectCallback:(ConnectCallback) callback;

@end
