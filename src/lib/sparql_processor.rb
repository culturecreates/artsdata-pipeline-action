require 'sparql'

class SparqlProcessor

  def initialize(sparql_paths, placeholder_value)
    @sparql_paths = sparql_paths
    @placeholder_value = placeholder_value
  end

  # Main method to perform SPARQL transformations on the graph
  # Parameters:
  # - graph: an RDF::Graph object
  # Outputs: RDF::Graph
  def perform_sparql_transformations(graph, placeholder)
    @sparql_paths.each do |sparql_path|
      puts "Executing #{sparql_path}"
      file = File.read(sparql_path).gsub(placeholder, @placeholder_value)
      graph.query(SPARQL.parse(file, update: true))
    end
    graph
  end
end

