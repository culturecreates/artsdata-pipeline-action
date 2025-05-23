module SparqlService
  class Sparql
    def initialize(sparql_directory)
      @sparql_directory = sparql_directory
    end

    def perform_sparql_transformation(graph, file_name, placeholder = "", placeholder_value = "")
      puts "Performing SPARQL transformation with file: #{file_name}"
      file = File.read(@sparql_directory + file_name).gsub(placeholder, placeholder_value)
      graph.query(SPARQL.parse(file, update: true))
      graph
    end
  end
end