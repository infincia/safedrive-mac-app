
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


#import "SafeDriveFinder.h"

#import "SDAppXPCProtocol.h"
#import "SDServiceXPCProtocol.h"

#import "SDSyncItem.h"

@interface SafeDriveFinder ()
@property NSXPCConnection *appConnection;
@property NSXPCConnection *serviceConnection;
@property NSSet <SDSyncItem*> *syncFolders;

-(void)showMessage:(NSString *)title withBody:(NSString *)body;
@end

@implementation SafeDriveFinder

- (instancetype)init {
    self = [super init];

    NSLog(@"%s launched from %@ ; compiled at %s", __PRETTY_FUNCTION__, [[NSBundle mainBundle] bundlePath], __TIME__);
    NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.io.safedrive.db"];
    NSLog(@"Group: %@", groupURL);
    
    // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameStatusAvailable] label:@"Idle" forBadgeIdentifier:@"idle"];
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameStatusPartiallyAvailable] label:@"Syncing" forBadgeIdentifier:@"syncing"];
    [[FIFinderSyncController defaultController] setBadgeImage:[NSImage imageNamed: NSImageNameStatusUnavailable] label:@"Error" forBadgeIdentifier:@"error"];
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
            self.serviceConnection = [self createServiceConnection];
            [[self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
                //NSLog(@"Error: %@", error);
            }] ping:^(NSString *reply) {
                NSLog(@"Ping reply from service: %@", reply);
            }];
            continue;
        }
        if (!self.appConnection) {
            FIFinderSyncController.defaultController.directoryURLs = [NSSet new];
            [[self.serviceConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
                //NSLog(@"Error: %@", error);
            }] getAppEndpoint:^(NSXPCListenerEndpoint *endpoint) {
                self.appConnection = [self createAppConnectionFromEndpoint:endpoint];
                [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
                    //NSLog(@"Error: %@", error);
                }] ping:^(NSString *reply) {
                    //NSLog(@"Ping reply from app: %@", reply);
                }];
            }];
        }
        else {
            [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
                //NSLog(@"Error: %@", error);
            }] getSyncFoldersWithReply:^(NSMutableArray<SDSyncItem *> *syncFolders) {
                NSMutableSet *s = [NSMutableSet new];
                [syncFolders enumerateObjectsUsingBlock:^(SDSyncItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [s addObject:obj.url];
                }];
                self.syncFolders = [NSSet setWithArray: syncFolders];
                FIFinderSyncController.defaultController.directoryURLs = s;
            }];
        }
        [NSThread sleepForTimeInterval:1];
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
                //NSLog(@"Service connection interrupted");
            }
        });
    };
    newConnection.invalidationHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                //NSLog(@"Service connection invalidated");
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
    NSSet *incomingClasses = [NSSet setWithObjects:[NSMutableArray class], [SDSyncItem class], nil];
    
    [appInterface setClasses:incomingClasses forSelector:@selector(getSyncFoldersWithReply:) argumentIndex:0 ofReply:YES];
    
    newConnection.remoteObjectInterface = appInterface;
    __weak typeof(self) weakSelf = self;
    newConnection.interruptionHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                //NSLog(@"App connection interrupted");
            }
        });
    };
    newConnection.invalidationHandler = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf) {
                //NSLog(@"App connection invalidated");
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
    //NSLog(@"beginObservingDirectoryAtURL:%@", url.filePathURL);
}


- (void)endObservingDirectoryAtURL:(NSURL *)url {
    // The user is no longer seeing the container's contents.
    //NSLog(@"endObservingDirectoryAtURL:%@", url.filePathURL);
}

- (void)requestBadgeIdentifierForURL:(NSURL *)url {
    SDSyncItem *syncFolder = [self syncFolderForURL:url];
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:&error];
    if (error != nil) {
        //NSLog(@"Error: %@", error.localizedDescription);
    }
    //NSLog(@"Modified: %@", [fileAttributes objectForKey:NSFileModificationDate]);
    
    //NSLog(@"Using %@ for %@ status", syncFolder.url.path, url.path);
    if (syncFolder != nil) {
        NSString* badgeIdentifier;
        if (syncFolder.isSyncing) {
            badgeIdentifier = @"syncing";
        }
        else {
            badgeIdentifier = @"idle";
        }
        [[FIFinderSyncController defaultController] setBadgeIdentifier:badgeIdentifier forURL:url];
    }
}

#pragma mark - Menu and toolbar item support

- (NSString *)toolbarItemName {
    return @"SafeDrive";
}

- (NSString *)toolbarItemToolTip {
    return @"SafeDrive";
}

- (NSImage *)toolbarItemImage {
    return [NSImage imageNamed:NSImageNameLockLockedTemplate];
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)whichMenu {
    //NSLog(@"Menu Kind: %lu", whichMenu);
    NSMenu *m = nil;
    switch (whichMenu) {
        case FIMenuKindContextualMenuForItems: /* contextual menu for one or more files/directories */
            m = [[NSMenu alloc] init];
            [m addItemWithTitle:@"SafeDrive: Restore Items" action:@selector(restoreItems:) keyEquivalent:@""];
            break;
        case FIMenuKindContextualMenuForContainer: /* contextual menu for the directory being displayed */
            m = [[NSMenu alloc] init];
            [m addItemWithTitle:@"SafeDrive: Restore Folder" action:@selector(restoreItems:) keyEquivalent:@""];
            break;
        case FIMenuKindContextualMenuForSidebar: /* contextual menu for an item in the sidebar */
            break;
        case FIMenuKindToolbarItemMenu: 
            m = [[NSMenu alloc] init];
            [m addItemWithTitle:@"SafeDrive Support" action:@selector(support:) keyEquivalent:@""];
            [m addItemWithTitle:@"SafeDrive Sync Preferences" action:@selector(openRestoreWindow:) keyEquivalent:@""];
            [m addItemWithTitle:@"SafeDrive Preferences Window" action:@selector(openPreferencesWindow:) keyEquivalent:@""];
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

    //NSLog(@"restoreItems: menu item: %@, target = %@, items = ", [sender title], [target filePathURL]);
    [items enumerateObjectsUsingBlock: ^(id obj, NSUInteger idx, BOOL *stop) {
        //NSLog(@"%@", [obj path]);
    }];
}

- (IBAction)openRestoreWindow:(id)sender {
    [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
        //NSLog(@"Error: %@", error);
    }] displayRestoreWindowForURLs:@[]];
}

- (IBAction)openPreferencesWindow:(id)sender {
    [[self.appConnection remoteObjectProxyWithErrorHandler:^(NSError * error) {
        //NSLog(@"Error: %@", error);
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

-(SDSyncItem  * _Nullable)syncFolderForURL:(NSURL *)url {
    for (SDSyncItem *item in self.syncFolders) {
        NSString *registeredPath = [item.url.path stringByExpandingTildeInPath];
        NSString *testPath = [url.path stringByExpandingTildeInPath];
        
        NSStringCompareOptions options = (NSAnchoredSearch | NSCaseInsensitiveSearch);
        
        // check if testPath is contained by this sync folder
        if ([testPath rangeOfString:registeredPath options:options].location != NSNotFound) {
            return item;
        }
    }
    return nil;
}

@end

