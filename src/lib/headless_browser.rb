require 'ferrum'
require 'json'
require 'linkeddata'
require 'rbconfig'
require_relative 'sparql_processor'

class HeadlessBrowser
  def initialize(headers = nil)
    @browser = create_browser(headers)
    @add_url_sparql_file = File.read('./sparql/add_derived_from.sparql')
  end

  # Main method to return html for a single url in headless mode
  # Input: URL of the index page
  # Output: string contianing html
  def fetch_page_data_with_browser(url)
    retry_count = 0
    max_retries = 3
    begin
      @browser.go_to(url)
      sleep 15
      main_page_html_text = @browser.body
    rescue StandardError => e
      retry_count += 1
      if retry_count < max_retries
        retry
      else
        puts "Max retries reached. Unable to fetch the content for page #{url}."
        puts "#{e.message}, consider passing a custom user agent instead of #{@browser.headers.get['User-Agent']}"
        exit(1)
      end
    end
    sleep 15
    main_page_html_text
  end

  # Main method to return an RDF::Graph using the list of entity URLs
  # Input: Array of URLs
  # Output: RDF::Graph
  def fetch_json_ld_objects(entity_urls)
    @graph = RDF::Graph.new
    puts "URL processing mode: Headless"
    entity_urls.each do |entity_url|
      process_entity_url(entity_url)
    end
    @graph
  end

  def process_entity_url(entity_url)
    puts "Processing #{entity_url}"
    @browser.go_to(entity_url)
    sleep 5
    @browser.stop

    # Process the HTML content and extract JSON-LD
    json_ld_scripts = @browser.css("script[type='application/ld+json']")  #TODO: Check if Nokogiri::HTML works better
    entity_graph = RDF::Graph.new
    options = {unique_bnodes: true}
    json_ld_scripts.each do |script|
      json_ld = string_to_json(script.text)
      JSON::LD::API.toRdf(json_ld, **options) do |statement|
        entity_graph << statement
      end
    end

    # Add the derivedFrom triple to the graph
    intermediate_sparql_paths = [
      './sparql/add_derived_from.sparql',
      './sparql/add_language.sparql'
    ]
    sparql_processor = SparqlProcessor.new(intermediate_sparql_paths, entity_url)
    entity_graph = sparql_processor.perform_sparql_transformations(entity_graph, "subject_url")

    @graph << entity_graph
  rescue StandardError => e
    puts "Error processing #{entity_url} in headless mode: #{e.message}"
  end

  def string_to_json(crawled_str)
    # Remove any linefeeds from the string
    crawled_str.gsub!("\n", "")
    JSON.parse(crawled_str)
  end

  private 

  def create_browser(headers = nil)
    browser_path =  if running_on_macos?
                      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                    else
                      "/usr/bin/google-chrome-stable"
                    end
    browser = Ferrum::Browser.new(browser_path: browser_path, headless: true, pending_connection_errors: false, process_timeout: 60, xvfb: true, browser_options: { 'no-sandbox': nil })
    browser.headers.set(headers) if headers
    browser
  end

  def running_on_macos?
    RbConfig::CONFIG['host_os'] =~ /darwin|mac os/
  end
end