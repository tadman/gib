require 'optparse'

class Gititback::CommandLine
  VALID_COMMANDS = {
    :contents => 'Shows the state of the contents for the current entity',
    :status => 'Shows the status of the current entity including directories',
    :report => 'Reports on the status of all local entities',
    :config => 'Describes all the configuration options being applied',
    :search => 'Searches for entities which match ',
    :update => 'Updates the current entity',
    :env => 'Environment variables used by git to execute',
    :run => 'Run an update on all local entities'
  }.freeze
  
  def self.interpret!
    new.perform!
  end
  
  def self.show_help
    puts option_parser({ })
  end
  
  def self.option_parser(options)
    OptionParser.new do |op|
      op.banner = "Usage: #{COMMAND_NAME} [options] <command>"
      
      op.separator('')
      op.separator('Common options:')

      op.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
        options[:verbose] = v
      end

      op.on('-c', '--config=s', 'Specify alternate configuration file') do |v|
        options[:config] = v
      end

      op.on('-V', '--version', 'Show version information') do
        puts "#{COMMAND_NAME}: Version #{Gititback::VERSION}"
        exit
      end
      
      op.on('-h', '--help') do
        puts op
        exit
      end
        
      op.separator('')
      op.separator("Common command names:")

      VALID_COMMANDS.collect do |command, description|
        "  %-12s %s\n" % [ command, description ]
      end.sort.each do |info|
        op.separator(info)
      end
    end
  end
  
  def initialize
    @options = options = { }
    
    @parser = self.class.option_parser(options)
    @args = @parser.parse!
    
    Gititback::Config.config_file_path = @options.delete(:config)
    
    @config = Gititback::Config.new(@options)
    @client = Gititback::Client.new(@config)
  end

  def perform!
    command = @args.first
    
    case (command)
    when 'contents'
      if (entity = @client.entity_for_working_directory)
        entity.archive.status.each do |info|
          unless (Gititback::Entity::INTERNAL_FILES.include?(info.path))
            puts "%1s %s" % [ info.type, info.path ]
          end
        end
      end
    when 'status'
      @client.entity_for_working_directory! do |entity|
        status = entity.archive.status
        
        puts "#{Gititback::Support.shortform_path(entity.path)} => #{Gititback::Support.shortform_path(entity.archive_path)}"
        puts '-' * 78
        
        archived_files = entity.archive.ls_files
        entity_path_length = entity.path.length
        
        entity.files.each do |file|
          if (relative_path = file[entity_path_length + 1, file.length])
            if (File.directory?(file))
              print '@ '
            else
              if (file_status = status[relative_path])
                if (file_status.type == 'M')
                  print "M "
                else
                  print "- "
                end
              else
                print 'A '
              end
            end

            puts relative_path
          end
        end
      end
    when 'report'
      puts "#{@config.server_id} Entities:"
      puts '-' * 78

      @client.local_entities_list.each do |e|
        puts "%-40s %-37s" % [ Gititback::Support.shortform_path(e.path), e.status_label ]
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

      if (entity = @client.entity_for_working_directory)
        puts
        puts Gititback::Support.shortform_path(entity.archive_path)
        puts '-' * 78
        
        entity.archive.config.each do |key, value|
          puts "%-40s %s" % [ key, value ]
        end
      end
    when 'permissions'
      @client.entity_for_working_directory! do |entity|
        puts "#{Gititback::Support.shortform_path(entity.path)} => #{Gititback::Support.shortform_path(entity.archive_path)}"
        puts '-' * 78
        
        puts entity.contained_file_stats.to_yaml
      end
    when 'search'
      puts "#{@config.server_id} Search:"
      puts '-' * 78
      
      home_dir = File.expand_path('~')
      count = 0
      
      @client.expand_entities_list(false).to_a.sort_by { |s| s[0] }.each do |source, paths|
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
      @client.entity_for_working_directory! do |entity|
        puts Gititback::Support.shortform_path(entity.path)
        stats = Hash.new(0)
        entity.update! do |state, path|
          if (@config.verbose)
            case (state)
            when :add_file
              stats[state] += 1
              puts "A #{path}"
            when :update_file
              stats[state] += 1
              puts "M #{path}"
            when :remove_file
              stats[state] += 1
              puts "R #{path}"
            end
          end
        end
        puts "(#{stats[:add_file]} added, #{stats[:update_file]} updated, #{stats[:remove_file]} removed)"
      end
    when 'env'
      @client.entity_for_working_directory do |entity|
        puts "GIT_DIR=#{entity.archive_path}"
        puts "GIT_INDEX_FILE=#{entity.archive_index_path}"
      end or begin
        puts ""
      end
    when 'log'
      @client.entity_for_working_directory do |entity|
        puts entity.archive.log.inspect
      end
    when 'run'
      stats = nil

      @client.update_all! do |state, entity|
        case (state)
        when :update_start
          stats = Hash.new(0)
          print Gititback::Support.shortform_path(entity.path)

          if (@config.verbose)
            puts
          end
        when :add_file
          stats[state] += 1
          if (@config.verbose)
            puts "A #{entity}"
          end
        when :update_file
          stats[state] += 1
          if (@config.verbose)
            puts "M #{entity}"
          end
        when :remove_file
          stats[state] += 1
          if (@config.verbose)
            puts "R #{entity}"
          end
        when :update_finish
          puts " (#{stats[:add_file]} added, #{stats[:update_file]} updated, #{stats[:remove_file]} removed)"
        end
      end
    when 'help', nil
      self.class.show_help
    else
      raise Gititback::Exception::InvalidCommand, "Invalid command #{command}"
    end
  end
  
  def options
    @options
  end
end
