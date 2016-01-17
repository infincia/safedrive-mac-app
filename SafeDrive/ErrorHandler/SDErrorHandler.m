

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDErrorHandler.h"
#import "SDAPI.h"

static SDAPI * sharedAPI;
static NSMutableArray * logBuffer;
static NSMutableArray * errors;
static dispatch_queue_t errorQueue;
static NSURL * serializedErrorLocation;
static NSURL * serializedLogLocation;

static NSString * currentUser;

static NSTimeInterval reporterInterval = 60;

static NSInteger maxLogSize = 100;

void _shiftLog();
void _saveLog();
void _startReportQueue();
void _saveErrors();

#pragma mark
#pragma mark Public API

void SDErrorHandlerInitialize() {

    errorQueue = dispatch_queue_create("errorQueue", DISPATCH_QUEUE_SERIAL);
    errors = [NSMutableArray new];
    logBuffer = [NSMutableArray new];
    
    sharedAPI = [SDAPI sharedAPI];
    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationSupportURL = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
    NSURL *safeDriveApplicationSupportURL = [applicationSupportURL URLByAppendingPathComponent:@"SafeDrive" isDirectory:YES];
    
    NSError *directoryError = nil;
    if (![fileManager createDirectoryAtURL:safeDriveApplicationSupportURL withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        NSLog(@"Error creating support directory: %@", directoryError.localizedDescription);
    }
    
    /*
        Set serializedErrorLocation to an NSURL corresponding to:
        ~/Library/Application Support/SafeDrive/SafeDrive-Errors.plist
    */
    serializedErrorLocation = [safeDriveApplicationSupportURL URLByAppendingPathComponent:@"SafeDrive-Errors.plist" isDirectory:NO];
    
    /*
        Set serializedErrorLocation to an NSURL corresponding to:
        ~/Library/Application Support/SafeDrive/SafeDrive-Log.plist
    */
    serializedLogLocation = [safeDriveApplicationSupportURL URLByAppendingPathComponent:@"SafeDrive-Log.plist" isDirectory:NO];
    
    
    
    // restore any saved error reports from previous sessions
    NSArray *serializedErrors = [[NSArray alloc] initWithContentsOfURL:serializedErrorLocation];
    if (serializedErrors != nil) {
        [errors addObjectsFromArray:serializedErrors];
    }
    
    // start the reporter loop now that any possible saved error reports are loaded
    _startReportQueue();
}

void SDErrorHandlerSetUser(NSString *user) {
    currentUser = user;
}

void SDLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *st = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
#ifdef DEBUG
    // pass through to NSLog for compatibility during development
    NSLog(@"%@", st);
#endif
    // for RELEASE builds, redirect logs to the buffer in case there is an error
    dispatch_async(errorQueue, ^{
        [logBuffer addObject:st];
        _shiftLog();
        _saveLog();
    });

}

void SDErrorHandlerReport(NSError *error) {
    
    // using archived NSError so the array can be serialized as a plist
    dispatch_async(errorQueue, ^{
        NSDictionary *report = @{ @"error": [NSKeyedArchiver archivedDataWithRootObject:error],
                                  @"log": logBuffer,
                                  @"user": currentUser ?: @"" };
        [errors insertObject:report atIndex:0];
        _saveErrors();
    });
    
}

void SDUncaughtExceptionHandler(NSException *exception) {
    NSArray *stack = [exception callStackReturnAddresses];
    NSLog(@"Stack trace: %@", stack);

    dispatch_async(errorQueue, ^{
        NSDictionary *report = @{ @"stack": stack,
                                  @"log": logBuffer,
                                  @"user": currentUser ?: @"" };
        [errors insertObject:report atIndex:0];
        _saveErrors();
    });
}

#pragma mark
#pragma mark Private APIs

void _startReportQueue() {
    NSLog(@"Error reporter running");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (;;) {
            dispatch_sync(errorQueue, ^{
                
                // get the oldest report and pop it off the end of the array temporarily
                NSDictionary *report = [errors lastObject];
                [errors removeObject:report];
                
                if (report != nil) {
                    NSString *reportUser = [report objectForKey:@"user"];
                    
                    NSArray *reportLog = [report objectForKey:@"log"];

                    id archivedError = [report objectForKey:@"error"];
                    
                    // Errors are stored as NSData in the error array so they can be transparently serialized to disk,
                    // so we must unarchive them before use
                    NSError *error = [NSKeyedUnarchiver unarchiveObjectWithData:archivedError];
                    
                    //note: passing the same queue we're in here is only OK because the called method uses it
                    //      with dispatch_async, if that were not the case this would deadlock forever
                    [sharedAPI reportError:error forUser:reportUser withLog:reportLog completionQueue:errorQueue success:^{
                        
                        _saveErrors();
                   
                    } failure:^(NSError *apiError) {
                        
                        // put the report back in the queue and save it since this attempt failed
                        [errors insertObject:report atIndex:0];
                        
                        _saveErrors();
                    }];
                }
            });
            [NSThread sleepForTimeInterval:reporterInterval];
        }
    });
}

// NOTE: These MUST NOT be called outside of the errorQueue

void _shiftLog() {
    if (logBuffer.count > maxLogSize) {
        [logBuffer removeObjectAtIndex:0];
    }
}

void _saveLog() {
    if (![logBuffer writeToURL:serializedLogLocation atomically:YES]) {
        SDLog(@"WARNING: log database could not be saved!!!");
    }
}

void _saveErrors() {
    if (![errors writeToURL:serializedErrorLocation atomically:YES]) {
        SDLog(@"WARNING: error report database could not be saved!!!");
    }
}
