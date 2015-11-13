
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

@import Foundation;

typedef void(^SDAPISuccessBlock)();
typedef void(^SDAPIFailureBlock)(NSError *apiError);

typedef void(^SDAPIClientRegistrationSuccessBlock)(NSString *sessionToken);
typedef void(^SDAPIAccountStatusBlock)(NSDictionary *accountStatus);
typedef void(^SDAPIAccountDetailsBlock)(NSDictionary *accountDetails);
typedef void(^SDAPIFingerprintListSuccessBlock)(NSDictionary *fingerprintPairs);

@interface SDAPI : NSObject {
    NSString *_privateSessionToken;
}

@property (nonatomic, readonly) NSURL *sshURL;
@property (nonatomic) NSString *sessionToken;

+(SDAPI *)sharedAPI;

-(void)registerMachineWithUser:(NSString *)user password:(NSString *)password success:(SDAPIClientRegistrationSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)accountStatusForUser:(NSString *)user success:(SDAPIAccountStatusBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)accountDetailsForUser:(NSString *)user success:(SDAPIAccountDetailsBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)apiStatus:(SDAPISuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

@end
