platform :osx, '10.9'

def keychain_pods
    pod 'MCSMKeychainItem',  :git => 'https://github.com/ObjColumnist/MCSMKeychainItem.git', :commit => 'dfac30c6e9dac4ee1e8deaae5a742a65523e92aa',  :branch => 'master'
    pod 'UICKeyChainStore', '2.1.0'
end

def shared_pods
    pod 'Fabric', '~>  1.6.11'
    pod 'Crashlytics', '~>  3.8.3'
    #pod 'SwiftDate', git: 'https://github.com/malcommac/SwiftDate.git', branch: 'feature/swift-3.0'
    pod 'RegexKitLite', '~> 4.0'
    pod 'Realm','~> 2.2.0'
    pod 'RealmSwift', '~> 2.2.0'
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
    pod 'IYLoginItem', '~> 0.1'
    pod 'DCOAboutWindow', '~> 0.2.0'
    pod 'LetsMove', '~> 1.22'
    pod 'Sparkle', '~> 1.15.1'
    pod 'STPrivilegedTask', '~> 1.0.1'
    pod 'TSMarkdownParser', '~> 2.1.2'
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end



