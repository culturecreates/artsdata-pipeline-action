require 'minitest/autorun'
require_relative '../src/lib/helper'

class SpiderCrawlerMaxPagesTest < Minitest::Test
  def build(max_pages: nil)
    SpiderCrawlerService::SpiderCrawler.new(
      url: ['https://example.com'],
      page_fetcher: nil,
      sparql: nil,
      robots_txt_content: nil,
      **(max_pages ? { max_pages: max_pages } : {})
    )
  end

  def test_defaults_to_config_value
    assert_equal Config::SPIDER_CRAWLER[:max_pages_to_crawl], build.instance_variable_get(:@max_pages)
  end

  def test_param_overrides_default
    assert_equal 10, build(max_pages: 10).instance_variable_get(:@max_pages)
  end
end
