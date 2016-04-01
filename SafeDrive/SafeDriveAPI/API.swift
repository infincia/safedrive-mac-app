
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation
import Alamofire

enum Endpoint: URLRequestConvertible {
    static let baseURLString = "https://\(SDAPIDomainTesting)/api/1"
    static var SessionToken: String?

    case ErrorLog([String:AnyObject])
    case RegisterClient([String:AnyObject])
    case AccountStatus
    case AccountDetails
    case CreateFolder([String:AnyObject])
    case ReadFolders
    case DeleteFolder([String:Int])
    case HostFingerprints
    case APIStatus

    var method: Alamofire.Method {
        switch self {
        case .ErrorLog:
            return .POST
        case .RegisterClient:
            return .POST
        case .AccountStatus:
            return .GET
        case .AccountDetails:
            return .GET
        case .CreateFolder:
            return .POST
        case .ReadFolders:
            return .GET
        case .DeleteFolder:
            return .DELETE
        case .HostFingerprints:
            return .GET
        case .APIStatus:
            return .GET
        }
    }

    var path: String {
        switch self {
        case .ErrorLog:
            return "/error/log"
        case .RegisterClient:
            return "/client/register"
        case .AccountStatus:
            return "/account/status"
        case .AccountDetails:
            return "/account/details"
        case .CreateFolder:
            return "/folder"
        case .ReadFolders:
            return "/folder"
        case .DeleteFolder:
            return "/folder"
        case .HostFingerprints:
            return "/fingerprints"
        case .APIStatus:
            return "/status"
        }
    }
    
    // MARK: URLRequestConvertible
    
    var URLRequest: NSMutableURLRequest {
        let URL = NSURL(string: Endpoint.baseURLString)!
        let mutableURLRequest = NSMutableURLRequest(URL: URL.URLByAppendingPathComponent(path))
        mutableURLRequest.HTTPMethod = method.rawValue
        
        if let token = API.sharedAPI.sessionToken {
            mutableURLRequest.setValue(token, forHTTPHeaderField: "SD-Auth-Token")
        }
        
        switch self {
        case .ErrorLog(let parameters):
            return Alamofire.ParameterEncoding.JSON.encode(mutableURLRequest, parameters: parameters).0
        case .RegisterClient(let parameters):
            return Alamofire.ParameterEncoding.JSON.encode(mutableURLRequest, parameters: parameters).0
        case .CreateFolder(let parameters):
            return Alamofire.ParameterEncoding.JSON.encode(mutableURLRequest, parameters: parameters).0
        case .DeleteFolder(let parameters):
            return Alamofire.ParameterEncoding.URLEncodedInURL.encode(mutableURLRequest, parameters: parameters).0
        default:
            return mutableURLRequest
        }
    }
}

class API: NSObject {
    static let sharedAPI = API()

    private var reachabilityManager = NetworkReachabilityManager(host: SDAPIDomainTesting)
    private var sharedSystemAPI = SDSystemAPI.sharedAPI()
    
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
        self.reachabilityManager?.listener = { status in

        }
        
        self.reachabilityManager?.startListening()
    }
    
    // MARK: Telemetry API
    
    func reportError(error: NSError, forUser user: String, withLog log: [String], completionQueue queue: dispatch_queue_t, success successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        var postParameters = [String : AnyObject]()
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion()!)"
        postParameters["operatingSystem"] = os
        let clientVersion: String = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        postParameters["clientVersion"] = clientVersion
        if !user.isEmpty {
            let macAddress: String = self.sharedSystemAPI.en0MAC()!
            let machineIdConcatenation: String = macAddress.stringByAppendingString(user)
            let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.dataUsingEncoding(NSUTF8StringEncoding))
            postParameters["uniqueClientId"] = identifier
        }

        postParameters["description"] = error.localizedDescription
        
        postParameters["context"] = error.domain
        
        postParameters["log"] = log.description

        Alamofire.request(Endpoint.ErrorLog(postParameters))
            .validate()
            .responseString { response in
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    print("Error error/log: \(error)")
                    guard let JSON = response.result.value as? [String: String], let message: String = JSON["message"] else {
                        failureBlock(error)
                        return
                    }
                    let responseError: NSError = NSError(domain: SDErrorDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
        }
        
    }
    
    // MARK: Account API
    
    func registerMachineWithUser(user: String, password: String, success successBlock: SDAPIClientRegistrationSuccessBlock, failure failureBlock: SDFailureBlock) {
        let languageCode: String = NSLocale.preferredLanguages()[0]
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion()!)"
        let macAddress: String = self.sharedSystemAPI.en0MAC()!
        let machineIdConcatenation: String = macAddress.stringByAppendingString(user)
        let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.dataUsingEncoding(NSUTF8StringEncoding))
        
        let postParameters = ["email": user,
            "password": password,
            "operatingSystem": os,
            "language": languageCode,
            "uniqueClientId": identifier]
        
        Alamofire.request(Endpoint.RegisterClient(postParameters))
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: AnyObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: client/register"])
                        failureBlock(responseError)
                        return
                    }
                    guard let token = JSON["token"] as? String else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Validation error"])
                        failureBlock(responseError)
                        return
                    }
                    self.sessionToken = token
                    self.sharedSystemAPI.insertCredentialsInKeychainForService(SDSessionServiceName, account: user, password: token)
                    successBlock(token, identifier)
                case .Failure(let error):
                    guard let data = response.data,
                              JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                              message: String = JSON?["message"] else {
                            print("Error client/register: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error client/register \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
            }
        
    }

    
    func accountStatusForUser(user: String, success successBlock: SDAPIAccountStatusBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(Endpoint.AccountStatus)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: account/status"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error account/status: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error account/status \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    func accountDetailsForUser(user: String, success successBlock: SDAPIAccountDetailsBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(Endpoint.AccountDetails)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: account/details"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error account/details: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error account/details \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    // MARK: Sync folder handling
    
    func createSyncFolder(localFolder: NSURL, success successBlock: SDAPICreateSyncFolderSuccessBlock, failure failureBlock: SDFailureBlock) {
        let postParameters = ["folderName": localFolder.lastPathComponent!, "folderPath": localFolder.path!]
        
        Alamofire.request(Endpoint.CreateFolder(postParameters))
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: AnyObject],
                          let folderID: Int = JSON["id"] as? Int else {
                        let responseError: NSError = NSError(domain: SDErrorSyncDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: folder:create"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(folderID)
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error folder/create: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error folder/create \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    func readSyncFoldersWithSuccess(successBlock: SDAPIReadSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(Endpoint.ReadFolders)
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [[String: NSObject]] else {
                            let responseError: NSError = NSError(domain: SDErrorSyncDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: folder:read"])
                            failureBlock(responseError)
                            return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error folder/read: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error folder/read \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    func deleteSyncFolder(folderId: Int, success successBlock: SDAPIDeleteSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        let folderIds = ["folderIds": folderId]
        Alamofire.request(Endpoint.DeleteFolder(folderIds))
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error folder/delete: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error folder/delete \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    // MARK: Unused
    
    func getHostFingerprintList(successBlock: SDAPIFingerprintListSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/fingerprints")
            .validate()
            .responseJSON { response in
                switch response.result {
                case .Success:
                    guard let JSON = response.result.value as? [String: String] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error: fingerprints"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error fingerprints: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error fingerprints \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
    
    func apiStatus(successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        Alamofire.request(.GET, "https://\(SDAPIDomainTesting)/api/1/status")
            .validate()
            .responseJSON { response in                
                switch response.result {
                case .Success:
                    successBlock()
                case .Failure(let error):
                    guard let data = response.data,
                        JSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as? [String: String],
                        message: String = JSON?["message"] else {
                            print("Error status: \(error)")
                            failureBlock(error)
                            return
                    }
                    let statusCode = response.response?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    print("Error status \(SDErrorToString(responseError)): \(responseError)")
                    failureBlock(responseError)
                }
        }
    }
}