
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSyncController.h"
#import <dispatch/dispatch.h>

#import <NMSSH/NMSSH.h>

@interface SDSyncController ()

@property NSTask *syncTask;
@property BOOL syncFailure;

-(void)createRemoteDirectory:(NSURL *)serverURL password:(NSString *)password success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock;

@end

@implementation SDSyncController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.syncTask = nil;
        self.syncFailure = NO;
    }
    return self;
}


+(SDSyncController *)sharedAPI {
    static SDSyncController *localInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        localInstance = [[SDSyncController alloc] init];
    });
    return localInstance;
}

-(void)createRemoteDirectory:(NSURL *)serverURL password:(NSString *)password success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NMSSHLogger *l = [NMSSHLogger sharedLogger];
    l.logLevel = NMSSHLogLevelWarn;
    [l setLogBlock:^(NMSSHLogLevel level, NSString *format) {
        SDLog(@"%@", format);
    }];
    
    NSString *host = [serverURL host];
    //unused NSNumber *port = [serverURL port];
    NSString *user = [serverURL user];
    NSString *serverPath = [serverURL path];
    NSString *machineDirectory = [serverPath stringByDeletingLastPathComponent];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NMSSHSession *session = [NMSSHSession connectToHost:host
                                               withUsername:user];
        
        if (session.isConnected) {
            // this can be swapped out for a key method as needed
            [session authenticateByPassword:password];
            
            if (session.isAuthorized) {
                SDLog(@"SFTP: authentication succeeded");
                NMSFTP *sftp = [NMSFTP connectWithSession:session];
                if ([sftp directoryExistsAtPath:machineDirectory]) {
                    SDLog(@"SFTP: sync directory exists");
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        successBlock();
                    });
                }
                else if ([sftp createDirectoryAtPath:machineDirectory]) {
                    SDLog(@"SFTP: creating sync directory");
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        successBlock();
                    });
                }
                else {
                    NSString *msg = [NSString stringWithFormat:@"SFTP: failed to create path: %@", machineDirectory];
                    SDLog(msg);
                    NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
                    
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        failureBlock(error);
                    });
                }
                [sftp disconnect];
            }
            else {
                NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"SFTP: failed to connect"}];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    failureBlock(error);
                });
            }
        }
        // all cases should end up disconnecting the session
        [session disconnect];
    });
}

#pragma mark
#pragma mark Public API

-(void)startSyncTaskWithLocalURL:(NSURL *)localURL serverURL:(NSURL *)serverURL password:(NSString *)password restore:(BOOL)restore success:(SDSyncResultBlock)successBlock failure:(SDSyncResultBlock)failureBlock {
    NSAssert([NSThread currentThread] != [NSThread mainThread], @"Sync task started from main thread");

    self.syncFailure = NO;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([fileManager fileExistsAtPath:localURL.path isDirectory:&isDirectory] && isDirectory) {

    }
    else {
        NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: @"Local directory not found"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(localURL, error);
        });
        return;
    }


#pragma mark - Retrieve necessary parameters from ssh url

    NSString *host = [serverURL host];
    NSNumber *port = [serverURL port];
    NSString *user = [serverURL user];
    NSString *fullServerPath = [serverURL path];
    NSString *serverPath = [fullServerPath substringFromIndex:1];
    NSString *localPath = [localURL path];
    SDLog(@"Syncing from %@/ to: %@/", localPath, serverPath);


#pragma mark - Create the subprocess to be configured below

    self.syncTask = [[NSTask alloc] init];

    [self.syncTask setLaunchPath:SDDefaultRsyncPath];


#pragma mark - Set custom environment variables for sshfs subprocess

    NSMutableDictionary *rsyncEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    /* path of our custom askpass helper so ssh can use it */
    NSString *safeDriveAskpassPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"safedriveaskpass"];

    if (safeDriveAskpassPath != nil) {
        [rsyncEnvironment setObject:safeDriveAskpassPath forKey:@"SSH_ASKPASS"];
    }
    else {
        NSError *askpassError = [NSError errorWithDomain:SDErrorDomain code:SDSSHErrorAskpassMissing userInfo:@{NSLocalizedDescriptionKey: @"Askpass helper missing"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(localURL, askpassError);
        });
        return;
    }

    /* pass the account name to the safedriveaskpass environment */
    [rsyncEnvironment setObject:user forKey:@"SSH_ACCOUNT"];

    /*
        remove any existing SSH agent socket in the subprocess environment so we
        have full control over auth behavior
    */
    [rsyncEnvironment removeObjectForKey:@"SSH_AUTH_SOCK"];

    /* 
        Set a blank DISPLAY environment variable. This is critical for making
        sure that OpenSSH actually runs our custom askpass binary, even though
        X11 isn't being used at all.
        
        If you're reading this code or working on it, just be aware that SSH auth
        relying on an askpass will *fail* 100% of the time without this variable
        set, even though it's blank.
        
        For the reason, see below.
        
        ------------------------------------------------------------------------

        OpenSSH will only run an askpass binary if a DISPLAY environment variable
        is set. On OS X, that variable isn't present unless XQuartz is installed.
        
        Given that the original purpose of askpass was to display a GUI password 
        prompt using X11, this behavior makes some sense. If DISPLAY isn't set, 
        OpenSSH assumes the askpass won't be able to function because it won't 
        have access to X11, so it doesn't even try to run the askpass.
        
        It's a flawed assumption now, particularly on systems that don't rely on
        X11 for native display, but Apple's version of OpenSSH doesn't patch it 
        out (likely because they don't use or even ship an askpass with OS X).

        Lastly, this only overrides the variable for the SSHFS process environment,
        it won't interfere with use of XQuartz at all.

    */
#warning DO NOT REMOVE THIS. See above comment for the reason.
    [rsyncEnvironment setObject:@"" forKey:@"DISPLAY"];
    self.syncTask.environment = rsyncEnvironment;



#pragma mark - Set Rsync subprocess arguments

    NSArray *taskArguments;
    
    // restore just reverses the local and remote path arguments to the rsync command,
    // is not as well tested as normal sync
    if (restore) {
        NSString *remote = [NSString stringWithFormat:@"%@@%@:\"%@/\"", user, host, serverPath];
        
        NSString *local = [NSString stringWithFormat:@"%@/", localPath];
        
        taskArguments = @[@"-r", remote, local];
    }
    else {
        NSString *local = [NSString stringWithFormat:@"%@/", localURL.path];
        
        NSString *remote = [NSString stringWithFormat:@"%@@%@:\"%@/\"", user, host, serverPath];
        
        // recursive, local and remote paths
        taskArguments = @[@"-r", local, remote];

    }
    [self.syncTask setArguments:taskArguments];


#pragma mark - Set asynchronous block to handle subprocess stdout

    NSPipe *outputPipe = [NSPipe pipe];
    NSFileHandle *outputPipeHandle = [outputPipe fileHandleForReading];
    outputPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *outputString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        SDLog(@"Rsync Task stdout output: %@", outputString);

        NSError *error;
        if ([outputString rangeOfString:@"Could not chdir to home directory"].length > 0) {
            /*
             NSString *msg = [NSString stringWithFormat:@"Could not chdir to home directory"];
            
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorRemoteEnvironment userInfo:@{NSLocalizedDescriptionKey: msg}];
             */
        }
        else if ([outputString rangeOfString:@"No such file or directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];

            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([outputString rangeOfString:@"Not a directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];

            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([outputString rangeOfString:@"Permission denied"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Permission denied"}];
        }
        else if ([outputString rangeOfString:@"Error resolving hostname"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSyncFailed userInfo:@{NSLocalizedDescriptionKey: @"Error resolving hostname, contact support"}];
        }
        else if ([outputString rangeOfString:@"remote host has disconnected"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Sync failed, check username and password"}];
        }
        else if ([outputString rangeOfString:@"REMOTE HOST IDENTIFICATION HAS CHANGED"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostFingerprintChanged userInfo:@{NSLocalizedDescriptionKey: @"Warning: server fingerprint changed!"}];
        }
        else if ([outputString rangeOfString:@"Host key verification failed"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostKeyVerificationFailed userInfo:@{NSLocalizedDescriptionKey: @"Warning: server key verification failed!"}];
        }
        else {
            error = [NSError errorWithDomain:SDErrorDomain code:SDSSHErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"An unknown error occurred, contact support"}];
            /*
                for the moment we don't want to call the failure block here, as 
                not everything that comes through stderr indicates a mount 
                failure.

                testing is required to discover and handle the stderr output that 
                we actually need to handle and ignore the rest.

            */
            // failureBlock(mountURL, mountError);
            return;
        }
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.syncFailure = YES;
                failureBlock(localURL, error);
            });
            SDLog(@"Rsync task stdout error: %@, %@", SDErrorToString(error), error.localizedDescription);
        }
    };
    [self.syncTask setStandardOutput:outputPipe];

#pragma mark - Set asynchronous block to handle subprocess stderr

    NSPipe *errorPipe = [NSPipe pipe];
    NSFileHandle *errorPipeHandle = [errorPipe fileHandleForReading];
    errorPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *errorString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        SDLog(@"Rsync Task stderr output: %@", errorString);
        
        NSError *error;
        if ([errorString rangeOfString:@"Could not chdir to home directory"].length > 0) {
            /*
             NSString *msg = [NSString stringWithFormat:@"Could not chdir to home directory"];
             
             error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorRemoteEnvironment userInfo:@{NSLocalizedDescriptionKey: msg}];
             */
        }
        else if ([errorString rangeOfString:@"connection unexpectedly closed"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSyncFailed userInfo:@{NSLocalizedDescriptionKey: @"Warning: server closed connection unexpectedly"}];
        }
        else if ([errorString rangeOfString:@"No such file or directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];
            
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([errorString rangeOfString:@"Not a directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];
            
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([errorString rangeOfString:@"Permission denied"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Permission denied"}];
        }
        else if ([errorString rangeOfString:@"Error resolving hostname"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSyncFailed userInfo:@{NSLocalizedDescriptionKey: @"Error resolving hostname, contact support"}];
        }
        else if ([errorString rangeOfString:@"remote host has disconnected"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Sync failed, check username and password"}];
        }
        else if ([errorString rangeOfString:@"REMOTE HOST IDENTIFICATION HAS CHANGED"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostFingerprintChanged userInfo:@{NSLocalizedDescriptionKey: @"Warning: server fingerprint changed!"}];
        }
        else if ([errorString rangeOfString:@"Host key verification failed"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostKeyVerificationFailed userInfo:@{NSLocalizedDescriptionKey: @"Warning: server key verification failed!"}];
        }
        else {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"An unknown error occurred, contact support"}];
            /*
             for the moment we don't want to call the failure block here, as
             not everything that comes through stderr indicates a mount
             failure.
             
             testing is required to discover and handle the stderr output that
             we actually need to handle and ignore the rest.
             
             */
            // failureBlock(mountURL, mountError);
            return;
        }
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.syncFailure = YES;
                failureBlock(localURL, error);
            });
            SDLog(@"Rsync task stderr: %@, %@", SDErrorToString(error), error.localizedDescription);
        }
    };
    [self.syncTask setStandardError:errorPipe];

#pragma mark - Set asynchronous block to handle subprocess termination


    /* 
        clear the read and write blocks once the subprocess terminates, and then
        call the success block if no error occurred.
        
    */
    __weak SDSyncController *weakSelf = self;
    [self.syncTask setTerminationHandler:^(NSTask *task) {
        [task.standardOutput fileHandleForReading].readabilityHandler = nil;
        [task.standardError fileHandleForReading].readabilityHandler = nil;
        if (task.terminationStatus == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // need to explicitly check if a sync failure occurred as the return value of 0 doesn't indicate success
                if (!weakSelf.syncFailure) {
                    successBlock(localURL, nil);
                }
            });
        }
    }];





#pragma mark - Launch subprocess and return

    [self createRemoteDirectory:serverURL password:password success:^{
        SDLog(@"Launching Rsync with arguments: %@", taskArguments);
        [self.syncTask launch];
    } failure:^(NSError * _Nonnull apiError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            failureBlock(localURL, apiError);
        });
    }];

}

@end
