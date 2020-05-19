# encoding: UTF-8

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-management_plugin"
  s.version     = "2.0.0"
  s.authors     = "Floris Janssens"
  s.email       = "florisjanssens@outlook.com"
  s.homepage    = "https://github.com/florisjanssens/openproject-management_plugin"
  s.summary     = 'OpenProject Management Plugin'
  s.description = "Plugin to bulk manage OpenProject Users, Groups, Roles and Projects"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,lib,doc}/**/*"] + %w(README.md)
  s.test_files = Dir["spec/**/*"]
end
