require 'open-uri'

module PageFetcherService
  class StaticPageFetcher < PageFetcherService::PageFetcher
    def initialize(headers:)
      super(headers: headers)
      @headers = headers
    end

    def fetch_page_data(page_url)
      response = URI.open(page_url, @headers)
      content_type = response.content_type
      charset = response.charset || 'utf-8'
      data = response.read
      if charset != 'utf-8'
        data = data.force_encoding(charset).encode("UTF-8")
      end
      [data, content_type]
    end
  end
end