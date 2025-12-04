require 'linkeddata'

module GraphFetcherService
  class LinkedDataGraphFetcher < GraphFetcherService::GraphFetcher
    def initialize(headers:, page_fetcher:, sparql:, html_extract_config:)
      super(headers: headers, page_fetcher: page_fetcher, sparql: sparql, html_extract_config: html_extract_config)
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
        if(!@html_extract_config.nil?)
          entity_type = @html_extract_config['entity_type']
          entity_uri = get_uri_by_type(loaded_graph, entity_type)
          if !entity_uri.nil?
            extract_logic = @html_extract_config['extract']
            loaded_graph << extract_with_xpath(entity_uri, data, extract_logic)
          else
            notification_instance = NotificationService::WebhookNotification.instance
            puts "Warning: Multiple/No entities of type #{entity_type} found from #{entity_url}, cannot add html data."
            notification_instance.send_notification(
              stage: 'adding_html_data',
              message: "Multiple entities of type #{entity_type} found."
            )
          end
        end
        if !loaded_graph.empty?
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_derived_from.sparql', 'subject_url', entity_url)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_language.sparql', 'subject_url', entity_url)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "remove_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "replace_blank_nodes.sparql", "domain_name", entity_urls[0].split('/')[0..2].join('/'))
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_timezone.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_schemaorg_https_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_attendance_mode.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_missing_seconds.sparql") 
        else
          puts "No RDF data found at #{entity_url}, skipping SPARQL transformations." 
        end

        graph = Helper.merge_graph(@graph, loaded_graph)
      end
      if !graph.empty?
        graph = @sparql.perform_sparql_transformation(graph, "fix_entity_type_capital.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_address_country_name.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_malformed_urls.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_wikidata_uri.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_isni.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "collapse_duplicate_contact_pointblanknodes.sparql")
      else
        puts "No RDF data found in any of the provided URLs, skipping final SPARQL transformations."
      end
    end

    def get_uri_by_type(graph, type)
      entities = graph.query([nil, RDF.type, RDF::URI(type)]).map(&:subject).uniq
      if entities.size != 1
        return nil
      end
      entities.first
    end

    private
    def transform_value(transform, value)
      func = transform['function']
      args = transform['args'] || {}
      if self.class.private_method_defined?(func.to_sym)
        value = self.send(func.to_sym, value, *args)
      else
        puts "Warning: Transform function #{func} not defined."
      end
      value
    end

    private
    def split(string, delimiter)
      return string if delimiter.nil? || delimiter.empty?
      string.split(delimiter).map(&:strip)
    end

    private
    def extract_with_xpath(uri, data, extract_logic)
      graph = RDF::Graph.new
      doc = Nokogiri::HTML(data)

      extract_logic.each do |predicate, config|
        xpath_expr, css_expr, transform = config.values_at('xpath', 'css', 'transform')
        is_uri   = config['uri'].to_s.casecmp?('true')
        is_array = config['array'].to_s.casecmp?('true')

        xpath_expr ||= Nokogiri::CSS.xpath_for(css_expr)&.first
        next unless xpath_expr

        begin
        nodes = doc.xpath(xpath_expr)
        rescue => e
          puts "Error extracting for predicate '#{predicate}' with XPath '#{xpath_expr}': #{e.message}"
          next
        end
        next if nodes.empty?

        extracted_values = extract_values(nodes, is_array)

        extracted_values.map! { |val| transform_value(transform, val) } if transform

        rdf_class = is_uri ? RDF::URI : RDF::Literal
        extracted_values.flatten.each do |val|
          graph << [uri, RDF::URI(predicate), rdf_class.new(val)]
        end
      end

      graph
    end

    private
    def extract_values(nodes, is_array)
      case nodes
      when Nokogiri::XML::NodeSet
        is_array ? nodes.map { |n| n.text.strip }.compact : [nodes.first.text.strip]
      when String
        [nodes.strip]
      else
        []
      end
    end
  end
end