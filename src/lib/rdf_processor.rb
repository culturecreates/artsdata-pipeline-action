require 'linkeddata'
require 'sparql'

module RDFProcessor
  def self.process_rdf(entity_urls, base_url, headers)
    graph = RDF::Graph.new
    add_url_sparql_file = File.read('./sparql/add_derived_from.sparql')
    puts("URL processing mode: Non-headless")
    entity_urls.each do |entity_url|
      begin
        puts "Processing #{entity_url}"
        entity_url = entity_url.gsub(' ', '+')
        options = { headers: headers }
        loaded_graph = RDF::Graph.load(entity_url, **options)
        sparql_file_with_url = add_url_sparql_file.gsub("subject_url", entity_url)
        loaded_graph.query(SPARQL.parse(sparql_file_with_url, update: true))
        graph << loaded_graph
      rescue StandardError => e
        puts "Error loading RDF from #{entity_url}: #{e.message}"
      end
    end
    graph
  end
end