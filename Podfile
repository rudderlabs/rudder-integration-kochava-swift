workspace 'RudderKochava.xcworkspace'
use_frameworks!
inhibit_all_warnings!
platform :ios, '13.0'

def shared_pods
    pod 'RudderStack', :path => '~/Documents/Rudder/RudderStack-Cocoa/'
end

target 'RudderKochava' do
    project 'RudderKochava.xcodeproj'
    shared_pods
    pod 'Apple-Cocoapod-KochavaTracker', '5.1.1'
    pod 'Apple-Cocoapod-KochavaAdNetwork', '5.1.1'
end

target 'SampleAppObjC' do
    project 'Examples/SampleAppObjC/SampleAppObjC.xcodeproj'
    shared_pods
    pod 'RudderKochava', :path => '.'
end

target 'SampleAppSwift' do
    project 'Examples/SampleAppSwift/SampleAppSwift.xcodeproj'
    shared_pods
    pod 'RudderKochava', :path => '.'
end
