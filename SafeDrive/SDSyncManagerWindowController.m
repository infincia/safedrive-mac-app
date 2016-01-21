
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSyncManagerWindowController.h"

#import "SDSystemAPI.h"
#import "SDAPI.h"

#import "SDAccountController.h"
#import "SDSyncController.h"

#import "SDSyncTableRowView.h"
#import "SDSyncTableCellView.h"

#import "SDSyncItem.h"

#import "NSURL+SFTP.h"

@interface NSFileManager (EmptyDirectoryAtURL)
- (BOOL)isEmptyDirectoryAtURL:(NSURL*)url;
@end

@implementation NSFileManager (EmptyDirectoryAtURL)

- (BOOL)isEmptyDirectoryAtURL:(NSURL*)url {
  return ([[self contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:NULL] count] <= 1);
}

@end

@interface SDSyncManagerWindowController ()
@property SDSystemAPI *sharedSystemAPI;
@property SDAPI *sharedSafedriveAPI;

@property SDAccountController *accountController;
@property SDSyncController *syncController;

@property SDSyncItem *mac;
@end

@implementation SDSyncManagerWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
}

-(void)awakeFromNib {
    //[self.syncListView expandItem:nil expandChildren:YES];
}

-(instancetype)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        self.sharedSystemAPI = [SDSystemAPI sharedAPI];
        self.sharedSafedriveAPI = [SDAPI sharedAPI];

        self.accountController = [SDAccountController sharedAccountController];
        self.syncController = [SDSyncController sharedAPI];
        self.mac = [SDSyncItem itemWithLabel:@"Mac" localFolder:nil isMachine:YES uniqueID:-1];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSignIn:) name:SDAccountSignInNotification object:nil];

        return self;
    }
    return nil;
}

#pragma mark -
#pragma mark - Actions

-(IBAction)startSyncItemNow:(id)sender {
    NSButton *button = sender;
    NSInteger uniqueID = button.tag;
    SDLog(@"Starting sync for folder ID: %lu", uniqueID);
    
    SDSyncItem *folder = [self.mac syncFolderForUniqueId:uniqueID];
    folder.syncing = YES;
    NSString *folderName = folder.label;
    NSURL *localFolder = folder.url;
    
    NSURL *defaultFolder = [NSURL URLWithString:SDDefaultServerPath];
    NSURL *machineFolder = [defaultFolder URLByAppendingPathComponent:[[NSHost currentHost] localizedName] isDirectory:YES];
    NSURL *remoteFolder = [machineFolder URLByAppendingPathComponent:folderName isDirectory:YES];
    SDLog(@"Remote path: %@", remoteFolder);
    
    NSURL *remote = [NSURL SFTPURLForAccount:self.accountController.internalUserName host:self.accountController.remoteHost port:self.accountController.remotePort path:remoteFolder.path];
    [self.syncListView reloadItem:self.mac reloadChildren:YES];
    [self.syncController startSyncTaskWithLocalURL:localFolder serverURL:remote password:self.accountController.password restore:NO success:^(NSURL *syncURL, NSError *syncError) {
        SDLog(@"Sync finished for local URL: %@", localFolder);
        folder.syncing = NO;
        [self.syncListView reloadItem:self.mac reloadChildren:YES];
        
    } failure:^(NSURL *syncURL, NSError *syncError) {
        SDErrorHandlerReport(syncError);
        SDLog(@"Sync failed for local URL: %@", localFolder);
        SDLog(@"Sync error: %@", syncError.localizedDescription);
        folder.syncing = NO;
        [self.syncListView reloadItem:self.mac reloadChildren:YES];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Error", nil);
        alert.informativeText = syncError.localizedDescription;
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        [alert runModal];
    }];
}

-(IBAction)addSyncFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setDelegate:self];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanCreateDirectories:YES];
    NSString *panelTitle = NSLocalizedString(@"Select a folder", @"Title of window");
    [panel setTitle:panelTitle];
 
    NSString *promptString = NSLocalizedString(@"Select", @"Button title");
    [panel setPrompt:promptString];
    [panel beginWithCompletionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self.spinner startAnimation:self];
            [self.sharedSafedriveAPI createSyncFolder:panel.URL success:^(NSNumber *folderID) {
                [self readSyncFolders:nil];
            } failure:^(NSError *apiError) {
                SDErrorHandlerReport(apiError);
                [self.spinner stopAnimation:self];

                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = NSLocalizedString(@"Error", nil);
                alert.informativeText = apiError.localizedDescription;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
                [alert runModal];
            }];
            
        }
    }];
    
}

-(IBAction)removeSyncFolder:(id)sender {
    NSButton *button = sender;
    NSInteger uniqueID = button.tag;
    SDLog(@"Deleting sync folder ID: %lu", uniqueID);
    [self.spinner startAnimation:self];

    [self.sharedSafedriveAPI deleteSyncFolder:@(uniqueID) success:^{
        SDSyncItem *folder = [self.mac syncFolderForUniqueId:uniqueID];
        [self.mac removeSyncFolder:folder];
        [self.syncListView setSortDescriptors:@[
            [NSSortDescriptor sortDescriptorWithKey:@"label" ascending:YES selector:@selector(compare:)]
        ]];
        [self.syncListView reloadItem:self.mac reloadChildren:YES];
        [self.syncListView expandItem:self.mac expandChildren:YES];
        [self.spinner stopAnimation:self];

    } failure:^(NSError *apiError) {
        SDErrorHandlerReport(apiError);
        [self.spinner stopAnimation:self];

        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Error", nil);
        alert.informativeText = apiError.localizedDescription;
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        [alert runModal];
    }];
}

-(IBAction)readSyncFolders:(id)sender {
    [self.spinner startAnimation:self];
    [self.sharedSafedriveAPI readSyncFoldersWithSuccess:^(NSArray *folders) {
        [self.mac.syncFolders removeAllObjects];
        for (NSDictionary *folder in folders) {
        /*
            Current sync folder model:
         
            "id" : 1,
            "folderName" : "Music",
            "folderPath" : /Volumes/MacOS/Music,
            "addedDate" : 1435864769463
        */
            NSString *folderName = folder[@"folderName"];
            NSString *folderPath = folder[@"folderPath"];
            NSNumber *folderId = folder[@"id"];
            // unused: NSNumber *addedDate = folder[@"addedDate"];
            
            NSURL *localFolder = [NSURL fileURLWithPath:folderPath isDirectory:YES];
            
            SDSyncItem *folder = [SDSyncItem itemWithLabel:folderName localFolder:localFolder isMachine:NO uniqueID:folderId.integerValue];
            
            [self.mac appendSyncFolder:folder];
        }

        [self.syncListView setSortDescriptors:@[
            [NSSortDescriptor sortDescriptorWithKey:@"label" ascending:YES selector:@selector(compare:)]
        ]];
        [self.syncListView reloadItem:self.mac reloadChildren:YES];
        [self.syncListView expandItem:self.mac expandChildren:YES];
        [self.spinner stopAnimation:self];
    } failure:^(NSError *apiError) {
        SDErrorHandlerReport(apiError);
        [self.spinner stopAnimation:self];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Error", @"");        
        alert.informativeText = apiError.localizedDescription;
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        [alert runModal];
    }];
}

#pragma mark - SDAccountProtocol

-(void)didSignIn:(NSNotification *)notification {
    [self readSyncFolders:self];
}

-(void)didReceiveAccountDetails:(NSNotification *)notification {
    
}

-(void)didReceiveAccountStatus:(NSNotification *)notification {
    
}

#pragma mark - NSOpenPanelDelegate

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // check if the candidate sync path is actually writable and readable
    if (![fileManager isWritableFileAtPath:url.path]) {
        NSDictionary *errorInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Cannot select this directory, read/write permission denied", @"String informing the user that they do not have permission to read/write to the selected directory") };
    
        if (outError != NULL) *outError = [NSError errorWithDomain:SDErrorSyncDomain code:SDSystemErrorFilePermissionDenied userInfo:errorInfo];
        return NO;
    }  
    // check if the candidate sync path is a parent or subdirectory of an existing registered sync folder
    if ([self.mac hasConflictingFolderRegistered:url]) {
        NSDictionary *errorInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"Cannot select this directory, it is a parent or subdirectory of an existing sync folder", @"String informing the user that the selected folder is a parent or subdirectory of an existing sync folder") };
        
        if (outError != NULL) *outError = [NSError errorWithDomain:SDErrorSyncDomain code:SDSystemErrorFolderConflict userInfo:errorInfo];
        return NO;
    }
    
    return YES;
}


#pragma mark -
#pragma mark - NSOutlineView

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
    [self.mac.syncFolders sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"label" ascending:YES selector:@selector(compare:)]]];
    [self.syncListView reloadItem:self.mac reloadChildren:YES];
    [self.syncListView expandItem:self.mac expandChildren:YES];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    SDSyncItem *syncItem = (SDSyncItem *)item;
    return syncItem.isMachine;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return 1; // Root
    }
    SDSyncItem *syncItem = (SDSyncItem *)item;
    if (syncItem.isMachine) {
        return [syncItem.syncFolders count];
    }
    else return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return self.mac; // Root
    }
    SDSyncItem *syncItem = (SDSyncItem *)item;
    if (syncItem.isMachine) { 
        return syncItem.syncFolders[index];
    }
    else return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    SDSyncItem *syncItem = (SDSyncItem *)item;
    if (syncItem.isMachine) return YES;
    else return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    if ([self outlineView:outlineView isGroupItem:item]) return NO;
    else return YES;
}

//--------------------------
// Set Content & Icons
//--------------------------

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item {
    return NO;
}

-(BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(nonnull id)item {
    return NO;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item {
    SDSyncTableRowView *v = [[SDSyncTableRowView alloc] init];
    return v;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    SDSyncTableCellView *tableCellView;
    tableCellView.representedSyncItem = item;
    SDSyncItem *syncItem = (SDSyncItem *)item;
    if ([self outlineView:outlineView isGroupItem:item]) {
        tableCellView = [outlineView makeViewWithIdentifier:@"MachineView" owner:self];
        tableCellView.textField.stringValue = syncItem.label;
        NSImage *cellImage = [NSImage imageNamed: NSImageNameComputer];
        
        [cellImage setSize:NSMakeSize(15.0, 15.0)];
        
        tableCellView.imageView.image = cellImage;
    }
    else {
        tableCellView = [outlineView makeViewWithIdentifier:@"FolderView" owner:self];
        tableCellView.textField.stringValue = syncItem.label;
        
        NSImage * cellImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)];
        
        [cellImage setSize:NSMakeSize(15.0, 15.0)];
        
        tableCellView.imageView.image = cellImage;
        tableCellView.removeButton.tag = syncItem.uniqueID;
        tableCellView.syncNowButton.tag = syncItem.uniqueID;
        if (syncItem.isSyncing) {
            [tableCellView.syncStatus startAnimation:self];
            tableCellView.syncNowButton.enabled = NO;
            tableCellView.syncNowButton.hidden = YES;

        }
        else {
            [tableCellView.syncStatus stopAnimation:self];
            tableCellView.syncNowButton.enabled = YES;
            tableCellView.syncNowButton.hidden = NO;

        }
    }
    
    return tableCellView;
}

//--------------------------
// Selection tracking
//--------------------------

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    if ([self.syncListView selectedRow] != -1) {
        SDSyncItem *syncItem = [self.syncListView itemAtRow:[self.syncListView selectedRow]];
        // visually selecting specific sync folders in the list is disabled for now but this would be the place to
        // do something with them, like display recent sync info or folder stats in the lower window pane
    }
}

//--------------------------
// Right-click menu
//--------------------------

- (NSMenu*)outlineView:(NSOutlineView*)outlineView contextMenuForItem:(id)item {
    // No right click menu on sync folders right now
    return nil;
}


@end
