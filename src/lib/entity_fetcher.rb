require 'nokogiri'
require 'open-uri'
require_relative 'entity_fetcher_helper'


module EntityFetcher
  def self.fetch_entity_urls(page_url:, entity_identifier:, is_paginated:, fetch_entity_urls_headlessly:, headers:, offset:, base_url:)
    entity_urls = []

    offset = EntityFetcherHelper.get_offset(offset)
    identifier_mapping = EntityFetcherHelper.create_url_identifier_mapping(page_url, entity_identifier)

    if fetch_entity_urls_headlessly == 'true'
      puts "Entity url fetch mode - Browser"
      browser = HeadlessBrowser.new(headers)
    else
      puts "Entity url fetch mode - Normal"
    end

    identifier_mapping.each do |page, identifier|
      page_number = EntityFetcherHelper.get_page_number(is_paginated)
      loop do
        url = "#{page}#{page_number}"
        puts "Fetching entity urls from #{url}..."
        page_data = if fetch_entity_urls_headlessly == 'true'
                      browser.fetch_page_data_with_browser(url)
                    else
                      self.fetch_page_data(url, headers)
                    end
        if(page.end_with?('.xml'))
          main_doc = Nokogiri::XML(page_data)
        else
          main_doc = Nokogiri::HTML(page_data)
        end
        entities_data = main_doc.css(identifier)
        number_of_entities = entity_urls.length
        entities_data.each do |entity|
          if(main_doc.xml?)
            href = entity.child.to_s
          else
            href = entity["href"]
          end
          entity_urls << (href.start_with?('http') ? href : base_url + (href.start_with?('/') ? href : "/#{href}"))
        end
        entity_urls = entity_urls.uniq
        if entity_urls.length == number_of_entities || page_number.nil?
          puts "Fetched all entity URLs from #{url}."
          break
        end
        page_number += offset
      end
    end
    puts "All entity URLs have been successfully fetched. Total entities: #{entity_urls.length}."
    entity_urls
  end

  def self.fetch_page_data(url, headers)
    retry_count = 0
    max_retries = 3
    begin
      main_page_html_text = URI.open(url, headers).read
    rescue StandardError => e
      retry_count += 1
      if retry_count < max_retries
        retry
      else
        puts "Max retries reached. Unable to fetch the content for page #{url}."
        puts "#{e.message}, consider passing a custom user agent instead of #{headers['User-Agent']}"
        exit(1)
      end
    end
    main_page_html_text
  end  
end
