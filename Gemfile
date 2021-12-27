source 'https://rubygems.org'

mysql2_version = nil
rubcop_version = nil
if RUBY_VERSION == '1.9.3'
  # trusty
  mysql2_version = '= 0.3.2'
  rubcop_version = '= 0.40.0'
elsif RUBY_VERSION == '2.3.1'
  mysql2_version = '= 0.4.3'
end

gem 'mysql2', mysql2_version
gem 'rake'
gem 'rspec'
gem 'rspec-mocks'
gem 'rubocop', rubcop_version
