
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

static NSInteger kSDAppXPCProtocolVersion = 6;

@protocol SDAppXPCProtocol
-(void)sendMessage:(NSString * _Nonnull)message reply:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)ping:(void (^ _Nonnull)(NSString * _Nonnull reply))replyBlock;
-(void)protocolVersion:(void (^ _Nonnull)(NSNumber * _Nonnull version))replyBlock;

-(void)displayPreferencesWindow;
-(void)displayRestoreWindowForURLs:(NSArray * _Nonnull)urls;

@end