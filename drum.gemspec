require_relative 'lib/drum/version'

Gem::Specification.new do |spec|
  spec.name          = 'drum'
  spec.version       = Drum::VERSION
  spec.authors       = ['fwcd']

  spec.summary       = 'Playlist manager'
  spec.description   = 'A tool for syncing and backing up your playlists'
  spec.homepage      = 'https://github.com/fwcd/drum.git'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'bin'
  spec.executables   = ['drum']
  spec.require_paths = ['lib']
  
  spec.add_dependency 'thor', '~> 0.20'
  spec.add_dependency 'sequel', '~> 5.39'
end
