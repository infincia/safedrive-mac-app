
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

@end
