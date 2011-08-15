require "rails"
require "fluxx_crm"

require "delayed_job"
require "hoptoad_notifier"
require "httpi"
require "crack"

# Some classes need to be required before or after; put those in these lists
GRANT_EXTENSION_CLASSES_TO_PRELOAD = []
GRANT_EXTENSION_CLASSES_TO_POSTLOAD = []

GRANT_EXTENSION_CLASSES_TO_NOT_AUTOLOAD = GRANT_EXTENSION_CLASSES_TO_PRELOAD + GRANT_EXTENSION_CLASSES_TO_POSTLOAD
GRANT_EXTENSION_CLASSES_TO_PRELOAD.each do |filename|
  require filename
end
all_extension_files = Dir.glob("#{File.dirname(__FILE__).to_s}/extensions/**/*.rb").map{|filename| filename.gsub /\.rb$/, ''}
all_extension_files = all_extension_files.reject{|filename| filename =~ /extensions\/cap_deploy$/}
all_extension_files.reject{|filename| GRANT_EXTENSION_CLASSES_TO_NOT_AUTOLOAD.include?(filename) }.each {|filename| require filename }
GRANT_EXTENSION_CLASSES_TO_POSTLOAD.each do |filename|
  
  require filename
end

Dir.glob("#{File.dirname(__FILE__).to_s}/fluxx_grant/**/*.rb").each do |fluxx_grant|
  require fluxx_grant.gsub /\.rb$/, ''
end

ActiveSupport::Dependencies.autoload_paths << File.dirname(__FILE__) + 
"/../app/helpers"

Dir[File.dirname(__FILE__) + "/../app/helpers/**/*_helper.rb"].each do 
|file|
  ActionController::Base.helper "#{File.basename(file,'.rb').camelize}".constantize
end

public_dir = File.join(File.dirname(__FILE__), '../public')
DirectorySync.new [
  ["#{public_dir}/images", '/images/fluxx_grant'],
  ["#{public_dir}/javascripts", '/javascripts/fluxx_grant'],
  ["#{public_dir}/stylesheets", '/stylesheets/fluxx_grant'],
]

FLUXX_ADMIN_CONFIGURATION = {
    :workflows => [['New Request Workflow', Request.name], ['New Report Workflow', RequestReport.name], ['New Transaction Workflow', RequestTransaction.name]],
    :alerts => [['New Report Alert', RequestReportsController.name]],
    :roles => [['New Program Role', Program.name]],
    :states => [['New Request State', Request.name], ['New Report State', RequestReport.name], ['New Transaction State', RequestTransaction.name]],
    :attributes => [['New Request Attribute', Request.name], ['New Report Attribute', RequestReport.name], ['New Transaction Attribute', RequestTransaction.name], ['New LOI Attribute', Loi.name]],
    :methods => [['New Request Model Method', Request.name], ['New Report Model Method', RequestReport.name], ['New Transaction Model Method', RequestTransaction.name]],
    :validations => [['New Request Model Validation', Request.name], ['New Report Model Validation', RequestReport.name], ['New Transaction Model Validation', RequestTransaction.name]],
    :pre_create => ['GrantRequest']
   } rescue nil
