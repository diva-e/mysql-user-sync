class Grant
  attr_reader :table, :grant_option

  def initialize(table)
    # @todo validate
    @rights = []
    table_string = ''

    # We can't escape *.* so special case this.
    table_string << if table == '*.*'
                      '*.*'
                    # Special case also for PROCEDURES
                    elsif table.start_with?('PROCEDURE ')
                      table.sub(/^PROCEDURE (.*)(\..*)/, 'PROCEDURE `\1`\2')
                    elsif table.end_with?('.*') # table has the form `abc%`.*
                      table.sub(/^(.*)(\.)(.*)/, '`\1`\2\3')
                    else
                      table.sub(/^(.*)(\.)(.*)/, '`\1`\2`\3`')
                    end
    # fix double quote if exist
    @table = table_string.gsub(/``/, '`')
    @grant_option = false
  end

  # describe this grant as it is unique per table
  def to_s
    @table
  end

  def all?
    all_grants = ['SELECT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'RELOAD', 'SHUTDOWN', 'PROCESS', 'FILE',
                  'REFERENCES', 'INDEX', 'ALTER', 'SHOW DATABASES', 'SUPER', 'LOCK TABLES', 'EXECUTE',
                  'REPLICATION SLAVE', 'REPLICATION CLIENT', 'CREATE VIEW', 'SHOW VIEW', 'CREATE ROUTINE', 'ALTER ROUTINE',
                  'CREATE USER', 'TRIGGER', 'CREATE TABLESPACE', 'CREATE ROLE', 'DROP ROLE'
                 ]
    all_grants = ['APPLICATION_PASSWORD_ADMIN', 'BACKUP_ADMIN', 'BINLOG_ADMIN', 'BINLOG_ENCRYPTION_ADMIN', 'CONNECTION_ADMIN',
                  'ENCRYPTION_KEY_ADMIN', 'GROUP_REPLICATION_ADMIN', 'PERSIST_RO_VARIABLES_ADMIN', 'REPLICATION_SLAVE_ADMIN',
                  'RESOURCE_GROUP_ADMIN', 'RESOURCE_GROUP_USER', 'ROLE_ADMIN', 'SERVICE_CONNECTION_ADMIN', 'SESSION_VARIABLES_ADMIN',
                  'SET_USER_ID', 'SYSTEM_VARIABLES_ADMIN', 'XA_RECOVER_ADMIN'
                  ]
    # puts " all_grants - @rights  #{all_grants - @rights} "
    (all_grants - @rights).empty? || (@rights.include? 'ALL PRIVILEGES')
  end

  def grant_option=(bool)
    raise 'grant_option parameter needs to be boolean' unless [true, false].include? bool
    @grant_option = bool
  end

  def enable(right)
    # remove whitespaces arround string
    right.strip!
    # Privileges always uppercase
    right.upcase!

    right = 'ALL PRIVILEGES' if right == 'ALL'
    # Usage is just the same as no privileges
    return if right == 'USAGE'

    # Validate 5.6 and 5.7 has the same http://dev.mysql.com/doc/refman/5.7/en/grant.html#grant-privileges
    # Added more privileges for 8.0 : https://dev.mysql.com/doc/refman/8.0/en/grant.html#grant-privileges
    all_privs = ['ALL PRIVILEGES', 'ALTER', 'ALTER ROUTINE', 'CLONE_ADMIN', 'CREATE', 'CREATE ROLE', 'CREATE ROUTINE',
                 'CREATE TABLESPACE',	'CREATE TEMPORARY TABLES', 'CREATE USER',	'CREATE VIEW', 'DELETE', 'DROP', 'DROP ROLE',
                 'EVENT', 'EXECUTE',	'FILE', 'GRANT OPTION', 'INDEX', 'INNODB_REDO_LOG_ARCHIVE',	'INSERT',
                 'LOCK TABLES', 'PROCESS',	'PROXY',	'REFERENCES', 'RELOAD',	'REPLICATION CLIENT',	'REPLICATION SLAVE',
                 'SELECT',	'SHOW DATABASES',	'SHOW VIEW',	'SHUTDOWN', 'SUPER',	'TRIGGER',	'UPDATE', 'USAGE',
                 'APPLICATION_PASSWORD_ADMIN', 'AUDIT_ADMIN', 'BACKUP_ADMIN', 'BINLOG_ADMIN', 'BINLOG_ENCRYPTION_ADMIN',
                 'CONNECTION_ADMIN', 'ENCRYPTION_KEY_ADMIN', 'FIREWALL_ADMIN', 'FIREWALL_USER', 'GROUP_REPLICATION_ADMIN',
                 'PERSIST_RO_VARIABLES_ADMIN', 'REPLICATION_APPLIER', 'REPLICATION_SLAVE_ADMIN', 'RESOURCE_GROUP_ADMIN', 'RESOURCE_GROUP_USER', 'ROLE_ADMIN',
                 'SESSION_VARIABLES_ADMIN', 'SET_USER_ID', 'SYSTEM_USER', 'SYSTEM_VARIABLES_ADMI', 'TABLE_ENCRYPTION_ADMIN',
                 'VERSION_TOKEN_ADMIN', 'XA_RECOVER_ADMIN', 'SERVICE_CONNECTION_ADMIN', 'SYSTEM_VARIABLES_ADMIN','INNODB_REDO_LOG_ENABLE',
                 'SHOW_ROUTINE',
               ]

    raise "#{right} is not a compatible privilege" unless all_privs.include?(right)

    if right == 'GRANT OPTION'
      @grant_option = true
    else
      @rights = [] if @rights.nil?
      @rights.push(right)
      # set all to the only one if its included
      @rights = ['ALL PRIVILEGES'] if all?
    end
  end

  def rights
    privs = @rights.uniq.sort
    privs = ['USAGE'] if privs.empty?
    privs
  end

  # equals this grant to another grant object
  def ==(other)
    # this is not the same table
    return false unless @table == other.table
    return false unless @grant_option == other.grant_option
    return true if all? == true && other.all? == true
    rights == other.rights
  end
end
