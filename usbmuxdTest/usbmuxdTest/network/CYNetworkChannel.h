//
//  CYNetworkChannel.h
//  usbmuxdTest
//
//  Created by 澄毅 god on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CYNetworkChannel : NSObject

- (instancetype)initWithIO:(dispatch_io_t)channel;

@end
