
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAPI.h"
#import <AFNetworking/AFHTTPRequestOperationManager.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>

typedef void(^SDAPIAccountStatusBlock)(NSDictionary *accountStatus);
typedef void(^SDAPIAccountDetailsBlock)(NSDictionary *accountDetails);
typedef void(^SDAPIFingerprintListSuccessBlock)(NSString *fingerprintList);

@interface SDAPI ()
@property (nonatomic, readonly) AFNetworkReachabilityManager *reachabilityManager;
@property (nonatomic, readonly) AFHTTPRequestOperationManager *apiManager;

-(void)accountStatusForUser:(NSString *)user sessionToken:(NSString *)token success:(SDAPIAccountStatusBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)accountDetailsForUser:(NSString *)user sessionToken:(NSString *)token success:(SDAPIAccountDetailsBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;

-(void)apiStatus:(SDAPISuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock;


@end

@implementation SDAPI

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"Creating SDAPI with base URL: %@", SDAPIDomain);

        _reachabilityManager = [AFNetworkReachabilityManager managerForDomain:SDAPIDomain];

        [self.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            switch (status) {
                case AFNetworkReachabilityStatusUnknown: {
                    //
                    break;
                }
                case AFNetworkReachabilityStatusNotReachable: {
                    //
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWWAN: {
                    //
                    break;
                }
                case AFNetworkReachabilityStatusReachableViaWiFi: {
                    //
                    break;
                }
                default: {
                    //
                    break;
                }
            }
        }];

        NSURL *apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/sd/a/", SDAPIDomain]];

        _apiManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:apiURL];
        self.apiManager.requestSerializer = [[AFHTTPRequestSerializer alloc] init];
        self.apiManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
    }
    return self;
}

- (void)dealloc {
    // never
}





# pragma mark
# pragma mark Public API

+(SDAPI *)sharedAPI {
    static SDAPI *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDAPI alloc] init];
    });
    return localInstance;
}

-(void)authenticateUser:(NSString *)user password:(NSString *)password success:(SDAPIAuthenticationSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"password": password };

    [self.apiManager POST:@"/user/authenticate" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;

    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}


-(void)volumeURLForUser:(NSString *)user sessionToken:(NSString *)token volume:(NSString *)volumeName success:(SDAPIVolumeLocationSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"session": token, @"volname": volumeName };

    [self.apiManager POST:@"/user/volume" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;


    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}





#pragma mark - Post phase 1 

-(void)accountStatusForUser:(NSString *)user sessionToken:(NSString *)token success:(SDAPIAccountStatusBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"session": token };

    [self.apiManager POST:@"accountStatus" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *accountStatus = (NSDictionary *)responseObject;
        successBlock(accountStatus);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}

-(void)accountDetailsForUser:(NSString *)user sessionToken:(NSString *)token success:(SDAPIAccountDetailsBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"session": token };

    [self.apiManager POST:@"accountDetails" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *accountDetails = (NSDictionary *)responseObject;
        successBlock(accountDetails);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {
    [self.apiManager GET:@"/fingerprints" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;


    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}


-(void)apiStatus:(SDAPISuccessBlock)successBlock failure:(SDAPIFailureBlock)failureBlock {

    [self.apiManager GET:@"/status" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;


    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(error);
    }];
}

@end
