
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation
import Alamofire

class API: NSObject {
    static let sharedAPI = API()

    var reachabilityManager: AFNetworkReachabilityManager
    var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
    private var _session: String?
    
    var sessionToken: String? {
        get {
            if let session = self.sharedSystemAPI.retrieveCredentialsFromKeychainForService(SDSessionServiceName){
                return session["password"]
            }
            return nil
        }
        set(newToken) {
            _session = newToken
        }
    }
    
    override init() {
        self.reachabilityManager = AFNetworkReachabilityManager(forDomain: SDAPIDomainTesting)
        self.reachabilityManager.setReachabilityStatusChangeBlock { (status: AFNetworkReachabilityStatus) -> Void in
            switch status {
            case .Unknown:
                print("AFNetworkReachabilityStatusUnknown")
            case .NotReachable:
                print("AFNetworkReachabilityStatusNotReachable")
            case .ReachableViaWWAN:
                print("AFNetworkReachabilityStatusReachableViaWWAN")
            case .ReachableViaWiFi:
                print("AFNetworkReachabilityStatusReachableViaWiFi")
            }
        }
        self.reachabilityManager.startMonitoring()
    }
    
    // MARK: Telemetry API
    
    func reportError(error: NSError, forUser user: String, withLog log: [String], completionQueue queue: dispatch_queue_t, success successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        var postParameters = [String : AnyObject]()
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion)"
        postParameters["operatingSystem"] = os
        let clientVersion: String = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        postParameters["clientVersion"] = clientVersion
        if !user.isEmpty {
            let macAddress: String = self.sharedSystemAPI.en0MAC()
            let machineIdConcatenation: String = macAddress.stringByAppendingString(user)
            let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.dataUsingEncoding(NSUTF8StringEncoding))
            postParameters["uniqueClientId"] = identifier
        }

        postParameters["description"] = error.localizedDescription
        
        postParameters["context"] = error.domain
        
        postParameters["log"] = log.description

        Alamofire.request(.POST, "https://\(SDAPIDomainTesting)/api/1/error/log", parameters: postParameters, encoding: .JSON)
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.result.value)   // result of response serialization
                
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
        
    }
    
    // MARK: Account API
    
    func registerMachineWithUser(user: String, password: String, success successBlock: SDAPIClientRegistrationSuccessBlock, failure failureBlock: SDFailureBlock) {
        let languageCode: String = NSLocale.preferredLanguages()[0]
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion)"
        let macAddress: String = self.sharedSystemAPI.en0MAC()
        let machineIdConcatenation: String = macAddress.stringByAppendingString(user)
        let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.dataUsingEncoding(NSUTF8StringEncoding))
        
        let postParameters = ["email": user,
            "password": password,
            "operatingSystem": os,
            "language": languageCode,
            "uniqueClientId": identifier]
        
        Alamofire.request(.POST, "https://\(SDAPIDomainTesting)/api/1/client/register", parameters: postParameters, encoding: .JSON)
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: AnyObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: client/register"])
                        failureBlock(responseError)
                        return
                    }
                    SDLog("Client registered: \(JSON)")
                    guard let token = JSON["token"] as? String else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Validation error"])
                        failureBlock(responseError)
                        return
                    }
                    self.sessionToken = token
                    self.sharedSystemAPI.insertCredentialsInKeychainForService(SDSessionServiceName, account: user, password: token)
                    successBlock(token)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
        
    }

    
    func accountStatusForUser(user: String, success successBlock: SDAPIAccountStatusBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/account/status", headers: ["SD-Auth-Token": self.sessionToken!])
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: account/status"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    func accountDetailsForUser(user: String, success successBlock: SDAPIAccountDetailsBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/account/details", headers: ["SD-Auth-Token": self.sessionToken!])
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: account/details"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    // MARK: Sync folder handling
    
    func createSyncFolder(localFolder: NSURL, success successBlock: SDAPICreateSyncFolderSuccessBlock, failure failureBlock: SDFailureBlock) {
        let postParameters = ["folderName": localFolder.lastPathComponent!, "folderPath": localFolder.path!]
        
        Alamofire.request(.POST, "https://\(SDAPIDomainTesting)/api/1/folder", parameters: postParameters, encoding: .JSON, headers: ["SD-Auth-Token": self.sessionToken!])
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: AnyObject],
                          let folderID: Int = JSON["id"] as? Int else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(folderID)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    func readSyncFoldersWithSuccess(successBlock: SDAPIReadSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/folder", headers: ["SD-Auth-Token": self.sessionToken!])
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [[String: NSObject]] else {
                            let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error"])
                            failureBlock(responseError)
                            return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    func deleteSyncFolder(folderId: Int, success successBlock: SDAPIDeleteSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        let folderIds = ["folderIds": folderId]
        Alamofire.request(.DELETE, "https://\(SDAPIDomainTesting)/api/1/folder", parameters: folderIds, encoding: .URLEncodedInURL, headers: ["SD-Auth-Token": self.sessionToken!])
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    // MARK: Unused
    
    func getHostFingerprintList(successBlock: SDAPIFingerprintListSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/fingerprints")
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: String] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
    
    func apiStatus(successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/status")
            .validate()
            .responseJSON { response in
                print(response.request)  // original URL request
                print(response.response) // URL response
                print(response.data)     // server data
                print(response.result)   // result of response serialization
                
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    print("Error: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
    }
}