
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

-(void)mountVolumeWithName:(NSString *)mountName atURL:(NSURL *)mountURL success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {

    NSURL *volumesDirectoryURL = [NSURL fileURLWithFileSystemRepresentation:"/Volumes\0" isDirectory:YES relativeToURL:nil];
    self.localMountURL = [NSURL fileURLWithFileSystemRepresentation:[mountName UTF8String] isDirectory:YES relativeToURL:volumesDirectoryURL];

#pragma mark - Create directory in /Volumes if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *createError;
    BOOL createSuccess = [fileManager createDirectoryAtURL:self.localMountURL withIntermediateDirectories:YES attributes:nil error:&createError];
    if (!createSuccess) {
        failureBlock(createError);
        return;
    }

#pragma mark - Retrieve necessary parameters from ssh url

    NSString *host = [mountURL host];
    NSNumber *port = [mountURL port];
    NSString *user = [mountURL user];
    NSString *volumePath = [mountURL path];






    self.sshfsTask = [[NSTask alloc] init];



#pragma mark - Set asynchronous blocks to handle subprocess stdout/stderr output

    // new pipe and handler for stdout
    NSPipe *stdoutPipe = [NSPipe pipe];
    NSFileHandle *stdoutPipeHandle = [stdoutPipe fileHandleForReading];
    stdoutPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *stdoutString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        NSLog(@"Stdout: %@", stdoutString);
    };
    [self.sshfsTask setStandardOutput:stdoutPipe];


    // new pipe and handler for stderr
    NSPipe *stderrPipe = [NSPipe pipe];
    NSFileHandle *stderrPipeHandle = [stderrPipe fileHandleForReading];
    stderrPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *stderrString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];

        NSError *mountError;
        if ([stderrString containsString:@"No such file or directory"]) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorMountFailed userInfo:@{@"error": stderrString}];
            failureBlock(mountError);
        }
        else if ([stderrString containsString:@"Permission denied"]) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAuthorization userInfo:@{@"error": stderrString}];
            failureBlock(mountError);
        }
        else if ([stderrString containsString:[NSString stringWithFormat:@"mount point %@ is itself on a OSXFUSE volume", self.localMountURL.path]]) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAlreadyMounted userInfo:@{@"error": stderrString}];
            //successBlock(); // no need to run the successblock again since the volume is already mounted
            // this case may occur if the SafeDrive app quits/crashes but the sshfs process remains running and mounted
        }
        else if ([stderrString containsString:@"remote host has disconnected"]) {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorMountFailed userInfo:@{@"error": stderrString}];
            failureBlock(mountError);
        }
        else {
            mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorUnknown userInfo:@{@"error": stderrString}];
            failureBlock(mountError);
        }
    };
    [self.sshfsTask setStandardError:stderrPipe];


#pragma mark - Set asynchronous blocks to handle subprocess termination


    // clear the old read and write blocks if the task terminates
    [self.sshfsTask setTerminationHandler:^(NSTask *task) {
        [task.standardOutput fileHandleForReading].readabilityHandler = nil;
        [task.standardError fileHandleForReading].readabilityHandler = nil;
        //NSError *terminationError = [NSError errorWithDomain:SDErrorDomain code:task.terminationReason userInfo:nil];
        //[[NSNotificationCenter defaultCenter] postNotificationName:SDMountSubprocessDidTerminateNotification object:terminationError];
    }];


#pragma mark - Set custom environment variables for sshfs subprocess

    NSMutableDictionary *sshfsEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    // path of our custom askpass helper so ssh can use it
    NSString *safeDriveAskpassPath;

#ifdef TEST_MODE
    NSString *debugPath = sshfsEnvironment[@"__XCODE_BUILT_PRODUCTS_DIR_PATHS"];
    NSURL *debugProductsURL = [NSURL fileURLWithFileSystemRepresentation:[debugPath UTF8String] isDirectory:YES relativeToURL:nil];
    NSURL *debugAskpassURL = [NSURL fileURLWithFileSystemRepresentation:"safedriveaskpass\0" isDirectory:NO relativeToURL:debugProductsURL];
    safeDriveAskpassPath = [debugAskpassURL path];
#else
    safeDriveAskpassPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"safedriveaskpass"];
#endif
    //NSLog(@"Askpass path: %@", safeDriveAskpassPath);
    if (safeDriveAskpassPath != nil) {
        [sshfsEnvironment setObject:safeDriveAskpassPath forKey:@"SSH_ASKPASS"];
    }
    else {
        NSError *askpassError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorAskpassMissing userInfo:@{@"error": @"Askpass helper missing"}];
        failureBlock(askpassError);
    }
    // pass the account name to the ssh environment so our safedrive-askpass helper can use it
    [sshfsEnvironment setObject:user forKey:@"SSH_ACCOUNT"];
    [sshfsEnvironment removeObjectForKey:@"SSH_AUTH_SOCK"];

    //NSLog(@"Subprocess environment: %@", sshfsEnvironment);
    self.sshfsTask.environment = sshfsEnvironment;



#pragma mark - Set SSHFS arguments



    NSMutableArray *taskArguments = [NSMutableArray new];

    // don't let sshfs background itself
    //[taskArguments addObject:@"-f"];



    // server connection
    [taskArguments addObject:[NSString stringWithFormat:@"%@@%@:%@", user, host, volumePath]];

    // mount location
    [taskArguments addObject:self.localMountURL.path];

    // don't prompt for passwords over and over (may be unnecessary)
    //[taskArguments addObject:@"-oNumberOfPasswordPrompts=1"];

    // basic sshfs options
    [taskArguments addObject:@"-oauto_cache"];
    [taskArguments addObject:@"-oreconnect"];
    [taskArguments addObject:@"-odefer_permissions"];
    [taskArguments addObject:@"-onoappledouble"];
    [taskArguments addObject:@"-onegative_vncache"];
    [taskArguments addObject:@"-oNumberOfPasswordPrompts=1"];

    // custom volume name
    [taskArguments addObject:[NSString stringWithFormat:@"-ovolname=%@", mountName]];

    // custom port if needed
    [taskArguments addObject:[NSString stringWithFormat:@"-p%@", port]];

#pragma mark - Set launch path of subprocess executable and run it

#warning this is the path of sshfs set by Homebrew or the official SSHFS package, it WILL change once we bundle sshfs-static!!!
    [self.sshfsTask setLaunchPath:@"/usr/local/bin/sshfs"];
    [self.sshfsTask setArguments:taskArguments];

    [self.sshfsTask launch];

    [self.sharedSystemAPI checkForMountedVolume:self.localMountURL withTimeout:30 success:^{
        successBlock();
    } failure:^(NSError *error) {
        NSError *mountError = [NSError errorWithDomain:SDErrorDomain code:SDMountErrorUnknown userInfo:@{@"error": error}];
        failureBlock(mountError);
    }];
}

-(void)unmountVolumeWithName:(NSString *)mountName success:(SDMountSuccessBlock)successBlock failure:(SDMountFailureBlock)failureBlock {
#warning Requires testing to see which is better, ejecting the mountpoint appears to work 100% of the time
    // which is better for a FUSE process? Interrupt signal is suggested by the docs
    //[self.sshfsTask terminate];
    //[self.sshfsTask interrupt];
    [self.sharedSystemAPI ejectMountpoint:self.localMountURL success:^{
        successBlock();
    } failure:^(NSError *error) {
        failureBlock(error);
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
