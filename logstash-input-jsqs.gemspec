Gem::Specification.new do |s|
  s.name          = 'logstash-input-jsqs'
  s.version       = '5.0.0'
  s.homepage      = 'https://github.com/JamieCressey/logstash-input-jsqs'
  s.licenses      = ['Apache-2.0']
  s.summary       = "SQS input plugin using the AWS Java SDK"
  s.description   = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install logstash-input-jsqs. This gem is not a stand-alone program"
  s.authors       = ["Jamie Cressey"]
  s.email         = 'jamiecressey89@gmail.com'
  s.require_paths = ['lib']
  s.platform      = RUBY_PLATFORM

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.requirements << "jar 'com.amazonaws:aws-java-sdk', '1.11.76'"
  s.requirements << "jar 'commons-logging:commons-logging', '1.2'"
  s.requirements << "jar 'org.apache.httpcomponents:httpclient', '4.5.2'"
  s.requirements << "jar 'org.apache.httpcomponents:httpcore', '4.4.5'"

  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'logstash-codec-json'
  s.add_runtime_dependency 'jar-dependencies'

  s.add_development_dependency 'logstash-devutils'
end
