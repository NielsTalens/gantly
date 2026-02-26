require "sinatra"
require "json"

get "/" do
  erb :index
end

post "/evaluate" do
  content_type :json
  { summary: { recommendation: "Refine and re-evaluate" }, evaluations: [] }.to_json
end
