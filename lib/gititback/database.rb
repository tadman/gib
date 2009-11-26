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
  def dump(database_name, dst)
    print "Dummping #{database_name} ..."
    command = "mysqldump5"
    command << " -u #{@username}"
    command << " --skip-comments"
    command << " --skip-extended-insert"
    command << " --single-transaction"
    command << " --quick"
    command << " -p #{@password}" unless @password.blank?
    command << " #{database_name}"
    command << " > #{dst}"
    output = `#{command}`
    unless $?.success?
      puts "Error: #{output}"
    else
      puts 'Done'
    end
  end
  
  def cleanup_dump(database_name, dst)
    FileUtils.rm(dst)
  end
end