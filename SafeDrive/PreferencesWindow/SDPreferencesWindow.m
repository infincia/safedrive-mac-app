
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDPreferencesWindow.h"
#import <INAppStoreWindow/INAppStoreWindow.h>
#import "SDSystemAPI.h"

@interface SDPreferencesWindow ()
@property SDSystemAPI *sharedSystemAPI;
@end

@implementation SDPreferencesWindow

/* 
    custom getter and setter for this property as it isn't local state, it's 
    system info to be set and retrieved dynamically using SDSystemAPI

*/
@dynamic autostart;

-(instancetype)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    self.sharedSystemAPI = [SDSystemAPI sharedAPI];

    self.volumeMountState = @"";
    self.volumeTotalSpace = @"";
    self.volumeFreeSpace = @"";
    
    // register SDVolumeEventProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateDetails:) name:SDMountStateDetailsNotification object:nil];

    // register SDMountStateProtocol notifications
    #warning Keep track of these SDMountStateProtocol requirements!!!
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateMounted:) name:SDMountStateMountedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountStateUnmounted:) name:SDMountStateUnmountedNotification object:nil];

    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

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
        self.volumeTotalSpace = mountDetails[NSURLVolumeTotalCapacityKey];
        self.volumeFreeSpace = mountDetails[NSURLVolumeAvailableCapacityKey];
    }
    else {
        self.volumeTotalSpace = nil;
        self.volumeFreeSpace = nil;
    }
}

@end
