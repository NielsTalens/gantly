module Evaluators
  class Vision
    include Base

    AGENT_NAME = "vision".freeze
    PROMPT_PATH = "product-thinking/02-vision-evaluator.md".freeze

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
          "vision_doc" => docs[:vision]
        }
      )
    end

    private

    attr_reader :client
  end
end
