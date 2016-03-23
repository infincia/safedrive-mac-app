
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

@import Foundation;

@interface SDSystemAPI : NSObject

@property (nonatomic, readonly) NSString * _Nonnull currentVolumeName;
@property (nonatomic) BOOL mountAtLaunch;

+(SDSystemAPI * _Nonnull)sharedAPI;

-(NSString * _Nullable)machineSerialNumber;

-(NSString * _Nullable)en0MAC;

-(NSString * _Nullable)currentOSVersion;

-(NSDictionary * _Nullable)detailsForMount:(NSURL * _Nonnull)mountURL;

-(BOOL)checkForMountedVolume:(NSURL * _Nonnull)mountURL;

-(void)checkForMountedVolume:(NSURL * _Nonnull)mountURL withTimeout:(NSTimeInterval)timeout success:(SDSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)ejectMount:(NSURL * _Nonnull)mountURL success:(SDSuccessBlock _Nonnull)success failure:(SDFailureBlock _Nonnull)failure;

-(BOOL)autostart;

-(NSError * _Nullable)enableAutostart;

-(NSError * _Nullable)disableAutostart;

-(NSDictionary<NSString *, NSString *>* _Nullable)retrieveCredentialsFromKeychainForService:(NSString * _Nonnull)service;

-(NSError * _Nullable)insertCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account password:(NSString * _Nonnull)password;

-(NSError * _Nullable)removeCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account;

-(NSError * _Nullable)removeCredentialsInKeychainForService:(NSString * _Nonnull)service;

@end
