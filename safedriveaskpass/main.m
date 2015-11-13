
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSMKeychainItem.h"

static NSString *SDSSHServiceName = @"ssh.safedrive.io";

static int SSHAskPassReturnValueSuccess = 0;
static int SSHAskPassReturnValueFailure = 1;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *keychainAccount = [[[NSProcessInfo processInfo] environment] objectForKey:@"SSH_ACCOUNT"];

        NSError *keychainError;
        MCSMKeychainItem *genericKeychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SDSSHServiceName
                                                                                                account:keychainAccount
                                                                                             attributes:nil
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
