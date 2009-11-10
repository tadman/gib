class Gititback::Client
  def initialize(config)
    @config = config
  end

  # Searches through the configured source_dirs for entities which match
  # the specification. Returns a hash of arrays of paths indexed by
  # configuerd source dir.
  def expand_source_dirs(apply_ignore_filter = true)
    @config.source_dirs.inject({ }) do |h, source|
      h[source] = Dir.glob(File.expand_path(source)).reject do |path|
        apply_ignore_filter and should_ignore_source?(path)
      end
      h
    end
  end
  
  def should_ignore_source?(path)
    @config.ignore_sources.include?(File.basename(path))
  end
  
  def local_entities_list
    expand_source_dirs.collect do |source, paths|
      paths.collect do |path|
        Gititback::Entity.new(@config, path)
      end
    end.flatten
  end
  
  def server_id
    @server_id ||= `uname -n`
  end
end
