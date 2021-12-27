require 'spec_helper'
require_relative '../lib/user'

RSpec.describe 'User' do
  describe 'with valid data' do
    it 'creates user object' do
      subject = User.new('foo@localhost', '*0000000000000000000000000000000000000000')

      expect(subject.name).to eq 'foo'
      expect(subject.host).to eq 'localhost'
      expect(subject.password).to eq '*0000000000000000000000000000000000000000'
      expect(subject.replicate).to eq true
      expect(subject.delete).to eq false
    end
  end

  describe 'with invalid password' do
    it 'raises invalid username exception' do
      expect { User.new('foo', 'invalid password') }.to raise_error 'Invalid database user foo'
    end

    it 'raises invalid password exception' do
      expect { User.new('foo@localhost', 'invalid password') }.to raise_error 'Invalid password hash invalid password'
    end
  end

  describe 'static method #split_username' do
    it 'splits user and host' do
      expect(User.split_username('user@127.0.0.1')).to eq ['user', '127.0.0.1']
    end
    it 'empty host string' do
      expect(User.split_username("'user'@''")).to eq ['user', '']
    end
    it 'fails to splits user and host' do
      users = ['user127.0.0.1', "'user@invalid'", "\"user'@localhost"]
      users.each do |name|
        expect { User.split_username(name) }.to raise_error "Invalid database user #{name}"
      end
    end
  end

  describe 'static method #make_username' do
    it 'returns an valid mysql username string' do
      expect(User.make_username('test', 'testurl.com')).to eq "'test'@'testurl.com'"
      expect(User.make_username('test', '')).to eq "'test'@''"
      expect(User.make_username('test', '%')).to eq "'test'@'%'"
    end
  end

  describe 'resource options' do
    it 'allows only integer' do
      subject = User.new('foo@localhost', '*0000000000000000000000000000000000000000')
      expect { subject.with_max_user_connections = 'not a number' }.to raise_error 'max_user_connections parameter needs to be integer'
      expect { subject.with_max_user_connections = 'd' }.to raise_error 'max_user_connections parameter needs to be integer'
      expect { subject.with_max_user_connections = true }.to raise_error 'max_user_connections parameter needs to be integer'
    end

    it 'is valid' do
      subject = User.new('foo@localhost', '*0000000000000000000000000000000000000000')
      # default should be 0
      expect(subject.with_max_user_connections).to eq 0
      # set to an number
      subject.with_max_user_connections = 200
      expect(subject.with_max_user_connections).to eq 200
      # reset to default
      subject.with_max_user_connections = 0
      expect(subject.with_max_user_connections).to eq 0
    end
  end
end
