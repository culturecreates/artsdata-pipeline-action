# frozen_string_literal: true

require "json"
require_relative "failure_classifier"

exit_code = ARGV[0].to_i
started_at = ARGV[1]
ended_at = ARGV[2]

log_text = File.exist?("run.log") ? File.read("run.log") : ""
category, http_status, ruby_exception_class = FailureClassifier.classify(log_text, exit_code)

result = {
  repo: ENV["GITHUB_REPOSITORY"],
  workflow: ENV["GITHUB_WORKFLOW"],
  run_id: ENV["GITHUB_RUN_ID"]&.to_i,
  result: exit_code.zero? ? "success" : "failure",
  started_at: started_at,
  ended_at: ended_at,
  failure_category: category,
  http_status: http_status,
  ruby_exception_class: ruby_exception_class
}

File.write("result.json", JSON.pretty_generate(result))
puts "Wrote result.json: #{result[:result]} (#{result[:failure_category] || 'n/a'})"