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

@interface CYProtocol : NSObject

- (void)readFramesOverChannel:(dispatch_io_t)channel queue:(dispatch_queue_t)queue onFrame:(void(^)(NSError*, uint32_t, uint32_t, uint32_t, dispatch_block_t))onFrame;

@end

