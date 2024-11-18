require 'nokogiri'
require 'open-uri'

module EntityFetcher
  def self.fetch_entity_urls(page_url, entity_identifier, is_paginated, fetch_entity_urls_headlessly, headers, offset)
    base_url = page_url.split('/')[0..2].join('/')
    entity_urls = []

    if is_paginated == 'false'
      page_number = nil
    elsif is_paginated == 'true'
      page_number = 1
    else
      page_number = is_paginated.to_i
    end

    if offset
      offset = offset.to_i
    else
      offset = 1
    end

    loop do
      url = "#{page_url}#{page_number}"
      puts "Fetching entity urls from #{url}..."
      if fetch_entity_urls_headlessly == 'true'
        puts "Entity url fetch mode - Headless"
        main_doc = Nokogiri::HTML(HeadlessBrowser.fetch_entity_urls_headless(url, headers))
      else
        puts "Entity url fetch mode - Headful"
        main_doc = Nokogiri::HTML(self.fetch_entity_urls_headful(url, headers))
      end
      entities_data = main_doc.css(entity_identifier)
      number_of_entities = entity_urls.length
      entities_data.each do |entity|
        href = entity["href"]
        entity_urls << (href.start_with?('http') ? href : base_url + (href.start_with?('/') ? href : "/#{href}"))
      end

      break if entity_urls.length == number_of_entities || page_number.nil?

      page_number += offset
    end
    entity_urls.uniq
  end

  def self.fetch_entity_urls_headful(url, headers)
    retry_count = 0
    max_retries = 3
    begin
      main_page_html_text = URI.open(url, headers).read
    rescue StandardError => e
      retry_count += 1
      if retry_count < max_retries
        retry
      else
        puts "Max retries reached. Unable to fetch the content for page #{page_number}."
        puts e.message
      end
    end
    main_page_html_text
  end
end
