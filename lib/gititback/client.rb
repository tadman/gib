class Gititback::Client
  def initialize(config)
    @config = config
  end
  
  def local_entities
    @config.source_dirs.collect do |path|
      Dir.glob(path)
    end.flatten.reject do |path|
      @config.ignore_sources.include?(File.basename(path))
    end.collect do |path|
      Gititback::Entity.new(@config, path)
    end.compact
  end
  
  def server_id
    @server_id ||= `uname -n`
  end
end
