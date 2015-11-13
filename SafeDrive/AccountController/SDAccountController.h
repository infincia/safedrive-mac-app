
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SDAccountController : NSObject
@property enum SDAccountStatus accountStatus;

@property NSString *email;
@property NSString *password;

+(SDAccountController *)sharedAccountController;

@end
