platform :osx, '10.9'

def shared_pods
    pod 'MCSMKeychainItem',  :git => 'https://github.com/ObjColumnist/MCSMKeychainItem.git', :commit => 'dfac30c6e9dac4ee1e8deaae5a742a65523e92aa',  :branch => 'master'
    pod 'UICKeyChainStore', '~> 2.1.0'
end

target 'safedriveaskpass' do
    shared_pods
end

target 'SafeDrive' do
    shared_pods
    pod 'AFNetworking', '2.5.4'
    pod 'AFNetworkActivityLogger'
    pod 'IYLoginItem', '0.1'
    pod 'INAppStoreWindow', '1.4'
    pod 'DCOAboutWindow', '0.2.0'
    pod 'LetsMove', '~> 1.20'
    pod 'Sparkle', '1.13.1'
    pod 'Fabric', '1.6.5'
    pod 'Crashlytics', '3.6.0'
    pod 'NMSSH', '~> 2.2'

end

