require "sinatra"
require "sinatra/reloader"
require "http"
require "json"
require "sinatra/cookies"

get("/") do
  erb(:home)
end

get("/umbrella") do
  erb(:umbrella)
end

post("/umbrella_result") do
  @local = params.fetch("user_local")
  gmaps = ENV.fetch("GMAPS_KEY")
  @local_url = @local.gsub(" ","+")
  gmaps_url = "https://maps.googleapis.com/maps/api/geocode/json?address=#{@local_url}&key=#{gmaps}"
  
  raw_gmaps = HTTP.get(gmaps_url)
  parsed_gmaps = JSON.parse(raw_gmaps)
  results = parsed_gmaps.fetch("results")
  result_hash = results.at(0)
  geohash = result_hash.fetch("geometry")
  localhash = geohash.fetch("location")
  @latitude = localhash.fetch("lat")
  @longitude = localhash.fetch("lng")

  pw_key = ENV.fetch("PIRATE_WEATHER_KEY")
  pw_url = "https://api.pirateweather.net/forecast/#{pw_key}/#{@latitude},#{@longitude}"

  raw_pw = HTTP.get(pw_url)
  parsed_pw = JSON.parse(raw_pw)
  @current_hash = parsed_pw.fetch("currently")
  @the_temp = @current_hash.fetch("temperature")
  @minute_hash = parsed_pw.fetch("hourly")
  @weather_summary = @minute_hash.fetch("summary")

  #@hour_hash = parsed_pw.fetch("hourly")
  hour_array = @minute_hash.fetch("data")
  @hour_hash = hour_array.at(0)
  next_twelve = hour_array[1..12]

  
  
  @any_precip = false
  


  next_twelve.each do |the_hour|
    precip_probability = the_hour.fetch("precipProbability")
    

    if precip_probability > 0.10
      @any_precip = true
      precip_time = Time.at(the_hour.fetch("time"))
      seconds_later = precip_time - Time.now
      hours_later = seconds_later / 60 / 60
    end

    if @any_precip == true
      @result = "You might want to carry an umbrella!"
    else
      @result = "You probaly won't need an umbrella today."
    end
  end

    cookies["last_location"] = @local
    cookies["last_lat"] = @lat
    cookies["last_long"] = @lng
  erb(:umbrella_result)
end

get("/message") do
  erb(:message)
end

post("/response") do
  erb(:response)
end

get("/chat") do
  erb(:chat)
end

post("/clear_chat") do
  cookies[:chat_history] = JSON.generate([])
  redirect to("/chat")
end

post("/chat")
  cookies[:chat_history] = JSON.generate(@chat_history)
  erb(:chat)
end
