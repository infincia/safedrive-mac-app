
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef NS_ENUM(NSUInteger, SDAPIErrorType) {
    SDAPIErrorAuthorization
};

@interface SDAPI : NSObject

@property (nonatomic, readonly) NSURL *shareLocation;

+(SDAPI *)sharedAPI;

-(void)authenticateWithUser:(NSString *)email password:(NSString *)password success:(void (^)(NSURL *shareLocation))successBlock failure:(void (^)(NSError *error))failureBlock;

@end
