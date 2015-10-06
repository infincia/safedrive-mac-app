
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


#import "SafeDriveFinder.h"

#import "SDAppXPCProtocol.h"
#import "SDServiceXPCProtocol.h"

@interface SafeDriveFinder ()
@property NSXPCConnection *appConnection;
@property NSXPCConnection *serviceConnection;

-(void)showMessage:(NSString *)title withBody:(NSString *)body;
@end

@implementation SafeDriveFinder

- (instancetype)init {
    self = [super init];

    NSLog(@"%s launched from %@ ; compiled at %s", __PRETTY_FUNCTION__, [[NSBundle mainBundle] bundlePath], __TIME__);    
    
    // hardcoded for testing, paths to monitor will be retrieved via IPC
    NSURL *u = [NSURL fileURLWithPath:@"/Users/Shared/SafeDrive"];
    NSSet *s = [NSSet setWithObject:u];
    
    FIFinderSyncController.defaultController.directoryURLs = s;

    // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameStatusAvailable] label:@"Available" forBadgeIdentifier:@"available"];
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameStatusPartiallyAvailable] label:@"Partially Available" forBadgeIdentifier:@"partially_available"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self serviceReconnectionLoop];
    });
    return self;
}

#pragma mark - XPC Connection Management

-(void)serviceReconnectionLoop {
    for (;;) {
        //[self ensureServiceIsRunning];
        if (!self.serviceConnection) {
            NSLog(@"Service connection not found, creating");
            self.serviceConnection = [self createServiceConnection];
            [[self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                NSLog(@"Error: %@", error);
            }] ping:^(NSString *reply) {
                NSLog(@"Ping reply from service: %@", reply);
            }];
            continue;
        }
        if (!self.appConnection) {
            NSLog(@"App connection not found, creating");
            [[self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                NSLog(@"Error: %@", error);
            }] getAppEndpoint:^(NSXPCListenerEndpoint *endpoint) {
                NSLog(@"Got app endpoint from service");
                self.appConnection = [self createAppConnectionFromEndpoint:endpoint];
            }];
            [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
                NSLog(@"Error: %@", error);
            }] ping:^(NSString *reply) {
                NSLog(@"Ping reply from app: %@", reply);
            }];
        }
        [NSThread sleepForTimeInterval:5];
    }
}

#pragma mark - Service XPC Connection 

-(NSXPCConnection *)createServiceConnection {
    NSXPCConnection *newConnection = [[NSXPCConnection alloc] initWithMachServiceName:@"io.safedrive.SafeDrive.Service" options:0];
    NSXPCInterface *serviceInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SDServiceXPCProtocol)];
    newConnection.remoteObjectInterface = serviceInterface;
    __weak typeof(self) weakSelf = self;
    newConnection.interruptionHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                NSLog(@"Service connection interrupted");
            }
        });
    };
    newConnection.invalidationHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                NSLog(@"Service connection invalidated");
                weakSelf.serviceConnection = nil;
            }
        });
    };
    [newConnection resume];
    return newConnection;
}

#pragma mark - App XPC Connection

-(NSXPCConnection *)createAppConnectionFromEndpoint:(NSXPCListenerEndpoint *)endpoint {
    NSXPCConnection *newConnection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
    NSXPCInterface *appInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SDAppXPCProtocol)];
    newConnection.remoteObjectInterface = appInterface;
    __weak typeof(self) weakSelf = self;
    newConnection.interruptionHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                NSLog(@"App connection interrupted");
            }
        });
    };
    newConnection.invalidationHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                NSLog(@"App connection invalidated");
                weakSelf.appConnection = nil;
            }
        });
    };
    [newConnection resume];
    return newConnection;
}

#pragma mark - Primary Finder Sync protocol methods

- (void)beginObservingDirectoryAtURL:(NSURL *)url {
    // The user is now seeing the container's contents.
    // If they see it in more than one view at a time, we're only told once.
    NSLog(@"beginObservingDirectoryAtURL:%@", url.filePathURL);
}


- (void)endObservingDirectoryAtURL:(NSURL *)url {
    // The user is no longer seeing the container's contents.
    NSLog(@"endObservingDirectoryAtURL:%@", url.filePathURL);
}

- (void)requestBadgeIdentifierForURL:(NSURL *)url {
    NSLog(@"requestBadgeIdentifierForURL:%@", url.filePathURL);
    
    NSInteger whichBadge = [url.filePathURL hash] % 2;
    NSString* badgeIdentifier = @[@"available", @"partially_available"][whichBadge];
    [[FIFinderSyncController defaultController] setBadgeIdentifier:badgeIdentifier forURL:url];
}

#pragma mark - Menu and toolbar item support

- (NSString *)toolbarItemName {
    return @"SafeDrive";
}

- (NSString *)toolbarItemToolTip {
    return @"SafeDrive";
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameNetwork];
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)whichMenu {
    NSLog(@"Menu Kind: %lu", whichMenu);
    NSMenu *m = nil;
    switch (whichMenu) {
        case FIMenuKindContextualMenuForItems: /* contextual menu for one or more files/directories */
            m = [[NSMenu alloc] init];
            [m addItemWithTitle:@"SafeDrive: Restore Items" action:@selector(restoreItems:) keyEquivalent:@"R"];
            break;
        case FIMenuKindContextualMenuForContainer: /* contextual menu for the directory being displayed */
            break;
        case FIMenuKindContextualMenuForSidebar: /* contextual menu for an item in the sidebar */
            break;
        case FIMenuKindToolbarItemMenu: 
            m = [[NSMenu alloc] init];
            [m addItemWithTitle:@"SafeDrive Support" action:@selector(support:) keyEquivalent:@"S"];
            [m addItemWithTitle:@"SafeDrive Restore Window" action:@selector(openRestoreWindow:) keyEquivalent:@"O"];
            [m addItemWithTitle:@"SafeDrive Preferences Window" action:@selector(openPreferencesWindow:) keyEquivalent:@"P"];
            break;     
            
        default:
            break;
    }
    return m;
}

#pragma mark - Main Actions

- (IBAction)support:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://safedrive.io/support"]];
}

#pragma mark - IPC Actions

- (IBAction)restoreItems:(id)sender {
    NSURL* target = [[FIFinderSyncController defaultController] targetedURL];
    NSArray* items = [[FIFinderSyncController defaultController] selectedItemURLs];

    NSLog(@"restoreItems: menu item: %@, target = %@, items = ", [sender title], [target filePathURL]);
    [items enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"    %@", [obj filePathURL]);
    }];
}

- (IBAction)openRestoreWindow:(id)sender {
    
}

- (IBAction)openPreferencesWindow:(id)sender {
    [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Error: %@", error);
    }] displayPreferencesWindow];
}

#pragma mark - Helpers

-(void)showMessage:(NSString *)title withBody:(NSString *)body {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = title;
        [alert addButtonWithTitle:@"OK"];

        alert.informativeText = body;
        if ([alert runModal]) {

        }
    });
}

@end

