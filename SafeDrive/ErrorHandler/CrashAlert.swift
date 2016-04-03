
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Cocoa

class CrashAlert {
    class func show() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {() -> Void in

            let suppressCrashAlerts = NSUserDefaults.standardUserDefaults().boolForKey("suppressCrashAlerts")
            if !suppressCrashAlerts {
                dispatch_async(dispatch_get_main_queue(), {() -> Void in
                    let alert = NSAlert()
                    alert.addButtonWithTitle("OK")
                    alert.messageText = "SafeDrive crashed :("
                    alert.informativeText = "A crash report has been submitted automatically"
                    alert.alertStyle = .WarningAlertStyle
                    alert.showsSuppressionButton = true
                    
                    alert.runModal()
                    
                    let shouldSuppressAlerts = Bool(alert.suppressionButton!.state)

                    NSUserDefaults.standardUserDefaults().setBool(shouldSuppressAlerts, forKey: "suppressCrashAlerts")
                })
            }
        })
    }
}
