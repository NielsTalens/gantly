require "sinatra"
require "json"

require_relative "lib/openai_client"
require_relative "lib/evaluators/base"
require_relative "lib/evaluators/strategy"
require_relative "lib/evaluators/vision"
require_relative "lib/evaluators/jtbd"
require_relative "lib/evaluators/user_flows"
require_relative "lib/evaluators/product_charter"
require_relative "lib/evaluators/feedback"

PROJECTS_ROOT = File.expand_path("projects", __dir__)

helpers do
  def project_names
    return [] unless Dir.exist?(PROJECTS_ROOT)

    Dir.children(PROJECTS_ROOT)
       .select { |entry| File.directory?(File.join(PROJECTS_ROOT, entry)) }
       .sort
  end
end

get "/" do
  @projects = project_names
  @default_project = @projects.first
  erb :index
end

post "/evaluate" do
  content_type :json
  feature = params["feature_proposal"].to_s
  project = params["project"].to_s.strip

  halt 400, { error: "project parameter is required" }.to_json if project.empty?

  read_doc = lambda do |path, label|
    File.exist?(path) ? File.read(path) : "No #{label} document provided."
  end

  docs = {
    strategy: read_doc.call("product-description/01-strategy.md", "strategy"),
    vision: read_doc.call("product-description/02-product-vision.md", "vision"),
    jtbd: read_doc.call("product-description/03-jtbd.md", "jtbd"),
    user_flows: read_doc.call("product-description/04-user-flows.md", "user flows"),
    product_charter: read_doc.call("product-description/05-product-charter.md", "product charter"),
    feedback: read_doc.call("product-description/06-feedback.md", "feedback")
  }
  evaluators = [
    Evaluators::Strategy.new,
    Evaluators::Vision.new,
    Evaluators::Jtbd.new,
    Evaluators::UserFlows.new,
    Evaluators::ProductCharter.new,
    Evaluators::Feedback.new
  ]

  index_by_agent = evaluators.each_with_index.to_h { |evaluator, index| [evaluator.agent_name, index] }
  mutex = Mutex.new
  evaluations = []
  errors = []

  threads = evaluators.map do |evaluator|
    Thread.new do
      begin
        result = evaluator.call(feature, docs)
        mutex.synchronize { evaluations << result }
      rescue StandardError => e
        sanitized_message = e.message.to_s.strip
        sanitized_message = "evaluator run failed" if sanitized_message.empty?
        mutex.synchronize do
          errors << {
            "agent" => evaluator.agent_name,
            "error_code" => "evaluator_failed",
            "message" => sanitized_message
          }
        end
      end
    end
  end

  threads.each(&:join)

  sorted_evaluations = evaluations.sort_by { |item| index_by_agent.fetch(item["agent"], 999) }
  sorted_errors = errors.sort_by { |item| index_by_agent.fetch(item["agent"], 999) }

  {
    evaluations: sorted_evaluations,
    errors: sorted_errors,
    meta: {
      total: evaluators.length,
      succeeded: sorted_evaluations.length,
      failed: sorted_errors.length
    }
  }.to_json
end
