require 'digest/sha1'

module Gititback
  VERSION = '0.0.3'
  
  autoload(:Client, 'gititback/client')
  autoload(:Config, 'gititback/config')
  autoload(:CommandLine, 'gititback/command_line')
  autoload(:Entity, 'gititback/entity')
  autoload(:Remote, 'gititback/remote')
  autoload(:Support, 'gititback/support')
  
  module Exception
    class ConfigurationError < ::Exception
    end

    class RuntimeError < ::Exception
    end

    class InvalidCommand < ::Exception
    end
    
    class RuntimeError < ::Exception
    end
    
    class NonEntity < ::Exception
    end
  end
  
  module Monkeypatches
    # There are several serious deficiencies in the
    # ruby-git library which precludes it from working
    # without some patches.
    
    def self.apply!
      Git::Base.send(:include, GitBasePatch)
      Git::Lib.send(:include, GitLibPatch)
      
      Git::Lib.class_eval do
        # Issue: http://github.com/schacon/ruby-git/issues#issue/5
        def escape(s)
          %Q{"#{s.to_s.gsub("'") { "\\'" }}"}
        end

        # Adds --amend option support to commit
        def commit(message, opts = {})
          arr_opts = ['-m', message]
          arr_opts << '-a' if opts[:add_all]
          arr_opts << '--amend' if opts[:amend]
          arr_opts << '--allow-empty' if opts[:allow_empty]
          arr_opts << "--author" << opts[:author] if opts[:author]
          command('commit', arr_opts)
        end
      end
    end

    module GitBasePatch
      # Adds support for options when adding files
      def add_with_opts(path = '.', opts = {})
        self.lib.add_with_opts(path, opts)
      end
    end
    
    module GitLibPatch
      # Adds support for options when adding files
      def add_with_opts(path = '.', opts = {})
        arr_opts = %w[--]
        arr_opts.unshift('-f') if opts[:force]
        if path.is_a?(Array)
          arr_opts += path
        else
          arr_opts << path
        end
        command('add', arr_opts)
      end
    end
  end
end
