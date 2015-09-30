
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


#import "SDAppXPCDelegate.h"

@implementation SDAppXPCDelegate


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

-(void)displayRestoreWindowForURLs:(NSArray<NSURL*> *)urls {
    
}



@end
