
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

public enum HTTPMethod: String {
    case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}

enum Endpoint {
    static var SessionToken: String?

    case ErrorLog([String:AnyObject])
    case RegisterClient([String:AnyObject])
    case AccountStatus
    case AccountDetails
    case CreateFolder([String:AnyObject])
    case ReadFolders
    case DeleteFolder(Int)
    case HostFingerprints
    case APIStatus

    var method: HTTPMethod {
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
            return "/api/1/error/log"
        case .RegisterClient:
            return "/api/1/client/register"
        case .AccountStatus:
            return "/api/1/account/status"
        case .AccountDetails:
            return "/api/1/account/details"
        case .CreateFolder:
            return "/api/1/folder"
        case .ReadFolders:
            return "/api/1/folder"
        case .DeleteFolder:
            return "/api/1/folder"
        case .HostFingerprints:
            return "/api/1/fingerprints"
        case .APIStatus:
            return "/api/1/status"
        }
    }

    // MARK: URLRequestConvertible

    var URLRequest: NSMutableURLRequest {

        
        let mutableURLRequest = NSMutableURLRequest()
        mutableURLRequest.HTTPMethod = method.rawValue

        if let token = API.sharedAPI.sessionToken {
            mutableURLRequest.setValue(token, forHTTPHeaderField: "SD-Auth-Token")
        }
        
        let u = NSURLComponents()
        u.scheme = "https"
        u.host = API.domain
        u.path = path
        
        switch self {
        case .ErrorLog(let parameters):
            mutableURLRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! NSJSONSerialization.dataWithJSONObject(parameters, options: .PrettyPrinted)
            mutableURLRequest.HTTPBody = jsonData
        case .RegisterClient(let parameters):
            mutableURLRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! NSJSONSerialization.dataWithJSONObject(parameters, options: .PrettyPrinted)
            mutableURLRequest.HTTPBody = jsonData
        case .AccountStatus:
            break
        case .AccountDetails:
            break
        case .CreateFolder(let parameters):
            mutableURLRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! NSJSONSerialization.dataWithJSONObject(parameters, options: .PrettyPrinted)
            mutableURLRequest.HTTPBody = jsonData
        case .ReadFolders:
            break
        case .DeleteFolder(let parameters):
            u.query = "folderIds=\(parameters)".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            break
        case .HostFingerprints:
            break
        case .APIStatus:
            break
        }
        SDLog("API request: <\(method.rawValue):\(u.URL!)>")
        mutableURLRequest.URL = u.URL!
        return mutableURLRequest
    }
}

class API: NSObject, NSURLSessionDelegate {
    #if DEBUG
    static let domain = SDAPIDomainStaging
    #else
    static let domain = SDAPIDomainProduction
    #endif

    static let sharedAPI = API()

    private var URLSession: NSURLSession!
    
    private var sharedSystemAPI = SDSystemAPI.sharedAPI()

    private var _session: String?

    var sessionToken: String? {
        get {
            if let session = self.sharedSystemAPI.retrieveCredentialsFromKeychainForService(SDSessionServiceName) {
                return session["password"]
            }
            return nil
        }
        set(newToken) {
            _session = newToken
        }
    }

    override init() {
        super.init()
        URLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: NSOperationQueue.mainQueue())
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

        let endpoint = Endpoint.ErrorLog(postParameters)
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<error/log>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
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
        
        let endpoint = Endpoint.RegisterClient(postParameters)
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<client/register>"])
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
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<client/register>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }


    func accountStatusForUser(user: String, success successBlock: SDAPIAccountStatusBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.AccountStatus
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/status>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/status>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }

    func accountDetailsForUser(user: String, success successBlock: SDAPIAccountDetailsBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.AccountDetails
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/details>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/details>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }

    // MARK: Sync folder handling

    func createSyncFolder(localFolder: NSURL, success successBlock: SDAPICreateSyncFolderSuccessBlock, failure failureBlock: SDFailureBlock) {
        let postParameters = ["folderName": localFolder.lastPathComponent!.lowercaseString, "folderPath": localFolder.path!]
        let endpoint = Endpoint.CreateFolder(postParameters)
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [String: AnyObject],
                              folderID: Int = JSON["id"] as? Int else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/create>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(folderID)
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/create>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }

    func readSyncFoldersWithSuccess(successBlock: SDAPIReadSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.ReadFolders
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [[String: NSObject]] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/read>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/read>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }

    func deleteSyncFolder(folderId: Int, success successBlock: SDAPIDeleteSyncFoldersSuccessBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.DeleteFolder(folderId)
        
        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
                else {
                    guard let data = data,
                        raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                        JSON = raw as? [String: String],
                        message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/delete>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? NSHTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }
        dataTask.resume()
    }

    // MARK: Unused

    func getHostFingerprintList(successBlock: SDAPIFingerprintListSuccessBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.HostFingerprints

        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              raw = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments),
                              JSON = raw as? [String: String] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.Unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<fingerprintse>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
            }
        }
        dataTask.resume()
    }
    
    func apiStatus(successBlock: SDSuccessBlock, failure failureBlock: SDFailureBlock) {
        let endpoint = Endpoint.APIStatus

        let dataTask = self.URLSession.dataTaskWithRequest(endpoint.URLRequest) { data, response, error in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? NSHTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
            }
        }
        dataTask.resume()
    }
}
