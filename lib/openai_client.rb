require "net/http"
require "uri"
require "json"

class OpenAIClient
  class ConfigError < StandardError; end
  class ApiError < StandardError; end
  class ParseError < StandardError; end

  DEFAULT_MODEL = "gpt-4.1-mini".freeze

  def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL), timeout_seconds: ENV.fetch("OPENAI_TIMEOUT_SECONDS", "30").to_i)
    @api_key = api_key
    @model = model
    @timeout_seconds = timeout_seconds
  end

  def evaluate_json(system_prompt:, user_prompt:)
    raise ConfigError, "OPENAI_API_KEY is not set" if @api_key.to_s.empty?

    uri = URI("https://api.openai.com/v1/chat/completions")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model,
      temperature: 0,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: user_prompt }
      ]
    }.to_json

    response = http_client(uri).request(request)
    raise ApiError, "OpenAI API error #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    content = payload.dig("choices", 0, "message", "content")
    raise ParseError, "OpenAI response content missing" if content.to_s.empty?

    JSON.parse(content)
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON from OpenAI: #{e.message}"
  end

  private

  def http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = @timeout_seconds
    http.read_timeout = @timeout_seconds
    http
  end
end
