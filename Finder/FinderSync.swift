
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable file_length

import Cocoa
import Crashlytics
import FinderSync
import Realm
import RealmSwift

class FinderSync: FIFinderSync {
    
    
    var appConnection: NSXPCConnection?
    var serviceConnection: NSXPCConnection?
    
    let dbURL = storageURL().appendingPathComponent("sync.realm")
    
    var token: RealmSwift.NotificationToken?
    
    var syncFolders: Results<SyncFolder>?
    
    var toolbarMenu: NSMenu!
    var supportMenuItem: NSMenuItem!
    var preferenceMenuItem: NSMenuItem!
    var mountMenuItem: NSMenuItem!

    override init() {
        super.init()
        
        var config = Realm.Configuration()
        
        config.fileURL = dbURL
        config.schemaVersion = UInt64(SDCurrentRealmSchema)
        
        Realm.Configuration.defaultConfiguration = config
        // swiftlint:disable force_try
        let realm = try! Realm()
        // swiftlint:enable force_try
        self.syncFolders = realm.objects(SyncFolder.self)
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        // swiftlint:disable force_unwrapping
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusAvailable)!, label: "Idle", forBadgeIdentifier: "idle")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusPartiallyAvailable)!, label: "Syncing", forBadgeIdentifier: "syncing")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImageNameStatusUnavailable)!, label: "Error", forBadgeIdentifier: "error")
        // swiftlint:enable force_unwrapping

        FIFinderSyncController.default().directoryURLs = Set<URL>()
        DispatchQueue.global(qos: DispatchQoS.default.qosClass).async(execute: {() -> Void in
            self.serviceReconnectionLoop()
        })
        
        DispatchQueue.global(qos: DispatchQoS.default.qosClass).async(execute: {() -> Void in
            self.mountStateLoop()
        })
        
        token = self.syncFolders!.addNotificationBlock({ (changes) in
            switch changes {
            case .initial(_):
                break
            case .update(_, _, _, let modifications):
                var s = [URL]()
                
                for index in modifications {
                    let folder = self.syncFolders![index]

                    // swiftlint:disable force_unwrapping
                    let u = folder.url!
                    // swiftlint:enable force_unwrapping

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
        
        self.mountMenuItem = NSMenuItem(title: "Mount SafeDrive",
                                             action: #selector(FinderSync.toggleMountState(_:)),
                                             keyEquivalent: "")
        
        self.supportMenuItem = NSMenuItem(title: "SafeDrive Support",
                                             action: #selector(FinderSync.support(_:)),
                                             keyEquivalent: "")
        
        self.preferenceMenuItem = NSMenuItem(title: "SafeDrive Preferences",
                                             action: #selector(FinderSync.openPreferencesWindow(_:)),
                                             keyEquivalent: "")
        self.toolbarMenu = NSMenu()
        self.toolbarMenu.addItem(self.supportMenuItem)
        self.toolbarMenu.addItem(self.preferenceMenuItem)
        self.toolbarMenu.addItem(self.mountMenuItem)
        
    }
    
    // MARK: - Service handling
    
    func serviceReconnectionLoop() {
        outer: while true {
            if self.serviceConnection == nil {
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
            if self.appConnection == nil {
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
                    let app = a.remoteObjectProxyWithErrorHandler { error in
                        print("remote proxy error: \(error)")
                    } as! AppXPCProtocol
                    
                    app.ping({ _ -> Void in
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
    
    // MARK: - Mount handling
    
    func mountStateLoop() {
        DispatchQueue.global(qos: DispatchQoS.default.qosClass).async(execute: {() -> Void in
            while true {
                guard let a = self.appConnection else {
                    Thread.sleep(forTimeInterval: 1)
                    continue
                }
                let app = a.remoteObjectProxyWithErrorHandler { error in
                    print("remote proxy error: \(error)")
                } as! AppXPCProtocol
            
                app.getMountState({ (mounted) in
                    DispatchQueue.main.async(execute: {() -> Void in
                        if mounted {
                            self.mountMenuItem.title = "Unmount SafeDrive"
                        } else {
                            self.mountMenuItem.title = "Mount SafeDrive"
                        }
                        
                    })
                })
                
                Thread.sleep(forTimeInterval: 1)
            }
        })
    }
    
    // MARK: - Primary Finder Sync protocol methods
    
    override func beginObservingDirectory(at url: URL) {
        // The user is now seeing the container's contents.
        // If they see it in more than one view at a time, we're only told once.

    }
    
    
    override func endObservingDirectory(at url: URL) {
        // The user is no longer seeing the container's contents.

    }
    
    override func requestBadgeIdentifier(for url: URL) {
        guard let syncFolder = self.syncFolderForURL(url),
        let path = syncFolder.path else {
            print("error")
            return
        }
        
        var fileAttributes: [AnyHashable: Any]
        
        do {
            try fileAttributes = FileManager.default.attributesOfItem(atPath: url.path)
            print("Modified: \((fileAttributes[FileAttributeKey.modificationDate] as! Date))")
            print("Using \(path) for \( url.path) status")
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
        // swiftlint:disable force_unwrapping

        return NSImage(named: NSImageNameLockLockedTemplate)!
        // swiftlint:enable force_unwrapping

    }
    
    // swiftlint:disable force_unwrapping
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
            m = self.toolbarMenu
        }
        return m!
    }
    // swiftlint:enable force_unwrapping

    @IBAction func support(_ sender: AnyObject) {
        // swiftlint:disable force_unwrapping

        NSWorkspace.shared().open(URL(string: "https://safedrive.io/support")!)
        // swiftlint:enable force_unwrapping

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
            // swiftlint:disable force_unwrapping
            let url = folder.url!
            // swiftlint:enable force_unwrapping

            app.displayRestoreWindow(forURLs: [url])
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
    
    @IBAction func toggleMountState(_ sender: AnyObject) {
        guard let a = self.appConnection else {
            print("App connection not found")
            return
        }
        let app = a.remoteObjectProxyWithErrorHandler { error in
            print("remote proxy error: \(error)")
        } as! AppXPCProtocol
        
        app.toggleMountState()
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
            // swiftlint:disable force_unwrapping
            let registeredPath: String = item.path!
            // swiftlint:enable force_unwrapping

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
