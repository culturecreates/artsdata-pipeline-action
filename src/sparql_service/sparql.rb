module SparqlService
  class Sparql
    def initialize(sparql_directory)
      @sparql_directory = sparql_directory
    end

    def perform_sparql_transformation(graph, file_name, placeholder = "", placeholder_value = "")
      puts "Performing SPARQL transformation with file: #{file_name}"
      file = File.read(@sparql_directory + file_name).gsub(placeholder, placeholder_value)
      begin
        graph.query(SPARQL.parse(file, update: true))
      rescue StandardError => e
        puts "Error performing SPARQL transformation: #{e.message}"
      end
      graph
    end
  end
end