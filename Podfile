platform :osx, '10.9'

swift_version = '3.2'

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.2'
        end
    end
end

def shared_pods
    pod 'Fabric', '~>  1.6.13'
    pod 'Crashlytics', '~>  3.8.6'
end

target 'SafeDrive' do
    use_frameworks!
    shared_pods
    pod 'IYLoginItem', '~> 0.1'
    pod 'DCOAboutWindow', '~> 0.2.0'
    pod 'LetsMove', '~> 1.23'
    pod 'Sparkle', '~> 1.18.1'
    pod 'STPrivilegedTask', :git => 'https://github.com/sveinbjornt/STPrivilegedTask.git', :tag => '1.0.6'
    pod 'TSMarkdownParser', '~> 2.1.2'
    pod 'FontAwesomeIconFactory', '~> 2.1.1'
    pod 'PromiseKit', :git => 'https://github.com/infincia/PromiseKit.git', :branch => 'infincia', :commit => 'ecf2619ccc431ea9b55f9d4ffcbc979db47b19ec'
    
    target 'SafeDriveTests' do
        inherit! :search_paths
    end
end


target 'SafeDriveFinder' do
    use_frameworks!
    pod 'FontAwesomeIconFactory', '~> 2.1.1'
    pod 'PromiseKit', :git => 'https://github.com/infincia/PromiseKit.git', :branch => 'infincia', :commit => 'ecf2619ccc431ea9b55f9d4ffcbc979db47b19ec'
end


