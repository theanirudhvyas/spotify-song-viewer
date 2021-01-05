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
      return response.code, [], { success: true,
                                  data: { body: "Successfully authorized the application" },
                                  errors: [] }.to_json
    else
      @log.error "Fetching of API token failed with response code: #{response.code}. The complete response is: #{response.body}"
      return response.code, [], {success: false,
                                       data: {},
                                       errors: [response.body]}.to_json
    end
  end

  get '/playlists' do
    response = HTTParty.get("https://api.spotify.com/v1/users/#{@@user_id}/playlists",
                          headers: { 'Authorization' => "Bearer #{@tokens[:access]}"})

    if response.success?
      return response.code, [], { success: true, data: {playlists: response.body}, errors: []}.to_json
    elsif response.unauthorized?
      @log.info "The response is unauthorized, refreshing tokens"
      response = refresh_access_token
      return response.code, [], { success: true, errors: [response['error']], data: {} }.to_json unless response.success?
      return redirect '/playlists/'
    else
      @log.error "Fetching playlists failed with error code: #{response.code}, and the complete response is: #{response.body} "
      return response.code, [], { success: false, errors: [response['error']], data: {} }.to_json
    end
  end

  get '/playlists/favorite/tracks' do
    playlist_id = '0Efusp2XptMk4cfDN7K7Q9'
    response = HTTParty.get("https://api.spotify.com/v1/playlists/#{playlist_id}",
                            headers: { 'Authorization' => "Bearer #{@tokens[:access]}"})

    song_items = JSON.parse(response.body)['tracks']['items']

    song_data = song_items.map { |item| { name: item['track']['name'],
                                          id: item['track']['id'],
                                          album: item['track']['album']['name'],
                                          spotify_code: "https://scannables.scdn.co/uri/plain/png/000000/white/1280/spotify:track:#{item['track']['id']}"} }

    return 200, [], {success: true, data: {songs: song_data}, errors: []}.to_json
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
      @log.info "Successfuly refreshed access token"
    else
      @log.error "Refreshing of access token failed with code: #{response.code}. The complete response is: #{response.body}"
    end

    response
  end
end
