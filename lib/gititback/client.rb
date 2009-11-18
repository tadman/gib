class Gititback::Client
  def initialize(config)
    @config = config
  end

  # Searches through the configured source_dirs for entities which match
  # the specification. Returns a hash of arrays of paths indexed by
  # configuerd source dir.
  def expand_source_dirs(apply_ignore_filter = true)
    @config.source_dirs.inject({ }) do |h, source|
      h[source] =
        Dir.glob(File.expand_path(source)).reject do |path|
          !File.directory?(path) or (apply_ignore_filter and should_ignore_source?(path))
        end
      h
    end
  end
  
  def should_ignore_source?(path)
    base_path = File.basename(path)
    
    @config.ignore_sources.each do |pattern|
      if (File.fnmatch(pattern, path) or File.fnmatch(pattern, base_path) or path == pattern or base_path == pattern)
        return true
      end
    end
    
    false
  end
  
  def local_entities_list(reload = false)
    @local_entities_list = nil if (reload)
    @local_entities_list ||=
      expand_source_dirs.collect do |source, paths|
        paths.collect do |path|
          Gititback::Entity.new(@config, path)
        end
      end.flatten
  end
  
  def entity_for_path(path)
    local_entities_list.find do |e|
      path[0, e.path.length] == e.path
    end
  end
  
  def server_id
    @server_id ||= Gititback::Support.hostname
  end
  
  def update_all!(&block)
    self.local_entities_list.each do |entity|
      yield(:update_start, entity) if (block_given?)
      entity.update!(&block)
      yield(:update_finish, entity) if (block_given?)
    end
  end
  
  def entity_for_working_directory
    entity = entity_for_path(Dir.getwd)
    yield(entity) if (block_given? and entity)
    entity
  end
end
