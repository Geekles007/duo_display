#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint duo_display.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'duo_display'
  s.version          = '0.0.1'
  s.summary          = 'iPhone Duo foldable geometry for Flutter.'
  s.description      = <<-DESC
Bridges the iOS 27.1 hinge and reserved region APIs of the iPhone Duo to Flutter.
                       DESC
  s.homepage         = 'https://github.com/geekles/duo_display'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'geekles' => 'https://github.com/geekles' }
  s.source           = { :path => '.' }
  s.source_files = 'duo_display/Sources/duo_display/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '6.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'duo_display_privacy' => ['duo_display/Sources/duo_display/PrivacyInfo.xcprivacy']}
end
