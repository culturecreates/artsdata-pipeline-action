module SpiderCrawlerService
  class SpiderCrawler
    def initialize(url:, page_fetcher:, sparql:)
      @url = url
      @page_fetcher = page_fetcher
      @sparql = sparql
      @graph = RDF::Graph.new
      @base_url = URI.parse(url[0]).scheme + "://" + URI.parse(url[0]).host
      @atleast_one_page_loaded = false
    end


    def crawl()
      visited = Set.new
      max_depth = 5
      queue = @url.map { |u| [u, 10, 0] }

      until queue.empty?
        queue.sort_by! { |_, score, _| -score }

        link, score, depth = queue.shift
        next if visited.include?(link)
        next if depth > max_depth

        puts "Crawling link: #{link} (score: #{score}, depth: #{depth})"
        puts "Queue size: #{queue.length}, Visited size: #{visited.length}"
        visited.add(link)

        page_data, content_type = @page_fetcher.fetcher_with_retry(page_url: link)
        if !page_data.nil?
          @atleast_one_page_loaded = true
        end
        if content_type.nil? || (!content_type.include?('html') && !content_type.include?('xml'))
          puts "Skipping non-HTML/XML content at #{link} (content type: #{content_type})"
          next
        end
        nokogiri_doc = Nokogiri::HTML(page_data)

        new_links = fetch_links(nokogiri_doc: nokogiri_doc)
        loaded_graph = fetch_graph(page_data: page_data)
        if !loaded_graph.empty?
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_derived_from.sparql', 'subject_url', link)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_language.sparql', 'subject_url', link)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "remove_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "replace_blank_nodes.sparql", "domain_name", @base_url)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_timezone.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_schemaorg_https_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_attendance_mode.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_missing_seconds.sparql")
        else
          puts "No RDF data found at #{link}, skipping SPARQL transformations." 
        end

        @graph << loaded_graph

        new_links.each do |new_link|
          if !new_link.start_with?@base_url
            next
          end
          next if visited.include?(new_link) || queue.any? { |q_link, _, _| q_link == new_link }

          new_score = calculate_score(new_link, loaded_graph)
          if new_score > 1
            queue << [new_link, new_score, depth + 1]
          end
        end
      end
      if !@atleast_one_page_loaded
        notification_message = 'No pages were loaded. Check your starting URL. Exiting...'
        puts notification_message
        NotificationService::WebhookNotification.instance.send_notification(
          stage: 'spider_crawling',
          message: notification_message
        )
        exit(1)
      end
      if !@graph.empty?
        @graph = @sparql.perform_sparql_transformation(@graph, "fix_entity_type_capital.sparql")
        @graph = @sparql.perform_sparql_transformation(@graph, "fix_address_country_name.sparql")
        @graph = @sparql.perform_sparql_transformation(@graph, "fix_malformed_urls.sparql")
        @graph = @sparql.perform_sparql_transformation(@graph, "fix_wikidata_uri.sparql")
        @graph = @sparql.perform_sparql_transformation(@graph, "fix_isni.sparql")
        @graph = @sparql.perform_sparql_transformation(@graph, "collapse_duplicate_contact_pointblanknodes.sparql")
      else
        puts "No RDF data found in any of the provided URLs, skipping final SPARQL transformations."
      end
    end

    def get_graph()
      @graph
    end


    def calculate_score(url, graph)
      exclusion_terms    = ['mailto']
      down = url.downcase
      return 0 if exclusion_terms.any? { |term| down.include?(term) }
      return 0 if down.length > 200

      event_count  = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).count
      person_count = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Person]).count
      org_count    = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Organization]).count
      place_count  = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Place]).count

      scoring_terms = [
        'calendar',
        'calendrier',
        'event',
        'events',
        'evenement',
        'evenements',
        'spectacle',
        'spectacles',
        'exposition',
        'season',
        'members',
        'performance',
        'performances',
        'programmation',
        'programme',
        'ticket',
        'tickets',
        'billet',
        'billets',
      ]

      normalized_end = down.gsub(/[\W_]+$/, '')

      url_contains_score = scoring_terms.sum { |term| down.scan(term).length * 3 }

      url_ends_score = scoring_terms.any? { |term| normalized_end.end_with?(term) } ? 5 : 0

      score =
        1 +
        (3 * event_count) +
        (1 * person_count) +
        (1 * org_count) +
        (2 * place_count) +
        url_contains_score +
        url_ends_score

      score
    end


    private
    def fetch_links(nokogiri_doc:)
      links = []
      nokogiri_doc.css('a').each do |link|
        href = link['href']
        next if href.nil? || href.empty?
        href.strip!
        full_url = href.start_with?('http') ? href : @base_url + (href.start_with?('/') ? href : "/#{href}")
        links << full_url
      end
      links.uniq
    end

    private
    def fetch_graph(page_data:)
      loaded_graph = RDF::Graph.new
        begin
          RDF::Reader.for(:rdfa).new(page_data, logger: false) do |reader|
            loaded_graph << reader
          end
        rescue StandardError => e
          puts "Error loading RDFa data, error: #{e.message}"
        end
      loaded_graph
    end
  end
end