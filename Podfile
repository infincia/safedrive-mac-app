platform :osx, '10.9'

def shared_pods
    pod 'Fabric', '~>  1.6.11'
    pod 'Crashlytics', '~>  3.8.3'
    pod 'Realm','~> 2.4.4'
    pod 'RealmSwift', '~> 2.4.4'
end

target 'safedriveaskpass' do

end

target 'SafeDriveService' do
    use_frameworks!
    shared_pods
end

target 'SafeDriveFinder' do
    use_frameworks!
    shared_pods
end

target 'SafeDrive' do
    use_frameworks!
    shared_pods
    pod 'FontAwesome.swift', :git => 'https://github.com/infincia/FontAwesome.swift', :branch => 'osx'
    #pod 'SwiftDate', git: 'https://github.com/malcommac/SwiftDate.git', branch: 'feature/swift-3.0'
    pod 'RegexKitLite', '~> 4.0'
    pod 'IYLoginItem', '~> 0.1'
    pod 'DCOAboutWindow', '~> 0.2.0'
    pod 'LetsMove', '~> 1.22'
    pod 'Sparkle', '~> 1.17.0'
    pod 'STPrivilegedTask', '~> 1.0.1'
    pod 'TSMarkdownParser', '~> 2.1.2'
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end



