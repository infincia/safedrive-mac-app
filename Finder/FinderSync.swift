
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import FinderSync

import Realm
import RealmSwift

class FinderSync: FIFinderSync {


    var appConnection: NSXPCConnection?
    var serviceConnection: NSXPCConnection?
    
    let dbURL = storageURL().appendingPathComponent("sync.realm")
    
    var token: RealmSwift.NotificationToken?
    
    var syncFolders: Results<SyncFolder>?
    
    override init() {
        super.init()

        var config = Realm.Configuration()
        
        config.fileURL = dbURL
        config.schemaVersion = 9
        
        Realm.Configuration.defaultConfiguration = config
        
        let realm = try! Realm()
        
        self.syncFolders = realm.objects(SyncFolder.self)
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusAvailable)!, label: "Idle", forBadgeIdentifier: "idle")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusPartiallyAvailable)!, label: "Syncing", forBadgeIdentifier: "syncing")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusUnavailable)!, label: "Error", forBadgeIdentifier: "error")
        
        FIFinderSyncController.default().directoryURLs = Set<URL>()
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {() -> Void in
            self.serviceReconnectionLoop()
        })
        
        token = self.syncFolders!.addNotificationBlock({ (changes) in
            switch changes {
            case .initial(_):
                break
            case .update(_, _, _, let modifications):
                var s = [URL]()
                
                for index in modifications {
                    let folder = self.syncFolders![index]
                    let u = folder.url!
                    s.append(u)
                    // force update of badges when top level folders change
                    self.requestBadgeIdentifier(for: u)
                }
                FIFinderSyncController.default().directoryURLs = Set<URL>(s)
                break
            case .error:
                break
            }
        })
        
    }
    
    // MARK: - Service handling
    
    func serviceReconnectionLoop() {
        outer: while true {
            if (self.serviceConnection == nil) {
                self.serviceConnection = self.createServiceConnection()
                guard let s = self.serviceConnection else {
                    Thread.sleep(forTimeInterval: 1)
                    continue outer
                }
                
                let service = s.remoteObjectProxyWithErrorHandler { error in
                    print("remote proxy error: %@", error)
                } as! ServiceXPCProtocol
                
                service.ping({ reply in
                    print("Ping reply from service: \(reply)")
                    
                })
            }
            if (self.appConnection == nil) {
                FIFinderSyncController.default().directoryURLs = Set<URL>()
                guard let s = self.serviceConnection else {
                    Thread.sleep(forTimeInterval: 1)
                    continue outer
                }
                let service = s.remoteObjectProxyWithErrorHandler { error in
                    print("remote proxy error: \(error)")
                } as! ServiceXPCProtocol
                
                service.getAppEndpoint({ endpoint in
                    self.appConnection = self.createAppConnectionFromEndpoint(endpoint)
                    guard let a = self.appConnection else {
                        Thread.sleep(forTimeInterval: 1)
                        return
                    }
                    let app = a.remoteObjectProxyWithErrorHandler() { error in
                        print("remote proxy error: \(error)")
                    } as! AppXPCProtocol
                    
                    app.ping( { reply -> Void in
                        //print("Ping reply from app: \(reply)");
                    })
                })
                
            }
            Thread.sleep(forTimeInterval: 1)
        }
    }
    
    func createServiceConnection() -> NSXPCConnection {
        let newConnection: NSXPCConnection = NSXPCConnection(machServiceName: "io.safedrive.SafeDrive.Service", options: NSXPCConnection.Options(rawValue: 0))
        
        let serviceInterface: NSXPCInterface = NSXPCInterface(with:ServiceXPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                //print("Service connection interrupted")
            })
        }
        
        newConnection.invalidationHandler = {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                //print("Service connection invalidated")
                self.serviceConnection = nil
            })
        }
        
        newConnection.resume()
        return newConnection
    }
    
    func createAppConnectionFromEndpoint(_ endpoint: NSXPCListenerEndpoint) -> NSXPCConnection {
        let newConnection: NSXPCConnection = NSXPCConnection(listenerEndpoint: endpoint)
        
        let appInterface: NSXPCInterface = NSXPCInterface(with:AppXPCProtocol.self)
        
        newConnection.remoteObjectInterface = appInterface
        
        
        newConnection.interruptionHandler = {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                //print("App connection interrupted")
                
            })
        }
        newConnection.invalidationHandler = {() -> Void in
            DispatchQueue.main.async(execute: {() -> Void in
                //print("App connection invalidated")
                self.appConnection = nil
                
            })
        }
        newConnection.resume()
        return newConnection
        
    }
    
    // MARK: - Primary Finder Sync protocol methods
    
    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.
        print("beginObservingDirectoryAtURL: %@", (url as NSURL).filePathURL!)
    }
    
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.
        print("endObservingDirectoryAtURL: %@", (url as NSURL).filePathURL!)
    }
    
    override func requestBadgeIdentifier(for url: URL) {
        guard let syncFolder = self.syncFolderForURL(url) else {
            print("error")
            return
        }
        
        var fileAttributes: [AnyHashable: Any]
        
        do {
            try fileAttributes = FileManager.default.attributesOfItem(atPath: url.path)
            print("Modified: \((fileAttributes[FileAttributeKey.modificationDate] as! Date))")
            print("Using \(syncFolder.path!) for \( url.path) status")
        } catch {
            print("error: \(error)")
        }
        var badgeIdentifier: String
        if syncFolder.syncing {
            badgeIdentifier = "syncing"
        } else {
            badgeIdentifier = "idle"
        }
        FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
        
    }
    
    // MARK: - Menu and toolbar item support
    
    override var toolbarItemName: String {
        return "SafeDrive"
    }
    
    override var toolbarItemToolTip: String {
        return "SafeDrive"
    }
    
    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImageNameLockLockedTemplate)!
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        var m: NSMenu? = nil
        switch menuKind {
        case .contextualMenuForItems:
            /* contextual menu for one or more files/directories */
            m = NSMenu()
            m!.addItem(withTitle: "SafeDrive: Restore Items", action: #selector(FinderSync.restoreItems(_:)), keyEquivalent: "")
        case .contextualMenuForContainer:
            /* contextual menu for the directory being displayed */
            m = NSMenu()
            m!.addItem(withTitle: "SafeDrive: Restore Folder", action: #selector(FinderSync.restoreItems(_:)), keyEquivalent: "")
        case .contextualMenuForSidebar:
            /* contextual menu for an item in the sidebar */
            break
        case .toolbarItemMenu:
            m = NSMenu()
            m!.addItem(withTitle: "SafeDrive Support", action: #selector(FinderSync.support(_:)), keyEquivalent: "")
            m!.addItem(withTitle: "SafeDrive Preferences", action: #selector(FinderSync.openPreferencesWindow(_:)), keyEquivalent: "")
        }
        return m!
    }
    
    @IBAction func support(_ sender: AnyObject) {
        NSWorkspace.shared().open(URL(string: "https://safedrive.io/support")!)
    }
    
    @IBAction func restoreItems(_ sender: AnyObject) {
        guard let target: URL = FIFinderSyncController.default().targetedURL() else {
            return
        }
        // not using individual item urls yet
        //let items: [AnyObject] = FIFinderSyncController.defaultController().selectedItemURLs()!
        
        let folder: SyncFolder? = self.syncFolderForURL(target)
        if let folder = folder {
            guard let a = self.appConnection else {
                print("App connection not found")
                return
            }
            let app = a.remoteObjectProxyWithErrorHandler { error in
                print("remote proxy error: \(error)")
            } as! AppXPCProtocol
            app.displayRestoreWindow(forURLs: [folder.url!])
        }
    }
    
    @IBAction func openRestoreWindow(_ sender: AnyObject) {
        guard let a = self.appConnection else {
            print("App connection not found")
            return
        }
        let app = a.remoteObjectProxyWithErrorHandler { error in
            print("remote proxy error: \(error)")
        } as! AppXPCProtocol

        app.displayRestoreWindow(forURLs: [])
    }
    
    @IBAction func openPreferencesWindow(_ sender: AnyObject) {
        guard let a = self.appConnection else {
            print("App connection not found")
            return
        }
        let app = a.remoteObjectProxyWithErrorHandler { error in
            print("remote proxy error: \(error)")
        } as! AppXPCProtocol
        
        app.displayPreferencesWindow()
    }
    
    func showMessage(_ title: String, withBody body: String) {
        DispatchQueue.main.async(execute: {() -> Void in
            let alert: NSAlert = NSAlert()
            alert.messageText = title
            alert.addButton(withTitle: "OK")
            alert.informativeText = body
            alert.runModal()
        })
    }
    
    func syncFolderForURL(_ url: URL) -> SyncFolder? {
        guard let syncFolders = try? Realm().objects(SyncFolder.self) else {
            return nil
        }
        for item: SyncFolder in syncFolders {
            
            let registeredPath: String = item.path!
            let testPath: String = url.path
            let options: NSString.CompareOptions = [.anchored, .caseInsensitive]
            
            // check if testPath is contained by this sync folder
            if testPath.range(of: registeredPath, options: options) != nil {
                return item
            }
        }
        return nil
    }
    
}
