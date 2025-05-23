module UriFetcherService
  class UriFetcher
    def initialize(base_url:)
      @base_url = base_url
    end

    def fetch_entity_urls(page_data:, page_type:, entity_identifier:)
      entity_urls = []
      begin
        entities_data = page_data.css(entity_identifier)
        entities_data.each do |entity|
          if(page_type == 'xml')
            href = entity.child.to_s
          else
            href = entity["href"]
          end
          url = (href.start_with?('http') ? href : @base_url + (href.start_with?('/') ? href : "/#{href}"))
          entity_urls << url
        end
      rescue StandardError => e
        puts "Error fetching entity URLs: #{e.message}"
      end
      entity_urls
    end
  end
end