platform :osx, '10.9'

def keychain_pods
    pod 'MCSMKeychainItem',  :git => 'https://github.com/ObjColumnist/MCSMKeychainItem.git', :commit => 'dfac30c6e9dac4ee1e8deaae5a742a65523e92aa',  :branch => 'master'
    pod 'UICKeyChainStore', '2.1.0'
end

def shared_pods
    pod 'Alamofire', '3.3.0'
    pod 'Fabric', '1.6.7'
    pod 'Crashlytics', '3.7.0'
    pod 'NMSSH', '2.2.4'
    pod 'SwiftDate', '1.2'
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
end

target 'SafeDrive' do
    use_frameworks!
    keychain_pods
    shared_pods
    pod 'IYLoginItem', '0.1'
    pod 'INAppStoreWindow', '1.4'
    pod 'DCOAboutWindow', '0.2.0'
    pod 'LetsMove', '1.20'
    pod 'Sparkle', '1.14.0'
    pod 'STPrivilegedTask', '1.0.1'
    
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end



