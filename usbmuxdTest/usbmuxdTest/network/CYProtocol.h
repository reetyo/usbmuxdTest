//
//  CYProtocol.h
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import <Foundation/Foundation.h>

static const uint32_t PTFrameTypeEndOfStream = 0;
static const uint32_t PTFrameNoTag = 0;

typedef void(^TextMessageCallback)(NSString* text);
typedef void(^DeviceInfoCallback)(NSDictionary* dic);


@interface CYProtocol : NSObject

- (void)startReadingOnChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue;
- (void)sendText:(NSString*)text tag:(uint32_t)tag overChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue;


- (void)registerTextMessageHandler:(TextMessageCallback)callback;
- (void)registerDeviceInfoHandler:(DeviceInfoCallback)callback;


@end

