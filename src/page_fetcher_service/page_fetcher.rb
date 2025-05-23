module PageFetcherService
  class PageFetcher
    def initialize(headers:)
      @headers = headers
    end

    def fetcher_with_retry(page_url:)
      retry_count = 0
      max_retries = 3
      begin
        data = fetch_page_data(page_url)
      rescue StandardError => e
      retry_count += 1
        if retry_count < max_retries
          retry
        else
          puts "Max retries reached. Unable to fetch the content for page #{page_url}."
          puts "#{e.message}, consider passing a custom user agent instead of #{@headers['User-Agent']}"
          exit(1)
        end
      end
      data
    end

    private 
    def fetch_page_data(page_url)
      raise NotImplementedError, 'Subclasses must implement fetch_page_data'
    end
  end
end