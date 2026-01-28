require_relative '../browser_service/browser'

module PageFetcherService
  class HeadlessPageFetcher < PageFetcherService::PageFetcher
    def initialize(browser:, private_key_content: nil)
      @browser = browser
      @browser_instance = @browser.create_browser()
      @private_key_content = private_key_content
    end

    def fetch_page_data(page_url:, selector:)
      timeout = 10 
      authority = URI.parse(page_url).authority
      headers = Helper.get_headers(authority, @private_key_content)
      @browser_instance.headers.set(headers)
      @browser_instance.go_to(page_url)
      start_time = Time.now
      until @browser_instance.at_css(selector)
        raise "Timeout waiting for page to load" if Time.now - start_time > timeout
        sleep 0.5
      end
      until @browser_instance.css('script[type="application/ld+json"]')
        raise "Timeout waiting for json-ld to load" if Time.now - start_time > timeout
        sleep 0.5
      end
      data = @browser_instance.body
      headers = @browser_instance.network.response.headers.transform_keys(&:downcase)
      content_type = headers["content-type"]
      charset = data[/<meta.*?charset=["']?([^"'>\s]+)/i, 1] || 'utf-8'
      if charset != 'utf-8'
        data.force_encoding(charset).encode("UTF-8")
      end
      [data, content_type]
    end
  end
end
