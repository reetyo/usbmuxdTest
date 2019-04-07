//
//  PTData.h
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PTData : NSObject
@property (readonly) dispatch_data_t dispatchData;
@property (readonly) void *data;
@property (readonly) size_t length;

- (id)initWithMappedDispatchData:(dispatch_data_t)mappedContiguousData data:(void*)data length:(size_t)length;

@end
