require 'linkeddata'

module GraphFetcherService
  class LinkedDataGraphFetcher < GraphFetcherService::GraphFetcher
    def initialize(page_fetcher:, sparql:, html_extract_config:, private_key_content: nil)
      super(page_fetcher: page_fetcher, sparql: sparql, html_extract_config: html_extract_config,
            private_key_content: private_key_content)
      # Linked pages (see `from_property`) are often shared by many entities,
      # so fetch each one once per run. Failed fetches are cached as nil.
      @linked_page_cache = {}
      @robots_txt_by_host = {}
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
        if (!@html_extract_config.nil?)
          entity_type = @html_extract_config['entity_type']
          entity_uri, entity_count = get_uri_by_type(loaded_graph, entity_type)
          if entity_count == 0
            # No entity of the configured type was found in the page's RDFa
            # (these pages have no structured markup). Mint one from the page
            # URL, appending the entity type ID as a fragment so the minted URI
            # is distinct from the webpage URL (e.g. .../webpage#Person).
            entity_type_id = entity_type.to_s.split(/[#\/]/).last
            entity_uri = RDF::URI("#{entity_url}##{entity_type_id}")
            loaded_graph << [entity_uri, RDF.type, RDF::URI(entity_type)]
            extract_logic = @html_extract_config['extract']
            loaded_graph << extract_with_xpath(entity_uri, data, extract_logic)
          elsif !entity_uri.nil?
            extract_logic = @html_extract_config['extract']
            loaded_graph << extract_with_xpath(entity_uri, data, extract_logic)
            loaded_graph << extract_from_linked_pages(entity_uri, entity_url, loaded_graph, extract_logic)
          else
            notification_instance = NotificationService::WebhookNotification.instance
            puts "Warning: Multiple entities of type #{entity_type} found from #{entity_url}, cannot add html data."
            notification_instance.send_notification(
              stage: 'adding_html_data',
              message: "Multiple entities of type #{entity_type} found."
            )
          end
        end
        # Normalize any double-encoded HTML entities (e.g. obfuscated mailto emails)
        # before anything downstream — SPARQL transforms, merging, skolemization — sees them.
        loaded_graph = Helper.normalize_literals(loaded_graph)

        if !loaded_graph.empty?
          puts "Performing SPARQL transformations on loaded graph from #{entity_url}."
          loaded_graph = Helper.transform_event_graph(loaded_graph, entity_url, entity_urls[0].split('/')[0..2].join('/'))
        else
          puts "No RDF data found at #{entity_url}, skipping SPARQL transformations."
        end

        graph = Helper.merge_graph(graph, loaded_graph)
      end
      if !graph.empty?
        graph = @sparql.perform_sparql_transformation(graph, "fix_entity_type_capital.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_address_country_name.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_malformed_urls.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_wikidata_uri.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "fix_isni.sparql")
        graph = @sparql.perform_sparql_transformation(graph, "collapse_duplicate_contact_pointblanknodes.sparql")
        
        # Skolemize blank nodes before returning
        base_url = entity_urls[0].split('/')[0..2].join('/')
        graph = Helper.skolemize_blank_nodes(graph, base_url)
      else
        puts "No RDF data found in any of the provided URLs, skipping final SPARQL transformations."
      end
      
      graph
    end

    def get_uri_by_type(graph, type)
      entities = graph.query([nil, RDF.type, RDF::URI(type)]).map(&:subject).uniq
      # Returns [uri, count]. uri is nil unless exactly one entity is present.
      return [nil, 0] if entities.empty?
      return [nil, entities.size] if entities.size > 1
      [entities.first, 1]
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
        # Entries with `from_property` read a linked page, not this one.
        next if config['from_property']
        xpath_expr, css_expr, transform = config.values_at('xpath', 'css', 'transform')
        is_uri = config['uri'].to_s.casecmp?('true')
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

    # Runs the `from_property` entries of extract_logic: each one takes a URL
    # from that property of the entity, fetches the page and extracts from it.
    def extract_from_linked_pages(uri, entity_url, entity_graph, extract_logic)
      graph = RDF::Graph.new
      linked = extract_logic.select { |_, config| config['from_property'] }
      linked.group_by { |_, config| config['from_property'] }.each do |property, entries|
        linked_url = linked_page_url(uri, entity_url, entity_graph, property)
        next if linked_url.nil?

        linked_data = fetch_linked_page(linked_url)
        next if linked_data.nil?

        logic = entries.to_h { |predicate, config| [predicate, config.reject { |k, _| k == 'from_property' }] }
        graph << extract_with_xpath(uri, linked_data, logic)
      end
      graph
    end

    private

    # First value of `property` on the entity that is an http(s) URL other than
    # the crawled page itself. Relative values are resolved against entity_url.
    def linked_page_url(uri, entity_url, entity_graph, property)
      predicates = [property, property.sub(%r{\Ahttps?://}) { |m| m == 'http://' ? 'https://' : 'http://' }].uniq
      values = predicates.flat_map { |p| entity_graph.query([uri, RDF::URI(p), nil]).map(&:object) }
      values.each do |value|
        begin
          url = URI.join(entity_url, value.to_s.strip).to_s
        rescue URI::Error
          next
        end
        next unless url.start_with?('http://', 'https://')
        next if same_page?(url, entity_url)
        return url
      end
      nil
    end

    private

    def same_page?(url_a, url_b)
      normalize = ->(u) { u.sub(/#.*\z/, '').sub(%r{/\z}, '') }
      normalize.call(url_a) == normalize.call(url_b)
    end

    private

    def fetch_linked_page(url)
      return @linked_page_cache[url] if @linked_page_cache.key?(url)

      @linked_page_cache[url] =
        if linked_page_allowed?(url)
          puts "Fetching linked page #{url}"
          @page_fetcher.fetcher_with_retry(page_url: url.gsub(' ', '+')).first
        else
          puts "Skipping linked page disallowed by robots.txt: #{url}"
          nil
        end
    end

    private

    def linked_page_allowed?(url)
      parsed = URI.parse(url)
      origin = "#{parsed.scheme}://#{parsed.authority}"
      @robots_txt_by_host[origin] ||= Helper.get_robots_txt_content(base_url: origin, private_key_content: @private_key_content)
      @robots_txt_by_host[origin].allowed?(Helper.get_user_agent, parsed.request_uri)
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