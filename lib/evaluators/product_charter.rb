module Evaluators
  class ProductCharter
    include Base

    AGENT_NAME = "product_charter".freeze
    PROMPT_PATH = "product-thinking/05-product-charter-evaluator.md".freeze

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
          "product_charter_doc" => docs[:product_charter]
        }
      )
    end

    private

    attr_reader :client
  end
end
