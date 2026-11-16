require 'nokogiri'
require_relative '../lib/helper'
module UrlFetcherService
  class UrlFetcher
    def initialize(page_url:, base_url:, entity_identifier:, is_paginated:, offset:, page_fetcher:, robots_txt_content:)
      @base_url = base_url
      @identifier_mapping = create_url_identifier_mapping(page_url, entity_identifier)
      @is_paginated = is_paginated
      @offset = get_offset(offset)
      @page_fetcher = page_fetcher
      @robots_txt_content = robots_txt_content
      @urls = []
      @atleast_one_page_loaded = false
      @diagnostics = { matched: 0, without_href: 0, invalid: 0, disallowed: 0, sample_links: [] }
    end


    def fetch_urls()
      @identifier_mapping.each do |page, identifier|
        page_number = get_page_number(@is_paginated)
        loop do
          url = "#{page}#{page_number}"
          puts "Fetching entity urls from #{url}"
          accept = url.end_with?('.xml') ? "text/xml, application/xml, */*" : nil
          expected_content_type = url.end_with?('.xml') ? 'xml' : nil
          page_data, content_type = @page_fetcher.fetcher_with_retry(
            page_url: url, selector: identifier, accept: accept, expected_content_type: expected_content_type
          ) 
          if !page_data.nil?
            @atleast_one_page_loaded = true
          end
          page_type = Helper.get_page_type(content_type)
          puts "Content-Type: #{content_type}, Page type: #{page_type}"
          main_doc =
            case page_type
            when :xml
              Nokogiri::XML(page_data)
            when :html
              Nokogiri::HTML(page_data)
            else
              puts "Skipping non-HTML/XML content at #{url} (content type: #{content_type})"
              nil
            end
          number_of_entities = @urls.length
          @urls.concat(fetch_url_from_page_data(page_data: main_doc, page_type: page_type, entity_identifier: identifier, page_url: url))
          @urls = @urls.uniq
          if @urls.length == number_of_entities || page_number.nil?
            puts "Fetched all entity URLs from #{url}."
            break
          end
          page_number += @offset
        end
      end
      puts "All matching entity URLs have been successfully fetched. Total entities: #{@urls.length}."
      puts "First #{[@urls.length, 10].min} entity URLs: #{@urls.take(10).join(', ')}" unless @urls.empty?
      if !@atleast_one_page_loaded
        notification_message = 'No pages were loaded. Check your page URL. Exiting...'
        puts notification_message
        NotificationService::WebhookNotification.instance.send_notification(
          stage: 'fetching_entity_urls',
          message: notification_message
        )
        exit(1)
      end
      explain_no_entity_urls if @urls.empty?
      @urls
    end

    private
    # Extracts entity URLs from one listing page. Each matched element is
    # handled on its own, so one bad element never drops the others.
    # Relative hrefs are resolved against the listing page URL.
    def fetch_url_from_page_data(page_data:, page_type:, entity_identifier:, page_url: nil)
      return [] if page_data.nil?
      page_urls = []
      begin
        identifier_type = detect_identifier_type(entity_identifier)
        case identifier_type
        when :css
          entities_data = page_data.css(entity_identifier)
        when :xpath
          entities_data = page_data.xpath(entity_identifier)
        end
      rescue StandardError => e
        notification_message = "Error fetching entity URLs: invalid entity-identifier '#{entity_identifier}': #{e.message}"
        NotificationService::WebhookNotification.instance.send_notification(
          stage: 'fetching_entity_urls',
          message: notification_message
        )
        puts notification_message
        return []
      end

      puts "Found #{entities_data.length} elements matching '#{entity_identifier}'"
      @diagnostics[:matched] += entities_data.length
      @diagnostics[:sample_links] = sample_links(page_data) if entities_data.empty? && page_type == :html && @diagnostics[:sample_links].empty?

      entities_data.each do |entity|
        url =
          if page_type == :xml
            entity.content.to_s.strip
          else
            href_for(entity)
          end
        if url.nil? || url.empty?
          @diagnostics[:without_href] += 1
          next
        end
        url = resolve_url(url, page_url)
        if url.nil?
          @diagnostics[:invalid] += 1
          next
        end
        path = URI.parse(url).path
        if !@robots_txt_content.allowed?(Helper.get_user_agent, path)
          puts "Skipping disallowed URL by robots.txt: #{url}"
          @diagnostics[:disallowed] += 1
          next
        end
        page_urls << url
      rescue StandardError => e
        @diagnostics[:invalid] += 1
        puts "Skipping entity element: #{e.message}"
      end
      page_urls
    end

    # The href of the element, or of the first link inside it, so a
    # selector on a container (e.g. "div.card") still works.
    def href_for(entity)
      href = entity['href'].to_s.strip
      return href unless href.empty?

      entity.at_css('a[href]')&.[]('href')&.strip
    end

    def resolve_url(href, page_url)
      return href if href.start_with?('http://', 'https://')

      url = URI.join(page_url || @base_url, href).to_s
      url.start_with?('http://', 'https://') ? url : nil # e.g. mailto:, javascript:
    rescue URI::Error
      nil
    end

    def sample_links(doc)
      doc.css('a[href]').map { |a| a['href'].to_s.strip }.reject { |h| h.empty? || h.start_with?('#') }.uniq.first(15)
    end

    # Says why no entity URLs were found, before main.rb exits with
    # "No entity URLs found".
    def explain_no_entity_urls
      d = @diagnostics
      reason =
        if d[:matched].zero?
          'the entity-identifier matched 0 elements on the page(s). The site markup may have changed, ' \
          'or the listing is rendered with JavaScript (try fetch-urls-headlessly: true)'
        elsif d[:disallowed].positive? && d[:without_href].zero? && d[:invalid].zero?
          "all #{d[:matched]} matched URLs are disallowed by robots.txt"
        elsif d[:without_href] == d[:matched]
          "the #{d[:matched]} matched elements have no href and contain no link. Select the <a> elements"
        else
          "#{d[:matched]} elements matched: #{d[:without_href]} without href, " \
          "#{d[:invalid]} invalid URLs, #{d[:disallowed]} disallowed by robots.txt"
        end
      puts "No entity URLs: #{reason}."
      unless d[:sample_links].empty?
        puts 'Sample links on the page:'
        d[:sample_links].each { |h| puts "  #{h}" }
      end
    end

    public
    def detect_identifier_type(identifier)
      identifier = identifier.to_s.strip
      return :xpath if identifier.start_with?('/')
      :css
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
