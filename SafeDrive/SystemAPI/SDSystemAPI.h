
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDSystemSuccessBlock)();
typedef void(^SDSystemFailureBlock)(NSError *error);

@interface SDSystemAPI : NSObject

+(SDSystemAPI *)sharedAPI;

-(NSDictionary *)statusForMount:(NSURL *)mountURL;

@end
