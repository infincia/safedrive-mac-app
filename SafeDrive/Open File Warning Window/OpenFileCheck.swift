//
//  OpenFileCheck.swift
//  SafeDrive
//
//  Created by steve on 2/21/17.
//  Copyright © 2017 Infincia LLC. All rights reserved.
//

import Foundation

class OpenFileCheck: NSObject {
    
    override init() {
        super.init()
    }
    
    public func check(volume: URL) -> [RunningProcess] {
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
        
        task.standardError = outputPipe
        task.standardOutput = outputPipe
        
        // MARK: - Launch subprocess and return
        
        task.launch()
        task.waitUntilExit()
        
        let data = outputPipeHandle.readDataToEndOfFile()
        let outputString = String(data: data, encoding: String.Encoding.utf8)!
        
        SDLog("check(): lsof: \(outputString)")
        
        var processes = [RunningProcess]()
        
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
                    
                    processes.append(p)
                    SDLog("check(): found process: <pid:\(pid), command:\(command)>")
                    
                }
            }
        }
        
        SDLog("check(): returning \(processes.count) processes still open")
        
        return processes
    }
}
