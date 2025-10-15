require 'linkeddata'

module GraphFetcherService
  class LinkedDataGraphFetcher < GraphFetcherService::GraphFetcher
    def initialize(headers:, page_fetcher:, sparql:, xpath_config:)
      super(headers: headers, page_fetcher: page_fetcher, sparql: sparql, xpath_config: xpath_config)
    end

    def load_with_retry(entity_urls:)
      graph = RDF::Graph.new
      entity_urls.each_with_index do |entity_url, index|
        puts "Processing URL #{index + 1}/#{entity_urls.length}: #{entity_url}"
        entity_url = entity_url.gsub(' ', '+')
        loaded_graph = RDF::Graph.new
        data,_ = @page_fetcher.fetcher_with_retry(page_url: entity_url)
        begin
          RDF::Reader.for(:rdfa).new(data, base_uri: entity_url, logger: false) do |reader|
            loaded_graph << reader
          end
        rescue StandardError => e
          puts "Error loading RDFa data from #{entity_url}: #{e.message}"
        end
        if(!@xpath_config.nil?)
          entity_type = @xpath_config['entity_type']
          entity_uri = get_uri_by_type(loaded_graph, entity_type)
          if !entity_uri.nil?
            extract_logic = @xpath_config['extract']
            loaded_graph << extract_with_xpath(entity_uri, data, extract_logic)
          else
            notification_instance = NotificationService::WebhookNotification.instance
            puts "Warning: Multiple/No entities of type #{entity_type} found from #{entity_url}, cannot add xpath data."
            notification_instance.send_notification(
              stage: 'adding_xpath_data',
              message: "Multiple entities of type #{entity_type} found."
            )
          end
        end
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_derived_from.sparql', 'subject_url', entity_url)
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_language.sparql', 'subject_url', entity_url)
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "remove_objects.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "replace_blank_nodes.sparql", "domain_name", entity_urls[0].split('/')[0..2].join('/'))
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_timezone.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_schemaorg_https_objects.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_attendance_mode.sparql")
        loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_missing_seconds.sparql")

        graph << loaded_graph
      end
      graph = @sparql.perform_sparql_transformation(graph, "fix_entity_type_capital.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_address_country_name.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_malformed_urls.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_wikidata_uri.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "fix_isni.sparql")
      graph = @sparql.perform_sparql_transformation(graph, "collapse_duplicate_contact_pointblanknodes.sparql")
    end

  def get_uri_by_type(graph, type)
    entities = graph.query([nil, RDF.type, RDF::URI(type)]).map(&:subject).uniq
    if entities.size != 1
      return nil
    end
    entities.first
  end


    private
    def extract_with_xpath(uri, data, extract_logic)
      graph = RDF::Graph.new
      doc = Nokogiri::HTML(data)


      extract_logic.each do |predicate, config|
        xpath_expr = config['xpath']
        value_expr = config['value']
        is_array = config['array'].to_s.downcase == 'true'

        nodes = doc.xpath(xpath_expr)
        next if nodes.empty?

        extracted_values = nodes.map do |node|
          case value_expr
          when 'normalize-space(.)'
            node.text.strip
          when '@href'
            node['href']  # get the href attribute
          when '@src'
            node['src']   # get the src attribute
          else
            node.text.strip  # fallback
          end
        end

        if is_array
          extracted_values.each do |value|
            graph << [uri, RDF::URI(predicate), RDF::Literal.new(value)]
          end
        else
          value = extracted_values.first
          graph << [uri, RDF::URI(predicate), RDF::Literal.new(value)] if value
        end
      end
      graph
    end
  end
end