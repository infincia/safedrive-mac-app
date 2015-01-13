
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSMKeychainItem.h"

static NSString *SDServiceName = @"safedrive.io";

static int SSHAskPassReturnValueFailure      = -1;
static int SSHAskPassReturnValueSuccess      = 0;
static int SSHAskPassReturnValueUserCanceled = 1;


void insert_test_data(NSString *accountName);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *keychainAccount = [[[NSProcessInfo processInfo] environment] objectForKey:@"SSH_ACCOUNT"];
        NSDictionary *attributes = @{ (__bridge id<NSCopying>)kSecAttrAccessGroup: SDServiceName };

        NSError *keychainError;
        MCSMKeychainItem *genericKeychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDServiceName
                                                                                                account:keychainAccount
                                                                                             attributes:attributes
                                                                                                  error:&keychainError];

        if (keychainError) {
            return SSHAskPassReturnValueFailure;
        }
        if(!genericKeychainItem) {
            return SSHAskPassReturnValueFailure;
        }
        NSString *password = genericKeychainItem.password;
        printf("%s", [password UTF8String]);
    }
    return SSHAskPassReturnValueSuccess;
}
