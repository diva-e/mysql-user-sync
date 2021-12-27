# Parse directory for yaml files and return as hash
require 'yaml'
require_relative 'user'
require_relative 'grant'

module ConfigParser
  def self.file(file)
    YAML.load_file(file)
  end

  # scan whole folder and return hash
  def self.dir(dir)
    config = {}
    files = Dir.glob("#{dir}/*.yaml")
    raise 'Directory is empty' if files.empty?

    # merge all files together
    files.each do |filename|
      config.merge!(file(filename))
    end
    config
  end

  # Get final user -> parse all user by config
  def self.parse_user_files(user_dir)
    managed_users = {}
    dir(user_dir).each do |username, userconfig|
      user = User.new(username)

      user.replicate = userconfig['replicate']
      delete = userconfig['ensure']
      unless delete.nil?
        if [true, false].include? delete
          user.delete = !delete
        elsif %w[true false].include? delete
          user.delete = (delete == 'false')
        elsif delete == 'present'
          user.delete = false
        elsif delete == 'absent'
          user.delete = true
        else
          raise "Invalid ensure/delete setting for user #{user}"
        end
      end

      unless user.delete
        user.password = userconfig['password_hash']

        userconfig['grants'].each do |grant|
          # crate new grant object if not exist for this table
          grant_obj = Grant.new(grant['table'])
          # grant already exists on user, so use this and extend
          grant_obj = user.grants[grant_obj.to_s] unless user.grants[grant_obj.to_s].nil?
          # enable grants
          grant['rights'].each { |right| grant_obj.enable(right) }
          user.grants[grant_obj.to_s] = grant_obj
        end
      end

      # resources/limits
      user.with_max_user_connections = userconfig['max_user_connections'] if userconfig['max_user_connections']

      managed_users[user.to_s] = user
    end
    managed_users
  end
end
