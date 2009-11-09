module Gititback
  autoload(:Config, 'gititback/config')
  autoload(:Entity, 'gititback/entity')
  
  module Exception
    class ConfigurationError < Exception
    end
    
    class RuntimeError < Exception
    end
  end
end
