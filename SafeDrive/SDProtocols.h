
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SDVolumeEventProtocol <NSObject>
@required
-(void)volumeDidMount:(NSNotification*)notification;
-(void)volumeDidUnmount:(NSNotification*)notification;
-(void)volumeShouldUnmount:(NSNotification*)notification;
-(void)volumeSubprocessDidTerminate:(NSNotification*)notification;
@end

@protocol SDMountStateProtocol <NSObject>
@required
-(void)mountStateMounted:(NSNotification*)notification;
-(void)mountStateUnmounted:(NSNotification*)notification;
-(void)mountStateDetails:(NSNotification *)notification;
@end

@protocol SDAccountProtocol <NSObject>
@required
-(void)didReceiveAccountStatus:(NSNotification*)notification;
-(void)didReceiveAccountDetails:(NSNotification *)notification;
@end
@protocol SDApplicationControlProtocol <NSObject>
@required
-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification;
-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification;
-(void)applicationShouldOpenAboutWindow:(NSNotification*)notification;
@end

@protocol SDAPIAvailabilityProtocol <NSObject>
@required
-(void)apiDidEnterMaintenancePeriod:(NSNotification*)notification;
-(void)apiDidBecomeReachable:(NSNotification*)notification;
-(void)apiDidBecomeUnreachable:(NSNotification*)notification;
@end