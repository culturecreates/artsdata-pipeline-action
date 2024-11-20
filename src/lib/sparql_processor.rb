require 'sparql'

class SparqlProcessor

  def initialize(sparql_paths, base_url)
    @sparql_paths = sparql_paths
    @base_url = base_url
  end

  # Main method to perform SPARQL transformations on the graph
  # Parameters:
  # - graph: an RDF::Graph object
  # Outputs: RDF::Graph
  def perform_sparql_transformations(graph)
    @sparql_paths.each do |sparql_path|
      puts "Executing #{sparql_path}"
      file = File.read(sparql_path).gsub("domain_name", @base_url)
      graph.query(SPARQL.parse(file, update: true))
    end
    graph
  end
end

