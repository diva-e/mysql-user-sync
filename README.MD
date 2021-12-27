MySQL - User synchronisation
============================
This tool manage complex user grants for mysql users from a set a per-user yaml files, containing the grants. It ensures that only the mentioned grants in the yaml file are set and passwords are synchronized.

Integration can be done via any tool generating the user yaml configuration files. Especially for MySQL 5.7, this can give the possibility to manage permissions based on user groups, implemented via the yaml per-user file generator.

## Path
Puppet/Ansible/Scripts --> Build yaml files --> Management scripts process user.yaml -->  Merge rights by table selector --> Compare source and dest grants --> Revoke none existing grants --> Apply merged grants --> Generate lists of managed and unmanaged users found in MySQL

## Configuration
### settings.yaml
Basic configuration of the sync

```
mysql_connection:
  user: puppet
  password: puppet
  host: 172.16.254.11

# these users are untouched and remain as it is in mysql
ignore_user:
    - root@localhost
    - root@%
    - repl@%
    - debian-sys-maint@localhost

# write these report files for monitoring etc..
reports:
  managed_user: /var/opt/mysql_managed_user.list
  unmanaged_user: /var/opt/mysql_unmanaged_user.list
```

### per user.yaml
Each user should be placed as single yaml file in an folder for parsing.

```
---
# mysql username @ host
"'test'@'%'":

  # like puppet, absent == drop user with all rights!
  ensure: present

  # enable or disable mysql replication of this user (mysql slaves will not receive these grant queries)
  replicate: false

  # Mysql password hash == 40 chars
  password_hash: 61111A4A85FF8B9B20E90B56177A551683BFBE7B

  # WITH MAX_USER_CONNECTION = count, defaults to 0 which means unlimited
  max_user_connections = 10

  # Array of all grants
  grants:
    - table: "*.*" # Set rights globally for all tables/databases.
      rights:
        - ALL PRIVILEGES
        - GRANT OPTION
    - table: "mydb.mytable" # set additional grant to this table
      rights:
        - SELECT
        - UPDATE
        - DELETE
```

### Dependencies
- Ruby >= 1.9.3
- Ruby mysql2 module `apt-get install ruby-mysql2`

### Usage
`ruby main.rb settings.yaml path/to/users.yaml/`

## Open features to implement
 - Mysql version 8 implementation - as it has groups this will have an big refactor impact
 - Drop unmanaged user
