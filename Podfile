# Volcengine CocoaPods spec source
source 'https://github.com/volcengine/volcengine-specs.git'
source 'https://cdn.cocoapods.org/'

# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'LingoBuddy' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Doubao AI Real-time Voice SDK
  pod 'SpeechEngineToB', '0.0.14.6'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
