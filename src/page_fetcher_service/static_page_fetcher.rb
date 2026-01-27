require 'open-uri'

module PageFetcherService
  class StaticPageFetcher < PageFetcherService::PageFetcher
    def initialize(private_key_content: nil)      
      @private_key_content = private_key_content
    end

    def fetch_page_data(page_url:, selector:)
      authority = URI.parse(page_url).authority
      headers = Helper.get_headers(authority, @private_key_content)
      response = URI.open(page_url, headers)
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