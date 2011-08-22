require "rails"
require "action_controller"
require "active_record"
require 'thinking_sphinx/deltas/delayed_delta'

module FluxxGrant
  class Engine < Rails::Engine
    config.i18n.load_path += Dir["#{File.dirname(__FILE__).to_s}/../../config/fluxx_locales/*.{rb,yml}"]
    initializer 'fluxx_engine.add_compass_hooks', :after=> :disable_dependency_loading do |app|
      Fluxx.logger.debug "Loaded FluxxGrant"
      Sass::Plugin.add_template_location "#{File.dirname(__FILE__).to_s}/../../app/stylesheets", "public/stylesheets/compiled/fluxx_grant"
      # Make sure that sphinx indices are loaded properly
      # In thinking sphinx's ThinkingSphinx::Context#add_indexed_models method, I ran rails console and then watched what order the classes are loaded
      Organization rescue nil
      RequestTransaction rescue nil
      RequestReport rescue nil
      Request rescue nil
      User rescue nil
      Project rescue nil
      Request.sphinx_index_names rescue nil
      
      
      LiquidLoader.include_libraries
      
      defaults = AdminDefaults.singleton
      begin
        defaults.workflows = [['New Request Workflow', Request.name], ['New Report Workflow', RequestReport.name], ['New Transaction Workflow', RequestTransaction.name]],
        defaults.alerts = [['New Report Alert', RequestReportsController.name]],
        defaults.roles = [['New Program Role', Program.name]],
        defaults.states = [['New Request State', Request.name], ['New Report State', RequestReport.name], ['New Transaction State', RequestTransaction.name]],
        defaults.attributes = [['New Request Attribute', Request.name], ['New Report Attribute', RequestReport.name], ['New Transaction Attribute', RequestTransaction.name], ['New LOI Attribute', Loi.name]],
        defaults.methods = [['New Request Model Method', Request.name], ['New Report Model Method', RequestReport.name], ['New Transaction Model Method', RequestTransaction.name]],
        defaults.validations = [['New Request Model Validation', Request.name], ['New Report Model Validation', RequestReport.name], ['New Transaction Model Validation', RequestTransaction.name]],
        defaults.pre_create = ['GrantRequest']
      rescue Exception => e
        p "ESH: have an error while setting up AdminDefaults: #{e.inspect}, #{e.backtrace.inspect}"
      end
      
      begin
        FluxxSphinxCheck.add_check Organization, 100, 2
        FluxxSphinxCheck.add_check User, 100, 2
        FluxxSphinxCheck.add_check Request, 100, 2
      rescue Exception => e
        p "ESH: have an error while setting up FluxxSphinxCheck: #{e.inspect}, #{e.backtrace.inspect}"
      end
    end
    
    rake_tasks do
      load File.expand_path('../../tasks.rb', __FILE__)
    end
  end
end
