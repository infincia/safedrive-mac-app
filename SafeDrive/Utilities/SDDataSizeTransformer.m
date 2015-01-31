
//  Copyright (c) 2015 Infincia LLC. All rights reserved.
//

#import "SDDataSizeTransformer.h"

@implementation SDDataSizeTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    long long inputBytes;

    if (value == nil) return nil;

    if ([value respondsToSelector: @selector(longLongValue)]) {
        inputBytes = [value longLongValue];
    } else {
        [NSException raise: NSInternalInconsistencyException format: @"Value (%@) does not respond to -longLongValue.", [value class]];
    }

    return [NSByteCountFormatter stringFromByteCount:inputBytes countStyle:NSByteCountFormatterCountStyleFile];
}


@end
