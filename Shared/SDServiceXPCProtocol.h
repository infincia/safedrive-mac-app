
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


static NSInteger kSDServiceXPCProtocolVersion = 4;

@protocol SDServiceXPCProtocol
-(void)sendMessage:(NSString * _Nonnull)message reply:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)ping:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)protocolVersion:(void (^ _Nonnull)(NSNumber * _Nonnull version))replyBlock;
-(void)sendAppEndpoint:(NSXPCListenerEndpoint * _Nonnull)endpoint reply:(void (^ _Nonnull)(BOOL success))replyBlock;
-(void)getAppEndpoint:(void (^ _Nonnull)(NSXPCListenerEndpoint * _Nonnull endpoint))replyBlock;

@end