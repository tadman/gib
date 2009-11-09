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
    :backup_dirs => %w[
      /web/*
      /home/*
      /etc
    ],
    :backup_location => '/var/spool/gititback'
  }

  def self.config_files_found
    @config_files_found ||=
      CONFIG_FILE_PATHS.select do |path|
        File.exist?(path)
      end
  end

  def self.config_file_path=(path)
    @config_file_path = File.expand_path(path)
  end
  
  def self.config_file_path
    @config_file_path ||= config_files_found.first
  end

  def initialize(config = nil)
    marshal_load(__import_config(config || self.class.config_file_path))
  end
  
protected
  def __import_config(config)
    case (config)
    when String
      config_data = nil

      begin
        config_data = YAML.load(config)
      rescue Object => e
        raise Gititback::Exception::ConfigurationError, "Could not process configuration file #{config} (#{e.class}: #{e.to_s})" 
      end
      
      case (config_data)
      when Hash
        Gititback::Support.symbolize_hash_keys(config_data)
      else
        raise Gititback::Exception::ConfigurationError, "Configuration file #{config} has an invalid structure, should be key/value"
      end
    when Hash
      DEFAULT_OPTIONS.merge(Gititback::Support.symbolize_hash_keys(config))
    when nil
      DEFAULT_OPTIONS.dup
    else
      raise Gititback::Exception::ConfigurationError, "Invalid configuration type #{config.class} passed."
    end
  end
end
