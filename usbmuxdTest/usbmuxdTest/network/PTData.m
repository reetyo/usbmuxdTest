//
//  PTData.m
//  usbmuxdTest
//
//  Created by Cairo on 2019/4/7.
//  Copyright © 2019 Cairo. All rights reserved.
//

#import "PTData.h"

@implementation PTData

@synthesize dispatchData = dispatchData_;
@synthesize data = data_;
@synthesize length = length_;

- (id)initWithMappedDispatchData:(dispatch_data_t)mappedContiguousData data:(void*)data length:(size_t)length {
    if (!(self = [super init])) return nil;
    dispatchData_ = mappedContiguousData;
    data_ = data;
    length_ = length;
    return self;
}

- (void)dealloc {
    data_ = NULL;
    length_ = 0;
}

@end
