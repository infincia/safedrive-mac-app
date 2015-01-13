
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDAPI : NSObject

@property (nonatomic, readonly) NSURL *volumeURL;


+(SDAPI *)sharedAPI;

-(void)authenticateWithUser:(NSString *)email password:(NSString *)password success:(void (^)(NSURL *shareLocation))successBlock failure:(void (^)(NSError *error))failureBlock;

@end
