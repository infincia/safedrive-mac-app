
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDMountController : NSObject

@property (getter=isMounted) BOOL mounted;
@property (getter=isMounting) BOOL mounting;
@property NSURL *mountURL;

+(SDMountController *)sharedAPI;

-(NSURL *)getMountURLForVolumeName:(NSString *)volumeName;

-(void)startMountTaskWithVolumeName:(NSString *)volumeName sshURL:(NSURL *)sshURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

-(void)unmountVolumeWithName:(NSString *)volumeName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

@end
