require_relative 'config_parser.rb'
require_relative 'user'

class Settings
  attr_reader :ignore_user
  def initialize(file)
    @settings = ConfigParser.file(file)

    @ignore_user = []
    @settings['ignore_user'].each do |user|
      # validate name
      name, host = User.split_username(user)
      # add to array
      ignore_user_push(name, host)
    end

    # add mysql port if undefined
    @settings['mysql_connection']['port'] = 3306 unless @settings['mysql_connection'].key? 'port'
  end

  def mysql
    @settings['mysql_connection']
  end

  def ignore_user_push(name, host)
    @ignore_user.push(User.make_username(name, host))
  end

  def reports
    SettingsReport.new(@settings['reports'])
  end
end

class SettingsReport
  attr_reader :unmanaged, :managed

  def initialize(report)
    @unmanaged = report['unmanaged_user'] unless report['unmanaged_user'].nil?
    @managed = report['managed_user'] unless report['managed_user'].nil?
  end
end
