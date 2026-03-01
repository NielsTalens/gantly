require "test_helper"

class AppTest < Minitest::Test
  def test_root_renders
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "Feature Proposal"
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
    assert_includes last_response.body, "project parameter is required"
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
    assert_includes agents, "user_flows"
    assert_includes agents, "product_charter"
    assert_includes agents, "feedback"
  end

  def test_evaluate_returns_meta_counts
    post "/evaluate", { feature_proposal: "Test feature", project: "crm" }
    json = JSON.parse(last_response.body)
    meta = json["meta"]
    assert_equal 6, meta["total"]
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
end
