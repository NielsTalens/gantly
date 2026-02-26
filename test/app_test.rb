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
end
