
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa
import SafeDriveSDK

class ValidateClientViewController: NSViewController {

    fileprivate var sdk = SafeDriveSDK.sharedSDK
    
    fileprivate weak var delegate: StateDelegate?
    
    fileprivate weak var viewDelegate: WelcomeViewDelegate?

    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!
    
    @IBOutlet fileprivate weak var clientList: NSTableView!
    
    @IBOutlet fileprivate weak var newClientButton: NSButton!
    
    @IBOutlet fileprivate weak var replaceClientButton: NSButton!
    
    var clients: [SoftwareClient]?
    
    fileprivate var prompted = false
    
    fileprivate var email: String?
    
    fileprivate var password: String?
    
    var hasRegisteredClients = NSNumber(value: 0)

    fileprivate var isClientRegistered = false
    
    override func viewDidLoad() {
        if #available(OSX 10.10, *) {
            super.viewDidLoad()
        } else {
            // Fallback on earlier versions
        }
        // Do view setup here.
    }
    
    override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    convenience init(delegate: StateDelegate, viewDelegate: WelcomeViewDelegate) {
        // swiftlint:disable force_unwrapping
        self.init(nibName: "ValidateClientView", bundle: nil)!
        // swiftlint:enable force_unwrapping

        self.delegate = delegate
        
        self.viewDelegate = viewDelegate
    }
    
    func reset() {
        self.email = nil
        self.password = nil
        self.prompted = false
        self.spinner.stopAnimation(self)
        self.clients = nil
        self.hasRegisteredClients = NSNumber(value: 0)
        self.isClientRegistered = false
    }
    
    func check(email: String, password: String, clients: [SoftwareClient]) {
        self.reset()
        
        SDLog("checking client")

        self.email = email
        self.password = password
        
        self.clients = clients
        self.hasRegisteredClients = NSNumber(value: clients.count)
        SDLog("have clients: \(self.hasRegisteredClients)")
        self.clientList.reloadData()
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
            
            let host = Host()
            // swiftlint:disable force_unwrapping
            let machineName = host.localizedName!
            // swiftlint:enable force_unwrapping
            
            if let uniqueClientID = try? SafeDriveSDK.sharedSDK.getKeychainItem(withUser: email, service: UCIDDomain()) {
                SDLog("valid client found, continuing")

                DispatchQueue.main.async {
                    self.delegate?.didValidateClient(withEmail: email, password: password, name: machineName, uniqueClientID: uniqueClientID)
                }
                return
            }
            
            while !self.isClientRegistered {
                if !self.prompted {
                    self.prompted = true
                    DispatchQueue.main.async {
                        self.delegate?.needsClient()
                    }
                }
                Thread.sleep(forTimeInterval: 1)
            }
            SDLog("valid client found, continuing")
        }
    }
    
    @IBAction func newClient(_ sender: AnyObject?) {
        SDLog("setting up client as new")
        guard let email = self.email,
              let password = self.password else {
                let error = SDError(message: "API contract invalid", kind: .apiContractInvalid)
                
            self.delegate?.didFail(error: error, uniqueClientID: nil)
            return
        }
        
        let uniqueClientID = self.sdk.generateUniqueClientID()
        let host = Host()
        // swiftlint:disable force_unwrapping
        let machineName = host.localizedName!
        // swiftlint:enable force_unwrapping
        DispatchQueue.main.async {
            self.delegate?.didValidateClient(withEmail: email, password: password, name: machineName, uniqueClientID: uniqueClientID)
        }
    }
    
    @IBAction func replaceClient(_ sender: AnyObject?) {
        SDLog("replacing client")

        guard let clients = self.clients else {
            return
        }
        
        let sindex = self.clientList.selectedRow
        
        guard sindex >= 0 else {
            return
        }
        
        let client = clients[sindex]
        
        SDLog("client \(client.uniqueClientID) being replaced")
        
        guard let email = self.email,
              let password = self.password else {
                let error = SDError(message: "An unknown error occurred, contact support", kind: .unknown)

            self.delegate?.didFail(error: error, uniqueClientID: client.uniqueClientID)
            return
        }

        let host = Host()
        // swiftlint:disable force_unwrapping
        let machineName = host.localizedName!
        // swiftlint:enable force_unwrapping
        
        self.delegate?.didValidateClient(withEmail: email, password: password, name: machineName, uniqueClientID: client.uniqueClientID)
    }
}

extension ValidateClientViewController: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 else {
            return nil
        }
        guard let clients = self.clients else {
            return nil
        }
        
        let view = tableView.make(withIdentifier: "SoftwareClientTableCellView", owner: self) as! SoftwareClientTableCellView
        
        let client = clients[row]

        view.softwareClient = client
        view.uniqueClientID.stringValue = client.uniqueClientID
        //view.icon.image = client.icon
        
        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let clients = self.clients else {
            return 0
        }
        return clients.count
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        return 1
    }
}

extension ValidateClientViewController:  NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let i = clientList.selectedRow
        
        guard let view = clientList.view(atColumn: 0, row: i, makeIfNecessary: false) as? SoftwareClientTableCellView else {
            return
        }
        
        _ = view.softwareClient
        
    }
}
