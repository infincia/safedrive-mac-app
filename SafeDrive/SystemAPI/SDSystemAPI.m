
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
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

+(SDSystemAPI * _Nonnull)sharedAPI {
    static SDSystemAPI *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDSystemAPI alloc] init];
    });
    return localInstance;
}

#pragma mark - System information

- (NSString * _Nullable)machineSerialNumber {
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

-(NSString * _Nullable)en0MAC {
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
        return nil;
    }
    
    if ((buf = malloc(len)) == NULL) {
        return nil;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        free(buf);
        return nil;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    mac = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    return mac;
}

-(NSString * _Nullable)currentOSVersion {
    NSDictionary *systemVersionDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    
    NSString *systemVersion = [systemVersionDictionary objectForKey:@"ProductVersion"];
    return systemVersion;
}

-(BOOL)autostart {
    return [[NSBundle mainBundle] isLoginItem];
}

-(BOOL)enableAutostartWithError:(NSError * _Nullable * _Nullable)error {
    NSError *loginItemError = nil;
    [[NSBundle mainBundle] addToLoginItems];
    if (!self.autostart) {
        loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Adding login item failed"}];
        if (error != nil) {
            *error = loginItemError;
        }
        return false;
    }
    return true;
}

-(BOOL)disableAutostartWithError:(NSError * _Nullable * _Nullable)error  {
    NSError *loginItemError = nil;
    [[NSBundle mainBundle] removeFromLoginItems];
    if (self.autostart) {
        loginItemError = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveLoginItemFailed userInfo:@{NSLocalizedDescriptionKey: @"Removing login item failed"}];
        if (error != nil) {
            *error = loginItemError;
        }
        return false;
    }
    return true;
}

-(NSDictionary<NSString *, NSString *>* _Nullable)retrieveCredentialsFromKeychainForService:(NSString * _Nonnull)service {
    NSDictionary *credentials = nil;
    NSError *error;
    
    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
                                                                                    account:nil
                                                                                 attributes:nil
                                                                                      error:&error];
    if (error) {
        //SDLog(@"Failure retrieving %@ credentials: %@", service, error.localizedDescription);
    }
    else {
        credentials = @{@"account": keychainItem.account, @"password": keychainItem.password };
    }
    return credentials;
}

-(BOOL)insertCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account password:(NSString * _Nonnull)password error:(NSError * _Nullable * _Nullable)error {
    
    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
                                                                                    account:nil
                                                                                 attributes:nil
                                                                                      error:NULL];
    if (keychainItem) {
        BOOL sameUser = [account isEqualToString:keychainItem.account];
        BOOL samePass = [password isEqualToString:keychainItem.password];
        /* don't do anything if credentials haven't changed */
        if (sameUser && samePass) return true;
        NSError *keychainRemoveError;
        [keychainItem removeFromKeychainWithError:&keychainRemoveError];
        if (keychainRemoveError) {
            CFStringRef err = SecCopyErrorMessageString((OSStatus)keychainRemoveError.code, NULL);
            NSString *keychainErrorString = (id) CFBridgingRelease(err);
            NSLog(@"Keychain remove error: %@, query: %@", keychainErrorString, keychainRemoveError.userInfo[MCSMKeychainItemQueryKey]);
            *error = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
            return false;
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
        *error = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorAddKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
        return false;
    }
    
    return true;
}

-(BOOL)removeCredentialsInKeychainForService:(NSString * _Nonnull)service account:(NSString * _Nonnull)account error:(NSError * _Nullable * _Nullable)error {
    
    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
                                                                                    account:account
                                                                                 attributes:nil
                                                                                      error:NULL];
    NSError *keychainRemoveError;
    [keychainItem removeFromKeychainWithError:&keychainRemoveError];
    if (keychainRemoveError) {
        CFStringRef err = SecCopyErrorMessageString((OSStatus)keychainRemoveError.code, NULL);
        NSString *keychainErrorString = (id) CFBridgingRelease(err);
        NSLog(@"Keychain remove error: %@, query: %@", keychainErrorString, keychainRemoveError.userInfo[MCSMKeychainItemQueryKey]);
        *error = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
        return false;
    }
    
    return true;
}

-(BOOL)removeCredentialsInKeychainForService:(NSString * _Nonnull)service error:(NSError * _Nullable * _Nullable)error {
    
    MCSMKeychainItem *keychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:service
                                                                                    account:nil
                                                                                 attributes:nil
                                                                                      error:NULL];
    NSError *keychainRemoveError;
    [keychainItem removeFromKeychainWithError:&keychainRemoveError];
    if (keychainRemoveError) {
        CFStringRef err = SecCopyErrorMessageString((OSStatus)keychainRemoveError.code, NULL);
        NSString *keychainErrorString = (id) CFBridgingRelease(err);
        NSLog(@"Keychain remove error: %@, query: %@", keychainErrorString, keychainRemoveError.userInfo[MCSMKeychainItemQueryKey]);
        *error = [NSError errorWithDomain:SDErrorDomain code:SDSystemErrorRemoveKeychainItemFailed userInfo:@{NSLocalizedDescriptionKey: keychainErrorString}];
        return false;
    }
    
    return true;
}

@end
