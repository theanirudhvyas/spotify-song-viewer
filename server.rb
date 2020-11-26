require 'sinatra/base'
require 'dotenv/load'
require 'httparty'
require 'logger'

class Server < Sinatra::Base
  @@scope = 'user-read-private user-read-email'
  @@client_id = ENV['CLIENT_ID']
  @@redirect_uri = ENV['REDIRECT_URI']
  @@client_secret = ENV['CLIENT_SECRET']
  @@user_id = 'anirudh2403'

  GRANT_TYPE = 'authorization_code'

  def initialize
    @tokens = {}
    @log = Logger.new(STDOUT)
    super
  end

  before do
    content_type :json
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
      @tokens[:access] = response['access_token']
      @tokens[:refresh] = response['refresh_token']
      @log.info "fetched the access and refresh tokens"
    else
      @log.error "Fetching of API token failed with response code: #{response.code}. The complete response is: #{response.body}"
    end

    content_type :json

    HTTParty.get("https://api.spotify.com/v1/me",
                 headers: { 'Authorization' => "Bearer #{@tokens[:access]}",
                            'Accept' => "application/json",
                            'Content-Type' => "application/json"})
  end

  get '/playlists' do
    response = HTTParty.get("https://api.spotify.com/v1/users/#{@@user_id}/playlists",
                          headers: { 'Authorization' => "Bearer #{@tokens[:access]}"})

    if response.success?
      return result
    elsif response.unauthorized?
      log.info "The response is unauthorized, refreshing tokens"
      response = refresh_access_token
      return json status: response.code, body: {success: true, errors: [response['error']], data: {}} unless response.success?
      return redirect '/playlists/'
    else
     return json status: response.code, body: {success: false, errors: [response['error']], data: {}}
    end
    content_type :json
  end


  private

  def refresh_access_token
    response = HTTParty.post('https://accounts.spotify.com/api/token',
                           body: {grant_type: 'refresh_token',
                                  refresh_token: @tokens[:refresh],
                                  client_id: @@client_id,
                                  client_secret: @@client_secret})

    if response.success?
      @tokens[:access] = response['access_token']
      log.info "Successfuly refreshed access token"

    else
      log.error "Refreshing of access token failed with code: #{response.code}. The complete response is: #{response.body}"
    end

    response
  end
end
