
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

@interface SDSystemAPI : NSObject

+(SDSystemAPI *)sharedAPI;

-(NSDictionary *)statusForMount:(NSURL *)mountURL;

@end
