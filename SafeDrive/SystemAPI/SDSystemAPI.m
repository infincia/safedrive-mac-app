
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSystemAPI.h"
#import "NSBundle+LoginItem.h"

#import "MCSMKeychainItem.h"

@import AppKit;
@import DiskArbitration; // May be necessary if higher level APIs don't work out


@interface SDSystemAPI ()

@end

@implementation SDSystemAPI

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

-(NSDictionary *)statusForMount:(NSURL *)mountURL {
    NSMutableDictionary *mountpointInfo = [NSMutableDictionary new];
    NSError *error;
    NSNumber *volumeSize;
    if([mountURL getResourceValue:&volumeSize forKey:NSURLVolumeTotalCapacityKey error:&error]) {
        NSLog(@"Volume size in bytes: %@", volumeSize);
        mountpointInfo[NSURLVolumeTotalCapacityKey] = volumeSize;
    }
    else {
        /* Handle error */
    }
    NSNumber *volumeSpaceAvailable;
    if([mountURL getResourceValue:&volumeSpaceAvailable forKey:NSURLVolumeAvailableCapacityKey error:&error]) {
        NSLog(@"Volume space available in bytes: %@", volumeSpaceAvailable);
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
    NSOperationQueue *opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperationWithBlock:^{
        for (NSInteger remainingTime = timeout; remainingTime > 0; remainingTime--) {
            if ([self checkForMountedVolume:mountURL]) {
                successBlock();
            }
            [NSThread sleepForTimeInterval:1];
        }
        NSError *volumeError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorTimeout userInfo:@{NSLocalizedDescriptionKey: @"Volume mount timeout"}];
        failureBlock(volumeError);
    }];
}




-(void)ejectMount:(NSURL *)mountURL success:(SDSystemSuccessBlock)successBlock failure:(SDSystemFailureBlock)failureBlock {
    NSError *error;
    BOOL ejectSuccess = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL:mountURL error:&error];
    if (ejectSuccess && successBlock) successBlock();
    else {
        failureBlock(error);
    }
}


-(void)registerStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure {
    [[NSBundle mainBundle] addToLoginItems];
    if ([[NSBundle mainBundle] isLoginItem]) {
        success();
    }
    else {
        NSError *loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Adding login item failed"}];
        failure(loginItemError);
    }
}

-(void)unregisterStartAtLogin:(id)sender success:(SDSystemSuccessBlock)success failure:(SDSystemFailureBlock)failure {
    [[NSBundle mainBundle] removeFromLoginItems];
    if ([[NSBundle mainBundle] isLoginItem]) {
        NSError *loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Removing login item failed"}];
        failure(loginItemError);
    }
    else {
        success();
    }
}

-(NSDictionary *)retrieveCredentialsFromKeychain {
    NSDictionary *credentials = nil;
    NSError *error;

    NSDictionary *attributes = @{ (__bridge id<NSCopying>)kSecAttrAccessGroup: SDServiceName };

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDServiceName
                                                                                        account:nil
                                                                                    attributes:attributes
                                                                                         error:&error];
    if (error) {
        NSLog(@"Failure retrieving credentials: %@", error.localizedDescription);
    }
    else {
        credentials = @{@"account": keychainItem.account, @"password": keychainItem.password };
    }
    return credentials;
}

-(BOOL)insertCredentialsInKeychain:(NSString *)account password:(NSString *)password {
    NSDictionary *attributes = @{ (__bridge id<NSCopying>)kSecAttrAccessGroup: SDServiceName };

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDServiceName
                                                                                    account:account
                                                                                 attributes:attributes
                                                                                      error:NULL];
    if (keychainItem) {
        NSError *keychainRemoveError;
        [keychainItem removeFromKeychainWithError:&keychainRemoveError];
        if (keychainRemoveError) {
            NSLog(@"Keychain remove error: %@", keychainRemoveError.localizedDescription);
            return NO;
        }
    }
    NSError *keychainInsertError;
    [MCSMGenericKeychainItem genericKeychainItemWithService:SDServiceName
                                                    account:account
                                                 attributes:attributes
                                                   password:password
                                                      error:&keychainInsertError];
    if (keychainInsertError) {
        NSLog(@"Keychain insert credential error: %@", keychainInsertError.localizedDescription);
        return NO;
    }
    return YES;
}


@end
