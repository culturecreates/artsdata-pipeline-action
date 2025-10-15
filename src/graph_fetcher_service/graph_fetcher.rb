module GraphFetcherService
  class GraphFetcher
    def initialize(headers:, page_fetcher:, sparql:, xpath_config:)
      @headers = headers
      @page_fetcher = page_fetcher
      @sparql = sparql
      @xpath_config = xpath_config
    end

    def load_with_retry(entity_urls:)
      raise NotImplementedError, "Subclasses must implement the save method"
    end

    def fetch_types(graph:)
      graph.query([nil, RDF.type, nil]).map(&:object).uniq
    end
  end
end