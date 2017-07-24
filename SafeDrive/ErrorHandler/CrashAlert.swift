
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//
// swiftlint:disable force_unwrapping


import Cocoa

extension Int {
    func toBool() -> Bool? {
        switch self {
        case 1:
            return true
        default:
            return false
        }
    }
}

class CrashAlert {
    class func show() {
        background {
            
            let suppressCrashAlerts = UserDefaults.standard.bool(forKey: "suppressCrashAlerts")
            if !suppressCrashAlerts {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "SafeDrive crashed :("
                    alert.informativeText = "A crash report has been submitted automatically"
                    alert.alertStyle = .warning
                    alert.showsSuppressionButton = true
                    
                    alert.runModal()
                    
                    let shouldSuppressAlerts = alert.suppressionButton!.state.toBool()
                    
                    UserDefaults.standard.set(shouldSuppressAlerts, forKey: "suppressCrashAlerts")
                }
            }
        }
    }
}
