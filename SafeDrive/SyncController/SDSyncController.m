
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import "SDSyncController.h"
#import <dispatch/dispatch.h>

#import <NMSSH/NMSSH.h>

#import <RegexKitLite/RegexKitLite.h>

@interface SDSyncController ()

@property NSTask *syncTask;
@property BOOL syncFailure;
@property BOOL syncTerminated;
@property dispatch_queue_t syncProgressQueue;
@end

@implementation SDSyncController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.syncTask = nil;
        self.syncFailure = NO;
        self.uniqueID = -1;
        self.syncTerminated = NO;
        self.syncProgressQueue = dispatch_queue_create("io.safedrive.SafeDrive.syncprogress", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)SFTPOperation:(SDSFTPOperation)op remoteDirectory:(NSURL *)serverURL password:(NSString *)password success:(SDSuccessBlock)successBlock failure:(SDFailureBlock)failureBlock {
    NMSSHLogger *l = [NMSSHLogger sharedLogger];
    l.logLevel = NMSSHLogLevelWarn;
    [l setLogBlock:^(NMSSHLogLevel level, NSString *format) {
        SDLog(@"%@", format);
    }];
    
    NSString *host = [serverURL host];
    NSNumber *port = [serverURL port];
    NSString *user = [serverURL user];
    NSString *serverPath = [serverURL path];
    NSString *machineDirectory = [serverPath stringByDeletingLastPathComponent];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NMSSHSession *session = [NMSSHSession connectToHost:host
                                                       port:port.integerValue
                                               withUsername:user];
        
        if (session.isConnected) {
            // this can be swapped out for a key method as needed
            [session authenticateByPassword:password];
            
            if (session.isAuthorized) {
                NMSFTP *sftp = [NMSFTP connectWithSession:session];
                switch (op) {
                    case SDSFTPOperationMoveFolder: {
                        NSURL *storageDir = [NSURL URLWithString:@"/storage/Storage/"];
                        NSDate *now = [NSDate new];
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        dateFormatter.dateFormat = @"yyyy-MM-dd@HH-mm-ss";
                        dateFormatter.locale = [NSLocale currentLocale];
                        NSString *dateString = [dateFormatter stringFromDate:now];
                        NSString *newName = [NSString stringWithFormat:@"%@ - %@", serverURL.lastPathComponent, dateString];
                        NSURL *destinationDir = [storageDir URLByAppendingPathComponent:newName isDirectory:YES];
                        SDLog(@"Moving SyncFolder %@ to %@", serverPath, destinationDir.path);
                        if ([sftp fileExistsAtPath:destinationDir.path]) {
                            NSString *msg = [NSString stringWithFormat:@"SFTP: File with conflicting name found: %@", serverURL.lastPathComponent];
                            SDLog(msg);
                            NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSFTPOperationFolderConflict userInfo:@{NSLocalizedDescriptionKey: msg}];
                            
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                failureBlock(error);
                            });
                        }
                        else if ([sftp directoryExistsAtPath:destinationDir.path]) {
                            NSString *msg = [NSString stringWithFormat:@"SFTP: Folder already exists: %@", serverURL.lastPathComponent];
                            SDLog(msg);
                            NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorSFTPOperationFolderConflict userInfo:@{NSLocalizedDescriptionKey: msg}];
                            
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                failureBlock(error);
                            });
                        }
                        else if ([sftp moveItemAtPath:serverPath toPath:destinationDir.path]) {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                successBlock();
                            });
                        }
                        else {
                            NSString *msg = [NSString stringWithFormat:@"SFTP: failed to move path: %@", serverPath];
                            SDLog(msg);
                            NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSFTPOperationFailure userInfo:@{NSLocalizedDescriptionKey: msg}];
                            
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                failureBlock(error);
                            });
                        }
                        break;
                    }
                    case SDSFTPOperationCreateFolder:
                        if ([sftp directoryExistsAtPath:machineDirectory]) {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                successBlock();
                            });
                        }
                        else if ([sftp createDirectoryAtPath:machineDirectory]) {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                successBlock();
                            });
                        }
                        else {
                            NSString *msg = [NSString stringWithFormat:@"SFTP: failed to create path: %@", machineDirectory];
                            SDLog(msg);
                            NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSFTPOperationFailure userInfo:@{NSLocalizedDescriptionKey: msg}];
                            
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                self.syncFailure = YES;
                                failureBlock(error);
                            });
                        }
                        break;
                    case SDSFTPOperationDeleteFolder:
                        if ([sftp removeDirectoryAtPath:serverPath]) {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                successBlock();
                            });
                        }
                        else {
                            NSString *msg = [NSString stringWithFormat:@"SFTP: failed to remove path: %@", serverPath];
                            SDLog(msg);
                            NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorSFTPOperationFailure userInfo:@{NSLocalizedDescriptionKey: msg}];
                            
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                failureBlock(error);
                            });
                        }
                        break;
                    default:
                        break;
                }
                [sftp disconnect];
            }
            else {
                NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"SFTP: authorization failed"}];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.syncFailure = YES;
                    failureBlock(error);
                });
            }
        }
        else {
            NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSSHErrorTimeout userInfo:@{NSLocalizedDescriptionKey: @"SFTP: failed to connect"}];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.syncFailure = YES;
                failureBlock(error);
            });
        }
        // all cases should end up disconnecting the session
        [session disconnect];
    });
}

#pragma mark
#pragma mark Public API

-(void)stopSyncTask {
    self.syncTerminated = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (self.syncTask.isRunning) {
            [self.syncTask terminate];
            [NSThread sleepForTimeInterval:0.1];
        }
    });

}

-(void)startSyncTaskWithLocalURL:(NSURL *)localURL serverURL:(NSURL *)serverURL password:(NSString *)password restore:(BOOL)restore progress:(SDSyncProgressBlock)progressBlock success:(SDSyncResultBlock)successBlock failure:(SDSyncResultBlock)failureBlock {
    NSAssert([NSThread currentThread] != [NSThread mainThread], @"Sync task started from main thread");
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([fileManager fileExistsAtPath:localURL.path isDirectory:&isDirectory] && isDirectory) {

    }
    else {
        NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSyncErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: @"Local directory not found"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.syncFailure = YES;
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


#pragma mark - Create the subprocess to be configured below

    self.syncTask = [[NSTask alloc] init];
    
    NSString *rsyncPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"rsync-3.1.2"];
    
    if (rsyncPath != nil) {
        [self.syncTask setLaunchPath:rsyncPath];
    }
    else {
        NSString *message = NSLocalizedString(@"Rsync missing, contact SafeDrive support", @"");
        NSError *rsyncError = [NSError errorWithDomain:SDMountErrorDomain code:SDSystemErrorRsyncMissing userInfo:@{NSLocalizedDescriptionKey: message}];
        failureBlock(localURL, rsyncError);
        return;
    }

#pragma mark - Set custom environment variables for sshfs subprocess

    NSMutableDictionary *rsyncEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];

    /* path of our custom askpass helper so ssh can use it */
    NSString *safeDriveAskpassPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"safedriveaskpass"];

    if (safeDriveAskpassPath != nil) {
        [rsyncEnvironment setObject:safeDriveAskpassPath forKey:@"SSH_ASKPASS"];
    }
    else {
        NSError *askpassError = [NSError errorWithDomain:SDErrorSyncDomain code:SDSystemErrorAskpassMissing userInfo:@{NSLocalizedDescriptionKey: @"Askpass helper missing"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.syncFailure = YES;
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
    NSString *sshCommand = [NSString stringWithFormat:@"ssh -o StrictHostKeyChecking=no -p %@", port];
    NSArray *commonArguments = @[@"-e", sshCommand, @"--delete", @"-rlpt", @"--info=progress2", @"--no-inc-recursive"];
    NSMutableArray *taskArguments = [NSMutableArray arrayWithArray:commonArguments];

    NSString *remote = [NSString stringWithFormat:@"%@@%@:\"%@/\"", user, host, serverPath];
    
    NSString *local = [NSString stringWithFormat:@"%@/", localURL.path];
    
    // restore just reverses the local and remote path arguments to the rsync command,
    // is not as well tested as normal sync
    if (restore) {
        [taskArguments addObject:remote];
        [taskArguments addObject:local];
    }
    else {
        [taskArguments addObject:local];
        [taskArguments addObject:remote];
    }
    [self.syncTask setArguments:taskArguments];


#pragma mark - Set asynchronous block to handle subprocess stdout

    NSPipe *outputPipe = [NSPipe pipe];
    NSFileHandle *outputPipeHandle = [outputPipe fileHandleForReading];

    outputPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
      
        NSString *outputString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        NSString *fullRegex  = @"^\\s*([0-9,]+)\\s+([0-9%]+)\\s+([0-9\\.A-Za-z/]+)";
        // example: "              0   0%    0.00kB/s    0:00:00 (xfr#0, to-chk=0/11)"
        if ([outputString isMatchedByRegex:fullRegex]) {
            NSArray *matches = [outputString arrayOfCaptureComponentsMatchedByRegex:fullRegex];
            if (matches.count == 1) {
                NSArray *capturedValues = matches[0];
                if (capturedValues.count >= 3) {
                    NSString *percent = capturedValues[2];
                    dispatch_async(self.syncProgressQueue, ^{
                        progressBlock(percent.doubleValue);
                    });
                }
            }
        }
        else {
            SDLog(@"Rsync Task stdout output: %@", outputString);
        }

    };
    [self.syncTask setStandardOutput:outputPipe];

#pragma mark - Set asynchronous block to handle subprocess stderr

    NSPipe *errorPipe = [NSPipe pipe];
    NSFileHandle *errorPipeHandle = [errorPipe fileHandleForReading];
    errorPipeHandle.readabilityHandler = ^( NSFileHandle *handle ) {
        NSString *errorString = [[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
        NSError *error;
        if ([errorString rangeOfString:@"Could not chdir to home directory"].length > 0) {
            /*
             NSString *msg = [NSString stringWithFormat:@"Could not chdir to home directory"];
             
             error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorRemoteEnvironment userInfo:@{NSLocalizedDescriptionKey: msg}];
             */
        }
        else if ([errorString rangeOfString:@"connection unexpectedly closed"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorSyncFailed userInfo:@{NSLocalizedDescriptionKey: @"Warning: server closed connection unexpectedly"}];
        }
        else if ([errorString rangeOfString:@"No such file or directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];
            
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([errorString rangeOfString:@"Not a directory"].length > 0) {
            NSString *msg = [NSString stringWithFormat:@"That path does not exist on the server: %@", serverPath];
            
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorDirectoryMissing userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else if ([errorString rangeOfString:@"Permission denied"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorAuthorization userInfo:@{NSLocalizedDescriptionKey: @"Permission denied"}];
        }
        else if ([errorString rangeOfString:@"Error resolving hostname"].length > 0) {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorSyncFailed userInfo:@{NSLocalizedDescriptionKey: @"Error resolving hostname, contact support"}];
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
        else if ([errorString rangeOfString:@"differs from the key for the IP address"].length > 0) {
            
            // silence host key mismatch for now
            // example: Warning: the ECDSA host key for 'sftp-client.safedrive.io' differs from the key for the IP address '185.104.180.61'
            //NSString *msg = [NSString stringWithFormat:@"Host key mismatch"];
            
            //error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSSHErrorHostFingerprintChanged userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        else {
            error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"An unknown error occurred, contact support"}];
            /*
             for the moment we don't want to call the failure block here, as
             not everything that comes through stderr indicates a mount
             failure.
             
             testing is required to discover and handle the stderr output that
             we actually need to handle and ignore the rest.
             
             */
            // failureBlock(mountURL, mountError);
            SDLog(@"Rsync Task stderr output: %@", errorString);
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
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.syncFailure) {
                    // do nothing, failureBlock already called elsewhere
                }
                else if (weakSelf.syncTerminated) {
                    // rsync returned a non-zero exit code because cancel/terminate was called by the user

                    NSError *error = [NSError errorWithDomain:SDErrorUIDomain code:SDSyncErrorCancelled userInfo:@{NSLocalizedDescriptionKey: @"Sync cancelled"}];
                    failureBlock(localURL, error);
                }
                else {
                    // since rsync returned a non-zero exit code AND we have not yet called failureBlock,
                    // we must call it as a catch-all.
                    
                    // This codepath should rarely if ever be used, if it does we'll need to log the entire
                    // output of rsync and report it to the telemetry API to be examined
                    NSError *error = [NSError errorWithDomain:SDErrorSyncDomain code:SDSyncErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"An unknown error occurred, contact support"}];
                    failureBlock(localURL, error);
                }
            });
        }
    }];





#pragma mark - Launch subprocess and return

    [self SFTPOperation:SDSFTPOperationCreateFolder remoteDirectory:serverURL password:password success:^{
        [self.syncTask launch];

    } failure:^(NSError * _Nonnull apiError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.syncFailure = YES;
            failureBlock(localURL, apiError);
        });
    }];
}

@end
