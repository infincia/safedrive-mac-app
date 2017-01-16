
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

public enum HTTPMethod: String {
    case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}

enum Endpoint {
    static var SessionToken: String?

    case errorLog([String:AnyObject])
    case registerClient([String:AnyObject])
    case accountStatus
    case accountDetails
    case createFolder([String:AnyObject])
    case readFolders
    case deleteFolder(Int)
    case hostFingerprints
    case apiStatus

    var method: HTTPMethod {
        switch self {
        case .errorLog:
            return .POST
        case .registerClient:
            return .POST
        case .accountStatus:
            return .GET
        case .accountDetails:
            return .GET
        case .createFolder:
            return .POST
        case .readFolders:
            return .GET
        case .deleteFolder:
            return .DELETE
        case .hostFingerprints:
            return .GET
        case .apiStatus:
            return .GET
        }
    }

    var path: String {
        switch self {
        case .errorLog:
            return "/api/1/error/log"
        case .registerClient:
            return "/api/1/client/register"
        case .accountStatus:
            return "/api/1/account/status"
        case .accountDetails:
            return "/api/1/account/details"
        case .createFolder:
            return "/api/1/folder"
        case .readFolders:
            return "/api/1/folder"
        case .deleteFolder:
            return "/api/1/folder"
        case .hostFingerprints:
            return "/api/1/fingerprints"
        case .apiStatus:
            return "/api/1/status"
        }
    }

    // MARK: URLRequestConvertible

    var URLRequest: URLRequest {

        
        var request = NSMutableURLRequest()
        
        request.httpMethod = method.rawValue

        if let token = API.sharedAPI.sessionToken {
            request.setValue(token, forHTTPHeaderField: "SD-Auth-Token")
        }
        
        var u = URLComponents()
        u.scheme = "https"
        u.host = API.domain
        u.path = path
        
        switch self {
        case .errorLog(let parameters):
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            request.httpBody = jsonData
        case .registerClient(let parameters):
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            request.httpBody = jsonData
        case .accountStatus:
            break
        case .accountDetails:
            break
        case .createFolder(let parameters):
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let jsonData = try! JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
            request.httpBody = jsonData
        case .readFolders:
            break
        case .deleteFolder(let parameters):
            u.query = "folderIds=\(parameters)".addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            break
        case .hostFingerprints:
            break
        case .apiStatus:
            break
        }
        SDLog("API request: <\(method.rawValue):\(u.url!)>")
        request.url = u.url!
        return request as URLRequest
    }
}

class API: NSObject, URLSessionDelegate {
    #if DEBUG
    static let domain = SDAPIDomainStaging
    #else
    static let domain = SDAPIDomainProduction
    #endif

    static let sharedAPI = API()

    fileprivate var URLSession: Foundation.URLSession!
    
    fileprivate var sharedSystemAPI = SDSystemAPI.shared()

    fileprivate var _session: String?

    var sessionToken: String? {
        get {
            if let session = self.sharedSystemAPI.retrieveCredentialsFromKeychain(forService: SDSessionServiceName) {
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
        URLSession = Foundation.URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
    }

    // MARK: Telemetry API

    func reportError(_ error: NSError, forUser user: String, withLog log: [String], completionQueue queue: DispatchQueue, success successBlock: @escaping SDSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        var postParameters = [String : AnyObject]()
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion()!)"
        postParameters["operatingSystem"] = os as AnyObject?
        let clientVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        postParameters["clientVersion"] = clientVersion as AnyObject?
        if !user.isEmpty {
            let macAddress: String = self.sharedSystemAPI.en0MAC()!
            let machineIdConcatenation: String = macAddress + user
            let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.data(using: String.Encoding.utf8))
            postParameters["uniqueClientId"] = identifier as AnyObject?
        }

        postParameters["description"] = error.localizedDescription as AnyObject?

        postParameters["context"] = error.domain as AnyObject?

        postParameters["log"] = log.description as AnyObject?

        let endpoint = Endpoint.errorLog(postParameters)
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<error/log>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    // MARK: Account API

    func registerMachineWithUser(_ user: String, password: String, success successBlock: @escaping SDAPIClientRegistrationSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let languageCode: String = Locale.preferredLanguages[0]
        let os: String = "OS X \(self.sharedSystemAPI.currentOSVersion()!)"
        let macAddress: String = self.sharedSystemAPI.en0MAC()!
        let machineIdConcatenation: String = macAddress + user
        let identifier: String = HKTHashProvider.sha256(machineIdConcatenation.data(using: String.Encoding.utf8))

        let postParameters = ["email": user,
            "password": password,
            "operatingSystem": os,
            "language": languageCode,
            "uniqueClientId": identifier]
        
        let endpoint = Endpoint.registerClient(postParameters as [String : AnyObject])
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<client/register>"])
                        failureBlock(responseError)
                        return
                    }
                    guard let token = JSON["token"] as? String else {
                        let responseError: NSError = NSError(domain: SDErrorAccountDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Validation error"])
                        failureBlock(responseError)
                        return
                    }
                    self.sessionToken = token
                    self.sharedSystemAPI.insertCredentialsInKeychain(forService: SDSessionServiceName, account: user, password: token)
                    successBlock(token, identifier)
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<client/register>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }


    func accountStatusForUser(_ user: String, success successBlock: @escaping SDAPIAccountStatusBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.accountStatus
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/status>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/status>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    func accountDetailsForUser(_ user: String, success successBlock: @escaping SDAPIAccountDetailsBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.accountDetails
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [String: NSObject] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/details>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<account/details>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    // MARK: Sync folder handling

    func createSyncFolder(_ localFolder: URL, encrypted: Bool, success successBlock: @escaping SDAPICreateSyncFolderSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let postParameters: [String : Any] = ["folderName": localFolder.lastPathComponent.lowercased(), "folderPath": localFolder.path, "encrypted": encrypted]
        let endpoint = Endpoint.createFolder(postParameters as [String : AnyObject])
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [String: AnyObject],
                              let folderID: Int = JSON["id"] as? Int else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/create>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(folderID)
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/create>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    func readSyncFoldersWithSuccess(_ successBlock: @escaping SDAPIReadSyncFoldersSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.readFolders
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [[String: NSObject]] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/read>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/read>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    func deleteSyncFolder(_ folderId: Int, success successBlock: @escaping SDAPIDeleteSyncFoldersSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.deleteFolder(folderId)
        
        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
                else {
                    guard let data = data,
                        let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let JSON = raw as? [String: String],
                        let message: String = JSON["message"] else {
                            let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<folder/delete>"])
                            failureBlock(responseError)
                            return
                    }
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let errorCode = SDAPIError(rawValue: statusCode)!
                    let responseError = NSError(domain: SDErrorUIDomain, code: errorCode.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
                    failureBlock(responseError)
                }
            }
        }) 
        dataTask.resume()
    }

    // MARK: Unused

    func getHostFingerprintList(_ successBlock: @escaping SDAPIFingerprintListSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.hostFingerprints

        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { (data, response, error) in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    guard let data = data,
                              let raw = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                              let JSON = raw as? [String: String] else {
                        let responseError: NSError = NSError(domain: SDErrorAPIDomain, code: SDAPIError.unknown.rawValue, userInfo: [NSLocalizedDescriptionKey: "Internal error<fingerprintse>"])
                        failureBlock(responseError)
                        return
                    }
                    successBlock(JSON)
                }
            }
        }) 
        dataTask.resume()
    }
    
    func apiStatus(_ successBlock: @escaping SDSuccessBlock, failure failureBlock: @escaping SDFailureBlock) {
        let endpoint = Endpoint.apiStatus

        let dataTask = self.URLSession.dataTask(with: endpoint.URLRequest, completionHandler: { data, response, error in
            if let error = error {
                let responseError = NSError(domain: SDErrorUIDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
                failureBlock(responseError)
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successBlock()
                }
            }
        }) 
        dataTask.resume()
    }
}
