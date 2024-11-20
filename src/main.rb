require_relative 'lib/entity_fetcher'
require_relative 'lib/graph_fetcher'

if ARGV.length < 4
  puts "Usage: ruby script_name.rb <page_url> <entity_identifier> <file_name> <is_paginated> <headless> <fetch_urls_headlessly> <offset>"
  exit
end

page_url, entity_identifier, file_name, is_paginated, headless, fetch_urls_headlessly, offset = ARGV[0..6]

linkeddata_version = Gem::Specification.find_by_name('linkeddata').version.to_s
headers = {"User-Agent" => "artsdata-crawler/#{linkeddata_version}"}
base_url = page_url.split('/')[0..2].join('/')

# Fetch index page with list of urls
entity_urls = EntityFetcher.fetch_entity_urls(page_url, entity_identifier, is_paginated, fetch_urls_headlessly, headers, offset)

# Fetch the data at each url to build the graph
graph = GraphFetcher.load(entity_urls: entity_urls, base_url: base_url, headers: headers, headless: headless)

File.open(file_name, 'w') do |file|
  file.puts(graph.dump(:jsonld))
end

