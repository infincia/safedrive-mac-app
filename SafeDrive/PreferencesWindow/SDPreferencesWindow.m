
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDPreferencesWindow.h"

@interface SDPreferencesWindow ()

@end

@implementation SDPreferencesWindow

- (void)windowDidLoad {
    [super windowDidLoad];

    // register SDMountStatusProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mountSubprocessDidTerminate:) name:SDMountSubprocessDidTerminateNotification object:nil];

}

#pragma mark - SDMountStatusProtocol methods

-(void)volumeDidMount:(NSNotification*)notification {

}

-(void)volumeDidUnmount:(NSNotification*)notification {
    
}

-(void)mountSubprocessDidTerminate:(NSNotification *)notification {

}


@end
