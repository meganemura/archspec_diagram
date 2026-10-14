require_relative "lib/archspec_diagram/version"

Gem::Specification.new do |spec|
  spec.name = "archspec_diagram"
  spec.version = ArchspecDiagram::VERSION
  spec.summary = "Draw an Archspec.rb as a Mermaid flowchart"
  spec.authors = ["meganemura"]
  spec.license = "MIT"
  spec.homepage = "https://github.com/meganemura/archspec_diagram"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["archspec_diagram"]
  spec.add_dependency "archspec", ">= 1.1", "< 2"
end
