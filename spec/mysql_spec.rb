require 'spec_helper'
require_relative '../lib/mysql'

RSpec.describe 'Method MysqlHandler#users' do
  describe 'Initialize handler' do
    it 'pass with valid mysql version' do
      conn = double('MysqlConnection')
      allow(conn).to receive(:server_info).and_return(:version => '5.6.27-56')
      MysqlHandler.new(conn)
    end

    it 'raise with invalid mysql version before 5.6' do
      conn = double('MysqlConnection')
      allow(conn).to receive(:server_info).and_return(:version => '5.4.21')
      expect { MysqlHandler.new(conn) }.to raise_error 'Incompatible MySQL Version 5.4.21'
    end

    it 'raise with invalid mysql version before 5.6' do
      conn = double('MysqlConnection')
      allow(conn).to receive(:server_info).and_return(:version => '5.5.21')
      expect { MysqlHandler.new(conn) }.to raise_error 'Incompatible MySQL Version 5.5.21'
    end

    it 'raise with invalid mysql version above 8' do
      conn = double('MysqlConnection')
      allow(conn).to receive(:server_info).and_return(:version => '9.0.1-56')
      expect { MysqlHandler.new(conn) }.to raise_error 'Incompatible MySQL Version 9.0.1'
    end

    it 'raise with invalid mysql version above 5.7' do
      conn = double('MysqlConnection')
      allow(conn).to receive(:server_info).and_return(:version => '5.8.17-56')
      expect { MysqlHandler.new(conn) }.to raise_error 'Incompatible MySQL Version 5.8.17'
    end
  end

  describe 'with valid data' do
    before(:each) do
      rows = [
        { 'User' => 'Username', 'Host' => 'Host', 'pw' => '*0000000000000000000000000000000000000000', 'max_user_connections' => 0 },
        { 'User' => 'Foo', 'Host' => 'Bar', 'pw' => '', 'max_user_connections' => 1 },
        { 'User' => 'mysql.session', 'Host' => 'localhost', 'pw' => '*THISISNOTANVALIDPASSWORD', 'max_user_connections' => 300 }
      ]
      conn = double('MysqlConnection')
      allow(conn).to receive(:query).and_return(rows)
      allow(conn).to receive(:server_info).and_return(:version => '5.6.27-56')
      @subject = MysqlHandler.new(conn)
    end

    it 'creates Users with Host and Password' do
      users = []
      @subject.users { |user| users.push(user) }
      expect(users.length).to eq 3

      user1 = users[0]
      expect(user1).to be_an_instance_of(User)
      expect(user1.name).to eq 'Username'
      expect(user1.host).to eq 'Host'
      expect(user1.password).to eq '*0000000000000000000000000000000000000000'
      expect(user1.with_max_user_connections).to eq 0

      user2 = users[1]
      expect(user2).to be_an_instance_of(User)
      expect(user2.password).to eq nil
      expect(user2.with_max_user_connections).to eq 1

      user3 = users[2]
      expect(user3).to be_an_instance_of(User)
      expect(user3.name).to eq 'mysql.session'
      expect(user3.host).to eq 'localhost'
      expect(user3.password).to eq '*THISISNOTANVALIDPASSWORD'
      expect(user3.with_max_user_connections).to eq 300
    end
  end
end
