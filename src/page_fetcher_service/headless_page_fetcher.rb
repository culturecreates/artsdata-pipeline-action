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
      @browser_instance.go_to(page_url)
      sleep 15
      html = @browser_instance.body

      charset = html[/<meta.*?charset=["']?([^"'>\s]+)/i, 1] || 'UTF-8'
      if charset != 'UTF-8'
        html.force_encoding(charset).encode("UTF-8")
      end
      html
    end
  end
end