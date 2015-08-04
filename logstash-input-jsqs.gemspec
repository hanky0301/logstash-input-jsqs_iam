Gem::Specification.new do |s|
  s.platform = RUBY_PLATFORM
  s.name = 'logstash-input-jsqs'
  s.version = '0.9.1'
  s.licenses = ['Apache License (2.0)']
  s.summary = "SQS input plugin using the AWS Java SDK"
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install logstash-input-jsqs. This gem is not a stand-alone program"
  s.authors = ["Jamie Cressey"]
  s.email = 'jamiecressey89@gmail.com'
  s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency 'logstash-core', '>= 1.4.0', '< 2.0.0'
  s.add_development_dependency 'logstash-devutils'

end
