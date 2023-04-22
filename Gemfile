source 'https://rubygems.org'

# Specify your gem's dependencies in drum.gemspec
gemspec

# Install AppleScript bridge on macOS
#
# Note: End-users installing drum via 'gem install'
# will need to install rb-scpt manually to use the integration.
#
# TODO: Investigate whether this could be done automatically
# See https://stackoverflow.com/a/10249133 for more info.
# Unfortunately checking the OS in the gemspec is insufficient,
# since the file is evaluated at packaging time.
if RUBY_PLATFORM =~ /\bdarwin/
  gem 'rb-scpt', '~> 1.0'
end

group :development, :test do
  gem 'rake', '~> 13.0'
  gem 'yard', '~> 0.9'
  gem 'rspec', '~> 3.10'
end
