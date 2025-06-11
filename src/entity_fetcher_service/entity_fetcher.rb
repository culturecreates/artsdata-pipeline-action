require 'nokogiri'

module EntityFetcherService
  class EntityFetcher
    def initialize(page_fetcher:, uri_fetcher:)
      @page_fetcher = page_fetcher
      @uri_fetcher = uri_fetcher
    end

    def fetch_entity_urls(page_url:, entity_identifier:, is_paginated:, offset:)
      entity_urls = []
  
      offset = get_offset(offset)
      identifier_mapping = create_url_identifier_mapping(page_url, entity_identifier)
  
      identifier_mapping.each do |page, identifier|
        page_number = get_page_number(is_paginated)
        loop do
          url = "#{page}#{page_number}"
          puts "Fetching entity urls from #{url}..."
          page_data, _ = @page_fetcher.fetcher_with_retry(page_url: url)
          page_type = get_page_type(url)
          main_doc = Nokogiri::HTML(page_data)
          number_of_entities = entity_urls.length
          entity_urls.concat(@uri_fetcher.fetch_entity_urls(page_data: main_doc, page_type: page_type, entity_identifier: identifier))
          entity_urls = entity_urls.uniq
          if entity_urls.length == number_of_entities || page_number.nil?
            puts "Fetched all entity URLs from #{url}."
            break
          end
          page_number += offset
        end
      end
      if entity_urls.empty?
        puts "No entity URLs found. Check your identifier. Exiting..."
        exit(1)
      end
      puts "All entity URLs have been successfully fetched. Total entities: #{entity_urls.length}."
      entity_urls
    end

    private
    def get_offset(offset)
      offset ? offset.to_i : 1
    end

    private
    def create_url_identifier_mapping(page_url, entity_identifier)
      raise ArgumentError, "page_url must be an array" unless page_url.is_a?(Array)
    
      mapping = {}
      page_url.each { |url| mapping[url] = entity_identifier }
    
      mapping
    end

    private
    def get_page_type(page_url)
      if page_url.end_with?('.xml')
        :xml
      else
        :html
      end
    end

    private
    def get_page_number(is_paginated)
      case is_paginated
      when false
        nil
      when true
        1
      else
        is_paginated.to_i
      end
    end
  end
end