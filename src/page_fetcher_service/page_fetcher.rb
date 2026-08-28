module PageFetcherService
  class PageFetcher
    def initialize()
    end

    def fetcher_with_retry(page_url:, selector: 'body', accept: nil, expected_content_type: nil)
      retry_count = 0
      max_retries = 3
      data = nil
      content_type = nil
      begin
        fetched_data, fetched_content_type = fetch_page_data(page_url: page_url, selector: selector, accept: accept)
        if expected_content_type && !fetched_content_type&.include?(expected_content_type)
          raise "Unexpected Content-Type '#{fetched_content_type}' for #{page_url} " \
                "(expected to include '#{expected_content_type}') — likely a bot-block, " \
                "WAF challenge, or cache response rather than the real resource"
        end
        data, content_type = fetched_data, fetched_content_type
      rescue StandardError => e
        retry_count += 1
        if retry_count < max_retries
          sleep(2 ** retry_count)
          retry
        else
          notification_message =
            "Max retries reached. Unable to fetch the content for page #{page_url}, " \
            "Error: #{e.message}, " \
            "consider passing a custom user agent instead of #{Helper.get_user_agent()}"          
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
    def fetch_page_data(page_url:, selector:, accept: nil)
      raise NotImplementedError, 'Subclasses must implement fetch_page_data'
    end
  end
end