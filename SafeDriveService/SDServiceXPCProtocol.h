
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


static NSInteger kSDServiceXPCProtocolVersion = 4;

@protocol SDServiceXPCProtocol
-(void)sendMessage:(NSString *)message reply:(void (^)(NSString *reply))replyBlock;
-(void)ping:(void (^)(NSString *reply))replyBlock;
-(void)protocolVersion:(void (^)(NSNumber *version))replyBlock;
-(void)sendAppEndpoint:(NSXPCListenerEndpoint *)endpoint reply:(void (^)(BOOL success))replyBlock;
-(void)getAppEndpoint:(void (^)(NSXPCListenerEndpoint *endpoint))replyBlock;

@end