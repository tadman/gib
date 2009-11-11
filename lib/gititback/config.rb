require 'yaml'
require 'ostruct'

class Gititback::Config < OpenStruct
  CONFIG_FILE_FORMATS = %w[
    conf
    yaml
    yml
  ].freeze
  
  CONFIG_FILE_PATHS = %w[
    /etc/gititback
    /etc/gititback/gititback
    ~/.gititback/gititback
  ].collect do |base|
    base = File.expand_path(base)
    CONFIG_FILE_FORMATS.collect do |ext|
      "#{base}.#{ext}"
    end
  end.flatten.freeze
  
  DEFAULT_OPTIONS = {
    :source_dirs => %w[
      /web/*
      /home/*
      /etc
    ],
    :backup_location => '/var/spool/gititback',
    :ignore_sources => %w[
      lost+found
    ],
    :ignore_files => %w[
      *.log
      .DS_Store
    ],
    :server_id => Gititback::Support.hostname,
    :user_name => 'Gititback Archiver',
    :user_email => "gititback@#{Gititback::Support.hostname}",
    :verbose => false
  }.freeze

  def self.config_files_found
    @config_files_found ||=
      CONFIG_FILE_PATHS.select do |path|
        File.exist?(path)
      end
  end

  def self.config_file_path=(path)
    @config_file_path = (path and File.expand_path(path))
  end
  
  def self.config_file_path
    @config_file_path ||= config_files_found.first
  end

  def initialize(config = nil)
    marshal_load(
      DEFAULT_OPTIONS.merge(
        __import_config(config)
      )
    )
  end
  
  def to_h
    marshal_dump
  end
  
protected
  def __import_config(config)
    config = config ? Gititback::Support.symbolize_hash_keys(config) : { }
    
    config_data = nil

    if (config_file = self.class.config_file_path)
      begin
        config_data = YAML.load(File.open(config_file))
      rescue Errno::ENOENT => e
        raise Gititback::Exception::ConfigurationError, "Could not open configuration file #{config_file} (#{e.class}: #{e.to_s})" 
      rescue Object => e
        raise Gititback::Exception::ConfigurationError, "Could not process configuration file #{config_file} (#{e.class}: #{e.to_s})" 
      end
      
      case (config_data)
      when Hash
        config_data = Gititback::Support.symbolize_hash_keys(config_data)
      else
        raise Gititback::Exception::ConfigurationError, "Configuration file #{config} has an invalid structure, should be key/value"
      end
    end
    
    config_data ? config_data.merge(config) : config
  end
end
