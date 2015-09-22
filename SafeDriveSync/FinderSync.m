
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//


#import "FinderSync.h"

@interface FinderSync ()
-(void)showMessage:(NSString *)title withBody:(NSString *)body;
@end

@implementation FinderSync

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
    
    return self;
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

