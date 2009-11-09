class Gititback::Support
  def self.symbolize_hash_keys(hash)
    hash.inject({ }) do |h, (k, v)|
      h[k.to_sym] = v.is_a?(Hash) ? symbolize_hash_keys(v) : v
    end
  end
end
