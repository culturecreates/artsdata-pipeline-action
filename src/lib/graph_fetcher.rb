require_relative 'headless_browser'
require_relative 'rdf_processor'
require_relative 'sparql_processor'

# Fetch the data at each entity url to build the graph
# Parameters:
# - entity_urls: an array of entity URLs
class GraphFetcher
  def self.load(entity_urls: [], base_url: nil, headers: nil, headless: false)
    @entity_urls = entity_urls
    @base_url = base_url
    @headers = headers ||= {"User-Agent" => "artsdata-crawler"}
    @graph = if headless == "true"
              headless_browser = HeadlessBrowser.new(headers)
              headless_browser.fetch_json_ld_objects(entity_urls)
            else
              RDFProcessor.process_rdf(entity_urls, base_url, headers)
            end

    sparql_paths = [
      "./sparql/remove_objects.sparql",
      "./sparql/replace_blank_nodes.sparql",
      "./sparql/fix_entity_type_capital.sparql",
      "./sparql/fix_date_timezone.sparql",
      "./sparql/fix_address_country_name.sparql",
      "./sparql/fix_malformed_urls.sparql",
      "./sparql/fix_schemaorg_https_objects.sparql",
      "./sparql/fix_wikidata_uri.sparql",
      "./sparql/fix_isni.sparql",
      "./sparql/create_eventseries.sparql",
      "./sparql/copy_subevent_data_to_eventseries.sparql",
      "./sparql/collapse_duplicate_contact_pointblanknodes.sparql"
    ]

    base_url = entity_urls[0].split('/')[0..2].join('/')
    sparql_processor = SparqlProcessor.new(sparql_paths, base_url)
    @graph = sparql_processor.perform_sparql_transformations(@graph)
    @graph
  end
end
