require 'spec_helper'
require 'mysql2'
require_relative '../lib/settings'
require_relative '../lib/config_parser'

# run tests
RSpec.describe 'Integration test against database' do
  before(:all) do
    # run only if mysql password is set
    skip unless ENV['MYSQL_ROOT_PASSWORD']

    # prepare
    fixtures = File.join(File.dirname(__FILE__), 'fixtures/')
    fixtures_settings = File.join(fixtures, 'settings.yaml')
    fixtures_user_dir = File.join(fixtures, 'users/')

    # connection
    settings = Settings.new(fixtures_settings)
    @mysql_connection = Mysql2::Client.new(host: settings.mysql['host'],
                                           username: settings.mysql['user'],
                                           password: settings.mysql['password'],
                                           port: settings.mysql['port'])
    # parse fixtures
    @fixture_user = ConfigParser.parse_user_files(fixtures_user_dir)
  end

  describe 'check destination user' do
    it 'consistent with database' do
      @fixture_user.each_value do |user|
        rs = @mysql_connection.query "SELECT User, Host, authentication_string as pw, max_user_connections FROM mysql.user WHERE User = '#{user.name}' AND host = '#{user.host}'"
        if user.delete
          expect(rs.count).to eq 0
        else
          expect(rs.count).to eq 1
        end
        rs.each do |row|
          expect(row['pw']).to eq user.password
          expect(row['max_user_connections']).to eq user.with_max_user_connections
        end
      end
    end
  end
end
