require 'minitest/autorun'
require_relative '../src/url_fetcher_service/url_fetcher'

class UrlFetcherTest < Minitest::Test
  def setup
    NotificationService::WebhookNotification.close rescue nil
    NotificationService::WebhookNotification.setup(workflow_id: 'test', actor: 'test', webhook_url: '')
    @fetcher = UrlFetcherService::UrlFetcher.new(
      page_url: ["https://example.com/page"],
      base_url: "https://example.com",
      entity_identifier: ".entity-link",
      is_paginated: true,
      offset: 10,
      page_fetcher: nil,
      robots_txt_content: nil
    )
  end

  def teardown
    NotificationService::WebhookNotification.close
  end

  def test_detect_identifier_type_with_css
    assert_equal :css, @fetcher.detect_identifier_type("#main")
  end

  def test_detect_identifier_type_with_xpath
    assert_equal :xpath, @fetcher.detect_identifier_type("//div[@class='foo']")
  end

  StubPageFetcher = Struct.new(:body, :content_type) do
    def fetcher_with_retry(**)
      [body, content_type]
    end
  end

  StubRobots = Struct.new(:disallowed_prefix) do
    def allowed?(_user_agent, path)
      disallowed_prefix.nil? || !path.to_s.start_with?(disallowed_prefix)
    end
  end

  def fetch(html, identifier, page_url: 'https://example.com/fr/events', content_type: 'text/html', disallow: nil)
    fetcher = UrlFetcherService::UrlFetcher.new(
      page_url: [page_url],
      base_url: 'https://example.com',
      entity_identifier: identifier,
      is_paginated: false,
      offset: nil,
      page_fetcher: StubPageFetcher.new(html, content_type),
      robots_txt_content: StubRobots.new(disallow)
    )
    urls = nil
    out, = capture_io { urls = fetcher.fetch_urls }
    [urls, out]
  end

  def test_element_without_href_does_not_drop_other_matches
    html = '<a class="e" href="/a">A</a><a class="e">no link</a><a class="e" href="/b">B</a>'
    urls, = fetch(html, 'a.e')
    assert_equal ['https://example.com/a', 'https://example.com/b'], urls
  end

  def test_container_selector_uses_link_inside
    html = '<div class="card"><h3>A</h3><a href="/fr/event/a">A</a></div><div class="card"><a href="/fr/event/b">B</a></div>'
    urls, = fetch(html, 'div.card')
    assert_equal ['https://example.com/fr/event/a', 'https://example.com/fr/event/b'], urls
  end

  def test_relative_hrefs_resolve_against_page_url
    html = '<a class="e" href="detail/1">1</a><a class="e" href="//other.com/2">2</a><a class="e" href="?id=3">3</a>'
    urls, = fetch(html, 'a.e')
    assert_equal ['https://example.com/fr/detail/1', 'https://other.com/2', 'https://example.com/fr/events?id=3'], urls
  end

  def test_non_http_links_are_skipped
    html = '<a class="e" href="mailto:x@example.com">m</a><a class="e" href="javascript:void(0)">j</a><a class="e" href="/ok">ok</a>'
    urls, = fetch(html, 'a.e')
    assert_equal ['https://example.com/ok'], urls
  end

  def test_sitemap_loc_entries
    xml = '<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc> https://example.com/e/1 </loc></url><url><loc>https://example.com/e/2</loc></url></urlset>'
    urls, = fetch(xml, 'loc', page_url: 'https://example.com/sitemap.xml', content_type: 'application/xml')
    assert_equal ['https://example.com/e/1', 'https://example.com/e/2'], urls
  end

  def test_explains_zero_matches_with_sample_links
    html = '<a href="/fr/concerts/saison">Season</a><a href="#main">skip</a>'
    urls, out = fetch(html, 'div.cont-even a')
    assert_empty urls
    assert_match(/matched 0 elements/, out)
    assert_match(%r{/fr/concerts/saison}, out)
    refute_match(/#main/, out)
  end

  def test_explains_matches_without_links
    urls, out = fetch('<div class="e">A</div><div class="e">B</div>', 'div.e')
    assert_empty urls
    assert_match(/2 matched elements have no href/, out)
  end

  def test_explains_robots_disallowed
    urls, out = fetch('<a class="e" href="/private/1">1</a>', 'a.e', disallow: '/private')
    assert_empty urls
    assert_match(/disallowed by robots\.txt/, out)
  end

  def test_invalid_selector_is_reported
    urls, out = fetch('<a href="/a">a</a>', 'a[[')
    assert_empty urls
    assert_match(/invalid entity-identifier/, out)
  end
end
