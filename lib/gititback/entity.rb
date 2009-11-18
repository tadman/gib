require 'find'
require 'etc'
require 'timeout'

require 'rubygems' rescue nil
require 'git'
Gititback::Monkeypatches.apply!
require 'httparty'

class Gititback::Entity
  INFO_FILE_NAME = '.gititback.metadata.yaml'.freeze
  INTERNAL_FILES = [
    INFO_FILE_NAME
  ].freeze
  FILE_INJECT_SIZE = 128
  
  def initialize(config, path)
    @config = config
    @path = path
  end
  
  def path
    @path
  end
  
  def path_id
    "#{@config.server_id}:#{@path}"
  end
  
  def unique_id
    @unique_id ||=
      Digest::SHA1.hexdigest(path_id)
  end
  
  def archive_path
    File.expand_path(File.join('archive', "#{unique_id}.git"), @config.backup_location)
  end
  
  def archive_index_path
    File.join(archive_path, 'index')
  end

  def archive_lock_path
    File.expand_path(File.join('archive', ".#{unique_id}.lock"), @config.backup_location)
  end
  
  def archive_exists?
    File.exist?(archive_path)
  end
  
  # Returns a handle to the Git archive, possibly cached. Include a true
  # value to reload, if required.
  def archive(reload = false)
    @archive = nil if (reload)
    return @archive if (@archive)
    
    if (archive_exists?)
      @archive = Git.open(@path, :repository => archive_path, :index => archive_path + '/index')
    else
      @archive = Git.init(@path, :repository => archive_path, :index => archive_path + '/index')

      @archive.config('user.name', @config.user_name)
      @archive.config('user.email', @config.user_email)
      
      @archive.commit("Initialize archive of #{path_id}", :allow_empty => true)
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
  
  # Returns statistics on the contained files including ownership, and
  # creation/modification times that is a Hash keyed by file inode number.
  def contained_file_stats(reload = false)
    @contained_file_stats = nil if (reload)
    @contained_file_stats ||=
      contained_files.inject({ }) do |h, path|
        stat = File.lstat(path)
      
        info = {
          'path' => relative_path_for(path),
          'uid' => uid_descriptor(stat.uid),
          'gid' => gid_descriptor(stat.gid),
          'mode' => ('%04o' % (stat.mode & 07777)),
          'mtime' => stat.mtime.to_i,
          'ctime' => stat.ctime.to_i
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
  
  # Converts path to be relative to the entity base path
  def relative_path_for(path)
    path[@path.length + 1, path.length] or '.'
  end
  
  # Returns a list of files contained within the archive. A true value passed
  # in will preclude the use of cached results.
  def files(reload = false)
    @files = nil if (reload)
    @files ||= contained_files
  end
  
  # Returns true if the file at the given path will be ignored according to
  # the current rules, false otherwise.
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

  # Returns the status of the archive as a text label
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
  
  def existing_info
    YAML.load(open(info_file_path))
  rescue
    { }
  end
  
  # Returns true if the entity archive is currently locked.
  def locked?
    File.exist?(archive_lock_path)
  end
  
  # Attempts to lock the entity archive, and if successul, will execute
  # the block provided.
  def lock!
    Gititback::Support.prepare_archive_path(archive_path)

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

  # Performs an update on the given entity, applying all outstanding changes
  def update!
    lock! do
      status(true)
      
      _archivable_files = archivable_files.sort
      _archived_files = archived_files.sort
    
      files_added = (_archivable_files - _archived_files)
      files_updated = (_archivable_files & _archived_files)
      files_removed = (_archived_files - _archivable_files - INTERNAL_FILES)
    
      files_added.each_slice(FILE_INJECT_SIZE) do |files|
        files.each do |path|
          yield(:add_file, path) if (block_given?)
        end
        archive.add_with_opts(files, :force => true) unless (files.empty?)
      end

      if (block_given?)
        files_updated.each do |path|
          yield(:update_file, path) if (status[path].type)
        end
      end

      files_removed.each_slice(FILE_INJECT_SIZE) do |files|
        files.each do |path|
          yield(:remove_file, path) if (block_given?)
        end
        archive.remove(files) unless (files.empty?)
      end
      
      should_amend = false

      if (modifications?)
        archive.commit("Archive of #{path_id} (#{COMMAND_NAME} #{ARGV.join(' ')})", :add_all => true)
        should_amend = true
      end

      archive.with_working(archive_path) do
        update_info_file!

        archive.add(INFO_FILE_NAME)
        
        status(true) # Reload

        if (file_modified?(INFO_FILE_NAME))
          archive.commit("Archive of #{path_id} (#{COMMAND_NAME} #{ARGV.join(' ')})", :amend => should_amend)
        end
      end
    end
  end

  def remote_url
    url = archive.config('remote.origin.url')

    if (!url or url.empty?)
      if (response = Gititback::Remote.register_archive(@config, self))
        if (response['response'] == 'success')
          url = response['archive_url']
          archive.config('remote.origin.url', url)
          archive.config('remote.origin.fetch', '+refs/heads/*:refs/remotes/origin/*')
        end
      end
    end

    url
  end

  def push!
    if (remote?)
      archive.push('origin', 'master')
    end
  end
  
  # Returns true if the archive is configured with an appropriate remote,
  # otherwise false.
  def remote?
    _remote_url = remote_url
    
    _remote_url and !_remote_url.empty?
  end
  
  # Returns the status of the archive A true value will reload status,
  # otherwise cached results may be returned.
  def status(reload = false)
    @status = nil if (reload)
    @status ||= archive.status
  end
  
  def update_info_file!
    open(info_file_path, 'w') do |f|
      f.write(contained_file_stats.to_yaml)
    end
  end
  
  # Returns true if any modifications have been made relative to
  # the contents of the archive.
  def modifications?
    status.each do |info|
      if (info.type and info.path != INFO_FILE_NAME)
        return true
      end
    end

    false
  end
  
  # Returns true if the file at the given path has been modified when
  # compared to what is in the archive.
  def file_modified?(path)
    !status[path] or status[path].type
  end
  
  def to_json
    {
      :server_id => @config.server_id,
      :path => path,
      :path_id => path_id,
      :unique_id => unique_id
    }.to_json
  end
  
protected
  # Returns a simplified id:name descriptor for a given user id number (uid)
  # or a number where no user with that id is found.
  def uid_descriptor(uid)
    info = Etc.getpwuid(uid)
    
    info ? "#{uid}:#{info.name}" : uid.to_s
  rescue ArgumentError
    uid.to_s
  end

  # Returns a simplified id:name descriptor for a given group id number (gid)
  # or a number where no group with that id is found.
  def gid_descriptor(gid)
    info = Etc.getgrgid(gid)
    
    info ? "#{gid}:#{info.name}" : gid.to_s
  rescue ArgumentError
    gid.to_s
  end
end
