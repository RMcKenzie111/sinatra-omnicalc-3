require "sinatra"
require "sinatra/reloader"
require "http"
require "json"
require "sinatra/cookies"

OPENAI_API_KEY = ENV.fetch("OPENAI_API_KEY")

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
      @result = "You probably won't need an umbrella today."
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
  request_headers_hash = { 
  "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
  "content-type" => "application/json" 
}

  request_body_hash = {
  "model" => "gpt-3.5-turbo",
  "messages" => [
    {
      "role" => "system",
      "content" => "You are a helpful assistant who talks like Shakespeare."
    },
    {
      "role" => "user",
      "content" => "#{params.fetch("the_message")}"
    }
  ]
}

request_body_json = JSON.generate(request_body_hash)

raw_response = HTTP.headers(request_headers_hash).post(
  "https://api.openai.com/v1/chat/completions",
  :body => request_body_json
).to_s

@parsed_responses = JSON.parse(raw_response)

@replies = @parsed_responses.dig("choices", 0, "message", "content")
#@format_replies =replies.gsub("\n",)
cookies["input"] = params.fetch("the_message")
  erb(:response) 
end

get("/chat") do
  #if chat_history cookies are requested from client, the data within the cookie is accessed and assigned to the variable if true, if false an empty array is assined to the variable, redirected  
  @chat_history = request.cookies["chat_history"] ? JSON.parse(request.cookies["chat_history"]) : []
  erb(:chat)
end

post("/clear_chat") do
  cookies[:chat_history] = JSON.generate([])
  redirect to("/chat")
end

post("/chat_messages") do
  @chat_history = JSON.parse(request.cookies["chat_history"] || "[]")
  @input_messages = params["the_messages"]
  @chat_history << {"role" => "user", "content" => @input_messages}
  
  request_headers_hash = { 
  "Authorization" => "Bearer #{ENV.fetch("OPENAI_API_KEY")}",
  "content-type" => "application/json" 
}

  request_messages = [{
    "role" => "system",
    "content" => "You are a helpful assistant."
  },
  {
    "role" => "user",
    "content" => @input_messages
  }
]

  request_body_hash = {
  "model" => "gpt-3.5-turbo",
  "messages" => request_messages 
}

request_body_json = JSON.generate(request_body_hash)

raw_response = HTTP.headers(request_headers_hash).post(
  "https://api.openai.com/v1/chat/completions",
  :body => request_body_json
).to_s

  @parsed_responses = JSON.parse(raw_response)
  @assistant_res = @parsed_responses.dig("choices", 0, "message", "content")

  @chat_history << {"role" => "assistant", "content" => @assistant_res}
  
  cookies[:chat_history] = JSON.generate(@chat_history)
  
  erb(:chat)
end
