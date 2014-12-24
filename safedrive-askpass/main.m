
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSMKeychainItem.h"
#import "SDTestCredentials.h"

#define TEST_MODE

static NSString *SafeDriveServiceName = @"safedrive";

void insert_test_data(NSString *accountName);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *keychainAccount = [[[NSProcessInfo processInfo] environment] objectForKey:@"SSH_ACCOUNT"];

        #ifdef TEST_MODE
        NSLog(@"Test mode, inserting keychain data");
        MCSMKeychainItem *testKeychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SafeDriveServiceName
                                                                                               account:keychainAccount
                                                                                            attributes:nil
                                                                                                 error:NULL];
        if (testKeychainItem) [testKeychainItem removeFromKeychainWithError:NULL];
        insert_test_data(keychainAccount);
        #endif

        NSError *keychainError;
        MCSMKeychainItem *genericKeychainItem = [MCSMGenericKeychainItem genericKeychainItemForService:SafeDriveServiceName
                                                                                                   account:keychainAccount
                                                                                                attributes:nil
                                                                                                     error:&keychainError];

        if (keychainError) {
            NSLog(@"Keychain test data error: %@", keychainError.localizedDescription);
            return -1;
        }
        if(!genericKeychainItem) {
            NSLog(@"Failed to obtain password from keychain");
            return -1; // tells ssh there was a failure to obtain the password
        }
        NSString *password = genericKeychainItem.password;
        printf("%s", [password UTF8String]);
    }
    return 0;
}


void insert_test_data(NSString *accountName) {
    NSError *keychainError;
    [MCSMGenericKeychainItem genericKeychainItemWithService:SafeDriveServiceName
                                                    account:SDTestCredentialsUser
                                                 attributes:nil
                                                   password:SDTestCredentialsPassword
                                                      error:&keychainError];
    if (keychainError) {
        NSLog(@"Keychain test data error: %@", keychainError.localizedDescription);
    }
}