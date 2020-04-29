require File.expand_path("../lib/ecsutil/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "ecsutil"
  s.version     = ECSUtil::VERSION
  s.summary     = "TBD"
  s.description = "TBD"
  s.homepage    = ""
  s.authors     = ["Dan Sosedoff"]
  s.email       = ["dan.sosedoff@gmail.com"]
  s.license     = "MIT"

  s.add_development_dependency "rake", "~> 10"
  s.add_dependency "json", "~> 2"
  s.add_dependency "ansible-vault", "~> 0.2"
  s.add_dependency "hashie", "~> 4"
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{|f| File.basename(f)}
  s.require_paths = ["lib"]
end