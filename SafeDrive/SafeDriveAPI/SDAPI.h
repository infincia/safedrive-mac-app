
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDAPI : NSObject

@property (nonatomic, readonly) NSURL *volumeURL;


+(SDAPI *)sharedAPI;

-(void)authenticateWithUser:(NSString *)user password:(NSString *)password success:(void (^)(void))successBlock failure:(void (^)(NSError *error))failureBlock;

-(void)volumeURLForUser:(NSString *)user password:(NSString *)password volume:(NSString *)volumeName success:(void (^)(NSURL *volumeURL))successBlock failure:(void (^)(NSError *error))failureBlock;

-(void)apiStatusWithSuccess:(void (^)(void))successBlock failure:(void (^)(NSError *error))failureBlock;


@end
