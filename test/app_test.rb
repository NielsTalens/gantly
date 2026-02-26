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
end
