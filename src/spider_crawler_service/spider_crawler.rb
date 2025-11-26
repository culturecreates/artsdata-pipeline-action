require_relative '../config/spider_config'
module SpiderCrawlerService
  class SpiderCrawler
    def initialize(url:, page_fetcher:, sparql:, robots_txt_content:)
      @url = url
      @page_fetcher = page_fetcher
      @sparql = sparql
      @robots_txt_content = robots_txt_content
      @graph = RDF::Graph.new
      @base_url = URI.parse(url[0]).scheme + "://" + URI.parse(url[0]).host
      @atleast_one_page_loaded = false
      @visited = Set.new
      @max_depth = Config::SPIDER_CRAWLER[:default_max_depth]
    end

    public
    def get_visited_count()
      @visited.size
    end

    public
    def crawl()    
      starting_score = Config::SPIDER_CRAWLER[:starting_url_initial_score]  
      sitemaps = @robots_txt_content.sitemaps
      if sitemaps.empty?
        sitemaps = [@base_url + '/sitemap.xml']
      end
      queue = sitemaps.map { |sitemap_url| [sitemap_url, starting_score, 0] }
      puts "Starting crawl with sitemaps: #{sitemaps.join(', ')}"
      crawl_queue(queue: queue, sitemap: true)
      puts "Continuing crawl with starting URLs."
      queue = @url.map { |u| [u, starting_score, 0] }
      crawl_queue(queue: queue)
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
      shrink_graph()
    end

    private
    def shrink_graph()
      event_count = @sparql.query_graph(@graph, "event_count.sparql").first[:count].to_i
      max_event_count = Config::SPIDER_CRAWLER[:max_event_count]
      if event_count > max_event_count
        puts "Limiting events from #{event_count} to #{max_event_count} based on start date."
        limit_events_by_date(max_event_count)
      end

      organization_count = @sparql.query_graph(@graph, "organization_count.sparql").first[:count].to_i
      max_organization_count = Config::SPIDER_CRAWLER[:max_organization_count]
      if organization_count > max_organization_count
        puts "Limiting organizations from #{organization_count} to #{max_organization_count}"
        limit_entities_by_count(
          max_organization_count, 
          [
            RDF::Vocab::SCHEMA.Organization, 
            RDF::Vocab::SCHEMA.LocalBusiness
          ]
        )
      end

      place_count = @sparql.query_graph(@graph, "place_count.sparql").first[:count].to_i
      max_place_count = Config::SPIDER_CRAWLER[:max_place_count]
      if place_count > max_place_count
        puts "Limiting places from #{place_count} to #{max_place_count}"
        limit_entities_by_count(
          max_place_count, 
          [
            RDF::Vocab::SCHEMA.Place, 
            RDF::Vocab::SCHEMA.PerformingArtsTheater, 
            RDF::Vocab::SCHEMA.MusicVenue, 
            RDF::Vocab::SCHEMA.CivicStructure, 
            RDF::Vocab::SCHEMA.MovieTheater
          ]
        )
      end

      person_count = @sparql.query_graph(@graph, "person_count.sparql").first[:count].to_i
      max_person_count = Config::SPIDER_CRAWLER[:max_person_count]
      if person_count > max_person_count
        puts "Limiting people from #{person_count} to #{max_person_count}"
        limit_entities_by_count(
          max_person_count, 
          [
            RDF::Vocab::SCHEMA.Person
          ]
        )
      end
    end

    private
    def crawl_queue(queue:, sitemap: false)
      user_agent = @page_fetcher.get_user_agent
      until queue.empty? || @visited.size >= Config::SPIDER_CRAWLER[:max_pages_to_crawl] do
        queue.sort_by! { |_, score, _| -score }

        link, score, depth = queue.shift
        if !@robots_txt_content.allowed?(user_agent, link.sub(@base_url, ''))
          puts "Skipping disallowed link by robots.txt: #{link}"
          next
        end
        next if @visited.include?(link)
        next if depth > @max_depth

        puts "Crawling link: #{link} (score: #{score}, depth: #{depth})"
        puts "Queue size: #{queue.length}, Visited size: #{@visited.length}"
        @visited.add(link)

        page_data, content_type = @page_fetcher.fetcher_with_retry(page_url: link)
        if !page_data.nil?
          @atleast_one_page_loaded = true
        end
        page_type = Helper.get_page_type(content_type)
        nokogiri_doc = Nokogiri::HTML(page_data)
        if page_type == :unknown
          puts "Skipping non-HTML/XML content at #{link} (content type: #{content_type})"
        end

        new_links = fetch_links(nokogiri_doc: nokogiri_doc, page_type: page_type)
        loaded_graph = fetch_graph(page_url: link, page_data: page_data)
        graph_score = calculate_graph_score(graph: loaded_graph)
        if graph_score == 0 || loaded_graph.empty?
          puts "No relevant RDF data found at #{link}, the graph will not be loaded." 
        else
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_derived_from.sparql', 'subject_url', link)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, 'add_language.sparql', 'subject_url', link)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "remove_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "replace_blank_nodes.sparql", "domain_name", @base_url)
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_timezone.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_schemaorg_https_objects.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_attendance_mode.sparql")
          loaded_graph = @sparql.perform_sparql_transformation(loaded_graph, "fix_date_missing_seconds.sparql")
          @graph << loaded_graph
        end

        new_links.each do |new_link|
          begin
            new_link = URI::DEFAULT_PARSER.escape(new_link)
            new_link_host = URI.parse(new_link).host
            base_url_host = URI.parse(@base_url).host
            if !normalize_host(new_link_host).downcase.eql?(normalize_host(base_url_host).downcase)
              next
            end
          rescue StandardError => e
            puts "Error parsing URL #{new_link}: #{e.message}, skipping."
            next
          end
          next if @visited.include?(new_link) || queue.any? { |q_link, _, _| q_link == new_link }

          new_score = calculate_score(url: new_link, graph_score: graph_score, is_sitemap_url: sitemap)
          if new_score > 1
            queue << [new_link, new_score, depth + 1]
          end
        end
      end
    end

    private
    def normalize_host(host)
      host.sub(/^www\./i, '')
    end

    private
    def limit_entities_by_count(max_limit, classes)
      types = [RDF::Vocab::SCHEMA.Organization, RDF::Vocab::SCHEMA.LocalBusiness]
      entities_to_delete = Set.new
      entities = []
      types.each do |type|
        entities.concat(@graph.query([nil, RDF.type, type]).map { |solution| solution.subject })
      end
      if entities.length > max_limit
        to_delete = entities.drop(max_limit)
        to_delete.each do |org|
          collect_connected_entities(org, entities_to_delete)
          @graph.delete(*@graph.query([nil, nil, org]))
        end
      end
      to_delete = @graph.statements.select { |st| entities_to_delete.include?(st.subject) }
      @graph.delete(*to_delete)
    end

    private
    def limit_events_by_date(max_limit)
      start_date_pred  = RDF::Vocab::SCHEMA.startDate

      event_types = [
        RDF::Vocab::SCHEMA.Event,
        RDF::Vocab::SCHEMA.TheaterEvent,
        RDF::Vocab::SCHEMA.MusicEvent,
        RDF::Vocab::SCHEMA.Festival
      ]

      events_with_dates = event_types.flat_map do |event_type|
        @graph.query([nil, RDF.type, event_type]).map do |solution|
          event = solution.subject
          date_literal = @graph.query([event, start_date_pred, nil]).first&.object
          next nil unless date_literal

          begin
            date = DateTime.parse(date_literal.to_s)
          rescue ArgumentError
            next nil
          end
          { event: event, date: date }
        end
      end.compact

      sorted = events_with_dates.sort_by { |h| h[:date] }.reverse
      events_to_delete = sorted.drop(max_limit).map { |h| h[:event] }
      nodes_to_delete = Set.new
      events_to_delete.each do |event|
        collect_connected_entities(event, nodes_to_delete)
        parents = @graph.query([nil, nil, event]).map { |st| st.subject }
        parents.each do |parent|
          collect_connected_entities(parent, nodes_to_delete)
        end
      end

      to_delete = @graph.statements.select { |st| nodes_to_delete.include?(st.subject) }
      @graph.delete(*to_delete)
    end

    private
    def collect_connected_entities(node, accumulator)
      return if accumulator.include?(node)
      accumulator.add(node)

      @graph.query([node, nil, nil]).each do |st|
        obj = st.object
        if obj.resource?
          collect_connected_entities(obj, accumulator)
        end
      end
    end

    public
    def get_graph()
      @graph
    end

    private
    def calculate_graph_score(graph:)
      event_count  = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Event]).count
      person_count = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Person]).count
      org_count    = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Organization]).count
      place_count  = graph.query([nil, RDF.type, RDF::Vocab::SCHEMA.Place]).count

      3*event_count + 1*person_count + 1*org_count + 2*place_count
    end

    private
    def calculate_score(url:, graph_score:, is_sitemap_url: false)
      exclusion_terms = [
        'mailto', 
        'timestamp'
      ]
      down = url.downcase
      return 0 if (
        exclusion_terms.any? { |term| down.include?(term) } ||
        down.length > Config::SPIDER_CRAWLER[:max_url_length] ||
        down.count('/') > Config::SPIDER_CRAWLER[:max_forward_slashes] ||
        down.count('?') > Config::SPIDER_CRAWLER[:max_query_params]
      )

      scoring_terms = [
        'sitemap',
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
        'designer',
        'entertainment',
        'divertissement'
      ]

      normalized_end = down.gsub(/[\W_]+$/, '')

      url_contains_score = scoring_terms.sum { |term| down.scan(term).length * Config::SPIDER_CRAWLER[:url_contains_score_weight] }

      url_ends_score = scoring_terms.any? { |term| normalized_end.end_with?(term) } ? Config::SPIDER_CRAWLER[:url_ends_score_weight] : 0

      sitemap_bonus = is_sitemap_url ? Config::SPIDER_CRAWLER[:sitemap_bonus_score] : 0

      score =
        1 +
        graph_score +
        url_contains_score +
        url_ends_score +
        sitemap_bonus
      score
    end


    private
    def fetch_links(nokogiri_doc:, page_type:)
      links = []
      identifier = page_type == :xml ? 'loc' : 'a'
      nokogiri_doc.css(identifier).each do |link|
        url = page_type == :xml ? link.content : link['href']
        next if url.nil? || url.empty?
        url.strip!
        full_url = url.start_with?('http') ? url : @base_url + (url.start_with?('/') ? url : "/#{url}")
        links << full_url
      end
      links.uniq
    end

    private
    def fetch_graph(page_url:, page_data:)
      loaded_graph = RDF::Graph.new
        begin
          RDF::Reader.for(:rdfa).new(page_data,base_uri: page_url, logger: false) do |reader|
            loaded_graph << reader
          end
        rescue StandardError => e
          puts "Error loading RDFa data, error: #{e.message}"
        end
      loaded_graph
    end
  end
end