require 'minitest/autorun'
require_relative '../src/uri_fetcher_service/uri_fetcher'

class UriFetcherTest < Minitest::Test
  def setup
    @fetcher = UriFetcherService::UriFetcher.new(base_url: "https://example.com")
  end

  def test_detect_identifier_type_with_css
    assert_equal :css, @fetcher.detect_identifier_type("#main")
  end

  def test_detect_identifier_type_with_xpath
    assert_equal :xpath, @fetcher.detect_identifier_type("//div[@class='foo']")
  end

end
