require 'httparty'
require 'json'

class Gititback::Remote
  include HTTParty
  format :json
  
  HEADERS = {
    'Content-type' => 'application/json',
    'Accept' => 'text/json, application/json'
  }.freeze

  def self.register_archive(config, entity)
    response = nil
    
    Timeout::timeout(5) do
      response =
        post(
          "#{config.remote_url}archives",
          :headers => HEADERS,
          :body => entity.to_json
        )
    end
    
    response
  end
end
