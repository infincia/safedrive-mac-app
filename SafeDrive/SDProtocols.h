
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SDMountStatusProtocol <NSObject>
@required
-(void)volumeDidMount:(NSNotification*)notification;
-(void)volumeDidUnmount:(NSNotification*)notification;
@end

@protocol SDApplicationControlProtocol <NSObject>
@required
-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification;
-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification;
@end