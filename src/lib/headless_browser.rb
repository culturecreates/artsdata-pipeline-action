require 'ferrum'
require 'json'
require 'linkeddata'
require 'rbconfig'

module HeadlessBrowser
  def self.fetch_json_ld_objects(entity_urls, base_url, headers, sparql_paths, browser: nil, graph: nil)
    browser ||= create_browser(headers)
    graph ||= RDF::Graph.new
    add_url_sparql_file = File.read('./sparql/add_derived_from.sparql')

    entity_urls.each do |entity_url|
      process_entity_url(entity_url, browser, graph, add_url_sparql_file)
    end

    SparqlProcessor.perform_sparql_transformations(graph, sparql_paths, base_url)
    graph
  end

  def self.create_browser(headers = nil)
    browser_path =  if running_on_macos?
                      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                    else
                      "/usr/bin/google-chrome-stable"
                    end
    browser = Ferrum::Browser.new(browser_path: browser_path, headless: true, pending_connection_errors: false, process_timeout: 60, xvfb: true, browser_options: { 'no-sandbox': nil })
    browser.headers.set(headers) if headers
    browser
  end

  def self.process_entity_url(entity_url, browser, graph, add_url_sparql_file = nil)
    puts "Processing #{entity_url} in headless mode"
    browser.go_to(entity_url)
    sleep 15
    browser.stop
    json_ld_scripts = browser.css("script[type='application/ld+json']")
    json_ld_scripts.each do |script|
      process_json_ld_script(script, entity_url, graph, add_url_sparql_file)
    end
  rescue StandardError => e
    puts "Error processing #{entity_url} in headless mode: #{e.message}"
  end

  def self.process_json_ld_script(script, entity_url, graph, add_url_sparql_file = nil)
    # Parse the JSON-LD string into a JSON object
    json_ld = string_to_json(script.text)
    # Convert the JSON-LD object to an RDF graph
    loaded_graph = RDF::Graph.new << JSON::LD::API.toRdf(json_ld)
    if add_url_sparql_file
      sparql_file_with_url = add_url_sparql_file.gsub("subject_url", entity_url)
      loaded_graph.query(SPARQL.parse(sparql_file_with_url, update: true))
    end
    graph << loaded_graph
  rescue JSON::ParserError => e
    puts "Error parsing JSON-LD: #{e.message}"
  end

  def self.string_to_json(crawled_str)
    # Remove any linefeeds from the string
    crawled_str.gsub!("\n", "")
    JSON.parse(crawled_str)
  end

  def self.fetch_entity_urls_headless(url, headers, browser: nil)
    browser ||= create_browser(headers)
    browser.go_to(url)
    sleep 15
    browser.body
  end

  def self.running_on_macos?
    RbConfig::CONFIG['host_os'] =~ /darwin|mac os/
  end
end