
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

@import Foundation;

@interface SDSystemAPI : NSObject

+(SDSystemAPI * _Nonnull)sharedAPI;

-(NSString * _Nullable)machineSerialNumber;

-(NSString * _Nullable)en0MAC;

-(NSString * _Nullable)currentOSVersion;

-(BOOL)autostart;

-(BOOL)enableAutostartWithError:(NSError * _Nullable * _Nullable)error;

-(BOOL)disableAutostartWithError:(NSError * _Nullable * _Nullable)error;

-(NSDictionary<NSString *, NSString *>* _Nullable)retrieveCredentialsFromKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nullable)account;

-(BOOL)insertCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account password:(NSString * _Nonnull)password error:(NSError * _Nullable * _Nullable)error;

-(BOOL)removeCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nullable)account error:(NSError * _Nullable * _Nullable)error;

@end
