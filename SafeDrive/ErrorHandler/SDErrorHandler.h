

//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

void SDErrorHandlerInitialize();
void SDUncaughtExceptionHandler(NSException *exception);
void SDErrorHandlerSetUser(NSString *user);
void SDLog(NSString *line, ...);
void SDLogv(NSString *format, va_list arguments);
void SDErrorHandlerReport(NSError *error);
