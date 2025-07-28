require 'open-uri'

module PageFetcherService
  class StaticPageFetcher < PageFetcherService::PageFetcher
    def initialize(headers:)
      super(headers: headers)
      @headers = headers
    end

    def fetch_page_data(page_url)
      begin
        response = URI.open(page_url, @headers)
        content_type = response.content_type
        charset = response.charset || 'utf-8'
        data = response.read
        if charset != 'utf-8'
          data = data.force_encoding(charset).encode("UTF-8")
        end
        [data, content_type]
      rescue StandardError => e
        puts "Error fetching page data from #{page_url}: #{e.message}"
        [nil, nil]
      end
    end
  end
end