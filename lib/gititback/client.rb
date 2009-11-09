class Gititback::Client
  def initialize(options = nil)
    @options = (options or { })
    
    @options[:config] = Gititback::Config.new(@options[:config])
  end
  
  def perform(*args)
    command = args.pop
    
    case (command)
    when 'status'
      puts "Status: OK"
    else
      raise Gititback::Exception::InvalidCommand, "Invalid command #{command}"
    end
  end
end
