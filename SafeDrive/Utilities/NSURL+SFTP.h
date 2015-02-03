
//  Copyright (c) 2015 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (SFTP)
+(NSURL *)SFTPURLForAccount:(NSString *)account
                       host:(NSString *)host
                       port:(NSNumber *)port
                       path:(NSString *)path;
@end