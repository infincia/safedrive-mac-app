
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


#import "SDAppXPCDelegate.h"

#import "SDSyncController.h"

#import "SDSyncItem.h"

@interface SDAppXPCDelegate ()
@property SDSyncController *syncController;
@end
@implementation SDAppXPCDelegate

-(instancetype)init {
    self = [super init];
    self.syncController = [SDSyncController sharedAPI];

    return self;
}



-(void)sendMessage:(NSString *)message reply:(void (^)(NSString *reply))replyBlock {
    
}

-(void)ping:(void (^)(NSString *reply))replyBlock {
    replyBlock(@"ack");
}

-(void)protocolVersion:(void (^)(NSNumber *version))replyBlock {
    replyBlock(@(kSDAppXPCProtocolVersion));
}

-(void)displayPreferencesWindow {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenPreferencesWindow object:nil];
}

-(void)displayRestoreWindowForURLs:(NSArray *)urls {
    [[NSNotificationCenter defaultCenter] postNotificationName:SDApplicationShouldOpenSyncWindow object:nil];

}

-(void)getSyncFoldersWithReply:(void (^)(NSMutableArray<SDSyncItem*> *syncFolders))replyBlock {
    replyBlock(self.syncController.mac.syncFolders);
}

@end
