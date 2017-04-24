
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//


import Foundation

import SafeDriveSDK

fileprivate var sdk = SafeDriveSDK.sharedSDK

func main() {
    
    let stderr = FileHandle.standardError
    let stdout = FileHandle.standardOutput
    
    
    // swiftlint:disable force_unwrapping
    let CFBundleShortVersionString = (Bundle.main.infoDictionary!["CFBundleShortVersionString"])! as! String
    // swiftlint:enable force_unwrapping
    
    // initialize safedrive SDK
    
    var config: SDKConfiguration
    if isProduction() {
        config = SDKConfiguration.Production
    } else {
        config = SDKConfiguration.Staging
    }
    
    let languageCode: String = Locale.preferredLanguages[0]
    
    let groupURL = storageURL()
    
    let currentOS = currentOSVersion()
    
    // swiftlint:disable force_try
    try! sdk.setUp(client_version: CFBundleShortVersionString, operating_system: currentOS, language_code: languageCode, config: config, local_storage_path: groupURL.path)
    // swiftlint:enable force_try
    
    let currentUser = try! sdk.getKeychainItem(withUser: "currentuser", service: currentUserDomain())
    let password = try! sdk.getKeychainItem(withUser: currentUser, service: accountCredentialDomain())

    if let data = password.data(using: .utf8) {
        stderr.write(data)
        exit(EXIT_SUCCESS)
    }
    
    exit(EXIT_FAILURE)
}
