
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDSystemAPI : NSObject

@property (nonatomic, readonly) NSString *currentVolumeName;
@property (nonatomic) BOOL mountAtLaunch;

+(SDSystemAPI *)sharedAPI;

-(BOOL)isOSXFUSEInstalled;

-(BOOL)isSSHFSInstalled;

-(NSString *)machineSerialNumber;

-(NSString *)machineID;

-(NSString *)en0MAC;

-(NSString *)currentOSVersion;

-(NSDictionary *)detailsForMount:(NSURL *)mountURL;

-(BOOL)checkForMountedVolume:(NSURL *)mountURL;

-(void)checkForMountedVolume:(NSURL *)mountURL withTimeout:(NSTimeInterval)timeout success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)ejectMount:(NSURL *)mountURL success:(SDSuccessBlock)success failure:(SDFailureBlock)failure;

-(BOOL)autostart;

-(NSError *)enableAutostart;

-(NSError *)disableAutostart;

-(NSDictionary *)retrieveCredentialsFromKeychainForService:(NSString *)service;

-(NSError *)insertCredentialsInKeychainForService:(NSString *)service account:(NSString *)account password:(NSString *)password;

-(NSError *)removeCredentialsInKeychainForService:(NSString *)service account:(NSString *)account;

@end
