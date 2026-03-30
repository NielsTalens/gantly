module Evaluators
  class CoherenceValidator
    PAIR_CONFIG = [
      ["strategy_vision", "Strategy <-> Vision"],
      ["strategy_product_charter", "Strategy <-> Product Charter"],
      ["vision_jtbd", "Vision <-> JTBD"],
      ["vision_product_charter", "Vision <-> Product Charter"]
    ].freeze
    PROMPT_PATH = "product-thinking/coherence-validator.md".freeze

    def initialize(client: OpenAIClient.new)
      @client = client
    end

    def call(docs)
      rendered_prompt = File.read(PROMPT_PATH)
      {
        "strategy_doc" => docs[:strategy],
        "vision_doc" => docs[:vision],
        "jtbd_doc" => docs[:jtbd],
        "product_charter_doc" => docs[:product_charter]
      }.each do |key, value|
        rendered_prompt = rendered_prompt.gsub("{#{key}}", value.to_s)
      end

      parsed = client.evaluate_json(
        system_prompt: "Follow the provided validator instructions strictly. Return only valid JSON.",
        user_prompt: rendered_prompt
      )
      normalize(parsed)
    end

    private

    attr_reader :client

    def normalize(parsed)
      result = parsed.is_a?(Hash) ? parsed : {}
      result = result["result"] if result["result"].is_a?(Hash)
      data = result || {}

      {
        "pairs" => PAIR_CONFIG.map { |id, label| normalize_pair(id, label, fetch_value(data, id)) },
        "summary" => {
          "overall_structural_risk" => normalized_risk(fetch_value(data, "overall_structural_risk")),
          "dominant_misalignment_pattern" => fetch_value(data, "dominant_misalignment_pattern").to_s,
          "most_leverage_fix" => fetch_value(data, "most_leverage_fix").to_s,
          "cross_document_findings" => normalize_cross_document_findings(fetch_value(data, "cross_document_findings"))
        }
      }
    end

    def normalize_pair(id, label, raw_value)
      data = raw_value.is_a?(Hash) ? raw_value : {}
      {
        "id" => id,
        "label" => label,
        "alignment_score" => bounded_score(fetch_value(data, "alignment_score"), 3),
        "confidence_score" => bounded_score(fetch_value(data, "confidence_score"), 2),
        "structural_risk_level" => normalized_risk(fetch_value(data, "structural_risk_level")),
        "core_alignment_themes" => normalized_array(fetch_value(data, "core_alignment_themes")),
        "detected_contradictions" => normalized_array(fetch_value(data, "detected_contradictions")),
        "missing_links" => normalized_array(fetch_value(data, "missing_links")),
        "minimal_change_to_improve_coherence" => fetch_value(data, "minimal_change_to_improve_coherence").to_s
      }
    end

    def normalize_cross_document_findings(value)
      data = value.is_a?(Hash) ? value : {}
      {
        "target_customer_mismatches" => normalized_array(fetch_value(data, "target_customer_mismatches")),
        "ambition_mismatches" => normalized_array(fetch_value(data, "ambition_mismatches")),
        "scope_inflation_or_dilution_risks" => normalized_array(fetch_value(data, "scope_inflation_or_dilution_risks"))
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
  end
end
