//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation
import SDDK

public class SDKSFTPFingerprint: Equatable, NSSecureCoding {
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.host, forKey: "host")
        aCoder.encode(self.fingerprint, forKey: "fingerprint")
        aCoder.encode(self.port, forKey: "port")
    }
    
    fileprivate let modificationQueue = DispatchQueue(label: "io.safedrive.SafeDriveSDK.SDKSFTPFingerprint.modificationQueue")
    
    public static var supportsSecureCoding = true
    
    var _host: String
    var _fingerprint: String
    var _port: UInt16
    
    public var port: UInt16 {
        get {
            var r: UInt16 = 0
            modificationQueue.sync {
                r = self._port
            }
            return r
        }
        set (newValue) {
            modificationQueue.sync(flags: .barrier, execute: {
                self._port = newValue
            })
        }
    }
    
    public var host: String {
        get {
            var r: String = ""
            modificationQueue.sync {
                r = self._host
            }
            return r
        }
        set (newValue) {
            modificationQueue.sync(flags: .barrier, execute: {
                self._host = newValue
            })
        }
    }
    
    public var fingerprint: String {
        get {
            var r: String = ""
            modificationQueue.sync {
                r = self._fingerprint
            }
            return r
        }
        set (newValue) {
            modificationQueue.sync(flags: .barrier, execute: {
                self._fingerprint = newValue
            })
        }
    }
    
    
    public static func == (left: SDKSFTPFingerprint, right: SDKSFTPFingerprint) -> Bool {
        return (left.fingerprint == right.fingerprint) && (left.host == right.host)
    }
    
    public init(fingerprint: SDDKSFTPFingerprint) {
        _host = String(cString: fingerprint.host)
        _fingerprint = String(cString: fingerprint.fingerprint)
        _port = fingerprint.port
    }
    
    public required init?(coder aDecoder: NSCoder) {
        
        guard let host = aDecoder.decodeObject(of: NSString.self, forKey: "host") as String? else {
            fatalError("Could not deserialise host!")
        }
        
        guard let fingerprint = aDecoder.decodeObject(of: NSString.self, forKey: "fingerprint") as String? else {
            fatalError("Could not deserialise fingerprint!")
        }
        
        guard let port = aDecoder.decodeObject(of: NSNumber.self, forKey: "port") as NSNumber? else {
            fatalError("Could not deserialise port!")
        }
        
        _host = host
        _fingerprint = fingerprint
        _port = UInt16(port)
    }
}
