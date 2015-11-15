
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


static NSInteger kSDAppXPCProtocolVersion = 4;

@protocol SDAppXPCProtocol
-(void)sendMessage:(NSString *)message reply:(void (^)(NSString *reply))replyBlock;
-(void)ping:(void (^)(NSString *reply))replyBlock;
-(void)protocolVersion:(void (^)(NSNumber *version))replyBlock;

-(void)displayPreferencesWindow;
-(void)displayRestoreWindowForURLs:(NSArray *)urls;


@end