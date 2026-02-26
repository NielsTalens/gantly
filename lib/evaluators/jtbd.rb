module Evaluators
  class Jtbd
    include Base

    AGENT_NAME = "jtbd".freeze
    PROMPT_PATH = "product-thinking/03-jtbd-evaluator.md".freeze

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
          "jtbd_doc" => docs[:jtbd]
        }
      )
    end

    private

    attr_reader :client
  end
end
