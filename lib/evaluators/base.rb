module Evaluators
  module Base
    REQUIRED_KEYS = %w[
      agent
      alignment_score
      confidence_score
      risk_level
      detected_conflicts
      what_would_make_this_a_5_of_5
    ].freeze

    def evaluate_with_template(template_path:, replacements:)
      rendered_prompt = File.read(template_path)
      replacements.each do |key, value|
        rendered_prompt = rendered_prompt.gsub("{#{key}}", value.to_s)
      end

      parsed = client.evaluate_json(
        system_prompt: "Follow the provided evaluator instructions strictly. Return only valid JSON.",
        user_prompt: rendered_prompt
      )
      normalize(parsed)
    end

    private

    def normalize(parsed)
      result = parsed.is_a?(Hash) ? parsed : {}
      result = result["result"] if result["result"].is_a?(Hash)
      data = result || {}

      {
        "agent" => agent_name,
        "alignment_score" => bounded_score(fetch_value(data, "alignment_score"), 3),
        "confidence_score" => bounded_score(fetch_value(data, "confidence_score"), 2),
        "risk_level" => normalized_risk(fetch_value(data, "risk_level")),
        "detected_conflicts" => normalized_conflicts(fetch_value(data, "detected_conflicts")),
        "what_would_make_this_a_5_of_5" => normalized_array(fetch_value(data, "what_would_make_this_a_5_of_5"))
      }
    end

    def fetch_value(hash, key)
      hash[key] || hash[key.to_sym]
    end

    def bounded_score(value, fallback)
      score = value.to_i
      return fallback if score <= 0

      [[score, 1].max, 5].min
    end

    def normalized_risk(value)
      risk = value.to_s
      return risk if %w[Low Medium High].include?(risk)

      "Medium"
    end

    def normalized_array(value)
      Array(value).map(&:to_s)
    end

    def normalized_conflicts(value)
      Array(value).map do |entry|
        if entry.is_a?(Hash)
          {
            "conflict" => fetch_value(entry, "conflict").to_s,
            "severity" => normalized_risk(fetch_value(entry, "severity")),
            "evidence" => normalized_array(fetch_value(entry, "evidence"))
          }
        else
          { "conflict" => entry.to_s, "severity" => "Medium", "evidence" => [] }
        end
      end
    end
  end
end
