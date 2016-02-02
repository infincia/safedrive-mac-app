
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountController.h"
#import "SDSystemAPI.h"
#import "SDAPI.h"
#import <dispatch/dispatch.h>
#import <Crashlytics/Crashlytics.h>


@interface SDAccountController ()
@property SDSystemAPI *sharedSystemAPI;
@property SDAPI *sharedSafedriveAPI;

-(void)accountLoop;
-(enum SDAccountStatus)accountStatusFromString:(NSString *)string;

@end

@implementation SDAccountController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.accountStatus = SDAccountStatusUnknown;
        self.sharedSystemAPI = [SDSystemAPI sharedAPI];
        self.sharedSafedriveAPI = [SDAPI sharedAPI];
        
        self.signedIn = NO;
        self.hasCredentials = NO;
        // grab credentials from keychain if they exist
        NSDictionary *credentials = [self.sharedSystemAPI retrieveCredentialsFromKeychainForService:SDServiceName];
        if (credentials) {
            self.email = credentials[@"account"];
            self.password = credentials[@"password"];
            [CrashlyticsKit setUserEmail:self.email];
            SDErrorHandlerSetUser(self.email);
            self.hasCredentials = YES;
        }
    }
    return self;
}

- (void)dealloc {
    //never
}

#pragma mark
#pragma mark Internal API

-(enum SDAccountStatus)accountStatusFromString:(NSString *)string {
    if ([string isEqualToString:@"active"]) {
        return SDAccountStatusActive;
    }
    else if ([string isEqualToString:@"trial"]) {
        return SDAccountStatusTrial;
    }
    else if ([string isEqualToString:@"trial-expired"]) {
        return SDAccountStatusTrialExpired;
    }
    else if ([string isEqualToString:@"expired"]) {
        return SDAccountStatusExpired;
    }
    else if ([string isEqualToString:@"locked"]) {
        return SDAccountStatusLocked;
    }
    else if ([string isEqualToString:@"reset-password"]) {
        return SDAccountStatusResetPassword;
    }
    else if ([string isEqualToString:@"pending-creation"]) {
        return SDAccountStatusPendingCreation;
    }    
    return SDAccountStatusUnknown;
}

-(void)accountLoop {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (;;) {
            if (!self.sharedSafedriveAPI.sessionToken) {
                [NSThread sleepForTimeInterval:1];
                continue;
            }
            [self.sharedSafedriveAPI accountStatusForUser:self.email success:^(NSDictionary *accountStatus) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDAccountStatusNotification object:accountStatus];
                });
                self.internalUserName = accountStatus[@"userName"];
                self.remoteHost = accountStatus[@"host"];
                self.remotePort = accountStatus[@"port"];
            } failure:^(NSError *apiError) {
#ifdef DEBUG
                SDLog(@"Account status retrieval failed: %@", apiError.localizedDescription);
#endif
                // don't report these for now, they're almost always going to be network failures
                // SDErrorHandlerReport(apiError);
            }];
            [self.sharedSafedriveAPI accountDetailsForUser:self.email success:^(NSDictionary *accountDetails) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDAccountDetailsNotification object:accountDetails];
                });
            } failure:^(NSError *apiError) {
#ifdef DEBUG
                SDLog(@"Account details retrieval failed: %@", apiError.localizedDescription);
#endif
                // don't report these for now, they're almost always going to be network failures
                // SDErrorHandlerReport(apiError);
            }];
            [NSThread sleepForTimeInterval:60 * 5]; // 5 minutes
        }
    });
}

#pragma mark
#pragma mark Public API

+(SDAccountController *)sharedAccountController {
    static SDAccountController *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDAccountController alloc] init];
    });
    return localInstance;
}

-(void)signInWithSuccess:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychainForService:SDServiceName account:self.email password:self.password];
    
    if (keychainError) {
        SDErrorHandlerReport(keychainError);
        failureBlock(keychainError);
        return;
    }
    
    [CrashlyticsKit setUserEmail:self.email];
    SDErrorHandlerSetUser(self.email);
    
    [self.sharedSafedriveAPI registerMachineWithUser:self.email password:self.password success:^(NSString *sessionToken) {
        [self.sharedSafedriveAPI accountStatusForUser:self.email success:^(NSDictionary *accountStatus) {
            SDLog(@"SafeDrive accountStatusForUser success in account controller");
            self.signedIn = YES;
            SDLog(@"Account status: %@", accountStatus);
            self.internalUserName = accountStatus[@"userName"];
            self.remoteHost = accountStatus[@"host"];
            self.remotePort = accountStatus[@"port"];
            
            NSError *keychainError = [self.sharedSystemAPI insertCredentialsInKeychainForService:SDSSHServiceName account:self.internalUserName password:self.password];
            if (keychainError) {
                SDErrorHandlerReport(keychainError);
                failureBlock(keychainError);
                return;
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:SDAccountSignInNotification object:nil];
            [self accountLoop];

            successBlock();
            
        } failure:^(NSError *apiError) {
            SDErrorHandlerReport(apiError);
            failureBlock(apiError);
        }];
    } failure:^(NSError *apiError) {
        SDErrorHandlerReport(apiError);
        failureBlock(apiError);
    }];
}

@end
