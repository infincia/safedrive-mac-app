
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDMountSuccessBlock)();
typedef void(^SDMountFailureBlock)(NSError *mountError);

@interface SDMountController : NSObject

+(SDMountController *)sharedAPI;

-(void)mountVolumeWithName:(NSString *)mountName atURL:(NSURL *)mountURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

-(void)unmountVolumeWithName:(NSString *)mountName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

@end
