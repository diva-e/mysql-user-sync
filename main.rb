#!/usr/bin/env ruby
# Description: Sync MySQL User by yaml files
# ./main.rb path/to/settings.yaml path/to/user/yamls/

# require 'bundler/setup'

require_relative 'lib/config_parser.rb'
require_relative 'lib/mysql.rb'
require_relative 'lib/user.rb'
require_relative 'lib/grant.rb'
require_relative 'lib/settings.rb'

if $PROGRAM_NAME == __FILE__
  # @todo argument/opts parser
  @settings = Settings.new(ARGV[0])
  mysql_handler = MysqlHandler.new(
    Mysql2::Client.new(
      :host => @settings.mysql['host'],
      :username => @settings.mysql['user'],
      :password => @settings.mysql['password'],
      :port => @settings.mysql['port']
    )
  )
  # add mysql connection user to ignore list, do not drop out ourself
  # Do we connect remote or local?
  mysql_connection_userhost = case @settings.mysql['host']
                              when 'localhost'
                                'localhost'
                              when '127.0.0.1'
                                'localhost'
                              else
                                '%'
                              end
  @settings.ignore_user_push(@settings.mysql['user'], mysql_connection_userhost)

  # get all user on server
  server_users = {}
  mysql_handler.users do |user|
    mysql_handler.get_grants(user.to_s) { |grant_obj| user.grants[grant_obj.to_s] = grant_obj }
    server_users[user.to_s] = user
  end

  # managed users have their config generated in text files via puppet
  managed_users = ConfigParser.parse_user_files(ARGV[1])

  list_user_exists = (server_users.keys & managed_users.keys) - @settings.ignore_user
  list_user_new = (managed_users.keys - list_user_exists) - @settings.ignore_user
  list_user_unmanaged = (server_users.keys - managed_users.keys) - @settings.ignore_user

  # generate new user
  list_user_new.each do |username|
    user = managed_users[username]
    next if user.delete

    p "Create User #{username}"
    user.password
    # create user
    mysql_handler.create_user(user.to_s, user.password, user.replicate)
    # add to existing user, to push grants
    list_user_exists.push(username)
    server_users[username] = User.new(username)
  end

  # sync (or drop) managed user with the server
  list_user_exists.each do |username|
    user = managed_users[username]
    if user.delete == false
      # compare via internal method logic
      # if the user is already in sync, do nothing
      unless server_users[username] == user
        p "update config User #{username}"
        mysql_handler.start_transaction(user.replicate)
        # set password
        mysql_handler.set_password(user.to_s, user.password)
        # revoke first all privs
        mysql_handler.revoke_all(user.to_s)
        # set new grants
        user.grants.each_value do |grant|
          mysql_handler.grant(user.to_s, grant.table, grant.rights, grant.grant_option)
        end
        # update resource limit/options
        mysql_handler.resource_options(user)
        mysql_handler.commit
        mysql_handler.flush_privileges
      end
    else
      p "Drop config User #{username}"
      mysql_handler.replication(user.replicate)
      mysql_handler.drop_user(user.to_s)
    end
  end

  # generate reports
  p 'Generate Reports'
  @settings.reports.unmanaged && File.open(@settings.reports.unmanaged, 'w') { |f| f.write(list_user_unmanaged.join("\n")) }
  @settings.reports.managed   && File.open(@settings.reports.managed, 'w') { |f| f.write(managed_users.keys.join("\n")) }
end
