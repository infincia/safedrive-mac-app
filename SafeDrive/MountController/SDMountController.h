
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDMountSuccessBlock)();
typedef void(^SDMountFailureBlock)(NSError *mountError);

typedef NS_ENUM(NSUInteger, SDMountErrorType) {
    SDMountErrorAuthorization
};

@interface SDMountController : NSObject

+(SDMountController *)sharedAPI;

-(void)mountVolumeWithName:(NSString *)mountName atURL:(NSURL *)mountURL username:(NSString *)username password:(NSString *)password success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

-(void)unmountVolumeWithName:(NSString *)mountName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock;

@end
