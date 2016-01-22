
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@class SDSyncItem;

static NSInteger kSDAppXPCProtocolVersion = 5;

@protocol SDAppXPCProtocol
-(void)sendMessage:(NSString *)message reply:(void (^)(NSString *reply))replyBlock;
-(void)ping:(void (^)(NSString *reply))replyBlock;
-(void)protocolVersion:(void (^)(NSNumber *version))replyBlock;

-(void)displayPreferencesWindow;
-(void)displayRestoreWindowForURLs:(NSArray *)urls;

-(void)getSyncFoldersWithReply:(void (^)(NSMutableArray<SDSyncItem*> *syncFolders))replyBlock;

@end