
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HKTHashProvider : NSObject

+ (NSString *)md5:(NSData *)data;


+ (NSString *)sha1:(NSData *)data;
+ (NSString *)sha224:(NSData *)data;
+ (NSString *)sha256:(NSData *)data;
+ (NSString *)sha384:(NSData *)data;
+ (NSString *)sha512:(NSData *)data;

@end
