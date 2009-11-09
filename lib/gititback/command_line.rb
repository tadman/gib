class Gititback::CommandLine
  def self.interpret!
    new.perform!
  end
  
  def initialize
    @options = options = { }
    
    @parser =
      OptionParser.new do |op|
        op.banner = "Usage: gib [options] <command>"

        op.on("-v", "--[no-]verbose", "Run verbosely") do |v|
          options[:verbose] = v
        end

        op.on("-c", "--config=s", "Specify alternate configuration file") do |v|
          options[:config] = v
        end

        op.on("-V", "--version", "Show version information") do
          puts "#{COMMAND_NAME}: Version #{Gititback::VERSION}"
          exit
        end
      end
      
    @args = @parser.parse!
    
    @config = Gititback::Config.new(@options)
    @client = Gititback::Client.new(@config)
  end

  def perform!
    command = @args.first
    
    case (command)
    when 'status'
      puts "#{@config.server_id} Status:"
      puts '-' * 78
      @client.local_entities.each do |e|
        puts "%-40s %-37s" % [ e.path, e.status ]
      end
    when 'config'
      puts "Config: ..."
    when 'config'
      puts "Config: ..."
    else
      raise Gititback::Exception::InvalidCommand, "Invalid command #{command}"
    end
  end
  
  def options
    @options
  end
end
