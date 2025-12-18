module SparqlService
  class Sparql
    def initialize(sparql_directory)
      @sparql_directory = sparql_directory
    end

    def perform_sparql_transformation(graph, file_name, placeholder = "", placeholder_value = "")
      file = File.read(@sparql_directory + file_name).gsub(placeholder, placeholder_value)
      begin
        graph.query(SPARQL.parse(file, update: true))
      rescue StandardError => e
        puts "Error performing SPARQL transformation: #{e.message}"
      end
      graph
    end

    def query_graph(graph, sparql_file)
      file = File.read(@sparql_directory + sparql_file)
      begin
        result = graph.query(SPARQL.parse(file))
      rescue StandardError => e
        puts "Error querying graph: #{e.message}"
        result = nil
      end
      result
    end
  end
end