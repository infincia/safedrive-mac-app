
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


@import Foundation;
#import "SDServiceXPCProtocol.h"


@interface SDServiceListenerDelegate : NSObject<NSXPCListenerDelegate, SDServiceXPCProtocol>

@end
