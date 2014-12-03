
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDMountController.h"

@interface SDMountController ()
@property NSTask *sshfsTask;
@end

@implementation SDMountController

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

+(SDMountController *)sharedAPI {
    static SDMountController *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDMountController alloc] init];
    });
    return localInstance;
}

-(void)mountVolumeAtURL:(NSURL *)mountURL withName:(NSString *)mountName username:(NSString *)username password:(NSString *)password success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
    NSAssert(NO, @"Unimplemented");

}

-(void)unmountVolumeWithName:(NSString *)mountName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
    NSAssert(NO, @"Unimplemented");
}

@end
