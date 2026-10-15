module GraphFetcherService
  class GraphFetcher
    def initialize(page_fetcher:, sparql:, html_extract_config:, private_key_content: nil)
      @page_fetcher = page_fetcher
      @sparql = sparql
      @html_extract_config = html_extract_config
      @private_key_content = private_key_content
    end

    def load_with_retry(entity_urls:)
      raise NotImplementedError, "Subclasses must implement the save method"
    end
  end
end