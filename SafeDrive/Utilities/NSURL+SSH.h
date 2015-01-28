
//  Copyright (c) 2015 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (SSH)
+(NSURL *)SSHURLForAccount:(NSString *)account
                  password:(NSString *)password
                      host:(NSString *)host
                      port:(NSNumber *)port
                      path:(NSString *)path;
@end