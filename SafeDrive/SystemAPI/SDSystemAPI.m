
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <dispatch/dispatch.h>
#include <IOKit/IOKitLib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#import "SDSystemAPI.h"
#import "NSBundle+LoginItem.h"
#import "HKTHashProvider.h"

#import "MCSMKeychainItem.h"

@import AppKit;
@import DiskArbitration; // May be necessary if higher level APIs don't work out


@interface SDSystemAPI ()

@end

@implementation SDSystemAPI
@dynamic currentVolumeName;
@dynamic mountAtLaunch;

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

#pragma mark - System information

- (NSString *)machineSerialNumber {
    NSString *serial = nil;
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0);
        if (serialNumberAsCFString) {
            serial = CFBridgingRelease(serialNumberAsCFString);
        }

        IOObjectRelease(platformExpert);
    }
    return serial;
}

-(NSString *)machineID {
    NSString *en0MAC = [self en0MAC];
    NSString *identifier = [HKTHashProvider sha256:[en0MAC dataUsingEncoding:NSUTF8StringEncoding]];
    return identifier;
}

-(NSString *)en0MAC {
	int	   mib[6];
    size_t len;
	char   *buf;
	unsigned char		*ptr;
	struct if_msghdr	*ifm;
	struct sockaddr_dl	*sdl;
    NSString *mac;

	mib[0] = CTL_NET;
	mib[1] = AF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_LINK;
	mib[4] = NET_RT_IFLIST;
	mib[5] = if_nametoindex("en0");

	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        return mac;
	}

	if ((buf = malloc(len)) == NULL) {
        return mac;
	}

	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
		free(buf);
        return mac;
	}

	ifm = (struct if_msghdr *)buf;
	sdl = (struct sockaddr_dl *)(ifm + 1);
	ptr = (unsigned char *)LLADDR(sdl);
    mac = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    return mac;
}

-(NSString *)currentOSVersion {
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];

    NSString *systemVersion = [systemVersionDictionary objectForKey:@"ProductVersion"];
    return systemVersion;
}

-(NSString *)currentVolumeName {
    NSString *volumeName = [[NSUserDefaults standardUserDefaults] objectForKey:SDCurrentVolumeNameKey];
    if (!volumeName) {
        volumeName = SDDefaultVolumeName;
    }
    return volumeName;
}

-(BOOL)mountAtLaunch {
    return [[NSUserDefaults standardUserDefaults] boolForKey:SDMountAtLaunchKey];
}

-(void)setMountAtLaunch:(BOOL)mountAtLaunch {
    [[NSUserDefaults standardUserDefaults] setBool:mountAtLaunch forKey:SDMountAtLaunchKey];
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

-(NSDictionary *)retrieveCredentialsFromKeychainForService:(NSString *)service {
    NSDictionary *credentials = nil;
    NSError *error;

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
                                                                                        account:nil
                                                                                    attributes:nil
                                                                                         error:&error];
    if (error) {
        NSLog(@"Failure retrieving %@ credentials: %@", service, error.localizedDescription);
    }
    else {
        credentials = @{@"account": keychainItem.account, @"password": keychainItem.password };
    }
    return credentials;
}

-(NSError *)insertCredentialsInKeychainForService:(NSString *)service account:(NSString *)account password:(NSString *)password {

    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
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
    [MCSMGenericKeychainItem genericKeychainItemWithService:service
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
