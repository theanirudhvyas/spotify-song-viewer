require 'sinatra'
require 'dotenv/load'

SCOPE = 'user-read-private user-read-email'

get '/login' do
  request =  "https://accounts.spotify.com/authorize?response_type=code&client_id=#{ENV['CLIENT_ID']}&scope=#{SCOPE}&redirect_uri=#{ENV['REDIRECT_URI']}"

  redirect request
end

get 'callback' do

end
