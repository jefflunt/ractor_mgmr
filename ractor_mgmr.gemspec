Gem::Specification.new do |s|
  s.name        = "ractor_mgmr"
  s.version     = "1.1.0"
  s.description = "a job queue and monitor for Ractors"
  s.summary     = "want to have a job queue for a list of identical Ractors, and have a little manager that feeds them work as they become availble? then this library is for you"
  s.authors     = ["Jeff Lunt"]
  s.email       = "jefflunt@gmail.com"
  s.files       = ["lib/ractor_mgmr.rb"]
  s.homepage    = "https://github.com/jefflunt/ractor_mgmr"
  s.license     = "MIT"

  s.add_runtime_dependency "tiny_eta", [">= 1.0.1"]
end
