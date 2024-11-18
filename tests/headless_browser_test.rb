require 'minitest/autorun'
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



end