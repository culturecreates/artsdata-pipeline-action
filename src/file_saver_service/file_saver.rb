require 'fileutils'

module FileSaverService
  class FileSaver
    def initialize(path:)
      @path = path
    end

    def save(content)
      raise NotImplementedError, "Subclasses must implement the save method"
    end

    def concat
      raise NotImplementedError, "Subclasses must implement the get_file_content method"
    end

    def save_graph_to_file(file_name:, graph:)
      FileUtils.mkdir_p(File.dirname(file_name))

      File.open(file_name, 'w') do |file|
        file.puts(graph.dump(:jsonld))
      end
    end
  end
end