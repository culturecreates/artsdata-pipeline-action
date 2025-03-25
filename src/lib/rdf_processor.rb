require 'linkeddata'
require 'sparql'
require_relative 'sparql_processor'

module RDFProcessor
  def self.process_rdf(entity_urls, base_url, headers)
    graph = RDF::Graph.new
    puts("URL processing mode: Non-headless")
    entity_urls.each do |entity_url|
      begin
        puts "Processing #{entity_url}"
        entity_url = entity_url.gsub(' ', '+')
        options = { headers: headers }
        loaded_graph = RDF::Graph.load(entity_url, **options)
        intermediate_sparql_paths = [
          './sparql/add_derived_from.sparql',
          './sparql/add_language.sparql'
        ]
        sparql_processor = SparqlProcessor.new(intermediate_sparql_paths, entity_url)
        loaded_graph = sparql_processor.perform_sparql_transformations(loaded_graph, "subject_url")
        graph << loaded_graph
      rescue StandardError => e
        puts "Error loading RDF from #{entity_url}: #{e.message}"
      end
    end
    graph
  end
end