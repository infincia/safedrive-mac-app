
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDSystemSuccessBlock)();
typedef void(^SDSystemFailureBlock)(NSError *error);

@interface SDSystemAPI : NSObject

@property (readonly) NSString *currentVolumeName;

+(SDSystemAPI *)sharedAPI;

-(NSDictionary *)detailsForMount:(NSURL *)mountURL;

-(BOOL)checkForMountedVolume:(NSURL *)mountURL;

-(void)checkForMountedVolume:(NSURL *)mountURL withTimeout:(NSTimeInterval)timeout success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock;

-(void)ejectMount:(NSURL *)mountURL success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure;

-(BOOL)autostart;

-(NSError *)enableAutostart;

-(NSError *)disableAutostart;

-(NSDictionary *)retrieveCredentialsFromKeychain;

-(NSError *)insertCredentialsInKeychain:(NSString *)account password:(NSString *)password;

@end
