require 'find'
require 'etc'

require 'rubygems' rescue nil
require 'git'
Gititback::Monkeypatches.apply!

class Gititback::Entity
  INFO_FILE_NAME = '.gititback-permissions.yaml'.freeze
  INTERNAL_FILES = [
    INFO_FILE_NAME
  ].freeze
  FILE_INJECT_SIZE = 128
  
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

  def archive_lock_path
    File.expand_path(File.join('archive', ".#{unique_id}.lock"), @config.backup_location)
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
  
  def contained_file_stats(reload = false)
    @contained_file_stats = nil if (reload)
    @contained_file_stats ||=
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
    when locked?
      'Updating'
    when archive_exists?
      'Archived'
    else
      '-'
    end
  end
  
  def archivable_files
    contained_file_stats.collect do |inode, info|
      case (info)
      when Array
        info[0]['path']
      when Hash
        info['path']
      end
    end.reject do |path|
      !File.file?(File.expand_path(path, @path))
    end
  end

  def archived_files
    archive.chdir do
      archive.ls_files.keys
    end
  end
  
  def info_file_path
    "#{archive_path}/#{INFO_FILE_NAME}"
  end
  
  def locked?
    File.exist?(archive_lock_path)
  end
  
  def lock!
    lock_path = archive_lock_path
    
    return false if (File.exist?(lock_path))
    
    file = File.new(lock_path, File::CREAT | File::RDWR, 0600)

    return false unless (file.flock(File::LOCK_EX | File::LOCK_NB) == 0)
    
    yield
    
    true
  rescue Timeout::Error
    false
  ensure
    file and file.flock(File::LOCK_UN)
    File.exist?(lock_path) and File.unlink(lock_path)
  end

  def update!
    lock! do
      _archivable_files = archivable_files
      _archived_files = archived_files
    
      files_added = (_archivable_files - _archived_files)
      files_updated = (_archivable_files & _archived_files)
      files_removed = (_archived_files - _archivable_files - INTERNAL_FILES)
    
      files_added.each_slice(FILE_INJECT_SIZE) do |files|
        files.each do |path|
          yield(:add_file, path) if (block_given?)
        end
        archive.add_with_opts(files, :force => true) unless (files.empty?)
      end

      files_updated.each_slice(FILE_INJECT_SIZE) do |files|
        files.each do |path|
          yield(:update_file, path) if (block_given?)
        end
        archive.add_with_opts(files, :force => true) unless (files.empty?)
      end

      files_removed.each_slice(FILE_INJECT_SIZE) do |files|
        files.each do |path|
          yield(:remove_file, path) if (block_given?)
        end
        archive.remove(files) unless (files.empty?)
      end
    
      open(info_file_path, 'w') do |f|
        f.write(contained_file_stats.to_yaml)
      end
    
      archive.with_working(archive_path) do
        archive.add(info_file_path)
      end
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
