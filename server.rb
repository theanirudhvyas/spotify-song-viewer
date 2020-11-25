require 'sinatra/base'
require 'dotenv/load'
require 'httparty'
require 'logger'

class Server < Sinatra::Base
  @@scope = 'user-read-private user-read-email'
  @@client_id = ENV['CLIENT_ID']
  @@redirect_uri = ENV['REDIRECT_URI']
  @@client_secret = ENV['CLIENT_SECRET']

  GRANT_TYPE = 'authorization_code'

  def initialize
    @tokens = {}
    @log = Logger.new(STDOUT)
    super
  end

  get '/login' do
    request =  "https://accounts.spotify.com/authorize?response_type=code&client_id=#{@@client_id}&scope=#{@@scope}&redirect_uri=#{@@redirect_uri}"

    redirect request
  end

  get '/callback' do
    authorization_code = params['code']
    response = HTTParty.post("https://accounts.spotify.com/api/token",
                             body: {code: authorization_code,
                                    grant_type: GRANT_TYPE,
                                    redirect_uri: @@redirect_uri,
                                    client_id: @@client_id,
                                    client_secret: @@client_secret})
    if response.success?
      @tokens['access'] = response['access_token']
      @tokens['refresh'] = response['refresh_token']
      @log.info "fetched the access and refresh tokens"
    else
      @log.error "Fetching of API token failed with response code: #{response.code}. The complete response is: #{response}"
    end

    content_type :json

    HTTParty.get("https://api.spotify.com/v1/me",
                 headers: { 'Authorization' => "Bearer #{@tokens['access']}",
                            'Accept' => "application/json",
                            'Content-Type' => "application/json"}).to_json
  end
end
