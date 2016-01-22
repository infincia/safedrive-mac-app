
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDSyncItem : NSObject <NSSecureCoding>
@property NSString *label;
@property BOOL isMachine;
@property NSURL *url;
@property NSInteger uniqueID;
@property (getter=isSyncing) BOOL syncing;

@property NSMutableArray<SDSyncItem*> *syncFolders;

+(instancetype)itemWithLabel:(NSString *)label localFolder:(NSURL *)url isMachine:(BOOL)isMachine uniqueID:(NSInteger)uniqueID;
-(void)appendSyncFolder:(SDSyncItem *)child;
-(void)removeSyncFolder:(SDSyncItem *)child;

-(instancetype)syncFolderForUniqueId:(NSInteger)uniqueID;
-(BOOL)hasConflictingFolderRegistered:(NSURL *)testFolder;

@end
