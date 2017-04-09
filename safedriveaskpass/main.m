
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sddk.h"

static int SSHAskPassReturnValueSuccess = 0;
static int SSHAskPassReturnValueFailure = 1;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *safedrive_storage_directory = [[[NSProcessInfo processInfo] environment] valueForKey:@"SAFEDRIVE_STORAGE_DIRECTORY"];
        if (safedrive_storage_directory == nil) {
            return SSHAskPassReturnValueFailure;
        }
        
        SDDKConfiguration sddk_config = SDDKConfigurationStaging;

        if ([[[NSProcessInfo processInfo] environment] valueForKey:@"SAFEDRIVE_ENVIRONMENT_PRODUCTION"] != nil) {
            sddk_config = SDDKConfigurationProduction;
        }

        SDDKError *error = NULL;
        SDDKState *state = NULL;
        
        if (sddk_initialize(NULL, NULL, NULL, sddk_config,  [safedrive_storage_directory UTF8String], &state, &error) != 0) {
            return SSHAskPassReturnValueFailure;
        }
        
        NSString *safedrive_currentuser_domain = [[[NSProcessInfo processInfo] environment] valueForKey:@"SAFEDRIVE_CURRENTUSER_DOMAIN"];
        if (safedrive_currentuser_domain == nil) {
            return SSHAskPassReturnValueFailure;
        }
        
        NSString *safedrive_account_domain = [[[NSProcessInfo processInfo] environment] valueForKey:@"SAFEDRIVE_ACCOUNT_DOMAIN"];
        
        if (safedrive_account_domain == nil) {
            return SSHAskPassReturnValueFailure;
        }
        
        char * current_user = NULL;
        SDDKError *current_user_error = NULL;
        
        if (0 != sddk_get_keychain_item("currentuser", [safedrive_currentuser_domain UTF8String], &current_user, &current_user_error)) {
            sddk_free_error(&current_user_error);
            return SSHAskPassReturnValueFailure;
        }
        
        char * current_password = NULL;
        SDDKError *current_password_error = NULL;
        if (0 != sddk_get_keychain_item(current_user, [safedrive_account_domain UTF8String], &current_password, &current_password_error)) {
            sddk_free_error(&current_password_error);
            return SSHAskPassReturnValueFailure;
        }
        
        printf("%s", current_password);

        sddk_free_string(&current_user);
        sddk_free_string(&current_password);
    }
    return SSHAskPassReturnValueSuccess;
}
