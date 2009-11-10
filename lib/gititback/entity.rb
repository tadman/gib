require 'rubygems' rescue nil
require 'git'
require 'find'

class Gititback::Entity
  # Finds new backupable entities within the defined root
  def self.detect!
  end
  
  def initialize(config, path)
    @config = config
    @path = path
  end
  
  def path
    @path
  end
  
  def unique_id
    @unique_id ||=
      Digest::SHA1.hexdigest("#{@config.server_id}://#{@path}")
  end
  
  def archive_path
    File.expand_path(File.join('archive', "#{unique_id}.git"), @config.backup_location)
  end
  
  def archive_exists?
    File.exist?(archive_path)
  end
  
  def archive(reload = false)
    @archive = nil if (reload)
    return @archive if (@archive)
    
    if (archive_exists?)
      @archive = Git.open(@path, :repository => archive_path, :index => archive_path + '/index')
    else
      Gititback::Support.prepare_archive_path(archive_path)
      @archive = Git.init(@path, :repository => archive_path, :index => archive_path + '/index')

      @archive.config('user.name', @config.user_name)
      @archive.config('user.email', @config.user_email)
    end
     
    @archive
  end
  
  def contained_files(with_ignore_filter = true)
    files = [ ]

    Find.find(@path) do |path|
      if (should_ignore_file?(path))
        Find.prune
      else
        files << path
      end
    end
    
    files.sort
  end
  
  def files(reload = false)
    @files = nil if (reload)
    @files ||= contained_files
  end
  
  def should_ignore_file?(path)
    base_path = File.basename(path)
    
    @config.ignore_files.each do |pattern|
      if (File.fnmatch(pattern, path) or File.fnmatch(pattern, base_path) or path == pattern or base_path == pattern)
        return true
      end
    end
    
    false
  end

  def status
    case
    when archive_exists?
      'Ready'
    else
      'New'
    end
  end
end
