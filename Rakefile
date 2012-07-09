# -*- coding: utf-8 -*-
$:.unshift("/Library/RubyMotion/lib")
require 'motion/project'
require 'bundler/setup'
Bundler.require :default

require 'yaml'

Motion::Project::App.setup do |app|
  # Use `rake config' to see complete project settings.
  app.name = 'Browser'

  if File.exists?('./config.yml')
    config = YAML::load_file('./config.yml')
    app.testflight.sdk        = 'vendor/TestFlightSDK'
    app.testflight.api_token  = config['testflight']['api_token']
    app.testflight.team_token = config['testflight']['team_token']
    app.testflight.distribution_lists = config['testflight']['distribution_lists']

    app.codesign_certificate = config['certificate']
    app.provisioning_profile = config['provisioning']
  end

  app.pods do
    dependency 'JSONKit'
    dependency 'AFNetworking'
    dependency 'GDataXML-HTML'
    dependency 'NSData+MD5Digest'
  end

  app.info_plist['CFBundleDisplayName'] = 'ぶらうざ'
end
