require 'linkeddata'

module GraphFetcherService
  class GraphFetcher
    def initialize(headers:, page_fetcher:, sparql:)
      @headers = headers
      @page_fetcher = page_fetcher
      @sparql = sparql
    end

    def load_with_retry(entity_urls:)
      graph = RDF::Graph.new
      entity_urls.each_with_index do |entity_url, index|
        puts "Processing URL #{index + 1}/#{entity_urls.length}: #{entity_url}"
        entity_url = entity_url.gsub(' ', '+')
        loaded_graph = RDF::Graph.new
        data = @page_fetcher.fetcher_with_retry(page_url: entity_url)
        begin
          RDF::Reader.for(:rdfa).new(data, base_uri: entity_url) do |reader|
            loaded_graph << reader
          end
        rescue StandardError => e
          puts "Error loading RDFa data from #{entity_url}: #{e.message}"
        end
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_derived_from.sparql', 'subject_url', entity_url)
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_language.sparql', 'subject_url', entity_url)
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "remove_objects.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "replace_blank_nodes.sparql", "domain_name", entity_urls[0].split('/')[0..2].join('/'))
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_timezone.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_schemaorg_https_objects.sparql")

        graph << loaded_graph
      end
      graph = @sparql.perform_sparql_transformation(graph, "fix_entity_type_capital.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_address_country_name.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_malformed_urls.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_wikidata_uri.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_isni.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "collapse_duplicate_contact_pointblanknodes.sparql")
    end
  end
end