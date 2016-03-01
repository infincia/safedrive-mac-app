
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDAPI : NSObject {
    NSString *_privateSessionToken;
}

@property (nonatomic, readonly, nullable) NSURL *sshURL;
@property (nonatomic, nullable) NSString *sessionToken;

+(SDAPI * _Nonnull)sharedAPI;

-(void)reportError:(NSError * _Nonnull)error forUser:(NSString * _Nonnull)user withLog:(NSArray * _Nonnull)log completionQueue:(dispatch_queue_t _Nonnull)queue success:(SDSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)registerMachineWithUser:(NSString * _Nonnull)user password:(NSString * _Nonnull)password success:(SDAPIClientRegistrationSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)accountStatusForUser:(NSString * _Nonnull)user success:(SDAPIAccountStatusBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)accountDetailsForUser:(NSString * _Nonnull)user success:(SDAPIAccountDetailsBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)apiStatus:(SDSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

@end

@interface SDAPI (SyncFolderHandling)

-(void)createSyncFolder:(NSURL * _Nonnull)localFolder success:(SDAPICreateSyncFolderSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)readSyncFoldersWithSuccess:(SDAPIReadSyncFoldersSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

-(void)deleteSyncFolder:(NSNumber * _Nonnull)folderId success:(SDAPIDeleteSyncFoldersSuccessBlock _Nonnull)successBlock failure:(SDFailureBlock _Nonnull)failureBlock;

@end
