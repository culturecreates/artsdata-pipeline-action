require 'minitest/autorun'
require_relative '../src/url_fetcher_service/url_fetcher'

class UrlFetcherTest < Minitest::Test
  def setup
    @fetcher = UrlFetcherService::UrlFetcher.new(
      page_url: ["https://example.com/page"],
      base_url: "https://example.com",
      entity_identifier: ".entity-link",
      is_paginated: true,
      offset: 10,
      page_fetcher: nil,
      robots_txt_ruleset: nil
    )
  end

  def test_detect_identifier_type_with_css
    assert_equal :css, @fetcher.detect_identifier_type("#main")
  end

  def test_detect_identifier_type_with_xpath
    assert_equal :xpath, @fetcher.detect_identifier_type("//div[@class='foo']")
  end

end
