
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDSystemSuccessBlock)();
typedef void(^SDSystemFailureBlock)(NSError *error);

@interface SDSystemAPI : NSObject

+(SDSystemAPI *)sharedAPI;

-(NSDictionary *)statusForMountpoint:(NSURL *)mountpointURL;

-(BOOL)checkForMountedVolume:(NSURL *)mountURL;

-(void)checkForMountedVolume:(NSURL *)mountURL withTimeout:(NSTimeInterval)timeout success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock;

-(void)ejectMountpoint:(NSURL *)mountpointURL success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure;

-(void)registerStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure;

-(void)unregisterStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure;

-(NSDictionary *)retrieveCredentialsFromKeychain;

-(BOOL)insertCredentialsInKeychain:(NSString *)account password:(NSString *)password;

@end
