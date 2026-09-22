require 'minitest/autorun'
require_relative '../../src/lib/helper'

class TestAutoDetectPageParam < Minitest::Test

  def test_detect_page_url_param_delegates_to_detector
    fake_detector = Minitest::Mock.new
    fake_detector.expect(:detect, "https://site.com/?page_x=1", [], base_page_url: "https://site.com/")

    # Stub the browser (so no real Chrome launches) and the detector class.
    BrowserService::ChromeBrowser.stub :new, :fake_browser do
      PaginationParamDetectorService::PaginationParamDetector.stub :new, fake_detector do
        result = Helper.detect_page_url_param(
          base_page_url: "https://site.com/",
          entity_identifier: "a.event-link"
        )
        assert_equal "https://site.com/?page_x=1", result
      end
    end

    fake_detector.verify
  end


  def with_stubs(detected_map)
    # detected_map: original url -> detected url (or nil to simulate failure)
    detector_lambda = lambda do |base_page_url:, entity_identifier:|
      detected_map.fetch(base_page_url)
    end

    detector_stub = Object.new
    detector_stub.define_singleton_method(:detect) do |base_page_url:|
      detector_lambda.call(base_page_url: base_page_url, entity_identifier: nil)
    end

    captured = {}
    fetcher_stub = lambda do |**kwargs|
      captured[:page_url] = kwargs[:page_url]
      :fake_fetcher
    end

    BrowserService::ChromeBrowser.stub :new, :fake_browser do
      PaginationParamDetectorService::PaginationParamDetector.stub :new, detector_stub do
        UrlFetcherService::UrlFetcher.stub :new, fetcher_stub do
          yield captured
        end
      end
    end
  end

  def test_get_url_fetcher_rewrites_urls_when_auto_detect_enabled
    detected = {
      "https://a.com/" => "https://a.com/?p_a=1",
      "https://b.com/" => "https://b.com/?p_b=1"
    }

    with_stubs(detected) do |captured|
      Helper.get_url_fetcher(
        page_url: ["https://a.com/", "https://b.com/"],
        base_url: "https://a.com",
        entity_identifier: "a.event",
        is_paginated: true,
        offset: 1,
        page_fetcher: :fake_page_fetcher,
        robots_txt_content: :fake_robots,
        auto_detect_page_param: true
      )

      assert_equal ["https://a.com/?p_a=1", "https://b.com/?p_b=1"], captured[:page_url]
    end
  end

  def test_get_url_fetcher_leaves_urls_unchanged_when_disabled
    captured = {}
    fetcher_stub = lambda do |**kwargs|
      captured[:page_url] = kwargs[:page_url]
      :fake_fetcher
    end

    UrlFetcherService::UrlFetcher.stub :new, fetcher_stub do
      Helper.get_url_fetcher(
        page_url: ["https://a.com/"],
        base_url: "https://a.com",
        entity_identifier: "a.event",
        is_paginated: false,
        offset: 1,
        page_fetcher: :fake_page_fetcher,
        robots_txt_content: :fake_robots,
        auto_detect_page_param: false
      )
    end

    assert_equal ["https://a.com/"], captured[:page_url]
  end

  def test_get_url_fetcher_exits_when_detection_fails
    detected = { "https://a.com/" => nil } # simulate detection failure

    # Stub the notification singleton so send_notification is a no-op.
    fake_notification = Object.new
    fake_notification.define_singleton_method(:send_notification) { |**_| nil }

    NotificationService::WebhookNotification.stub :instance, fake_notification do
      with_stubs(detected) do |_captured|
        assert_raises(SystemExit) do
          Helper.get_url_fetcher(
            page_url: ["https://a.com/"],
            base_url: "https://a.com",
            entity_identifier: "a.event",
            is_paginated: true,
            offset: 1,
            page_fetcher: :fake_page_fetcher,
            robots_txt_content: :fake_robots,
            auto_detect_page_param: true
          )
        end
      end
    end
  end

end
