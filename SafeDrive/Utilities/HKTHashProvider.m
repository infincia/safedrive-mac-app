
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "HKTHashProvider.h"
#import <CommonCrypto/CommonDigest.h>


@implementation NSData (Hex)
- (NSString*)hexString {
    NSUInteger length = self.length;
    unichar* hexChars = (unichar*)malloc(sizeof(unichar) * (length*2));
    unsigned char* bytes = (unsigned char*)self.bytes;
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = bytes[i] / 16;
        if (c < 10) c += '0';
        else c += 'A' - 10;
        hexChars[i*2] = c;
        c = bytes[i] % 16;
        if (c < 10) c += '0';
        else c += 'A' - 10;
        hexChars[i*2+1] = c;
    }
    NSString* retVal = [[NSString alloc] initWithCharactersNoCopy:hexChars
                                                           length:length*2
                                                     freeWhenDone:YES];
    return retVal.lowercaseString;
}
@end

@implementation HKTHashProvider

# pragma mark - Synchronous functions for small amounts of data

# pragma mark - MD5

+ (NSString *)md5:(NSData *)data {
    unsigned char hash[CC_MD5_DIGEST_LENGTH];
    if ( CC_MD5([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *md5 = [NSData dataWithBytes:hash length:CC_MD5_DIGEST_LENGTH];
        NSString *string = [md5 hexString];
        return string;
    }
    return nil;
}

# pragma mark - SHA1

+ (NSString *)sha1:(NSData *)data {
    unsigned char hash[CC_SHA1_DIGEST_LENGTH];
    if ( CC_SHA1([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *sha1 = [NSData dataWithBytes:hash length:CC_SHA1_DIGEST_LENGTH];
        NSString *string = [sha1 hexString];
        return string;
    }
    return nil;
}

#pragma mark - SHA2

+ (NSString *)sha224:(NSData *)data {
    unsigned char hash[CC_SHA224_DIGEST_LENGTH];
    if ( CC_SHA224([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *sha224 = [NSData dataWithBytes:hash length:CC_SHA224_DIGEST_LENGTH];
        NSString *string = [sha224 hexString];
        return string;
    }
    return nil;
}

+ (NSString *)sha256:(NSData *)data {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    if ( CC_SHA256([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *sha256 = [NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH];
        NSString *string = [sha256 hexString];
        return string;
    }
    return nil;
}

+ (NSString *)sha384:(NSData *)data {
    unsigned char hash[CC_SHA384_DIGEST_LENGTH];
    if ( CC_SHA384([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *sha384 = [NSData dataWithBytes:hash length:CC_SHA384_DIGEST_LENGTH];
        NSString *string = [sha384 hexString];
        return string;
    }
    return nil;
}
+ (NSString *)sha512:(NSData *)data {
    unsigned char hash[CC_SHA512_DIGEST_LENGTH];
    if ( CC_SHA512([data bytes], (CC_LONG)[data length], hash) ) {
        NSData *sha512 = [NSData dataWithBytes:hash length:CC_SHA512_DIGEST_LENGTH];
        NSString *string = [sha512 hexString];
        return string;
    }
    return nil;
}



@end
