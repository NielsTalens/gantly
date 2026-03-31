require "sinatra"
require "json"

require_relative "lib/openai_client"
require_relative "lib/run_logger"
require_relative "lib/evaluators/base"
require_relative "lib/evaluators/coherence_validator"
require_relative "lib/evaluators/strategy"
require_relative "lib/evaluators/vision"
require_relative "lib/evaluators/jtbd"
require_relative "lib/evaluators/product_charter"
require_relative "lib/evaluators/feedback"

PROJECTS_ROOT = File.expand_path("projects", __dir__)
FEATURE_DOC_FILES = {
  strategy: "01-strategy.md",
  vision: "02-product-vision.md",
  jtbd: "03-jtbd.md",
  product_charter: "05-product-charter.md",
  feedback: "06-feedback.md"
}.freeze
COHERENCE_DOC_FILES = {
  strategy: "01-strategy.md",
  vision: "02-product-vision.md",
  jtbd: "03-jtbd.md",
  product_charter: "05-product-charter.md"
}.freeze
LOGO_PATH = File.expand_path("logo.png", __dir__)

helpers do
  def project_names
    return [] unless Dir.exist?(PROJECTS_ROOT)

    Dir.children(PROJECTS_ROOT)
       .select { |entry| File.directory?(File.join(PROJECTS_ROOT, entry)) }
       .sort
  end

  def bad_request_payload(message)
    {
      evaluations: [],
      errors: [
        {
          agent: "request",
          error_code: "bad_request",
          message: message
        }
      ],
      meta: {
        total: 0,
        succeeded: 0,
        failed: 1
      }
    }
  end

  def error_payload(message)
    {
      error_code: "bad_request",
      message: message
    }
  end

  def load_project_docs(project, doc_files, error_builder:)
    halt 400, error_builder.call("project parameter is required").to_json if project.empty?

    project_path = File.join(PROJECTS_ROOT, project)
    halt 400, error_builder.call("Unknown project: #{project}").to_json unless Dir.exist?(project_path)

    md_files = Dir.glob(File.join(project_path, "*.md"))
    halt 400, error_builder.call("No .md files found for project #{project}").to_json if md_files.empty?

    read_doc = lambda do |path, label|
      File.exist?(path) ? File.read(path) : "No #{label} document provided."
    end

    doc_files.transform_values do |filename|
      label = filename.sub(/\A\d+-/, "").sub(/\.md\z/, "").tr("-", " ")
      read_doc.call(File.join(project_path, filename), label)
    end
  end
end

get "/" do
  @projects = project_names
  @default_project = @projects.first
  erb :index
end

get "/logo.png" do
  content_type :png
  send_file LOGO_PATH
end

post "/evaluate" do
  content_type :json
  feature = params["feature_proposal"].to_s
  project = params["project"].to_s.strip

  docs = load_project_docs(project, FEATURE_DOC_FILES, error_builder: method(:bad_request_payload))
  evaluators = [
    Evaluators::Strategy.new,
    Evaluators::Vision.new,
    Evaluators::Jtbd.new,
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

  response_payload = {
    evaluations: sorted_evaluations,
    errors: sorted_errors,
    meta: {
      total: evaluators.length,
      succeeded: sorted_evaluations.length,
      failed: sorted_errors.length
    }
  }

  RunLogger.save(feature_input: feature, result_payload: response_payload)
  response_payload.to_json
end

post "/coherence" do
  content_type :json
  project = params["project"].to_s.strip
  docs = load_project_docs(project, COHERENCE_DOC_FILES, error_builder: method(:error_payload))

  Evaluators::CoherenceValidator.new.call(docs).to_json
rescue Sinatra::Halt
  raise
rescue StandardError => e
  status 500
  {
    error_code: "coherence_failed",
    message: e.message.to_s.strip.empty? ? "coherence validation failed" : e.message.to_s.strip
  }.to_json
end
