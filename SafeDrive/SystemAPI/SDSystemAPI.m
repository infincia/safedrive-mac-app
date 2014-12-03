
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSystemAPI.h"

@interface SDSystemAPI ()

@end

@implementation SDSystemAPI

- (instancetype)init {
    self = [super init];
    if (self) {
        //
    }
    return self;
}

- (void)dealloc {
    //never
}


#pragma mark
#pragma mark Public API

+(SDSystemAPI *)sharedAPI {
    static SDSystemAPI *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDSystemAPI alloc] init];
    });
    return localInstance;
}

-(NSDictionary *)statusForMount:(NSURL *)mountURL {
    NSAssert(NO, @"Unimplemented");

    return nil;
}

@end
