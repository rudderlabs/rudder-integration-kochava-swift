Pod::Spec.new do |s|
    s.name             = 'RudderKochava'
    s.version          = '1.0.0'
    s.summary          = 'Privacy and Security focused Segment-alternative. Kochava Native SDK integration support.'
    s.description      = <<-DESC
    Rudder is a platform for collecting, storing and routing customer event data to dozens of tools. Rudder is open-source, can run in your cloud environment (AWS, GCP, Azure or even your data-centre) and provides a powerful transformation framework to process your event data on the fly.
    DESC
    s.homepage         = 'https://github.com/rudderlabs/rudder-firebase-ios'
    s.license          = { :type => "Apache", :file => "LICENSE" }
    s.author           = { 'RudderStack' => 'arnab@rudderlabs.com' }
    s.source           = { :git => 'https://github.com/rudderlabs/rudder-kochava-ios.git' , :tag => 'v#{s.version}'}
    
    s.ios.deployment_target = '13.0'
    s.osx.deployment_target = '10.13'
    s.tvos.deployment_target = '11.0'
    s.watchos.deployment_target = '7.0'
    
    s.source_files = 'Sources/**/*{h,m,swift}'
    s.module_name = 'RudderKochava'
    s.static_framework = true
    s.swift_version = '5.3'

    ## Ref: https://github.com/CocoaPods/CocoaPods/issues/10065
#    s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
#    s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

    s.dependency 'RudderStack', '~> 1.0'
    s.dependency 'Apple-Cocoapod-KochavaTracker', '5.1.1'
    s.dependency 'Apple-Cocoapod-KochavaAdNetwork', '5.1.1'
end
