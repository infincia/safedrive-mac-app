
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

@import Foundation;

@interface SDSystemAPI : NSObject

+(SDSystemAPI * _Nonnull)sharedAPI;

-(BOOL)autostart;

-(BOOL)enableAutostartWithError:(NSError * _Nullable * _Nullable)error;

-(BOOL)disableAutostartWithError:(NSError * _Nullable * _Nullable)error;

@end
