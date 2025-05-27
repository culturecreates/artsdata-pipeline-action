require_relative '../browser_service/browser'

module PageFetcherService
  class HeadlessPageFetcher < PageFetcherService::PageFetcher
    def initialize(headers:, browser:)
      super(headers: headers)
      @headers = headers
      @browser = browser
      @browser_instance = @browser.create_browser()
      @browser_instance.headers.set(@headers) if @headers
    end

    def fetch_page_data(page_url)
      selector = 'body'
      timeout = 10 
      @browser_instance.go_to(page_url)
      start_time = Time.now
      until @browser_instance.at_css(selector)
        raise "Timeout waiting for page to load" if Time.now - start_time > timeout
        sleep 0.5
      end
      html = @browser_instance.body

      charset = html[/<meta.*?charset=["']?([^"'>\s]+)/i, 1] || 'utf-8'
      if charset != 'utf-8'
        html.force_encoding(charset).encode("UTF-8")
      end
      html
    end
  end
end