require 'minitest/autorun'
require 'minitest/mock'
require_relative '../../src/lib/helper'

# Serves canned HTML per URL and records every URL requested.
class LinkedPageStubFetcher < PageFetcherService::PageFetcher
  attr_reader :requested

  def initialize(pages:)
    super()
    @pages = pages
    @requested = []
  end

  def fetch_page_data(page_url:, selector:, accept: nil)
    @requested << page_url
    [@pages.fetch(page_url), 'text/html']
  end
end

class LinkedPageExtractTest < Minitest::Test
  SCHEMA_DESCRIPTION = RDF::URI('http://schema.org/description')
  SHOW_URL = 'https://example.com/shows/play/blithe-spirit/'

  def event_page(slug, url: SHOW_URL)
    url_property = url.nil? ? '' : %("url": "#{url}",)
    <<~HTML
      <html><head>
      <script type="application/ld+json">
      { "@context": "http://schema.org", "@type": "Event", "@id": "https://example.com/event/#{slug}/#event",
        #{url_property} "name": "#{slug}", "startDate": "2026-11-01T19:30:00-06:00" }
      </script>
      </head><body><div class="content-box">event page text</div></body></html>
    HTML
  end

  def show_page
    '<html><body><div class="content-box">  The show   synopsis. </div></body></html>'
  end

  def config(from_property: 'http://schema.org/url')
    entry = { 'xpath' => 'normalize-space(//div[contains(@class,"content-box")])' }
    entry['from_property'] = from_property if from_property
    { 'entity_type' => 'http://schema.org/Event', 'extract' => { SCHEMA_DESCRIPTION.to_s => entry } }
  end

  def run_fetcher(pages, entity_urls, html_extract_config)
    fetcher = LinkedPageStubFetcher.new(pages: pages)
    graph_fetcher = Helper.get_graph_fetcher(
      page_fetcher: fetcher,
      sparql_path: './sparql/',
      html_extract_config: html_extract_config
    )
    graph = Helper.stub(:get_robots_txt_content, RobotsTxtParser.parse(nil)) do
      graph_fetcher.load_with_retry(entity_urls: entity_urls)
    end
    [graph, fetcher.requested]
  end

  def descriptions(graph, slug)
    graph.query([RDF::URI("https://example.com/event/#{slug}/#event"), SCHEMA_DESCRIPTION, nil]).map { |s| s.object.to_s }
  end

  def test_extracts_from_linked_page_and_fetches_it_once
    pages = {
      'https://example.com/event/a/' => event_page('a'),
      'https://example.com/event/b/' => event_page('b'),
      SHOW_URL => show_page
    }
    graph, requested = run_fetcher(pages, pages.keys.first(2), config)

    assert_equal ['The show synopsis.'], descriptions(graph, 'a')
    assert_equal ['The show synopsis.'], descriptions(graph, 'b')
    assert_equal 1, requested.count(SHOW_URL)
  end

  def test_skips_when_property_missing
    pages = { 'https://example.com/event/a/' => event_page('a', url: nil) }
    graph, requested = run_fetcher(pages, pages.keys, config)

    assert_empty descriptions(graph, 'a')
    assert_equal pages.keys, requested
  end

  def test_skips_when_property_points_to_crawled_page
    pages = { 'https://example.com/event/a/' => event_page('a', url: 'https://example.com/event/a') }
    graph, requested = run_fetcher(pages, pages.keys, config)

    assert_empty descriptions(graph, 'a')
    assert_equal pages.keys, requested
  end

  def test_without_from_property_reads_crawled_page
    pages = { 'https://example.com/event/a/' => event_page('a') }
    graph, requested = run_fetcher(pages, pages.keys, config(from_property: nil))

    assert_equal ['event page text'], descriptions(graph, 'a')
    assert_equal pages.keys, requested
  end
end
