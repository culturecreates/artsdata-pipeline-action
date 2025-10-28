module GraphFetcherService
  class GraphFetcher
    def initialize(headers:, page_fetcher:, sparql:, html_extract_config:)
      @headers = headers
      @page_fetcher = page_fetcher
      @sparql = sparql
      @html_extract_config = html_extract_config
    end

    def load_with_retry(entity_urls:)
      raise NotImplementedError, "Subclasses must implement the save method"
    end
  end
end