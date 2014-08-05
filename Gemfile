source 'https://rubygems.org'

gem 'vcr'
gem 'webmock'
gem 'pry'
gem 'timecop'

gemspec

# TODO: Update this to branch '2-2-dev' once we have returns & exchanges merged in.
# TODO: Remove this completely whenever we upgrade spree_avatax to Spree 2.4+
gem 'spree_core', git: 'git@github.com:bonobos/spree.git', branch: '2-2-dev-returns-and-exchanges'

group :test, :development do
  platforms :ruby_19 do
    gem 'pry-debugger'
  end
  platforms :ruby_20, :ruby_21 do
    gem 'pry-byebug'
  end
end
