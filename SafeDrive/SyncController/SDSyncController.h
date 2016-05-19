
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

@import Foundation;

@interface SDSyncController : NSObject

@property NSInteger uniqueID;

-(void)stopSyncTask:(SDSuccessBlock)completion;
    
-(void)startSyncTaskWithLocalURL:(NSURL *)localURL serverURL:(NSURL *)serverURL password:(NSString *)password restore:(BOOL)restore progress:(SDSyncProgressBlock)progressBlock success:(SDSyncResultBlock)successBlock failure:(SDSyncResultBlock)failureBlock;


-(void)SFTPOperation:(SDSFTPOperation)op remoteDirectory:(NSURL *)serverURL password:(NSString *)password success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

@end
