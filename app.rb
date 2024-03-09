require "sinatra"
require "sinatra/reloader"
require "http"
require "json"
require "sinatra/cookies"

get("/") do
  "
  <p>Welcome to Omnicalc 3</p>"
end
