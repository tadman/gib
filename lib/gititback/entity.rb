require 'find'
require 'etc'

require 'rubygems' rescue nil
require 'git'

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
  
  def contained_file_stats
    contained_files.inject({ }) do |h, path|
      stat = File.lstat(path)
      
      info = {
        'path' => relative_path_for(path),
        'uid' => uid_descriptor(stat.uid),
        'gid' => gid_descriptor(stat.gid),
        'mode' => ('%04o' % (stat.mode & 07777))
      }
      
      case (entry = h[stat.ino])
      when Hash
        h[stat.ino] = [ entry, info ]
      when Array
        entry << info
      else
        h[stat.ino] = info
      end
      
      h
    end
  end
  
  def relative_path_for(path)
    path[@path.length + 1, path.length] or '.'
  end
  
  def files(reload = false)
    @files = nil if (reload)
    @files ||= contained_files
  end
  
  def should_ignore_file?(path)
    return true unless (File.file?(path) or File.symlink?(path) or File.directory?(path))
    
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
      Time.now.to_s
    else
      '-'
    end
  end
  
protected
  def uid_descriptor(uid)
    info = Etc.getpwuid(uid)
    
    info ? "#{uid}:#{info.name}" : uid.to_s
  end

  def gid_descriptor(gid)
    info = Etc.getgrgid(gid)
    
    info ? "#{gid}:#{info.name}" : gid.to_s
  end
end
