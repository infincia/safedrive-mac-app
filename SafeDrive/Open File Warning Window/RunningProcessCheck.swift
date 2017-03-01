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

class RunningProcessCheck: NSObject {
    
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
    
    public func runningProcesses() -> [RunningProcess] {
        
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
        
        task.standardError = outputPipe
        task.standardOutput = outputPipe
        
        // MARK: - Launch subprocess and return
        
        task.launch()
        task.waitUntilExit()
        
        let data = outputPipeHandle.readDataToEndOfFile()
        let outputString = String(data: data, encoding: String.Encoding.utf8)!
        
        var processes = [RunningProcess]()
        
        //    28103        ttys000           0:02.46           -zsh
        SDLog("runningProcesses(): ps: \(outputString)")
        
        let fullRegex = "([0-9]+)\\s([0-9A-Za-z]+)\\s\\s\\s\\s([0-9\\:\\.]+)\\s([\\w\\-]+)\\n*"
        
        if outputString.isMatched(byRegex: fullRegex) {
            
            if let matches = outputString.arrayOfCaptureComponentsMatched(byRegex: fullRegex) as [AnyObject]! {
                SDLog("runningProcesses(): \(matches.count) matches found")
                
                for capturedValues in matches {
                    let process = capturedValues as! [String]
                    let pid = process[1]
                    let command = process[4]
                    var p = RunningProcess(pid: Int(pid)!, command: command)
                    for app in NSWorkspace.shared().runningApplications {
                        if p.pid == Int(app.processIdentifier) {
                            p.icon = app.icon
                        }
                    }
                    processes.append(p)
                    SDLog("runningProcesses(): found running process: <pid:\(pid), command:\(command)>")
                }
            }
        }
        SDLog("runningProcesses(): task exited, \(processes.count) processes running")
        
        return processes
    }
}
