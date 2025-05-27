require 'open-uri'

module PageFetcherService
  class StaticPageFetcher < PageFetcherService::PageFetcher
    def initialize(headers:)
      super(headers: headers)
      @headers = headers
    end

    def fetch_page_data(page_url)
      response = URI.open(page_url, @headers)
      charset = response.charset || 'utf-8'
      data = response.read
      if charset != 'utf-8'
        data = data.force_encoding(charset).encode("UTF-8")
      end
      data
    end
  end
end