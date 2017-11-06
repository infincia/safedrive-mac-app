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
        
        SDLogDebug("Closing non-user application: \(pid)")
        
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
        
        SDLogDebug("runningProcesses(): looking for running processes")
        
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
        // swiftlint:disable force_unwrapping
        let outputString = String(data: data, encoding: String.Encoding.utf8)!
        // swiftlint:enable force_unwrapping

        
        var processes = [RunningProcess]()
        
        //    28103        ttys000           0:02.46           -zsh
        SDLogDebug("runningProcesses(): ps: \(outputString)")
        
        let pattern = "([0-9]+)\\s([0-9A-Za-z]+)\\s\\s\\s\\s([0-9\\:\\.]+)\\s([\\w\\-]+)\\n*"
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let s = outputString as NSString
            
            
            let result: [NSTextCheckingResult] = regex.matches(in: outputString, range: NSRange(location: 0, length: s.length))
            
            SDLogDebug("runningProcesses(): \(result.count) matches found")
            
            for res in result {
                if res.numberOfRanges < 5 {
                    continue
                }
                
                let pidRange = res.range(at: 1)
                let commandRange = res.range(at: 4)
                
                let pid = s.substring(with: pidRange)
                let command = s.substring(with: commandRange)
                
                // swiftlint:disable force_unwrapping
                var p = RunningProcess(pid: Int(pid)!, command: command)
                // swiftlint:enable force_unwrapping
                
                for app in NSWorkspace.shared.runningApplications {
                    if p.pid == Int(app.processIdentifier) {
                        p.icon = app.icon
                    }
                }
                processes.append(p)
                SDLogDebug("runningProcesses(): found running process: <pid:\(pid), command:\(command)>")
            }
        }
        
        SDLogDebug("runningProcesses(): task exited, \(processes.count) processes running")
        
        return processes
    }
}
