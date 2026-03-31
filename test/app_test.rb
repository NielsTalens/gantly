require "test_helper"

class AppTest < Minitest::Test
  class BaseHarness
    include Evaluators::Base

    def agent_name
      "test_agent"
    end

    def normalize_payload(payload)
      send(:normalize, payload)
    end
  end

  def test_strategy_prompt_path_exists
    assert File.exist?(Evaluators::Strategy::PROMPT_PATH),
           "Expected strategy prompt path to exist: #{Evaluators::Strategy::PROMPT_PATH}"
  end

  def test_normalize_preserves_mostly_aligns_with
    result = BaseHarness.new.normalize_payload(
      "alignment_score" => 4,
      "confidence_score" => 5,
      "risk_level" => "Low",
      "detected_conflicts" => [],
      "mostly_aligns_with" => ["fast input", "reduced admin work"],
      "what_would_make_this_a_5_of_5" => ["tighten onboarding"]
    )

    assert_equal ["fast input", "reduced admin work"], result["mostly_aligns_with"]
  end

  def test_normalize_defaults_mostly_aligns_with_to_empty_array
    result = BaseHarness.new.normalize_payload(
      "alignment_score" => 4,
      "confidence_score" => 5,
      "risk_level" => "Low",
      "detected_conflicts" => [],
      "what_would_make_this_a_5_of_5" => ["tighten onboarding"]
    )

    assert_equal [], result["mostly_aligns_with"]
  end

  def test_root_renders
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "Feature Proposal"
  end

  def test_root_uses_logo_png_for_brand_and_favicon
    get "/"

    assert last_response.ok?
    assert_includes last_response.body, 'rel="icon" href="/logo.png"'
    assert_includes last_response.body, 'src="/logo.png"'
    assert_includes last_response.body, 'alt="Gantly logo"'
  end

  def test_logo_png_is_served_from_root_path
    get "/logo.png"

    assert last_response.ok?
    assert_equal "image/png", last_response.headers["Content-Type"]
    assert_operator last_response.body.bytesize, :>, 0
  end

  def test_root_renders_alignment_guard_tab
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "Alignment Guard"
    assert_includes last_response.body, "id=\"run-coherence\""
  end

  def test_evaluate_returns_json
    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert json.key?("evaluations")
    assert json.key?("errors")
    assert json.key?("meta")
    refute json.key?("summary")
  end

  def test_coherence_requires_project_param
    post "/coherence", {}

    assert_equal 400, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal "project parameter is required", payload["message"]
    assert_equal "bad_request", payload["error_code"]
  end

  def test_coherence_returns_json
    original_method = Evaluators::CoherenceValidator.instance_method(:call)
    Evaluators::CoherenceValidator.send(:define_method, :call) do |_docs|
      {
        "pairs" => [
          {
            "id" => "strategy_vision",
            "label" => "Strategy <-> Vision",
            "alignment_score" => 4,
            "confidence_score" => 4,
            "structural_risk_level" => "Low",
            "core_alignment_themes" => ["shared target user"],
            "detected_contradictions" => [],
            "missing_links" => [],
            "minimal_change_to_improve_coherence" => "Clarify metric ownership."
          }
        ],
        "summary" => {
          "overall_structural_risk" => "Low",
          "dominant_misalignment_pattern" => "none",
          "most_leverage_fix" => "None"
        }
      }
    end

    post "/coherence", { project: "crm" }

    assert last_response.ok?
    payload = JSON.parse(last_response.body)
    assert_equal 1, payload["pairs"].length
    assert_equal "Strategy <-> Vision", payload["pairs"].first["label"]
    assert_equal "Low", payload.dig("summary", "overall_structural_risk")
  ensure
    Evaluators::CoherenceValidator.send(:define_method, :call, original_method)
  end

  def test_coherence_uses_selected_project_docs
    captured_docs = nil
    original_method = Evaluators::CoherenceValidator.instance_method(:call)
    Evaluators::CoherenceValidator.send(:define_method, :call) do |docs|
      captured_docs = docs
      {
        "pairs" => [],
        "summary" => {
          "overall_structural_risk" => "Low",
          "dominant_misalignment_pattern" => "none",
          "most_leverage_fix" => "None"
        }
      }
    end

    post "/coherence", { project: "crm" }

    assert last_response.ok?
    assert captured_docs
    assert_includes captured_docs[:strategy], "CRM"
    assert_includes captured_docs[:vision], "CRM"
    assert_includes captured_docs[:jtbd], "sales"
    assert_includes captured_docs[:product_charter], "CRM"
  ensure
    Evaluators::CoherenceValidator.send(:define_method, :call, original_method)
  end

  def test_evaluate_returns_real_evaluations
    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    json = JSON.parse(last_response.body)
    combined = json["evaluations"] + json["errors"]
    assert combined.any?
    assert combined.first.key?("agent")
  end

  def test_index_includes_summary_container
    get "/"
    assert_includes last_response.body, "id=\"summary\""
  end

  def test_index_renders_project_tags
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "data-project-tags"
    assert_includes last_response.body, "crm"
  end

  def test_evaluate_requires_project_param
    post "/evaluate", { feature_proposal: "Test feature" }
    assert_equal 400, last_response.status
    payload = JSON.parse(last_response.body)
    assert_equal [], payload["evaluations"]
    assert_kind_of Array, payload["errors"]
    assert_equal 1, payload["errors"].length
    assert_includes payload["errors"].first["message"], "project parameter is required"
    assert_equal 0, payload.dig("meta", "total")
  end

  def test_evaluate_rejects_unknown_project
    post "/evaluate", { feature_proposal: "Test feature", project: "does-not-exist" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "Unknown project"
  end

  def test_evaluate_rejects_project_without_md
    post "/evaluate", { feature_proposal: "Test feature", project: "empty_project" }
    assert_equal 400, last_response.status
    assert_includes last_response.body, "No .md files found"
  end

  def test_all_evaluators_returned
    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    json = JSON.parse(last_response.body)
    agents = (json["evaluations"] + json["errors"]).map { |e| e["agent"] }
    assert_includes agents, "strategy"
    assert_includes agents, "vision"
    assert_includes agents, "jtbd"
    assert_includes agents, "product_charter"
    assert_includes agents, "feedback"
    refute_includes agents, "user_flows"
  end

  def test_evaluate_returns_meta_counts
    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    json = JSON.parse(last_response.body)
    meta = json["meta"]
    assert_equal 5, meta["total"]
    assert_equal meta["total"], meta["succeeded"] + meta["failed"]
  end

  def test_evaluate_returns_partial_results_when_one_evaluator_fails
    original_method = Evaluators::Vision.instance_method(:call)
    Evaluators::Vision.send(:define_method, :call) { |_feature, _docs| raise "boom" }

    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    json = JSON.parse(last_response.body)

    vision_error = json["errors"].find { |error| error["agent"] == "vision" }
    assert vision_error
    assert_equal "evaluator_failed", vision_error["error_code"]
  ensure
    Evaluators::Vision.send(:define_method, :call, original_method)
  end

  def test_index_has_two_panel_layout
    get "/"
    assert_includes last_response.body, "class=\"layout page\""
  end

  def test_index_includes_loader_container
    get "/"
    assert_includes last_response.body, "id=\"loading\""
  end

  def test_evaluate_saves_feature_input_and_json_output_to_markdown_file
    output_dir = File.expand_path("../projects-output", __dir__)
    before_files = Dir.glob(File.join(output_dir, "project-*.md"))
    created_files = []

    post "/evaluate", { feature_proposal: "Save me for validation", project: "crm" }

    after_files = Dir.glob(File.join(output_dir, "project-*.md"))
    created_files = after_files - before_files

    assert_equal 1, created_files.length

    content = File.read(created_files.first)
    assert_includes content, "Save me for validation"
    assert_includes content, "\"evaluations\""
    assert_includes content, "\"errors\""
    assert_includes content, "\"meta\""
  ensure
    created_files.each { |file| File.delete(file) if File.exist?(file) }
  end
end
