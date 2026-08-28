require 'minitest/autorun'
require_relative '../../src/page_fetcher_service/page_fetcher'
require_relative '../../src/notification_service/webhook_notification'
require_relative '../../src/lib/helper'

# Stub subclass: returns canned (data, content_type) pairs per call, and
# no-ops sleep so retry/backoff doesn't slow the suite down.
class StubPageFetcher < PageFetcherService::PageFetcher
  def initialize(responses:)
    super()
    @responses = responses
    @call_count = 0
  end

  def fetch_page_data(page_url:, selector:, accept: nil)
    response = @responses[[@call_count, @responses.length - 1].min]
    @call_count += 1
    response
  end

  def sleep(*); end
end

class PageFetcherContentTypeTest < Minitest::Test
  CASES = {
    'mismatch_exhausts_retries_and_returns_nil' => {
      responses: [['<html>blocked</html>', 'text/html']],
      expected_content_type: 'xml',
      expected_data: nil,
      expected_result_content_type: nil,
      notification_expected: true
    },
    'matching_type_returns_data_immediately' => {
      responses: [['<urlset><loc>http://example.com/a</loc></urlset>', 'text/xml']],
      expected_content_type: 'xml',
      expected_data: '<urlset><loc>http://example.com/a</loc></urlset>',
      expected_result_content_type: 'text/xml',
      notification_expected: false
    },
    'nil_expectation_skips_content_type_check' => {
      responses: [['<html>whatever</html>', 'text/html']],
      expected_content_type: nil,
      expected_data: '<html>whatever</html>',
      expected_result_content_type: 'text/html',
      notification_expected: false
    }
  }

  def setup
    NotificationService::WebhookNotification.close rescue nil
    NotificationService::WebhookNotification.setup(workflow_id: 'test', actor: 'test', webhook_url: '')

    @sent_notifications = []
    notifications = @sent_notifications
    NotificationService::WebhookNotification.instance.define_singleton_method(:send_notification) do |stage:, message:|
      notifications << { stage: stage, message: message }
    end
  end

  def teardown
    NotificationService::WebhookNotification.close
  end

  def test_fetcher_with_retry_content_type_validation
    CASES.each do |name, c|
      fetcher = StubPageFetcher.new(responses: c[:responses])
      data, content_type = nil, nil

      capture_io do
        data, content_type = fetcher.fetcher_with_retry(
          page_url: 'https://example.com/tribe_events-sitemap1.xml',
          selector: 'loc',
          expected_content_type: c[:expected_content_type]
        )
      end

      if c[:expected_data].nil?
        assert_nil data, "[#{name}] expected data to be nil"
      else
        assert_equal c[:expected_data], data, "[#{name}] unexpected data"
      end

      if c[:expected_result_content_type].nil?
        assert_nil content_type, "[#{name}] expected content_type to be nil"
      else
        assert_equal c[:expected_result_content_type], content_type, "[#{name}] unexpected content_type"
      end

      assert_equal c[:notification_expected], @sent_notifications.any?, "[#{name}] unexpected notification state"

      @sent_notifications.clear
    end
  end
end