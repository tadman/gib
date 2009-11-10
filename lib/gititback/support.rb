class Gititback::Support
  def self.symbolize_hash_keys(hash)
    hash.inject({ }) do |h, (k, v)|
      h[k.to_sym] = v.is_a?(Hash) ? symbolize_hash_keys(v) : v
      h
    end
  end
  
  def self.home_dir
    @home_dir = File.expand_path('~')
  end
  
  def self.shortform_path(path)
    path.sub(/^#{home_dir}/, '~')
  end
end
