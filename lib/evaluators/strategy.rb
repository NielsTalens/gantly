module Evaluators
  class Strategy
    include Base

    AGENT_NAME = "strategy".freeze
    PROMPT_PATH = "product-thinking/01-strategy-evaluator".freeze

    def initialize(client: OpenAIClient.new)
      @client = client
    end

    def agent_name
      AGENT_NAME
    end

    def call(feature, docs)
      evaluate_with_template(
        template_path: PROMPT_PATH,
        replacements: {
          "feature_proposal" => feature,
          "strategy_doc" => docs[:strategy]
        }
      )
    end

    private

    attr_reader :client
  end
end
