//
//  OpenFileCheck.swift
//  SafeDrive
//
//  Created by steve on 2/21/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

class OpenFileCheck: NSObject {

    fileprivate var _processes = [RunningProcess]()
    
    fileprivate let checkQueue = DispatchQueue(label: "io.safedrive.checkQueue")
    
    fileprivate let processQueue = DispatchQueue(label: "io.safedrive.processQueue")
    
    fileprivate var processes: [RunningProcess] {
        get {
            var r: [RunningProcess]?
            processQueue.sync {
                r = self._processes
            }
            return r!
        }
        set (newValue) {
            processQueue.sync(flags: .barrier, execute: {
                self._processes = newValue
            })
        }
    }
    
    override init() {
        super.init()
    }
    
    public func check(volume: URL, success: @escaping ([RunningProcess]) -> Void) {
        self.processes = [RunningProcess]()
        
        SDLog("check(): looking for open files on volume: \(volume)")
        
        
        let task = Process()
        
        task.launchPath = "/usr/sbin/lsof"
        
        // MARK: - Set subprocess arguments
        
        var taskArguments = [String]()
        
        /* basic lsof options */
        taskArguments.append("-F")
        taskArguments.append("cfp")
        
        
        /* mount location */
        taskArguments.append(volume.path)
        
        task.arguments = taskArguments
        
        // MARK: - Set asynchronous block to handle subprocess stderr and stdout
        
        let outputPipe = Pipe()
        
        let outputPipeHandle = outputPipe.fileHandleForReading
        
        var err: NSError?
        
        outputPipeHandle.readabilityHandler = { (handle) in
            let outputString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
            
            SDLog("check(): lsof: \(outputString)")
            
            if outputString.contains("error") {
                err = NSError(domain: SDMountErrorDomain, code:SDMountError.unmountFailed.rawValue, userInfo:[NSLocalizedDescriptionKey: "Could not determine open files"])
                return
            }
            
            let fullRegex = "p([0-9]+)\\nc([0-9A-Za-z]+)\\nf([0-9A-Za-z]+)\\n*"
            
            if outputString.isMatched(byRegex: fullRegex) {
                
                if let matches = outputString.arrayOfCaptureComponentsMatched(byRegex: fullRegex) as [AnyObject]! {
                    SDLog("check(): \(matches.count) matches found")
                    for capturedValues in matches {
                        let process = capturedValues as! [String]
                        let pid = process[1]
                        let command = process[2]
                        var p = RunningProcess(pid: Int(pid)!, command: command)
                        for app in NSWorkspace.shared().runningApplications {
                            if p.pid == Int(app.processIdentifier) {
                                p.icon = app.icon
                                p.isUserApplication = true
                            }
                        }
                        if p.icon == nil {
                            let terminalIcon = NSWorkspace.shared().icon(forFile: "/Applications/Utilities/Terminal.app")
                            p.icon = terminalIcon
                            p.isUserApplication = false
                        }
                        
                        self.processes.append(p)
                        SDLog("check(): found process: <pid:\(pid), command:\(command)>")
                        
                    }
                }
            }
        }
        
        task.standardError = outputPipe
        task.standardOutput = outputPipe
        
        
        // MARK: - Set asynchronous block to handle subprocess termination
        
        
        /*
         clear the read and write blocks once the subprocess terminates, and then
         call the success block if no error occurred.
         
         */
        task.terminationHandler = { (task: Process) in
            outputPipeHandle.readabilityHandler = nil
            SDLog("check(): returning \(self.processes.count) processes still open")
            success(self.processes)
        }
        
        
        // MARK: - Launch subprocess and return
        
        task.launch()
    }
}