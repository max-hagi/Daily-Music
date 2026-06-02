require 'xcodeproj'

path = 'Daily Music.xcodeproj'
project = Xcodeproj::Project.open(path)
app = project.targets.find { |t| t.name == 'Daily Music' }
raise 'app target not found' unless app

unless project.targets.any? { |t| t.name == 'Daily MusicTests' }
  test = project.new_target(:unit_test_bundle, 'Daily MusicTests', :ios, '26.5', nil, :swift)
  test.add_dependency(app)

  test.build_configurations.each do |c|
    c.build_settings['TEST_HOST'] =
      '$(BUILT_PRODUCTS_DIR)/Daily Music.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Daily Music'
    c.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
    c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'maxhagi.Daily-MusicTests'
    c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    c.build_settings['SWIFT_VERSION'] = '5.0'
    c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.5'
    c.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  end

  group = project.main_group.new_group('Daily MusicTests', 'Daily MusicTests')
  ref = group.new_file('Daily MusicTests/TasteMirrorTests.swift')
  test.add_file_references([ref])

  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(app)
  scheme.set_launch_target(app)
  scheme.add_test_target(test)
  scheme.save_as(path, 'Daily Music', true)
end

project.save
puts 'OK: test target ready'
