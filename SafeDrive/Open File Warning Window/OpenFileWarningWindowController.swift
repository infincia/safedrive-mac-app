//
//  OpenFileWarningWindowController.swift
//  SafeDrive
//
//  Created by steve on 2/21/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Cocoa

protocol OpenFileWarningDelegate: class {
    func closeApplication(_ process: RunningProcess)
    func runningProcesses() -> [RunningProcess]
    func blockingProcesses(_ url: URL) -> [RunningProcess]
    func tryAgain()
    func finished()
}

protocol OpenFileReactor: class {
    func didTerminate(_ notification: Notification)
}

extension OpenFileWarningWindowController: OpenFileReactor {
    @objc func didTerminate(_ notification: Notification) {
        if !self.shouldCheckRunning {
            return
        }

        if let userInfo = notification.userInfo,
            let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            
            let pid = app.processIdentifier
            let index = self.processes.index(where: { (process) -> Bool in
                process.pid == Int(pid)
            })
            if let i = index {
                self.processes.remove(at: i)
                self.processList.reloadData()
            }
        }
    }
}

extension OpenFileWarningWindowController: NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 else {
            return nil
        }
        
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "OpenFileWarningTableCellView"), owner: self) as! OpenFileWarningTableCellView
        
        let process = self.processes[row]
        
        view.name.stringValue = process.command
        view.processName = process.command
        view.processPID = process.pid
        view.closeApp.tag = process.pid
        
        view.icon.image = process.icon
        
        return view
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.processes.count
    }
    
    func numberOfSections(in tableView: NSTableView) -> Int {
        return 1
    }
}

extension OpenFileWarningWindowController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        let sessionIndex = processList.selectedRow
        
        guard let _ = processList.view(atColumn: 0, row: sessionIndex, makeIfNecessary: false) as? OpenFileWarningTableCellView else {
            return
        }
        
    }
}


class OpenFileWarningWindowController: NSWindowController {
    @IBOutlet fileprivate weak var spinner: NSProgressIndicator!

    @IBOutlet fileprivate weak var processList: NSTableView!
    
    fileprivate weak var openFileWarningDelegate: OpenFileWarningDelegate!
    
    fileprivate var processes = [RunningProcess]()
    
    fileprivate var _shouldCheckRunning = false
    
    fileprivate var url: URL!
    
    fileprivate let checkQueue = DispatchQueue(label: "io.safedrive.checkQueue")
    
    var shouldCheckRunning: Bool {
        get {
            var r: Bool = false
            checkQueue.sync {
                r = self._shouldCheckRunning
            }
            return r
        }
        set (newValue) {
            checkQueue.sync(flags: .barrier, execute: {
                self._shouldCheckRunning = newValue
            })
        }
    }
    
    
    convenience init() {
        self.init(windowNibName: NSNib.Name(rawValue: "OpenFileWarningWindow"))
    }
    
    
    convenience init(delegate: OpenFileWarningDelegate) {
        self.init(windowNibName: NSNib.Name(rawValue: "OpenFileWarningWindow"))
        self.openFileWarningDelegate = delegate
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(didTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        // swiftlint:disable force_unwrapping
        _ = self.window!
        // swiftlint:enable force_unwrapping
        self.checkLoop()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        if let w = self.window as? FlatWindow {
            w.keepOnTop = true
        }
    }
    
    func check(url: URL) {
        main {
            if !self.shouldCheckRunning {
                self.shouldCheckRunning = true
                self.showWindow(self)
                self.spinner.startAnimation(self)
                self.url = url
            }
        }
    }
    
    func stop() {
        main {
            self.close()
            self.shouldCheckRunning = false
            self.spinner.stopAnimation(self)
        }
    }
    
    fileprivate func checkLoop() {
        background {
            while true {
                Thread.sleep(forTimeInterval: 1)

                if self.shouldCheckRunning {
                    SDLog("checking for running processes")

                    let runningProcesses = self.openFileWarningDelegate.runningProcesses()
                    let blockingProcesses = self.openFileWarningDelegate.blockingProcesses(self.url)

                    let runningSet = Set<RunningProcess>(runningProcesses)
                    let blockingSet = Set<RunningProcess>(blockingProcesses)
                    let processesToClose = Array(blockingSet.intersection(runningSet))

                    SDLog("volume \(self.url.lastPathComponent) has \(blockingProcesses.count) blocking processes")
                    
                    SDLog("volume \(self.url.lastPathComponent) has \(processesToClose.count) processes with open files")
                    DispatchQueue.main.sync {
                        self.spinner.stopAnimation(self)

                        if processesToClose.count == 0 {
                            SDLog("volume \(self.url.path) is safe do disconnect now")
                            self.openFileWarningDelegate?.tryAgain()
                            self.shouldCheckRunning = false
                            self.close(nil)
                            return
                        }
                        self.processes = processesToClose
                        self.processList.reloadData()
                    }
                } else {
                    DispatchQueue.main.sync {
                        self.spinner.stopAnimation(self)
                        if self.processes.count >= 1 {
                            self.processes.removeAll()
                            self.processList.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func close(_ sender: AnyObject?) {
        self.shouldCheckRunning = false
        self.openFileWarningDelegate?.finished()
    }
    
    
    @IBAction func closeApp(_ sender: AnyObject) {
        let b = sender as! NSButton
        
        if let index = self.processes.index(where: { (process) -> Bool in
            process.pid == b.tag
        }) {
            let process = self.processes[index]
            self.openFileWarningDelegate?.closeApplication(process)
        }
    }
    
    @IBAction func closeAllApps(_ sender: AnyObject) {
        for process in self.processes {
            self.openFileWarningDelegate?.closeApplication(process)
        }
    }
    
    @IBAction func forceUnmount(_ sender: AnyObject) {
        let driveURL = MountController.shared.currentMountURL
        ServiceManager.sharedServiceManager.forceUnmountSafeDrive(driveURL.path, {
            self.close(nil)
            NotificationCenter.default.post(name: Notification.Name.volumeDidUnmount, object: nil)
        }, { (error) in
            let notification = NSUserNotification()
            
            notification.identifier = "drive-force-unmount-failed"
            
            notification.title = "SafeDrive force unmount failed"
            
            notification.informativeText = error.localizedDescription
            
            notification.soundName = NSUserNotificationDefaultSoundName
            
            NSUserNotificationCenter.default.deliver(notification)
        })
    }
}
