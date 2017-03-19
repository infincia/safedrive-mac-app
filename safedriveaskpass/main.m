
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import <Foundation/Foundation.h>

static int SSHAskPassReturnValueSuccess = 0;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *sshPassword = [[[NSProcessInfo processInfo] environment] objectForKey:@"SSH_PASSWORD"];
        printf("%s", [sshPassword UTF8String]);
    }
    return SSHAskPassReturnValueSuccess;
}
