require 'socket'
require 'fileutils'

# A collection of utility methods used within Gititback
class Gititback::Support
  # Equivalent to Ruby on Rails Hash#symbolize_keys but without having to
  # extend or alter the base Hash class.
  def self.symbolize_hash_keys(hash)
    hash.inject({ }) do |h, (k, v)|
      h[k.to_sym] = v.is_a?(Hash) ? symbolize_hash_keys(v) : v
      h
    end
  end
  
  # Returns the current hostname, or best guess
  def self.hostname
    Socket.gethostname
  end
  
  # Returns the home directory of the current user
  def self.home_dir
    @home_dir = File.expand_path('~')
  end
  
  # Strips the user's directory from the given path to shorten it
  def self.shortform_path(path)
    path.sub(/^#{home_dir}/, '~')
  end
  
  # Creates the archive path, if required
  def self.prepare_archive_path(path)
    FileUtils::mkdir_p(File.dirname(path))
  end
end
