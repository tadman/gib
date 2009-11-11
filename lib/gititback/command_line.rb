require 'optparse'

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
      if (entity = @client.entity_for_path(Dir.getwd))
        puts "#{Gititback::Support.shortform_path(entity.path)} => #{Gititback::Support.shortform_path(entity.archive_path)}"
        puts '-' * 78
        
        archived_files = entity.archive.ls_files
        entity_path_length = entity.path.length
        
        entity.files.each do |file|
          if (relative_path = file[entity_path_length + 1, file.length])
            if (File.directory?(file))
              print '= '
            else
              if (archived_files[relative_path])
                print "= "
              else
                print '+ '
              end
            end

            puts relative_path
          end
        end
      else
        puts "Current directory is not part of a backupable entity. Use 'gib report' to see a list of those."
      end
    when 'report'
      puts "#{@config.server_id} Entities:"
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
    when 'permissions'
      if (entity = @client.entity_for_path(Dir.getwd))
        puts "#{Gititback::Support.shortform_path(entity.path)} => #{Gititback::Support.shortform_path(entity.archive_path)}"
        puts '-' * 78
        
        puts entity.contained_file_stats.to_yaml
      else
        puts "Current directory is not part of a backupable entity. Use 'gib report' to see a list of those."
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
    when 'update'
      @client.update_all! do |entity, state|
        case (state)
        when :update_start
          print Gititback::Support.shortform_path(entity.path)
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
