
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDAccountWindow.h"

@interface SDAccountWindow ()

@end

@implementation SDAccountWindow

- (void)windowDidLoad {
    [super windowDidLoad];

    // register SDMountStatusProtocol notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidMount:) name:SDVolumeDidMountNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeDidUnmount:) name:SDVolumeDidUnmountNotification object:nil];

}

#pragma mark - SDMountStatusProtocol methods

-(void)volumeDidMount:(NSNotification*)notification {

}

-(void)volumeDidUnmount:(NSNotification*)notification {

}


@end
