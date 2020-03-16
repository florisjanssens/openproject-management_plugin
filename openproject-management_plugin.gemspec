# encoding: UTF-8

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-management_plugin"
  s.version     = "0.0.1"
  s.authors     = "Floris Janssens"
  s.email       = "florisjanssens@outlook.com"
  s.homepage    = "https://gitlab.groept.be/floris.janssens/openproject-management-plugin.git"
  s.summary     = 'OpenProject Management Plugin'
  s.description = "Plugin to bulk manage OpenProject Users and Projects"
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib,doc}/**/*"] + %w(README.md)

  s.add_dependency "rails", "~> 6.0"
end
