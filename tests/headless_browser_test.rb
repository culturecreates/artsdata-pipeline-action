require 'minitest/autorun'
require 'mocha/minitest'
require 'ferrum'
require 'linkeddata'
require_relative '../src/lib/headless_browser'

class HeadlessBrowserTest < Minitest::Test

  def test_string_to_json
    expected = {"key" => "value"}
    actual = HeadlessBrowser.string_to_json('{"key": "value"}')
    assert_equal expected, actual
  end

  def test_string_to_json_with_newlines
    expected = {"key" => "a bad linefeed"}
    crawled_str = "{\"key\" : \"a bad \nlinefeed\"}"
    actual = HeadlessBrowser.string_to_json(crawled_str)
    assert_equal expected, actual
  end

  # Test create_browser method
  def test_create_browser
    # Stub the Ferrum::Browser.new method
    Ferrum::Browser.stubs(:new).returns(mock_browser)

    # Call the method
    browser = HeadlessBrowser.create_browser

    # Assertions
    assert_instance_of Mocha::Mock, browser
  end

  def test_create_browser_with_headers    
    # Stub the Ferrum::Browser.new method
    Ferrum::Browser.stubs(:new).returns(mock_browser)
    
    # Call the method with headers
    browser = HeadlessBrowser.create_browser({"User-Agent" => "Chrome"})

    # Assertions
    assert_instance_of Mocha::Mock, browser
    assert_equal "Chrome", browser.headers["User-Agent"]
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