
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDMountController.h"
#import "SDSystemAPI.h"
#import <dispatch/dispatch.h>

@interface SDMountController ()

@property NSTask *sshfsTask;
@property SDSystemAPI *sharedSystemAPI;

-(NSURL *)mountURLForVolumeName:(NSString *)volumeName;
-(void)mountCheckLoop;

@end

@implementation SDMountController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.mountState = SDMountStateUnmounted;
        self.sharedSystemAPI = [SDSystemAPI sharedAPI];
        [self mountCheckLoop];
    }
    return self;
}

- (void)dealloc {
    //never
}


#pragma mark
#pragma mark Public API

+(SDMountController *)sharedAPI {
    static SDMountController *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDMountController alloc] init];
    });
    return localInstance;
}

-(void)startMountTaskWithVolumeName:(NSString *)volumeName sshURL:(NSURL *)sshURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {

    NSURL *mountURL = [self mountURLForVolumeName:volumeName];

    if (self.mountState == SDMountStateMounted) {
        NSError *mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAlreadyMounted userInfo:@{NSLocalizedDescriptionKey: @"Volume already mounted"}];
        failureBlock(mountURL, mountError);
        return;
    }

    
#pragma mark - Create the mount path directory if it doesn't exist


    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *createError;
    BOOL createSuccess = [fileManager createDirectoryAtURL:mountURL withIntermediateDirectories:YES attributes:nil error:&createError];
    if (!createSuccess) {
        failureBlock(mountURL, createError);
        return;
    }



#pragma mark - Retrieve necessary parameters from ssh url

    NSString *host = [sshURL host];
    NSNumber *port = [sshURL port];
    NSString *user = [sshURL user];
    NSString *serverPath = [sshURL path];
    NSLog(@"Mounting ssh URL: %@", sshURL);




#pragma mark - Create the subprocess to be configured below

    self.sshfsTask = [[NSTask alloc] init];

    [self.sshfsTask setLaunchPath:@"/usr/local/bin/sshfs"];





#pragma mark - Set custom environment variables for sshfs subprocess

    NSMutableDictionary *sshfsEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    /* path of our custom askpass helper so ssh can use it */
    NSString *safeDriveAskpassPath;

#ifdef TEST_MODE
    /*
        Point sshfs/ssh directly at the askpass binary in the compiled products directory
        
        This is needed as the alternative relative path based on the bundle does
        not work for testing purposes, as there is no bundle

    */
    NSLog(@"Using test mode askpass");
    NSString *debugPath = sshfsEnvironment[@"__XCODE_BUILT_PRODUCTS_DIR_PATHS"];
    NSURL *debugProductsURL = [NSURL fileURLWithFileSystemRepresentation:[debugPath UTF8String] isDirectory:YES relativeToURL:nil];
    NSURL *debugAskpassURL = [NSURL fileURLWithFileSystemRepresentation:"safedriveaskpass\0" isDirectory:NO relativeToURL:debugProductsURL];
    safeDriveAskpassPath = [debugAskpassURL path];
#else
    NSLog(@"Using bundled askpass");
    safeDriveAskpassPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"safedriveaskpass"];
#endif

    NSLog(@"Askpass path: %@", safeDriveAskpassPath);


    if (safeDriveAskpassPath != nil) {
        [sshfsEnvironment setObject:safeDriveAskpassPath forKey:@"SSH_ASKPASS"];
    }
    else {
        NSError *askpassError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAskpassMissing userInfo:@{NSLocalizedDescriptionKey: @"Askpass helper missing"}];
        failureBlock(mountURL, askpassError);
        return;
    }

    /* pass the account name to the safedriveaskpass environment */
    [sshfsEnvironment setObject:user forKey:@"SSH_ACCOUNT"];

    /*
        remove any existing SSH agent socket in the subprocess environment so we
        have full control over auth behavior
    */
    [sshfsEnvironment removeObjectForKey:@"SSH_AUTH_SOCK"];

    NSLog(@"Subprocess environment: %@", sshfsEnvironment);
    self.sshfsTask.environment = sshfsEnvironment;



#pragma mark - Set SSHFS subprocess arguments

    NSMutableArray *taskArguments = [NSMutableArray new];

    /* server connection */
    [taskArguments addObject:[NSString stringWithFormat:@"%@@%@:%@", user, host, serverPath]];

    /* mount location */
    [taskArguments addObject:mountURL.path];

    /* basic sshfs options */
    [taskArguments addObject:@"-oauto_cache"];
    [taskArguments addObject:@"-oreconnect"];
    [taskArguments addObject:@"-odefer_permissions"];
    [taskArguments addObject:@"-onoappledouble"];
    [taskArguments addObject:@"-onegative_vncache"];
    [taskArguments addObject:@"-oNumberOfPasswordPrompts=1"];

    /* 
        This shouldn't be necessary and I don't like it, but it'll work for 
        testing purposes until we can implement a UI and code for displaying
        server fingerprints and allowing users to check and accept them or use
        the bundled known_hosts file to preapprove server fingerprints 

    [taskArguments addObject:@"-oCheckHostIP=no"];
    [taskArguments addObject:@"-oStrictHostKeyChecking=no"];
    
    */

    /* 
        Use a bundled known_hosts file as static root of trust.
        
        This serves two purposes:
        
            1. Users never have to click through fingerprint verification
               prompts, or manually verify the fingerprint (most people won't).
               We don't currently have code for scripting that part of an initial
               ssh connection anyway, and it's not clear if we can even get sshfs 
               to put ssh in the right mode to print the fingerprint prompt on 
               stdout while running as a background process using SSH_ASKPASS 
               for authentication.
               
            2. Users are never going to be subject to man-in-the-middle attacks
               as the fingerprint is preconfigured in the app and
    */
    NSString *knownHostsFile = [[NSBundle mainBundle] pathForResource:@"known_hosts" ofType:nil];
    NSLog(@"Known hosts file: %@", knownHostsFile);
    [taskArguments addObject:[NSString stringWithFormat:@"-oUserKnownHostsFile=%@", knownHostsFile]];


    #ifdef TEST_MODE
    /* debug output from sshfs, this will cause stderr to go crazy, but may be
       necessary to properly parse fingerprint messages and host key verification
       prompts
    */
    //[taskArguments addObject:@"-d"];
    //[taskArguments addObject:@"-odebug"];
    #endif

    /* custom volume name */
    [taskArguments addObject:[NSString stringWithFormat:@"-ovolname=%@", volumeName]];

    /* custom port if needed */
    [taskArguments addObject:[NSString stringWithFormat:@"-p%@", port]];

    [self.sshfsTask setArguments:taskArguments];


#pragma mark - Set asynchronous block to handle subprocess stderr and stdout

    NSPipe *outputPipe = [NSPipe pipe];
    NSFileHandle *outputPipeHandle = [outputPipe fileHandleForReading];
    outputPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *outputString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        NSLog(@"SSHFS Task output: %@", outputString);

        NSError *mountError;
        if ([outputString rangeOfString:@"No such file or directory"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorMountFailed userInfo:@{NSLocalizedDescriptionKey: @"Server could not find that volume name"}];
            failureBlock(mountURL, mountError);
        }
        else if ([outputString rangeOfString:@"Permission denied"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Permission denied"}];
            failureBlock(mountURL, mountError);
        }
        else if ([outputString rangeOfString:@"is itself on a OSXFUSE volume"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAlreadyMounted userInfo:@{NSLocalizedDescriptionKey: @"Volume already mounted"}];
            /* 
                no need to run the successblock again since the volume is already mounted

                this is unlikely to happen in practice, we shouldn't even get to this
                point if the mount status code is reacting quickly

                this case may occur if the SafeDrive app quits/crashes but the sshfs process 
                remains running and mounted. We'll deal with that at startup time
                since we'll be constantly watching for mount/unmount anyway
            */
            //successBlock();
        }
        else if ([outputString rangeOfString:@"Error resolving hostname"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorMountFailed userInfo:@{NSLocalizedDescriptionKey: @"Error resolving hostname, contact support"}];
            failureBlock(mountURL, mountError);
        }
        else if ([outputString rangeOfString:@"remote host has disconnected"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorMountFailed userInfo:@{NSLocalizedDescriptionKey: @"Mount failed, check username and password"}];
            failureBlock(mountURL, mountError);
        }
        else if ([outputString rangeOfString:@"REMOTE HOST IDENTIFICATION HAS CHANGED"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorHostFingerprintChanged userInfo:@{NSLocalizedDescriptionKey: @"Warning: server fingerprint changed!"}];
            failureBlock(mountURL, mountError);
        }
        else if ([outputString rangeOfString:@"Host key verification failed"].length > 0) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorHostKeyVerificationFailed userInfo:@{NSLocalizedDescriptionKey: @"Warning: server key verification failed!"}];
            failureBlock(mountURL, mountError);
        }
        else {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorUnknown userInfo:@{NSLocalizedDescriptionKey: outputString}];
            /*
                for the moment we don't want to call the failure block here, as 
                not everything that comes through stderr indicates a mount 
                failure.

                testing is required to discover and handle the stderr output that 
                we actually need to handle and ignore the rest.

            */
            // failureBlock(mountURL, mountError);
        }
        if (mountError) {
            NSLog(@"SSHFS Task error: %lu, %@", mountError.code, mountError.localizedDescription);
        }
    };
    [self.sshfsTask setStandardError:outputPipe];
    [self.sshfsTask setStandardOutput:outputPipe];




#pragma mark - Set asynchronous block to handle subprocess termination


    /* 
        clear the read and write blocks once the subprocess terminates, and then
        call the success block if no error occurred.
        
    */
    __weak SDMountController *weakSelf = self;
    [self.sshfsTask setTerminationHandler:^(NSTask *task) {
        [task.standardOutput fileHandleForReading].readabilityHandler = nil;
        [task.standardError fileHandleForReading].readabilityHandler = nil;
        if (task.terminationStatus == 0) {
            NSLog(@"Task exited cleanly, running successBlock");
            weakSelf.mountURL = mountURL;
            successBlock(mountURL, nil);
        }
    }];





#pragma mark - Launch subprocess and return


    NSLog(@"Launching SSHFS with arguments: %@", taskArguments);
    [self.sshfsTask launch];
}

-(void)unmountVolumeWithName:(NSString *)volumeName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
    NSURL *mountURL = [self mountURLForVolumeName:volumeName];

    [self.sharedSystemAPI ejectMount:mountURL success:^{
        successBlock(mountURL, nil);
    } failure:^(NSError *error) {
        failureBlock(mountURL, error);
    }];
}

#pragma mark - Internal API

-(NSURL *)mountURLForVolumeName:(NSString *)volumeName {
    NSURL *volumesDirectoryURL = [NSURL fileURLWithFileSystemRepresentation:"/Volumes\0" isDirectory:YES relativeToURL:nil];
    NSURL *mountURL = [NSURL fileURLWithFileSystemRepresentation:[volumeName UTF8String] isDirectory:YES relativeToURL:volumesDirectoryURL];
    return mountURL;
}

-(void)mountCheckLoop {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (;;) {
            NSString *volumeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"volumeName"];
            if (volumeName) {
                NSURL *mountURL = [self mountURLForVolumeName:volumeName];
                BOOL mounted = [self.sharedSystemAPI checkForMountedVolume:mountURL];
                self.mountState = ( mounted ? SDMountStateMounted : SDMountStateUnmounted);
            }
            NSLog(@"Mount state: %lu", self.mountState);
            switch (self.mountState) {
                case SDMountStateMounted: {
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDMountStateMountedNotification object:nil];
                    break;
                }
                case SDMountStateUnmounted: {
                    [[NSNotificationCenter defaultCenter] postNotificationName:SDMountStateUnmountedNotification object:nil];
                    break;
                }
                case SDMountStateUnknown: {
                    //
                }
                default: {
                    break;
                }
            }
            [NSThread sleepForTimeInterval:1];
        }
    });
}

@end
