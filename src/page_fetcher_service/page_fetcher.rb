module PageFetcherService
  class PageFetcher
    def initialize(headers:)
      @headers = headers
    end

    def fetcher_with_retry(page_url:)
      retry_count = 0
      max_retries = 3
      begin
        data, content_type = fetch_page_data(page_url)
      rescue StandardError => e
        retry_count += 1
        if retry_count < max_retries
          sleep(2 ** retry_count)
          retry
        else
          notification_message =
            "Max retries reached. Unable to fetch the content for page #{page_url}, " \
            "Error: #{e.message}, " \
            "consider passing a custom user agent instead of #{@headers['User-Agent']}"          
          NotificationService::WebhookNotification.instance.send_notification(
            stage: 'fetching_page_data',
            message: notification_message
          )
          puts notification_message
        end
      end
      [data, content_type]
    end

    private 
    def fetch_page_data(page_url)
      raise NotImplementedError, 'Subclasses must implement fetch_page_data'
    end
  end
end