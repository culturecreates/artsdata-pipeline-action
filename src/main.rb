require_relative 'lib/entity_fetcher'
require_relative 'lib/graph_fetcher'
require 'fileutils'

if ARGV.length < 4
  puts "Usage: ruby script_name.rb <page_url> <entity_identifie> <file_name> <is_paginated> <headless> <fetch_urls_headlessly> <offset> <custom_user_agent>"
  exit
end

page_url, entity_identifier, file_name, is_paginated, headless, fetch_urls_headlessly, offset, custom_user_agent = ARGV[0..7]

page_url = page_url.split(',')

linkeddata_version = Gem::Specification.find_by_name('linkeddata').version.to_s
headers = {"User-Agent" => custom_user_agent || "artsdata-crawler/#{linkeddata_version}"}
base_url = page_url[0].split('/')[0..2].join('/')

# Fetch index page with list of urls
entity_urls = EntityFetcher.fetch_entity_urls(
  page_url: page_url, entity_identifier: entity_identifier,
  is_paginated: is_paginated, fetch_entity_urls_headlessly: fetch_urls_headlessly,
  headers: headers, offset: offset, base_url: base_url
)

if entity_urls.empty?
  puts "No entity URLs found. Check your identifier. Exiting..."
  exit(1)
end

# Fetch the data at each url to build the graph
graph = GraphFetcher.load(entity_urls: entity_urls, base_url: base_url, headers: headers, headless: headless)

FileUtils.mkdir_p(File.dirname(file_name))

File.open(file_name, 'w') do |file|
  file.puts(graph.dump(:jsonld))
end

