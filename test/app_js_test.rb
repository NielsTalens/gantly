require "test_helper"
require "open3"

class AppJsTest < Minitest::Test
  def test_running_coherence_switches_to_coherence_view
    stdout, stderr, status = Open3.capture3("node", File.expand_path("support/app_view_switch_test.mjs", __dir__))

    assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
  end
end
