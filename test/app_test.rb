require "test_helper"

class AppTest < Minitest::Test
  def test_root_renders
    get "/"
    assert last_response.ok?
    assert_includes last_response.body, "Feature Proposal"
  end

  def test_evaluate_returns_json
    post "/evaluate", { feature_proposal: "Test feature" }
    assert last_response.ok?
    json = JSON.parse(last_response.body)
    assert json.key?("summary")
    assert json.key?("evaluations")
  end

  def test_evaluate_returns_real_evaluations
    post "/evaluate", { feature_proposal: "Test feature" }
    json = JSON.parse(last_response.body)
    assert json["evaluations"].any?
    assert json["evaluations"].first.key?("agent")
  end

  def test_index_includes_summary_container
    get "/"
    assert_includes last_response.body, "id=\"summary\""
  end

  def test_all_evaluators_returned
    post "/evaluate", { feature_proposal: "Test feature" }
    json = JSON.parse(last_response.body)
    agents = json["evaluations"].map { |e| e["agent"] }
    assert_includes agents, "vision"
    assert_includes agents, "jtbd"
    assert_includes agents, "user_flows"
    assert_includes agents, "product_description"
    assert_includes agents, "feedback"
  end

  def test_index_has_two_panel_layout
    get "/"
    assert_includes last_response.body, "class=\"layout\""
  end
end
