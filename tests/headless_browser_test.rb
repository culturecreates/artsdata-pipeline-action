require 'minitest/autorun'
require 'mocha/minitest'
require 'ferrum'
require 'linkeddata'
require_relative '../src/lib/headless_browser'

class HeadlessBrowserTest < Minitest::Test

  def setup
    # Stub the Ferrum::Browser.new method
    Ferrum::Browser.stubs(:new).returns(mock_browser)
    @browser = HeadlessBrowser.new
  end

  def test_string_to_json
    expected = {"key" => "value"}
    actual = @browser.string_to_json('{"key": "value"}')
    assert_equal expected, actual
  end

  def test_string_to_json_with_newlines
    expected = {"key" => "a bad linefeed"}
    crawled_str = "{\"key\" : \"a bad \nlinefeed\"}"
    actual = @browser.string_to_json(crawled_str)
    assert_equal expected, actual
  end


  private

  def mock_browser
    headers_mock = mock('headers')
    headers_mock.stubs(:set)
    headers_mock.stubs(:[]).returns("Chrome")

    browser = mock('browser')
    browser.stubs(:headers).returns(headers_mock)
    
    browser
  end
end