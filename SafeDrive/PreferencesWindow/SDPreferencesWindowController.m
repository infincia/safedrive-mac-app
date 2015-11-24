
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDPreferencesWindowController.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import "SDSystemAPI.h"
#import "SDServiceManager.h"

@interface SDPreferencesWindowController ()
@property SDSystemAPI *sharedSystemAPI;
@property SDServiceManager *sharedServiceManager;
@property NSString *serviceStatus;
@end

@implementation SDPreferencesWindowController

/* 
    custom getter and setter for this property as it isn't local state, it's 
    system info to be set and retrieved dynamically using SDSystemAPI

*/
@dynamic autostart;

-(instancetype)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    self.sharedSystemAPI = [SDSystemAPI sharedAPI];
    self.sharedServiceManager = [SDServiceManager sharedServiceManager];

    self.volumeMountState = @"";
    self.volumeTotalSpace = @(0);
    self.volumeFreeSpace = @(0);
    
    // register SDVolumeEventProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];

    // register SDMountStateProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateMounted:) name:SDMountStateMountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateUnmounted:) name:SDMountStateUnmountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateDetails:) name:SDMountStateDetailsNotification object:nil];
    
    // register SDAccountProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveAccountStatus:) name:SDAccountStatusNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveAccountDetails:) name:SDAccountDetailsNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveServiceStatus:) name:SDServiceStatusNotification object:nil];
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setLevel:NSStatusWindowLevel];
    
    INAppStoreWindow *aWindow = (INAppStoreWindow*)[self window];
    aWindow.titleBarHeight = 24.0;
    aWindow.showsBaselineSeparator = NO;
    
    NSColor *topColor = [NSColor whiteColor];
    aWindow.titleBarStartColor     = topColor;
    aWindow.titleBarEndColor       = topColor;
    aWindow.baselineSeparatorColor = topColor;

    aWindow.inactiveTitleBarEndColor       = topColor;
    aWindow.inactiveTitleBarStartColor     = topColor;
    aWindow.inactiveBaselineSeparatorColor = topColor;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(IBAction)selectTab:(id)sender {
    NSButton *button = (NSButton *)sender;
    NSInteger selectedTab = button.tag;
    [self.tabView selectTabViewItemAtIndex:selectedTab];
    [self resetButtons];
    //button.highlighted = YES;
}

-(void)resetButtons {
    self.generalButton.highlighted = NO;
    self.accountButton.highlighted = NO;
    self.bandwidthButton.highlighted = NO;
    self.statusButton.highlighted = NO;

}

#pragma mark - Dynamic getter and setter for autostart property

-(BOOL)autostart {
    return [self.sharedSystemAPI autostart];
}

-(void)setAutostart:(BOOL)autostart {
    NSError *autostartError = nil;
    if (autostart == YES) {
        autostartError = [self.sharedSystemAPI enableAutostart];
    }
    else {
        autostartError = [self.sharedSystemAPI disableAutostart];
    }
    if (autostartError) {
        NSLog(@"Error during login item setter: %@", autostartError);
    }
}

#pragma mark - SDMountStatusProtocol methods

-(void)volumeDidMount:(NSNotification*)notification {

}

-(void)volumeDidUnmount:(NSNotification*)notification {
    
}

-(void)mountSubprocessDidTerminate:(NSNotification *)notification {

}

#pragma mark - SDMountStateProtocol methods

-(void)mountStateMounted:(NSNotification *)notification {
    self.volumeMountState = NSLocalizedString(@"Mounted", @"String for volume mount status of mounted");
}

-(void)mountStateUnmounted:(NSNotification*)notification {
    self.volumeMountState = NSLocalizedString(@"Unmounted", @"String for volume mount status of unmounted");

}

-(void)mountStateDetails:(NSNotification *)notification {
    NSDictionary *mountDetails = notification.object;
    if (mountDetails) {
        self.volumeTotalSpace = mountDetails[NSFileSystemSize];
        self.volumeFreeSpace = mountDetails[NSFileSystemFreeSize];
        self.volumeUsedSpace = @(self.volumeTotalSpace.longLongValue - self.volumeFreeSpace.longLongValue);
    }
    else {
        self.volumeTotalSpace = nil;
        self.volumeFreeSpace = nil;
        self.volumeUsedSpace = nil;
    }
}

#pragma mark - SDAccountProtocol methods

-(void)didReceiveAccountStatus:(NSNotification *)notification {
    NSDictionary *accountStatus = notification.object;
    NSString *status = accountStatus[@"status"];
    self.accountStatus = [status capitalizedString];
}

-(void)didReceiveAccountDetails:(NSNotification *)notification {
    NSDictionary *accountDetails = notification.object;
    self.assignedStorage = accountDetails[@"assignedStorage"];
    self.usedStorage = accountDetails[@"usedStorage"];
    NSNumber *expirationDate = accountDetails[@"expirationDate"];
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:expirationDate.doubleValue / 1000];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale currentLocale];
    dateFormatter.timeStyle = NSDateFormatterMediumStyle;
    dateFormatter.dateStyle = NSDateFormatterMediumStyle;
    //[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    self.expirationDate = [dateFormatter stringFromDate:date];

}

#pragma mark - SDServiceStatusProtocol methods

-(void)didReceiveServiceStatus:(NSNotification*)notification {
    NSNumber *status = notification.object;
    self.serviceStatus = status.boolValue ? @"Running" : @"Stopped";
}


@end
