
//  Copyright (c) 2015 Infincia LLC. All rights reserved.
//

#import "NSURL+SFTP.h"

@implementation NSURL (SFTP)

+(NSURL *)SFTPURLForAccount:(NSString *)account
                      host:(NSString *)host
                      port:(NSNumber *)port
                      path:(NSString *)path {
    // sftp://user:password@host.domain.org

    NSString *escapedPath = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    NSString *escapedAccount = [account stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    NSString *urlString = [NSString stringWithFormat:@"sftp://%@@%@:%@/%@",escapedAccount, host, port, escapedPath];
    return [NSURL URLWithString:urlString];
}

@end