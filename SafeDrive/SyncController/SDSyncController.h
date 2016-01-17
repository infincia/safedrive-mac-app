
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDSyncController : NSObject

@property enum SDSyncState syncState;
@property (getter=isSyncing) BOOL syncing;

+(SDSyncController *)sharedAPI;

-(void)startSyncTaskWithLocalURL:(NSURL *)localURL serverURL:(NSURL *)serverURL restore:(BOOL)restore success:(SDSyncResultBlock)successBlock failure:(SDSyncResultBlock)failureBlock;

@end
