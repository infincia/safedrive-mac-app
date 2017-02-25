
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

-(BOOL)enableAutostartWithError:(NSError * _Nullable * _Nullable)error;

-(BOOL)disableAutostartWithError:(NSError * _Nullable * _Nullable)error;

-(NSDictionary<NSString *, NSString *>* _Nullable)retrieveCredentialsFromKeychainForService:(NSString * _Nonnull)service;

-(BOOL)insertCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account password:(NSString * _Nonnull)password error:(NSError * _Nullable * _Nullable)error;

-(BOOL)removeCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account error:(NSError * _Nullable * _Nullable)error;

-(BOOL)removeCredentialsInKeychainForService:(NSString * _Nonnull)service error:(NSError * _Nullable * _Nullable)error;

@end
