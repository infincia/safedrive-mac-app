platform :osx, '10.9'

def keychain_pods
    pod 'MCSMKeychainItem',  :git => 'https://github.com/ObjColumnist/MCSMKeychainItem.git', :commit => 'dfac30c6e9dac4ee1e8deaae5a742a65523e92aa',  :branch => 'master'
    pod 'UICKeyChainStore', '2.1.0'
end

def shared_pods
    pod 'Fabric', '1.6.8'
    pod 'Crashlytics', '3.8'
    #pod 'SwiftDate', git: 'https://github.com/malcommac/SwiftDate.git', branch: 'feature/swift-3.0'
    pod 'RegexKitLite', '4.0'
    pod 'Realm', git: 'https://github.com/realm/realm-cocoa.git', branch: 'master', submodules: true
    pod 'RealmSwift', git: 'https://github.com/realm/realm-cocoa.git', branch: 'master', submodules: true
end

target 'safedriveaskpass' do
    keychain_pods
end

target 'SafeDriveService' do
    use_frameworks!
    keychain_pods
    shared_pods
end

target 'SafeDriveFinder' do
    use_frameworks!
    shared_pods
end

target 'SafeDrive' do
    use_frameworks!
    keychain_pods
    shared_pods
    pod 'IYLoginItem', '0.1'
    pod 'DCOAboutWindow', '0.2.0'
    pod 'LetsMove', '1.20'
    pod 'Sparkle', '1.14.0'
    pod 'STPrivilegedTask', '1.0.1'
    pod 'TSMarkdownParser'
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end



