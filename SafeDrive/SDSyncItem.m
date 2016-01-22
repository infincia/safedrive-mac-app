
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

#import "SDSyncItem.h"

@implementation SDSyncItem

-(instancetype)init {
    self = [super init];
    if (self) {
        self.syncFolders = [NSMutableArray new];
        self.syncing = NO;
        return self;
    }
    return nil;
}

- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        self.label = [coder decodeObjectOfClass:[NSString class] forKey:@"label"];
        self.isMachine = [coder decodeBoolForKey:@"isMachine"];
        self.uniqueID = [coder decodeIntegerForKey:@"uniqueID"];
        self.url = [coder decodeObjectOfClass:[NSURL class] forKey:@"url"];
        self.syncing = [coder decodeBoolForKey:@"syncing"];
        NSSet *syncFolderClasses = [NSSet setWithObjects:[NSMutableArray class], [SDSyncItem class], nil];
        self.syncFolders = [coder decodeObjectOfClasses:syncFolderClasses forKey:@"syncFolders"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.label forKey:@"label"];
    [coder encodeBool:self.isMachine forKey:@"isMachine"];
    [coder encodeInteger:self.uniqueID forKey:@"uniqueID"];
    [coder encodeObject:self.url forKey:@"url"];
    [coder encodeBool:self.syncing forKey:@"syncing"];
    [coder encodeObject:self.syncFolders forKey:@"syncFolders"];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

+(instancetype)itemWithLabel:(NSString *)label localFolder:(NSURL *)url isMachine:(BOOL)isMachine uniqueID:(NSInteger)uniqueID {
    SDSyncItem *item = [[SDSyncItem alloc] init];
    if (item) {
        item.label = label;
        item.isMachine = isMachine;
        item.uniqueID = uniqueID;
        item.url = url;
        return item;
    }
    return nil;
}

-(void)appendSyncFolder:(SDSyncItem *)item {
    [self.syncFolders addObject:item];
}

-(void)removeSyncFolder:(SDSyncItem *)item {
    [self.syncFolders removeObject:item];
}

-(instancetype)syncFolderForUniqueId:(NSInteger)uniqueID {
    SDSyncItem *syncItem = nil;
    for (SDSyncItem *item in self.syncFolders) {
        if (item.uniqueID == uniqueID) {
            syncItem = item;
        }
    }
    return syncItem;
}

-(BOOL)hasConflictingFolderRegistered:(NSURL *)testFolder {
    for (SDSyncItem *item in self.syncFolders) {
        NSString *registeredPath = [item.url.path stringByExpandingTildeInPath];
        NSString *testPath = [testFolder.path stringByExpandingTildeInPath];
        
        NSStringCompareOptions options = (NSAnchoredSearch | NSCaseInsensitiveSearch);
        
        // check if testFolder is a parent or subdirectory of an existing folder
        if ([testPath rangeOfString:registeredPath options:options].location != NSNotFound) {
            return YES;
        }
        if ([registeredPath rangeOfString:testPath options:options].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

@end
