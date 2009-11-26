class Gititback::Client
  def initialize(config)
    @config = config
  end

  # Returns the current server_id value which is typically the
  # FQDN hostname
  def server_id
    @server_id ||= Gititback::Support.hostname
  end
  
  # Searches through the configured source_dirs for entities which match
  # the specification. Returns a hash of arrays of paths indexed by
  # configuerd source dir.
  def expand_entities_list(apply_ignore_filter = true)
    @config.entities.inject({ }) do |h, source|
      h[source] =
        case (source)
        when /^mysql:\/\/([^\/]+)\/(.*)/
          db_list = [ ]
          db = Gititback::Database.new(@config.connections[$1.to_sym])
          db.connection($1) do |c|
            if $2 == '*'
              c.query("SHOW DATABASES") do |res|
                while (row = res.fetch_row)
                  db_list << row[0]
                end
              end
            else
              db_list << $2
            end
          end
          db_list
        else
          Dir.glob(File.expand_path(source)).reject do |path|
            !File.directory?(path) or (apply_ignore_filter and should_ignore_source?(path))
          end
        end
      h
    end
  end
  
  # Returns true if the given path should be ignored, false otherwise
  def should_ignore_source?(path)
    return false unless @config.ignore_entities
    base_path = File.basename(path)
    
    @config.ignore_entities.each do |pattern|
      if (File.fnmatch(pattern, path) or File.fnmatch(pattern, base_path) or path == pattern or base_path == pattern)
        return true
      end
    end
    
    false
  end
  
  def local_entities_list(reload = false)
    @local_entities_list = nil if (reload)
    @local_entities_list ||=
      expand_entities_list.collect do |source, paths|
        paths.collect do |path|
          Gititback::Entity.new(@config, path, source)
        end
      end.flatten
  end
  
  # Returns the entity for the given path, or nil if none is found
  def entity_for_path(path)
    local_entities_list.find do |e|
      path[0, e.path.length] == e.path
    end
  end
  
  # Updates all entities sequentially. An optional block is called with the
  # arguments [entity, operation] where operation is one of :update_start
  # or :update_end depending on the stage.
  def update_all!(&block)
    self.local_entities_list.each do |entity|
      yield(:update_start, entity) if (block_given?)
      entity.update!(&block)
      yield(:update_finish, entity) if (block_given?)
    end
  end
  
  # Returns the entity for the current working directory. An optional block
  # will be called with the entity if one is found.
  def entity_for_working_directory
    entity = entity_for_path(Dir.getwd)
    yield(entity) if (block_given? and entity)
    entity
  end

  # Returns the entity for the current working directory. An optional block
  # will be called with the entity if one is found, otherwise an exception
  # of type Gititback::Exception::NonEntity will be thrown.
  def entity_for_working_directory!
    entity = entity_for_working_directory
    
    unless (entity)
      raise Gititback::Exception::NonEntity
    end
    
    yield(entity) if (block_given?)
    
    entity
  end
end
