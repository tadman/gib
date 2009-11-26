class Gititback::Database
  def initialize(options = {})
    @username = options[:username] || 'root'
    @password = options[:password] || ''
    @socket   = options[:socket]
    @host     = options[:host] || 'localhost'
    @port     = options[:port] || 3306
  end

  def connection(name)
    # Only load mysql dependency if this feature is used
    require 'mysql'
    
    name = name.to_sym
    @connection ||= { }
    @connection[name] ||= begin
      conn = Mysql.new(
        @socket ? nil : @host,
        @username,
        @password,
        '',
        @socket ? nil : @port,
        @socket
      )
      yield(conn) if (block_given?)
      conn
    end
  rescue Mysql::Error => e
    puts "ERROR : connecting to #{name} - #{e.message}"
  end
  
  # For more details on the mysqldump options see
  # http://dev.mysql.com/doc/refman/5.1/en/mysqldump.htm
  def dump(database_name, archive_path)
    puts "Dummping #{database_name} ..."
    backup_filename = "#{database_name}.sql"
    command = "mysqldump5"
    command << " -u #{@username}"
    command << " --skip-comments"
    command << " --skip-extended-insert"
    command << " --single-transaction"
    command << " --quick"
    command << " -p #{@password}" unless @password.blank?
    command << " #{database_name}"
    command << " > #{archive_path}/#{backup_filename}"
    puts command
    output = `#{command}`
    unless $?.success?
      puts "Error: #{output}"
    else
      puts 'Done'
    end
  end
  
  def cleanup_dump(database_name, archive_path)
    backup_filename = "#{database_name}.sql"
    FileUtils.rm(File.join(archive_path, backup_filename))
  end
end