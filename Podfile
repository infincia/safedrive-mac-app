platform :osx, '10.9'

def shared_pods
    pod 'Fabric', '~>  1.6.11'
    pod 'Crashlytics', '~>  3.8.3'
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
    pod 'IYLoginItem', '~> 0.1'
    pod 'DCOAboutWindow', '~> 0.2.0'
    pod 'LetsMove', '~> 1.22'
    pod 'Sparkle', '~> 1.17.0'
    pod 'STPrivilegedTask', :git => 'https://github.com/sveinbjornt/STPrivilegedTask.git', :tag => '1.0.6'
    pod 'TSMarkdownParser', '~> 2.1.2'
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end



