
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDAPISuccessBlock)();

typedef void(^SDAPIAuthenticationSuccessBlock)(NSString *sessionToken);
typedef void(^SDAPIVolumeLocationSuccessBlock)(NSURL *sshURL);
typedef void(^SDAPIFailureBlock)(NSError *apiError);

@interface SDAPI : NSObject

@property (nonatomic, readonly) NSURL *sshURL;
@property (nonatomic, readonly) NSString *sessionToken;

+(SDAPI *)sharedAPI;

-(void)authenticateUser:(NSString *)user password:(NSString *)password success:(SDAPIAuthenticationSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)volumeURLForUser:(NSString *)user sessionToken:(NSString *)token volume:(NSString *)volumeName success:(SDAPIVolumeLocationSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

@end
