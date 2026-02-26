module Evaluators
  class Feedback
    include Base

    AGENT_NAME = "feedback".freeze
    PROMPT_PATH = "product-thinking/06-feedback-evaluator.md".freeze

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
          "feedback_doc" => docs[:feedback]
        }
      )
    end

    private

    attr_reader :client
  end
end
