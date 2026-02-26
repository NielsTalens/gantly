module Evaluators
  class UserFlows
    include Base

    AGENT_NAME = "user_flows".freeze
    PROMPT_PATH = "product-thinking/04-user-flow-evaluator.md".freeze

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
          "user_flows_doc" => docs[:user_flows]
        }
      )
    end

    private

    attr_reader :client
  end
end
