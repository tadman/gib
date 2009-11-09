module Gititback
  VERSION = '0.0.1'
  
  autoload(:Client, 'gititback/client')
  autoload(:Config, 'gititback/config')
  autoload(:Entity, 'gititback/entity')
  autoload(:Support, 'gititback/support')
  
  module Exception
    class ConfigurationError < ::Exception
    end

    class InvalidCommand < ::Exception
    end
    
    class RuntimeError < ::Exception
    end
  end
end
