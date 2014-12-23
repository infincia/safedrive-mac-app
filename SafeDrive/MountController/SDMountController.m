
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDMountController.h"
#import "SDSystemAPI.h"

@interface SDMountController ()
@property NSTask *sshfsTask;
@property SDSystemAPI *sharedSystemAPI;
@end

@implementation SDMountController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sharedSystemAPI = [SDSystemAPI sharedAPI];
    }
    return self;
}

- (void)dealloc {
    //never
}


#pragma mark
#pragma mark Public API

+(SDMountController *)sharedAPI {
    static SDMountController *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDMountController alloc] init];
    });
    return localInstance;
}

-(void)mountVolumeWithName:(NSString *)mountName atURL:(NSURL *)mountURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
}

-(void)unmountVolumeWithName:(NSString *)mountName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
    NSAssert(NO, @"Unimplemented");
}

@end
