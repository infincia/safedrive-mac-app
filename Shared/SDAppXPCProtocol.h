
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@class SDSyncItem;

static NSInteger kSDAppXPCProtocolVersion = 5;

@protocol SDAppXPCProtocol
-(void)sendMessage:(NSString * _Nonnull)message reply:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)ping:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)protocolVersion:(void (^ _Nonnull)(NSNumber * _Nonnull version))replyBlock;

-(void)displayPreferencesWindow;
-(void)displayRestoreWindowForURLs:(NSArray * _Nonnull)urls;

-(void)getSyncFoldersWithReply:(void (^ _Nonnull)(NSMutableArray<SDSyncItem*> * _Nonnull syncFolders))replyBlock;

@end