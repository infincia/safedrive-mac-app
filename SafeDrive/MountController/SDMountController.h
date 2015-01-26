
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDMountSuccessBlock)(NSURL *mountURL, NSError *mountError);
typedef void(^SDMountFailureBlock)(NSURL *mountURL, NSError *mountError);

@interface SDMountController : NSObject

@property enum SDMountState mountState;
@property NSURL *mountURL;

+(SDMountController *)sharedAPI;

-(void)startMountTaskWithVolumeName:(NSString *)volumeName sshURL:(NSURL *)sshURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

-(void)unmountVolumeWithName:(NSString *)volumeName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

@end
