class Gititback::Client
  def initialize(config)
    @config = config
  end
  
  def local_entities
    @config.backup_dirs.collect do |path|
      Dir.glob(path)
    end.flatten.collect do |path|
      Gititback::Entity.new(@config, path)
    end
  end
  
  def server_id
    @server_id ||= `uname -n`
  end
end
