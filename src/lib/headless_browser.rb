require 'ferrum'
require 'json'
require 'linkeddata'

module HeadlessBrowser
  def self.fetch_json_ld_objects(entity_urls, base_url, headers, sparql_paths)
    puts "Loading browser..."
    browser = Ferrum::Browser.new(browser_path: "/usr/bin/google-chrome-stable", headless: true, pending_connection_errors: false, process_timeout: 60, xvfb: true, browser_options: { 'no-sandbox': nil })
    browser.headers.set(headers)
    graph = RDF::Graph.new
    add_url_sparql_file = File.read('./sparql/add_derived_from.sparql')
    entity_urls.each do |entity_url|
      begin
        puts "Processing #{entity_url} in headless mode"
        browser.go_to(entity_url)
        sleep 15
        browser.stop
        json_ld_scripts = browser.css("script[type='application/ld+json']")
        json_ld_scripts.each do |script|
          begin
            loaded_graph = RDF::Graph.new << JSON::LD::API.toRdf(JSON.parse(script.text))
            sparql_file_with_url = add_url_sparql_file.gsub("subject_url", entity_url)
            loaded_graph.query(SPARQL.parse(sparql_file_with_url, update: true))
            graph << loaded_graph
          rescue JSON::ParserError => e
            puts "Error parsing JSON-LD: #{e.message}"
          end
        end
      rescue StandardError => e
        puts "Error processing #{entity_url} in headless mode: #{e.message}"
      end
    end

    SparqlProcessor.perform_sparql_transformations(graph, sparql_paths, base_url)
    graph
  end

  def self.fetch_entity_urls_headless(url, headers)
    puts "Loading browser..."
    browser = Ferrum::Browser.new(browser_path: "/usr/bin/google-chrome-stable", headless: true, pending_connection_errors: false, process_timeout: 60, xvfb: true, browser_options: { 'no-sandbox': nil })
    browser.headers.set(headers)
    browser.go_to(url)
    sleep 15
    browser.body
  end
end
