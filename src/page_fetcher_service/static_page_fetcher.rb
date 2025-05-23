require 'open-uri'

module PageFetcherService
  class StaticPageFetcher < PageFetcherService::PageFetcher
    def initialize(headers:)
      super(headers: headers)
      @headers = headers
    end

    def fetch_page_data(page_url)
      response = URI.open(page_url, @headers)
      charset = response.charset || 'UTF-8'
      data = response.read
      data.force_encoding(charset).encode("UTF-8")
    end
  end
end