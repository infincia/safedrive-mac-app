
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
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
-(void)didAuthenticate:(NSNotification*)notification;
-(void)didSignOut:(NSNotification*)notification;
-(void)didReceiveAccountStatus:(NSNotification*)notification;
-(void)didReceiveAccountDetails:(NSNotification *)notification;
@end

@protocol SDServiceStatusProtocol <NSObject>
@required
-(void)didReceiveServiceStatus:(NSNotification*)notification;
@end

@protocol SDApplicationControlProtocol <NSObject>
@required
-(void)applicationShouldOpenPreferencesWindow:(NSNotification*)notification;
-(void)applicationShouldOpenAccountWindow:(NSNotification*)notification;
-(void)applicationShouldOpenAboutWindow:(NSNotification*)notification;
-(void)applicationShouldFinishConfiguration:(NSNotification*)notification;
@end

@protocol SDAPIAvailabilityProtocol <NSObject>
@required
-(void)apiDidEnterMaintenancePeriod:(NSNotification*)notification;
-(void)apiDidBecomeReachable:(NSNotification*)notification;
-(void)apiDidBecomeUnreachable:(NSNotification*)notification;
@end
