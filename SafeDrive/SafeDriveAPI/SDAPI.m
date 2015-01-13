
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAPI.h"
#import <AFNetworking/AFHTTPRequestOperationManager.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>

@interface SDAPI ()
@property (nonatomic, readonly) AFNetworkReachabilityManager *reachabilityManager;
@property (nonatomic, readonly) AFHTTPRequestOperationManager *apiManager;
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

        NSURL *apiURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", SDAPIDomain]];

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

-(void)authenticateWithUser:(NSString *)user password:(NSString *)password success:(void (^)(void))successBlock failure:(void (^)(NSError *error))failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"password": password };

    [self.apiManager POST:@"/user/authenticate" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)response;





    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //
    }];
}

-(void)volumeURLForUser:(NSString *)user password:(NSString *)password volume:(NSString *)volumeName success:(void (^)(NSURL *volumeURL))successBlock failure:(void (^)(NSError *error))failureBlock {
    NSDictionary *postParameters = @{@"user": user, @"password": password, @"volname": volumeName };

    [self.apiManager POST:@"/user/volume" parameters:postParameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *response = (NSDictionary *)response;


    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        //
    }];
}


@end
