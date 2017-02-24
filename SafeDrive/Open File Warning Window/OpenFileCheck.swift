//
//  OpenFileCheck.swift
//  SafeDrive
//
//  Created by steve on 2/21/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

public struct RunningProcess {
    public let pid: Int
    public let command: String
    public var icon: NSImage?
    public var isUserApplication = false

    
    init(pid: Int, command: String) {
        self.pid = pid
        self.command = command
        self.icon = nil
    }
}

extension RunningProcess: Hashable {
    public var hashValue: Int {
        return pid.hashValue
    }

    public static func == (lhs: RunningProcess, rhs: RunningProcess) -> Bool {
        return lhs.pid == rhs.pid
    }
}

class OpenFileCheck: NSObject {

    static var shared = OpenFileCheck()


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
    
    public func close(pid: Int) {
        
        SDLog("Closing non-user application: \(pid)")
        
        let task = Process()
        
        task.launchPath = "/bin/kill"
        
        // MARK: - Set subprocess arguments
        
        var taskArguments = [String]()
        
        /* basic kill options */
        taskArguments.append("-KILL")
        taskArguments.append("\(pid)")
        
        task.arguments = taskArguments
        
        // MARK: - Launch subprocess and return
        
        task.launch()
        task.waitUntilExit()
    }
    
    public func check(volume: URL) -> [RunningProcess]? {
        var _p = [RunningProcess]()
        self.checkQueue.sync {
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
                            if process.count >= 3 {
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
            }
            
            
            // MARK: - Launch subprocess and return
            
            task.launch()
            task.waitUntilExit()
            
            SDLog("check(): returning \(self.processes.count) processes still open")
            _p = self.processes
        }
        return _p
    }
    
    public func runningProcesses() -> [RunningProcess] {
        var _p = [RunningProcess]()

        self.checkQueue.sync {
            self.processes = [RunningProcess]()

            SDLog("runningProcesses(): looking for running processes")
            
            let task = Process()
            
            task.launchPath = "/bin/ps"
            
            // MARK: - Set subprocess arguments
            
            var taskArguments = [String]()
            
            /* basic ps options */
            taskArguments.append("-c")
            
            task.arguments = taskArguments
            
            // MARK: - Set asynchronous block to handle subprocess stderr and stdout
            
            let outputPipe = Pipe()
            
            let outputPipeHandle = outputPipe.fileHandleForReading
            
            outputPipeHandle.readabilityHandler = { (handle) in
                let outputString: String! = String(data: handle.availableData, encoding: String.Encoding.utf8)
                //    28103        ttys000           0:02.46           -zsh
                SDLog("runningProcesses(): ps: \(outputString)")
                
                let fullRegex = "\\n*([0-9]+)\\s+([0-9A-Za-z]+)\\s*([0-9\\:\\.]+)\\s+([0-9A-Za-z\\-]+)\\n*"
                
                if outputString.isMatched(byRegex: fullRegex) {
                    
                    if let matches = outputString.arrayOfCaptureComponentsMatched(byRegex: fullRegex) as [AnyObject]! {
                        SDLog("runningProcesses(): \(matches.count) matches found")
                        
                        for capturedValues in matches {
                            let process = capturedValues as! [String]
                            if process.count >= 4 {
                                let pid = process[1]
                                let command = process[4]
                                var p = RunningProcess(pid: Int(pid)!, command: command)
                                for app in NSWorkspace.shared().runningApplications {
                                    if p.pid == Int(app.processIdentifier) {
                                        p.icon = app.icon
                                    }
                                }
                                self.processes.append(p)
                                SDLog("runningProcesses(): found running process: <pid:\(pid), command:\(command)>")
                            }
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
            }
            
            
            // MARK: - Launch subprocess and return
            
            task.launch()
            task.waitUntilExit()
            
            SDLog("runningProcesses(): returning \(processes.count) processes running")
            
            _p = self.processes
        }
        return _p
    }


}
