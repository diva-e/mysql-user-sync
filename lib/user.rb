class User
  # add getter
  attr_reader :name, :host, :password, :delete, :replicate, :with_max_user_connections
  attr_accessor :grants

  def initialize(username, password = nil)
    # validate user and hostname
    # split user / host
    @name, @host = User.split_username(username)
    self.password = password unless password.nil?
    # defaults
    @grants = {}
    @replicate = true
    @delete = false
    @with_max_user_connections = 0 # 0 is unlimited
  end

  # used by mysql query
  def to_s
    User.make_username(@name, @host)
  end

  # static public method to generate compatible usernames
  def self.make_username(name, host)
    "'#{name}'@'#{host}'"
  end

  # static public method to split user and host
  def self.split_username(username)
    if username =~ /^(['`"])((?:(?!\1).)*)\1@([\w%\.:\-\/]+)$/
      name = Regexp.last_match(2)
      host = Regexp.last_match(3)
    elsif username =~ /^([0-9a-zA-Z$_]*)@([\w%\.:\-\/]+)$/
      name = Regexp.last_match(1)
      host = Regexp.last_match(2)
    elsif username =~ /^((?!['`"]).*[^0-9a-zA-Z$_].*)@(.+)$/
      name = Regexp.last_match(1)
      host = Regexp.last_match(2)
    elsif username =~ /^(['`"])((?:(?!\1).)*)\1@(['`"])((?:(?!\1).)*)\3$/
      name = Regexp.last_match(2)
      host = Regexp.last_match(4)
    else
      raise "Invalid database user #{username}"
    end
    [name, host]
  end

  # has grant for table
  def grant?(table)
    @grants.key?(table)
  end

  def password=(pwhash)
    # add new password version flag
    pwhash = "*#{pwhash}" if pwhash.length == 40
    raise "Invalid password hash #{pwhash}" unless pwhash =~ /^\*[0-9A-F]{40}$/
    @password = pwhash
  end

  # set password without validation, if user has invalid hash in mysql
  def password_raw=(pwhash)
    @password = pwhash
  end

  def delete=(bool)
    raise 'delete parameter needs to be boolean' unless [true, false].include? bool
    @delete = bool
  end

  def replicate=(bool)
    raise 'replicate parameter needs to be boolean' unless [true, false].include? bool
    @replicate = bool
  end

  def with_max_user_connections=(count)
    raise 'max_user_connections parameter needs to be integer' unless count.is_a?(Integer)
    @with_max_user_connections = count
  end

  # equals this user to onother user object
  def ==(other)
    return false unless @with_max_user_connections == other.with_max_user_connections
    return false unless @password == other.password
    return false unless @grants.length == other.grants.length
    @grants.each_value do |grant|
      return false unless other.grant?(grant.to_s)
      return false unless grant == other.grants[grant.to_s]
    end
    true
  end
end
