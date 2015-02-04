
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <dispatch/dispatch.h>

#import "SDSystemAPI.h"
#import "NSBundle+LoginItem.h"

#import "MCSMKeychainItem.h"

@import AppKit;
@import DiskArbitration; // May be necessary if higher level APIs don't work out


@interface SDSystemAPI ()

@end

@implementation SDSystemAPI
@dynamic currentVolumeName;

- (instancetype)init {
    self = [super init];
    if (self) {
        //
    }
    return self;
}

- (void)dealloc {
    //never
}


#pragma mark
#pragma mark Public API

+(SDSystemAPI *)sharedAPI {
    static SDSystemAPI *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDSystemAPI alloc] init];
    });
    return localInstance;
}

-(NSString *)currentVolumeName {
    NSString *volumeName = [[NSUserDefaults standardUserDefaults] objectForKey:SDCurrentVolumeNameKey];
    if (!volumeName) {
        volumeName = SDDefaultVolumeName;
    }
    return volumeName;
}

-(NSDictionary *)detailsForMount:(NSURL *)mountURL {
    NSMutableDictionary *mountpointInfo = [NSMutableDictionary new];
    NSError *error;
    NSNumber *volumeSize;
    if([mountURL getResourceValue:&volumeSize forKey:NSURLVolumeTotalCapacityKey error:&error]) {
        mountpointInfo[NSURLVolumeTotalCapacityKey] = volumeSize;
    }
    else {
        /* Handle error */
    }
    NSNumber *volumeSpaceAvailable;
    if([mountURL getResourceValue:&volumeSpaceAvailable forKey:NSURLVolumeAvailableCapacityKey error:&error]) {
        mountpointInfo[NSURLVolumeAvailableCapacityKey] = volumeSpaceAvailable;
    }
    else {
        /* Handle error */
    }
    return mountpointInfo;
}


-(BOOL)checkForMountedVolume:(NSURL *)mountURL {
    NSArray *mountedVolumes = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeNameKey] options:NSVolumeEnumerationSkipHiddenVolumes];
    for (NSURL *mountedVolumeURL in mountedVolumes) {
        if ([mountedVolumeURL.path isEqualToString:mountURL.path]) {
            return YES;
        }
    }
    return NO;
}

-(void)checkForMountedVolume:(NSURL *)mountURL withTimeout:(NSTimeInterval)timeout success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock {
    NSAssert([NSThread currentThread] == [NSThread mainThread], @"Mount check called on background thread");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSInteger remainingTime = timeout; remainingTime > 0; remainingTime--) {
            if ([self checkForMountedVolume:mountURL]) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    successBlock();
                });
                return;
            }
            [NSThread sleepForTimeInterval:1];
        }
        NSError *volumeError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorTimeout userInfo:@{NSLocalizedDescriptionKey: @"Volume mount timeout"}];
        dispatch_sync(dispatch_get_main_queue(), ^{
            failureBlock(volumeError);
        });
    });
}




-(void)ejectMount:(NSURL *)mountURL success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock {
    NSError *error;
    BOOL ejectSuccess = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:mountURL error:&error];
    if (ejectSuccess && successBlock) successBlock();
    else {
        failureBlock(error);
    }
}

-(BOOL)autostart {
    return [[NSBundle mainBundle] isLoginItem];
}

-(NSError *)enableAutostart {
    NSError *loginItemError = nil;
    [[NSBundle mainBundle] addToLoginItems];
    if (!self.autostart) {
        loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Adding login item failed"}];
    }
    return loginItemError;
}

-(NSError *)disableAutostart {
    NSError *loginItemError = nil;
    [[NSBundle mainBundle] removeFromLoginItems];
    if (self.autostart) {
        loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Removing login item failed"}];
    }
    return loginItemError;
}

-(NSDictionary *)retrieveCredentialsFromKeychain {
    NSDictionary *credentials = nil;
    NSError *error;

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDServiceName
                                                                                        account:nil
                                                                                    attributes:nil
                                                                                         error:&error];
    if (error) {
        NSLog(@"Failure retrieving credentials: %@", error.localizedDescription);
    }
    else {
        credentials = @{@"account": keychainItem.account, @"password": keychainItem.password };
    }
    return credentials;
}

-(NSError *)insertCredentialsInKeychain:(NSString *)account password:(NSString *)password {

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDServiceName
                                                                                    account:nil
                                                                                 attributes:nil
                                                                                      error:NULL];
    if (keychainItem) {
        BOOL sameUser = [account isEqualToString:keychainItem.account];
        BOOL samePass = [password isEqualToString:keychainItem.password];
        /* don't do anything if credentials haven't changed */
        if (sameUser && samePass) return nil;
        NSError *keychainRemoveError;
        [keychainItem removeFromKeychainWithError:&keychainRemoveError];
        if (keychainRemoveError) {
            CFStringRef err = SecCopyErrorMessageString((OSStatus)keychainRemoveError.code, NULL);
            NSString *keychainErrorString = (id) CFBridgingRelease(err);
            NSLog(@"Keychain remove error: %@, query: %@", keychainErrorString, keychainRemoveError.userInfo[MCSMKeychainItemQueryKey]);
            return [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
;
        }
    }
    NSError *keychainInsertError;
    [MCSMGenericKeychainItem genericKeychainItemWithService:SDServiceName
                                                    account:account
                                                 attributes:nil
                                                   password:password
                                                      error:&keychainInsertError];
    if (keychainInsertError) {
        CFStringRef err = SecCopyErrorMessageString((OSStatus)keychainInsertError.code, NULL);
        NSString *keychainErrorString = (id) CFBridgingRelease(err);
        NSLog(@"Keychain insert credential error: %@, query: %@", keychainErrorString, keychainInsertError.userInfo[MCSMKeychainItemQueryKey]);
        return [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
;
    }
    return nil;
}


@end
