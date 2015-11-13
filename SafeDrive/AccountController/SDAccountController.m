
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountController.h"
#import "SDSystemAPI.h"
#import "SDAPI.h"
#import <dispatch/dispatch.h>

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
        [self accountLoop];
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
            } failure:^(NSError *apiError) {
                //
            }];
            [self.sharedSafedriveAPI accountDetailsForUser:self.email success:^(NSDictionary *accountDetails) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDAccountDetailsNotification object:accountDetails];
                });
            } failure:^(NSError *apiError) {
                //
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


@end
