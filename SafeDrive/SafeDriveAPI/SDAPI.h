
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDAPI : NSObject {
    NSString *_privateSessionToken;
}

@property (nonatomic, readonly) NSURL *sshURL;
@property (nonatomic) NSString *sessionToken;

+(SDAPI *)sharedAPI;

-(void)reportError:(NSError *)error forUser:(NSString *)user withLog:(NSArray *)log completionQueue:(dispatch_queue_t)queue success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)registerMachineWithUser:(NSString *)user password:(NSString *)password success:(SDAPIClientRegistrationSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)accountStatusForUser:(NSString *)user success:(SDAPIAccountStatusBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)accountDetailsForUser:(NSString *)user success:(SDAPIAccountDetailsBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)apiStatus:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

@end

@interface SDAPI (SyncFolderHandling)

-(void)createSyncFolder:(NSURL *)localFolder success:(SDAPICreateSyncFolderSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)readSyncFoldersWithSuccess:(SDAPIReadSyncFoldersSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

-(void)deleteSyncFolder:(NSNumber *)folderId success:(SDAPIDeleteSyncFoldersSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

@end
