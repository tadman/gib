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
    
    Gititback::Config.config_file_path = @options.delete(:config)
    
    @config = Gititback::Config.new(@options)
    @client = Gititback::Client.new(@config)
  end

  def perform!
    command = @args.first
    
    case (command)
    when 'status'
      puts "#{@config.server_id} Status:"
      puts '-' * 78

      @client.local_entities_list.each do |e|
        puts "%-40s %-37s" % [ Gititback::Support.shortform_path(e.path), e.status ]
      end
      
      if (@client.local_entities_list.empty?)
        puts "No backupable entities found. Use 'gib search' to see search paths."
      end
    when 'config'
      puts "Configuration"
      puts '-' * 78
      
      @config.to_h.collect do |key, value|
        case (value)
        when Array
          value.each_with_index do |item, i|
            puts "%-20s %s" % [ (i == 0 ? key : ''), item ]
          end
        else
          puts "%-20s %s" % [ key, value ]
        end
      end
      
      puts
      puts "Config Files"
      puts '-' * 78

      puts "#{Gititback::Config.config_file_path} (Loaded)"
      Gititback::Config.config_files_found.each do |file|
        next if (file == Gititback::Config.config_file_path)

        puts file
      end
    when 'search'
      puts "#{@config.server_id} Search:"
      puts '-' * 78
      
      home_dir = File.expand_path('~')
      count = 0
      
      @client.expand_source_dirs(false).each do |source, paths|
        if (paths.empty?)
          puts "%-40s %s" % [ source, '-' ]
        else
          paths.sort.each_with_index do |path, i|
            puts "%-40s %s" % [
              i > 0 ? '' : source,
              Gititback::Support.shortform_path(path) + (@client.should_ignore_source?(path) ? ' (Ignored)' : '')
            ]
          end
        end
      end
    else
      raise Gititback::Exception::InvalidCommand, "Invalid command #{command}"
    end
  end
  
  def options
    @options
  end
end
