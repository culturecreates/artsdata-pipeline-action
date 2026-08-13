# frozen_string_literal: true

# Classifies a pipeline run by grepping the captured combined stdout+stderr
# of the docker run step. Every pattern below is matched against an actual
# `puts` call (or Ruby's default uncaught-exception printer) found in the
# real source of artsdata-pipeline-action - none of these are guessed.
#
# Known gap: SHACL validation results travel via `report-callback-url`
# (async POST), never touching this process's exit code or stdout, so
# they can't be classified here. See NOTES.md.
#
# Known gap: github_saver.rb's missing-token path calls exit(0), so that
# failure mode looks like a success from outside and won't appear at all.
module FailureClassifier
  PATTERNS = [
    # main.rb -> Helper.check_mode_requirements
    [/Missing required parameter\(s\) in config file/, "missing_config"],

    # main.rb, fetch mode, entity_identifier path
    [/No entity URLs found/, "no_entity_urls"],

    # url_fetcher.rb#fetch_urls
    [/No pages were loaded\. Check your page URL/, "no_pages_loaded"],

    # main.rb, after crawl/fetch
    [/No RDF data extracted/, "empty_graph"],

    # headless_page_fetcher.rb, raised RuntimeError, uncaught -> Ruby's
    # default exception printer puts this substring on stderr
    [/Timeout waiting for (page|json-ld) to load/, "timeout"],

    # databus.rb#send, non-201 response - HTTP status is embedded in the text
    [/Error posting data: (\d{3})/, "databus_error"],

    # databus.rb#send, rescue StandardError (network-level, no HTTP status)
    [/Exception occurred:/, "databus_exception"],

    # helper.rb#send_databus_notification, defensive else branch
    [/Unknown status:/, "databus_unknown_status"]
  ].freeze

  HTTP_STATUS = /Error posting data: (\d{3})/
  RUBY_EXCEPTION_CLASS = /\(([\w:]+(?:Error|Exception))\)\s*$/

  # classify(log_text, exit_code) -> [category, http_status_or_nil, ruby_exception_class_or_nil]
  def self.classify(log_text, exit_code)
    return [nil, nil, nil] if exit_code.zero?

    PATTERNS.each do |pattern, category|
      next unless pattern.match?(log_text)

      status = log_text[HTTP_STATUS, 1]&.to_i
      return [category, status, nil]
    end

    # Nothing matched a known path - likely an unhandled Ruby exception.
    # Try to pull the exception class name from the last few lines for
    # a useful "unhandled_exception:ClassName" breakdown instead of one
    # opaque bucket.
    last_lines = log_text.lines.last(20).join
    exception_class = last_lines[RUBY_EXCEPTION_CLASS, 1]
    ["unhandled_exception", nil, exception_class]
  end
end