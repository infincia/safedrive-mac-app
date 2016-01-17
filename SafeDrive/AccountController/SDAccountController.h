
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SDAccountController : NSObject
@property enum SDAccountStatus accountStatus;

@property NSString *email;
@property NSString *internalUserName;
@property NSString *password;
@property NSString *remoteHost;
@property NSNumber *remotePort;

@property BOOL hasCredentials;
@property (getter=isSignedIn) BOOL signedIn;

+(SDAccountController *)sharedAccountController;

-(void)signInWithSuccess:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;
@end
