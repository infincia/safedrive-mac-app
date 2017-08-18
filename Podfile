platform :osx, '10.9'

swift_version = '3.0'

def shared_pods
    pod 'Fabric', '~>  1.6.12'
    pod 'Crashlytics', '~>  3.8.5'
end

target 'SafeDrive' do
    use_frameworks!
    shared_pods
    pod 'IYLoginItem', '~> 0.1'
    pod 'DCOAboutWindow', '~> 0.2.0'
    pod 'LetsMove', '~> 1.22'
    pod 'Sparkle', '~> 1.18.1'
    pod 'STPrivilegedTask', :git => 'https://github.com/sveinbjornt/STPrivilegedTask.git', :tag => '1.0.6'
    pod 'TSMarkdownParser', '~> 2.1.2'
    pod 'FontAwesomeIconFactory', '~> 2.1.1'
    pod 'PromiseKit', :git => 'https://github.com/infincia/PromiseKit.git', :branch => 'infincia', :commit => '31870803665d6207da296dcd65f140547b4cdb08'
    
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end


target 'SafeDriveFinder' do
    use_frameworks!
    pod 'FontAwesomeIconFactory', '~> 2.1.1'
    pod 'PromiseKit', :git => 'https://github.com/infincia/PromiseKit.git', :branch => 'infincia', :commit => '31870803665d6207da296dcd65f140547b4cdb08'
end


