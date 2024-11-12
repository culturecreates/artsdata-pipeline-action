require_relative 'lib/entity_fetcher'
require_relative 'lib/rdf_processor'
require_relative 'lib/headless_browser'

if ARGV.length < 4
  puts "Usage: ruby script_name.rb <page_url> <entity_identifier> <file_name> <is_paginated> <headless> <fetch_urls_headlessly>"
  exit
end

page_url, entity_identifier, file_name, is_paginated, headless, fetch_urls_headlessly = ARGV[0..5]

linkeddata_version = Gem::Specification.find_by_name('linkeddata').version.to_s
headers = {"User-Agent" => "artsdata-crawler/#{linkeddata_version}"}

entity_urls = EntityFetcher.fetch_entity_urls(page_url, entity_identifier, is_paginated, fetch_urls_headlessly, headers)
base_url = page_url.split('/')[0..2].join('/')

sparql_paths = [
  "./sparql/remove_objects.sparql",
  "./sparql/replace_blank_nodes.sparql",
  "./sparql/fix_entity_type_capital.sparql",
  "./sparql/fix_date_timezone.sparql",
  "./sparql/fix_address_country_name.sparql",
  "./sparql/fix_malformed_urls.sparql",
]

if headless == 'true'
  graph = HeadlessBrowser.fetch_json_ld_objects(entity_urls, base_url, headers, sparql_paths)
  File.open(file_name, 'w') do |file|
    file.puts(graph.dump(:jsonld))
  end
else
  graph = RDFProcessor.process_rdf(entity_urls, base_url, headers, sparql_paths)
  File.open(file_name, 'w') do |file|
    file.puts(graph.dump(:jsonld))
  end
end
