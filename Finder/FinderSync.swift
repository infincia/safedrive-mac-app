
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

// swiftlint:disable force_cast
// swiftlint:disable file_length

import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    
    var appConnection: NSXPCConnection?
    var serviceConnection: NSXPCConnection?
    fileprivate var finderListener: NSXPCListener
    fileprivate weak var finderXPCDelegate: FinderXPCDelegate?

    var folders = [SDKSyncFolder]()
    
    var tasks = [SDKSyncTask]()
    
    var toolbarMenu: NSMenu!
    var supportMenuItem: NSMenuItem!
    var preferenceMenuItem: NSMenuItem!
    var mountMenuItem: NSMenuItem!
    
    var uniqueClientID: String?

    override init() {
        finderXPCDelegate = FinderXPCDelegate()
        finderListener = NSXPCListener.anonymous()
        
        super.init()
        
        finderListener.delegate = self
        finderListener.resume()
        
        // Set up images for our badge identifiers. For demonstration purposes, this uses off-the-shelf images.
        // swiftlint:disable force_unwrapping
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.Name.statusAvailable)!, label: "Idle", forBadgeIdentifier: "idle")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.Name.statusPartiallyAvailable)!, label: "Syncing", forBadgeIdentifier: "syncing")
        FIFinderSyncController.default().setBadgeImage(NSImage(named: NSImage.Name.statusUnavailable)!, label: "Error", forBadgeIdentifier: "error")
        // swiftlint:enable force_unwrapping

        FIFinderSyncController.default().directoryURLs = Set<URL>()
        
        self.serviceReconnectionLoop()
        
        self.mountMenuItem = NSMenuItem(title: "Mount SafeDrive",
                                             action: #selector(FinderSync.toggleMountState(_:)),
                                             keyEquivalent: "")
        
        self.supportMenuItem = NSMenuItem(title: "SafeDrive Support",
                                             action: #selector(FinderSync.support(_:)),
                                             keyEquivalent: "")
        
        self.preferenceMenuItem = NSMenuItem(title: "SafeDrive Preferences",
                                             action: #selector(FinderSync.openPreferencesWindow(_:)),
                                             keyEquivalent: "")
        
        let sep = NSMenuItem.separator()
        
        self.toolbarMenu = NSMenu()
        self.toolbarMenu.addItem(self.mountMenuItem)
        self.toolbarMenu.addItem(self.preferenceMenuItem)
        self.toolbarMenu.addItem(sep)
        self.toolbarMenu.addItem(self.supportMenuItem)
        
        // register SDAccountProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignIn), name: Notification.Name.accountSignIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didSignOut), name: Notification.Name.accountSignOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountStatus), name: Notification.Name.accountStatus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDAccountProtocol.didReceiveAccountDetails), name: Notification.Name.accountDetails, object: nil)
        
        // register SDApplicationEventProtocol notifications
        
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureClient), name: Notification.Name.applicationDidConfigureClient, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDApplicationEventProtocol.applicationDidConfigureUser), name: Notification.Name.applicationDidConfigureUser, object: nil)
        
        // register SDSyncEventProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDSyncEventProtocol.syncEvent), name: Notification.Name.syncEvent, object: nil)
        
        // register SDMountStateProtocol notifications
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountState), name: Notification.Name.mountState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SDMountStateProtocol.mountStateDetails), name: Notification.Name.mountDetails, object: nil)
        
    }
    
    // MARK: - Service handling
    
    func serviceReconnectionLoop() {
        background { [weak self] in
            while true {
                autoreleasepool {
                    if self?.serviceConnection == nil {
                        self?.serviceConnection = self?.createServiceConnection()
                        self?.enableMenuItems(false)
                        print("IPC connection created")
                    } else {
                        if self?.appConnection == nil {
                            FIFinderSyncController.default().directoryURLs = Set<URL>()
                            guard let s = self?.serviceConnection else {
                                Thread.sleep(forTimeInterval: 1)
                                return
                            }
                            let service = s.remoteObjectProxyWithErrorHandler { error in
                                print("remote proxy error: \(error)")
                            } as! IPCProtocol
                            
                            service.getAppEndpoint({ endpoint in
                                print("App endpoint received")
                                self?.appConnection = self?.createAppConnectionFromEndpoint(endpoint)
                            })
                        }
                    }

                    Thread.sleep(forTimeInterval: 1)
                }
            }
        }
    }
    
    func createServiceConnection() -> NSXPCConnection {
        let newConnection: NSXPCConnection = NSXPCConnection(machServiceName: "G738Z89QKM.io.safedrive.IPCService", options: NSXPCConnection.Options(rawValue: 0))
        
        let serviceInterface: NSXPCInterface = NSXPCInterface(with: IPCProtocol.self)
        
        newConnection.remoteObjectInterface = serviceInterface
        
        newConnection.interruptionHandler = {() -> Void in
            DispatchQueue.main.async {
                print("Service connection interrupted")
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                print("Service connection invalidated")
                self?.serviceConnection = nil
            }
        }
        
        newConnection.resume()
        return newConnection
    }
    
    func createAppConnectionFromEndpoint(_ endpoint: NSXPCListenerEndpoint) -> NSXPCConnection {
        let newConnection: NSXPCConnection = NSXPCConnection(listenerEndpoint: endpoint)
        
        let appInterface: NSXPCInterface = NSXPCInterface(with: AppXPCProtocol.self)
        
        newConnection.remoteObjectInterface = appInterface

        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                print("App connection invalidated")
                self?.appConnection = nil
            }
        }
        newConnection.resume()
        return newConnection
        
    }

    func configureClient(uniqueClientID: String?) {
        self.folders = [SDKSyncFolder]()
        
        guard let newID = uniqueClientID else {
            return
        }
        
        var needConfig = false
        
        if let existingID = self.uniqueClientID {
            if existingID != newID {
                needConfig = true
            }
        } else {
            needConfig = true
        }
        self.uniqueClientID = newID

        if !needConfig {
            return
        }

        /*        
        token = folders.addNotificationBlock({ (changes) in
            switch changes {
            case .initial:
                break
            case .update(_, _, _, let modifications):
                var s = [URL]()
                
                for index in modifications {
                    if let folders = self.syncFolders,
                        let folder = folders[safe: index],
                        let url = folder.url {
                    
                        s.append(url)
                        // force update of badges when top level folders change
                        self.requestBadgeIdentifier(for: url)
                    }
                }
                FIFinderSyncController.default().directoryURLs = Set<URL>(s)
                break
            case .error:
                break
            }
        })*/
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
        guard let folder = self.syncFolderForURL(url) else {
            print("error")
            return
        }
        
        var fileAttributes: [AnyHashable: Any]
        
        do {
            try fileAttributes = FileManager.default.attributesOfItem(atPath: url.path)
            print("Modified: \((fileAttributes[FileAttributeKey.modificationDate] as! Date))")
            print("Using \(folder.path) for \(url.path) status")
        } catch {
            print("error: \(error)")
        }
        var badgeIdentifier: String
        guard let task = self.tasks.first(where: { $0.folderID == folder.id }) else {
            badgeIdentifier = "idle"

            FIFinderSyncController.default().setBadgeIdentifier(badgeIdentifier, for: url)
            return
        }
        
        if task.syncing || task.restoring {
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

        return NSImage(named: NSImage.Name.lockLockedTemplate)!
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

        NSWorkspace.shared.open(URL(string: "https://safedrive.io/support")!)
        // swiftlint:enable force_unwrapping

    }
    
    @IBAction func restoreItems(_ sender: AnyObject) {
        guard let target: URL = FIFinderSyncController.default().targetedURL() else {
            return
        }
        // not using individual item urls yet
        //let items: [AnyObject] = FIFinderSyncController.defaultController().selectedItemURLs()!
        
        if let folder = self.syncFolderForURL(target) {
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
        DispatchQueue.main.async {
            let alert: NSAlert = NSAlert()
            alert.messageText = title
            alert.addButton(withTitle: "OK")
            alert.informativeText = body
            alert.runModal()
        }
    }
    
    func syncFolderForURL(_ url: URL) -> SDKSyncFolder? {
        for folder in folders {
            let registeredPath: String = folder.path

            let testPath: String = url.path
            let options: NSString.CompareOptions = [.anchored, .caseInsensitive]
            
            // check if testPath is contained by this sync folder
            if testPath.range(of: registeredPath, options: options) != nil {
                return folder
            }
        }
        return nil
    }
    
    func enableMenuItems(_ enabled: Bool) {
        self.supportMenuItem.isEnabled = enabled
        self.preferenceMenuItem.isEnabled = enabled
        self.mountMenuItem.isEnabled = enabled
    }
}

extension FinderSync: NSXPCListenerDelegate {
    
    // MARK: - Finder Listener Delegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        
        let finderInterface = NSXPCInterface(with: FinderXPCProtocol.self)
        newConnection.exportedInterface = finderInterface
        newConnection.exportedObject = self.finderXPCDelegate
        
        newConnection.resume()
        return true
        
    }
}

extension FinderSync: SDAccountProtocol {
    
    func didSignIn(notification: Notification) {
        self.enableMenuItems(true)
    }
    
    func didSignOut(notification: Notification) {
        self.enableMenuItems(false)
    }
    
    func didReceiveAccountDetails(notification: Notification) {
    }
    
    func didReceiveAccountStatus(notification: Notification) {
    }
    
}

extension FinderSync: SDMountStateProtocol {
    
    func mountState(notification: Notification) {
        guard let mounted = notification.object as? Bool else {
            return
        }
        
        if mounted {
            //self.connectMenuItem.title = NSLocalizedString("Disconnect", comment: "Menu title for disconnecting the volume")
            //self.menuBarImage = NSImage(named: NSImageNameLockUnlockedTemplate)
        } else {
            //self.connectMenuItem.title = NSLocalizedString("Connect", comment: "Menu title for connecting the volume")
            //self.menuBarImage = NSImage(named: NSImageNameLockLockedTemplate)
        }
    }
    
    func mountStateDetails(notification: Notification) {
        
    }
}

extension FinderSync: SDApplicationEventProtocol {
    
    func applicationDidConfigureClient(notification: Notification) {
        guard let uniqueClientID = notification.object as? String else {
            print("API contract invalid: applicationDidConfigureClient in FinderSync")
            
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.configureClient(uniqueClientID: uniqueClientID)
        }
        
    }
    
    func applicationDidConfigureUser(notification: Notification) {
        guard let _ = notification.object as? String else {
            print("API contract invalid: applicationDidConfigureUser in FinderSync")
            
            return
        }
    }
}
