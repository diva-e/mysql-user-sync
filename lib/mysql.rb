require 'mysql2'

class MysqlHandler
  attr_reader :version

  def initialize(mysql_connection)
    @version = Class.new
    class << @version
      attr_accessor :major, :minor, :release
    end

    raise 'Cannot retrieve MySQL Version' unless mysql_connection.server_info[:version] =~ /^(\d)\.(\d)\.(\d*)/
    @version.major = Integer(Regexp.last_match(1))
    @version.minor = Integer(Regexp.last_match(2))
    @version.release = Regexp.last_match(3)

    raise "Incompatible MySQL Version #{@version.major}.#{@version.minor}.#{@version.release}" unless (@version.major == 5 && @version.minor >= 6 && @version.minor <= 7) || (@version.major == 8 && @version.minor == 0)

    @mysql_connection = mysql_connection
  end

  # get all user
  def users
    # Get current user -> read all user from mysql
    rs = if @version.major == 5 && @version.minor == 7
           @mysql_connection.query 'SELECT User, Host, authentication_string as pw, Plugin, max_user_connections FROM mysql.user WHERE User not in ("", "mysql.sys")'
         elsif  @version.major == 8 && @version.minor == 0
           @mysql_connection.query 'SELECT User, Host, authentication_string as pw, Plugin, max_user_connections FROM mysql.user WHERE User not in ("", "mysql.sys")'
         else
           @mysql_connection.query 'SELECT User, Host, Password as pw, Plugin, max_user_connections FROM mysql.user WHERE User != ""'
         end
    rs.each do |row|
      user = User.new("'#{row['User']}'@'#{row['Host']}'")
      user.password_raw = !(row['pw'].nil? || row['pw'].empty?) ? row['pw'] : nil
      # resource options
      user.with_max_user_connections = row['max_user_connections']
      yield user
    end
  end

  # get grants for user
  def get_grants(user)
    rs_grants = @mysql_connection.query "SHOW GRANTS FOR #{user}"
    rs_grants.each(:as => :array) do |grant|
      # parse row
      raise "Failed to parse Grant for #{user}" unless grant[0] =~ /^GRANT (.*?) ON (.*?) TO ([`'].*?[`']@[`'].*?[`'])/
      # ignore special root user case
      next if grant[0] == "GRANT PROXY ON ''@'' TO 'root'@'localhost' WITH GRANT OPTION"

      privs = Regexp.last_match(1)
      table = Regexp.last_match(2)

      # Skip if username is not the same
      grant_user_name, grant_user_host = User.split_username(Regexp.last_match(3))
      next unless user == User.make_username(grant_user_name, grant_user_host)

      grant_obj = Grant.new(table)
      # Add grant option as privilege if present
      grant_obj.grant_option = true if grant[0] =~ /WITH GRANT OPTION/
      privs.split(',').each { |priv| grant_obj.enable(priv) }
      yield grant_obj
    end
  end

  def query(query)
    p query
    @mysql_connection.query query
  end

  def set_password(user, pwhash)
    if @version.major == 5 && @version.minor == 7
      query("ALTER USER #{user} IDENTIFIED WITH mysql_native_password AS '#{pwhash}'")
    elsif @version.major == 8 && @version.minor == 0
      query("ALTER USER #{user} IDENTIFIED WITH mysql_native_password AS '#{pwhash}'")
    else
      query("SET PASSWORD FOR #{user} = '#{pwhash}'")
    end
  end

  # update resource limits
  def resource_options(user)
    query("UPDATE mysql.user SET
            max_user_connections = #{user.with_max_user_connections}
          WHERE User = '#{user.name}' AND Host = '#{user.host}'")
  end

  def revoke_all(user)
    query("REVOKE ALL PRIVILEGES, GRANT OPTION FROM #{user}")
  end

  # revoke all privs from table
  def revoke(user, table)
    query("REVOKE ALL PRIVILEGES ON #{table} FROM #{user}")
  end

  def grant(user, table, privilieges, grant_option = false)
    query_grant_option = ''
    query_grant_option = 'WITH GRANT OPTION' if grant_option
    privilieges = privilieges.join(',')
    query("GRANT #{privilieges} ON #{table} TO #{user} #{query_grant_option}")
  end

  def create_user(user, password, replicate = nil)
    replication(replicate) unless replicate.nil?
    if @version.major == 8 && @version.minor == 0
      query("CREATE USER #{user} IDENTIFIED BY '#{password}'")
    else
      query("CREATE USER #{user} IDENTIFIED BY PASSWORD '#{password}'")
    end
  end

  def drop_user(user)
    query("DROP USER #{user}")
  end

  def replication(replicate)
    case replicate
    when true
      sql_log_bin = 1
    when false
      sql_log_bin = 0
    else
      raise 'Replication must be boolean'
    end

    # enable/disable binary logging of this query
    query "SET sql_log_bin = #{sql_log_bin}"
  end

  def start_transaction(replicate = nil)
    replication(replicate) unless replicate.nil?
    query 'START TRANSACTION'
  end

  def commit
    query 'COMMIT'
  end

  def flush_privileges
    query 'FLUSH PRIVILEGES'
  end
end
