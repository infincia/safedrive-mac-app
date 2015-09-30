
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SDServiceManager : NSObject

+(SDServiceManager *)sharedServiceManager;

-(void)deployService;

-(void)loadService;
-(void)unloadService;

@property (nonatomic, readonly) BOOL serviceStatus;

@end
