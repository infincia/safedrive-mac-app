
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;
@class SDSyncItem;

@interface SDSyncController : NSObject

@property enum SDSyncState syncState;
@property (getter=isSyncing) BOOL syncing;

+(SDSyncController *)sharedAPI;

@property SDSyncItem *mac;

-(void)startSyncTaskWithLocalURL:(NSURL *)localURL serverURL:(NSURL *)serverURL password:(NSString *)password restore:(BOOL)restore success:(SDSyncResultBlock)successBlock failure:(SDSyncResultBlock)failureBlock;

@end
