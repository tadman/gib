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
    File.expand_path("#{unique_id}.git", @config.backup_location)
  end
  
  def archive_exists?
    File.exist?(archive_path)
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
