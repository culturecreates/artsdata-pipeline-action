require_relative '../browser_service/browser'

module PaginationParamDetectorService
  # Detects a pagination query-string param whose name is generated
  # per-widget-instance by the site (e.g. Ultimate Member directory
  # widgets use "page_<directory_id>"), rather than being a fixed,
  # predictable string. Hardcoding the discovered value in a workflow
  # breaks whenever the site owner recreates the widget.
  #
  # Ultimate Member stamps its directory-instance id onto every member
  # card's DOM id, e.g. <div id="um-member-1HPMx-Jgayh">, where "Jgayh"
  # is the same directory id used as the pagination query param
  # ("page_Jgayh"). So rather than clicking through pagination, we just
  # render the page once and read that id off any card.
  class PaginationParamDetector
    # CSS selector matching each entity's wrapping container element,
    # whose "id" attribute carries "<prefix>-<per-item-hash>-<directory_id>".
    CONTAINER_SELECTOR = '[id^="um-member-"]'.freeze
    ID_PATTERN = /-([A-Za-z0-9]{3,10})\z/

    def initialize(browser:, entity_selector:, timeout: 20)
      @browser = browser
      @browser_instance = @browser.create_browser()
      @entity_selector = entity_selector
      @timeout = timeout
    end

    # Returns the full param-prefixed URL to use as page_url
    # (e.g. "https://site.com/members/?page_Jgayh="), or nil if
    # detection failed.
    def detect(base_page_url:)
      @browser_instance.go_to(base_page_url)
      wait_for_selector(@entity_selector)

      directory_id = detect_directory_id
      unless directory_id
        puts "PaginationParamDetector: could not find any '#{CONTAINER_SELECTOR}' element with a usable id on #{base_page_url}"
        return nil
      end

      base_without_query = base_page_url.split('?').first
      detected_url = "#{base_without_query}?page_#{directory_id}="
      puts "PaginationParamDetector: detected directory id '#{directory_id}' -> #{detected_url}"
      detected_url
    ensure
      @browser_instance.quit
    end

    private

    def wait_for_selector(selector)
      start_time = Time.now
      until @browser_instance.at_css(selector)
        raise "Timeout waiting for '#{selector}' to render" if Time.now - start_time > @timeout
        sleep 0.5
      end
    end

    # Reads the id attribute off every matching container and returns
    # whichever suffix value appears most often, since the trailing
    # directory id is constant across cards while the per-item hash
    # before it varies. Guards against an occasional malformed id.
    def detect_directory_id
      elements = @browser_instance.css(CONTAINER_SELECTOR)
      return nil if elements.empty?

      suffixes = elements.filter_map do |el|
        id = el.attribute('id')
        match = id&.match(ID_PATTERN)
        match && match[1]
      end
      return nil if suffixes.empty?

      suffixes.tally.max_by { |_, count| count }&.first
    end
  end
end