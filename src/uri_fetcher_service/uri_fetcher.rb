module UriFetcherService
  class UriFetcher
    def initialize(base_url:)
      @base_url = base_url
    end

    def fetch_entity_urls(page_data:, page_type:, entity_identifier:)
      entity_urls = []
      begin
        identifier_type = detect_identifier_type(entity_identifier)
        case identifier_type
        when :css
          entities_data = page_data.css(entity_identifier)
        when :xpath
          entities_data = page_data.xpath(entity_identifier)
        end
        entities_data.each do |entity|
          if(page_type == :xml)
            url = entity.child.to_s
          else
            href = entity['href']
            url = (href.start_with?('http') ? href : @base_url + (href.start_with?('/') ? href : "/#{href}"))
          end
          entity_urls << url
        end
      rescue StandardError => e
        puts "Error fetching entity URLs: #{e.message}"
      end
      entity_urls
    end

    def detect_identifier_type(identifier)
      identifier = identifier.to_s.strip
      return :xpath if identifier.start_with?('/')
      :css
    end
  end
end