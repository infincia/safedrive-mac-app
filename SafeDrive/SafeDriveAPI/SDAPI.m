
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAPI.h"
#import "SDSystemAPI.h"
#import <AFNetworking/AFHTTPSessionManager.h>
#import <AFNetworking/AFNetworkReachabilityManager.h>


#import "HKTHashProvider.h"

@interface SDAPI ()
@property (nonatomic, readonly) AFNetworkReachabilityManager *reachabilityManager;
@property (nonatomic, readonly) AFHTTPSessionManager *apiManager;

@property SDSystemAPI *sharedSystemAPI;
@property NSURL *baseURL;
@end

@implementation SDAPI

- (instancetype)init {
    self = [super init];
    if (self) {
        
        self.sharedSystemAPI = [SDSystemAPI sharedAPI];
        


        _reachabilityManager = [AFNetworkReachabilityManager managerForDomain:SDAPIDomainTesting];

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
        [_reachabilityManager startMonitoring];
        
        self.baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/1/", SDAPIDomainTesting]];

        _apiManager = [[AFHTTPSessionManager alloc] initWithBaseURL:self.baseURL];
        self.apiManager.requestSerializer = [[AFJSONRequestSerializer alloc] init];
        [self.apiManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self.apiManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
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

-(void)setSessionToken:(NSString *)sessionToken {
    _privateSessionToken = sessionToken;
    [self.apiManager.requestSerializer setValue:_privateSessionToken forHTTPHeaderField:@"SD-Auth-Token"];
}

-(NSString *)sessionToken {
    NSDictionary *session = [self.sharedSystemAPI retrieveCredentialsFromKeychainForService:SDSessionServiceName];
    if (session) {
        [self.apiManager.requestSerializer setValue:session[@"password"] forHTTPHeaderField:@"SD-Auth-Token"];
        return session[@"password"];
    }
    return _privateSessionToken;
}

#pragma mark - Telemetry

-(void)reportError:(NSError *)error forUser:(NSString *)user withLog:(NSArray *)log completionQueue:(dispatch_queue_t)queue success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {

    NSMutableDictionary *postParameters = [NSMutableDictionary new];
    
    NSString *os = [NSString stringWithFormat:@"OS X %@", self.sharedSystemAPI.currentOSVersion];
    [postParameters setObject:os forKey:@"operatingSystem"];
    
    NSString *clientVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    [postParameters setObject:clientVersion forKey:@"clientVersion"];
    

    if (user != nil && user.length > 0) {
        NSString *macAddress = [self.sharedSystemAPI en0MAC];
        
        NSString *machineIdConcatenation = [macAddress stringByAppendingString:user];
        
        NSString *identifier = [HKTHashProvider sha256:[machineIdConcatenation dataUsingEncoding:NSUTF8StringEncoding]];
        
        [postParameters setObject:identifier forKey:@"uniqueClientId"];
    }

    [postParameters setObject:error.localizedDescription forKey:@"description"];
    [postParameters setObject:error.domain forKey:@"context"];
    if (log.count > 0) {
        NSString *logString = [log description];
        [postParameters setObject:logString forKey:@"log"];
    }

    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:self.baseURL sessionConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    
    [manager setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [manager setRequestSerializer:[AFJSONRequestSerializer serializer]];
    [manager POST:@"error/log" parameters:postParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        successBlock();
    } failure:^(NSURLSessionTask *task, NSError *error) {
        
        NSLog(@"Error: %@", error);
        failureBlock(error);
    }];
}

#pragma mark - Client registration

-(void)registerMachineWithUser:(NSString *)user password:(NSString *)password success:(SDAPIClientRegistrationSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NSString *languageCode = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSString *os = [NSString stringWithFormat:@"OS X %@", self.sharedSystemAPI.currentOSVersion];
    NSString *macAddress = [self.sharedSystemAPI en0MAC];
    NSString *machineIdConcatenation = [macAddress stringByAppendingString:user];
    NSString *identifier = [HKTHashProvider sha256:[machineIdConcatenation dataUsingEncoding:NSUTF8StringEncoding]];

    
    NSDictionary *postParameters = @{ @"email": user, @"password": password, @"operatingSystem": os,   @"language": languageCode, @"uniqueClientId": identifier };
    
    [self.apiManager.requestSerializer setValue:nil forHTTPHeaderField:@"SD-Auth-Token"];

    [self.apiManager POST:@"client/register" parameters:postParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;
        SDLog(@"Client registered: %@", response);
        self.sessionToken = response[@"token"];
        [self.sharedSystemAPI insertCredentialsInKeychainForService:SDSessionServiceName account:user password:response[@"token"]];
        successBlock(self.sessionToken);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
             responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorAccountDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError); 
            return;       
        }
        failureBlock(error);
    }];
}

-(void)accountStatusForUser:(NSString *)user success:(SDAPIAccountStatusBlock)successBlock failure:(SDFailureBlock)failureBlock {
    [self.apiManager GET:@"account/status" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *accountStatus = (NSDictionary *)responseObject;
        successBlock(accountStatus);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
            responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorAccountDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError); 
            return;       
        }
        failureBlock(error);
    }];
}

-(void)accountDetailsForUser:(NSString *)user success:(SDAPIAccountDetailsBlock)successBlock failure:(SDFailureBlock)failureBlock {
    [self.apiManager GET:@"account/details" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *accountDetails = (NSDictionary *)responseObject;
        successBlock(accountDetails);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
            responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorAccountDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError); 
            return;       
        }
        failureBlock(error);
    }];
}

#pragma mark - Unused 

-(void)getHostFingerprintList:(SDAPIFingerprintListSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    [self.apiManager GET:@"fingerprints" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;
        successBlock(response[@"fingerprints"]);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        failureBlock(error);
    }];
}


-(void)apiStatus:( SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    [self.apiManager GET:@"status" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        successBlock();
    } failure:^(NSURLSessionTask *task, NSError *error) {
        failureBlock(error);
    }];
}

@end

#pragma mark -
#pragma mark - Sync folder handling

@implementation SDAPI (SyncFolderHandling)

-(void)createSyncFolder:(NSURL *)localFolder success:(SDAPICreateSyncFolderSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NSDictionary *postParameters = @{ @"folderName": localFolder.lastPathComponent, @"folderPath": localFolder.path };

    [self.apiManager POST:@"folder" parameters:postParameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *response = (NSDictionary *)responseObject;
        NSNumber *folderID = response[@"id"];
        successBlock(folderID);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
            responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorSyncDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError); 
            return;       
        }
        failureBlock(error);
    }];
}

-(void)readSyncFoldersWithSuccess:(SDAPIReadSyncFoldersSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    [self.apiManager GET:@"folder" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSArray *folders = (NSArray *)responseObject;
        successBlock(folders);
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
            responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorSyncDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError); 
            return;       
        }
        failureBlock(error);
    }];
}

-(void)deleteSyncFolder:(NSNumber *)folderId success:(SDAPIDeleteSyncFoldersSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NSDictionary *folderIds = @{ @"folderIds": folderId };
    
    AFHTTPRequestSerializer *ser = [AFHTTPRequestSerializer serializer];
    
    [ser setValue:self.sessionToken forHTTPHeaderField:@"SD-Auth-Token"];
    
    [ser setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc] initWithBaseURL:self.baseURL sessionConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
    
    [manager setResponseSerializer:[AFJSONResponseSerializer serializer]];
    [manager setRequestSerializer:ser];
    
    [manager DELETE:@"folder" parameters:folderIds success:^(NSURLSessionTask *task, id responseObject) {
        successBlock();
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
        
        NSDictionary *responseObject;
        if (errorData != nil) {
            responseObject = [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
        }
        
        if (responseObject) {
            NSString *message = responseObject[@"message"];
            NSError *responseError = [NSError errorWithDomain:SDErrorSyncDomain code:SDAPIErrorUnknown userInfo:@{NSLocalizedDescriptionKey:  message}];
            failureBlock(responseError);
            return;
        }
        failureBlock(error);
    }];
}

@end
