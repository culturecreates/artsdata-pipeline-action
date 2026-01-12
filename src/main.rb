require_relative 'lib/helper'
require 'yaml'

config_file = ARGV[0]
if config_file.nil?
  puts "Usage: ruby main.rb <config_file>"
  exit(1)
end
html_extract_config_file = ARGV[1]
puts "HTML Extract Config File: #{html_extract_config_file}"
metadata_file = ARGV[2]
puts "Metadata File: #{metadata_file}"

config = YAML.load_file(config_file)

mode = config['mode']

page_url = config['page_url']
entity_identifier = config['entity_identifier']
is_paginated = config['is_paginated']
headless = config['headless']
fetch_urls_headlessly = config['fetch_urls_headlessly']
offset = config['offset']
custom_user_agent = config['custom_user_agent']
callback_url = config['callback_url']
workflow_id = config['workflow_id']
actor = config['actor']
token = config['token']
repository = config['repository']
artifact = config['artifact']
publisher = config['publisher']
reference = config['reference']
version = config['version']
comment = config['comment']
group = config['group']
download_file = config['download_file']
download_url = config['download_url']
shacl = config['shacl']
databus_url = config['databus']
register_only = config['register_only'] == true
enable_signing = config['enable_cloudflare_signing'] || false
private_key_path = config['private_key_path']
key_directory_url = config['key_directory_url']


if html_extract_config_file && File.exist?(html_extract_config_file)
  begin
    html_extract_config = JSON.parse(File.read(html_extract_config_file))
  rescue JSON::ParserError => e
    html_extract_config = nil
  end
end

metadata_exists = false

if metadata_file && File.exist?(metadata_file)
  puts "Loading metadata file: #{metadata_file}"
  begin
    metadata_content = JSON.parse(File.read(metadata_file))
    if metadata_content['file_name']
      metadata_exists = true
      puts "Metadata file will be saved as: #{metadata_content['file_name']}"
    end
    puts "Loaded metadata content: #{metadata_content}"
  rescue JSON::ParserError => e
    metadata_content = nil
  end
else
  puts "No metadata file provided or file does not exist."
end

Helper.check_mode_requirements(mode, config)

NotificationService::WebhookNotification.setup(
  workflow_id: workflow_id,
  actor: actor,
  webhook_url: callback_url
)

notification_instance = NotificationService::WebhookNotification.instance

if mode.include?('fetch')
  page_url, base_url = Helper.format_urls(page_url)
  Helper.set_custom_user_agent(custom_user_agent)

  if entity_identifier.nil? || entity_identifier.strip.empty?
  # Check if testing Cloudflare
    if enable_signing && page_url.first.include?('crawltest.com')
      puts "Using CloudflareSignedPageFetcher for Cloudflare test"
      page_fetcher = Helper.get_page_fetcher_with_signing(
        is_headless: headless,
        enable_signing: true,
        private_key_path: private_key_path,
        key_directory_url: key_directory_url
      )
    else
      page_fetcher = Helper.get_page_fetcher(is_headless: headless)
    end
    # Use SpiderCrawler when no entity identifier is provided
    crawler = Helper.get_spider_crawler(
      url: page_url,
      page_fetcher: page_fetcher,
      sparql_path: "./sparql/",
      robots_txt_content: Helper.get_robots_txt_content(base_url: base_url, page_fetcher: page_fetcher)
    )
    start_time = Time.now.utc.iso8601
    if metadata_content&.[]('skip_crawl') == "true"
      puts "Skipping crawl as per metadata file instruction."
      graph = RDF::Graph.new
      structured_score = 0
      end_time = start_time
      visited_count = 0
      event_count = 0
    else
      crawler.crawl()
      graph = crawler.get_graph()
      structured_score = crawler.get_structured_score()
      end_time = Time.now.utc.iso8601
      visited_count = crawler.get_visited_count()
      event_count = crawler.get_event_count()
    end
    if metadata_exists
      metadata_content['structured_score'] = structured_score
      metadata_content['start_time'] = start_time
      metadata_content['end_time'] = end_time
      metadata_content['url_count'] = visited_count
      metadata_content['event_count'] = event_count
    end
  else
    # Use UrlFetcher and GraphFetcher when entity identifier is provided
    page_fetcher = Helper.get_page_fetcher(is_headless: fetch_urls_headlessly)
    url_fetcher = Helper.get_url_fetcher(
      page_url: page_url,
      base_url: base_url,
      entity_identifier: entity_identifier,
      is_paginated: is_paginated,
      offset: offset,
      page_fetcher: page_fetcher,
      robots_txt_content: Helper.get_robots_txt_content(base_url: base_url, page_fetcher: page_fetcher)
    )

    entity_urls = url_fetcher.fetch_urls()

    if entity_urls.empty?
      notification_message = 'No entity URLs found. Check your identifier. Exiting...'
      puts notification_message
      notification_instance.send_notification(
        stage: 'fetching_entity_urls',
        message: notification_message
      )
      exit(1)
    end
    
    notification_instance.send_notification(
      stage: 'fetching_entity_urls',
      message: 'generated list of urls to crawl , count: ' + entity_urls.length.to_s
    )

    if mode.include?('test')
      entity_urls = entity_urls.take(5) # Limit to 5 URLs for testing
    end

    notification_instance.send_notification(
      stage: 'entity_urls_fetched',
      message: 'sample entity urls fetched: ' + entity_urls.join(', ')
    )

    graph_fetcher = Helper.get_graph_fetcher(
      page_fetcher: Helper.get_page_fetcher(is_headless: headless),
      sparql_path: "./sparql/",
      html_extract_config: html_extract_config
    )

    graph = graph_fetcher.load_with_retry(entity_urls: entity_urls)
  end

  notification_instance.send_notification(
    stage: 'graph_fetched',
    message: 'crawl completed, triple count: ' + graph.size.to_s
  )

  if graph.size == 0
    notification_message = 'No RDF data extracted'
    puts notification_message
    notification_instance.send_notification(
      stage: 'graph_fetched',
      message: notification_message
    )
    if !metadata_exists
      exit(1)
    end
  end 

  entity_types = Helper.fetch_types(graph: graph)
  notification_instance.send_notification(
    stage: 'entity_types_fetched',
    message: 'entity types fetched: ' + entity_types.map(&:to_s).join(', ')
  )

  if !mode.include?('test') && graph.size != 0
    download_file ||= "output/#{artifact}.jsonld"
    github_saver = Helper.get_github_saver(
      repository: repository,
      file_name: download_file,
      token: token,
    )
    github_saver.save_graph_to_file(file_name: download_file, graph: graph)
    download_url = github_saver.save(File.read(download_file))

    notification_instance.send_notification(
      stage: 'file_saved',
      message: 'file saved to github'
    )
  end
end

if mode.include?('push')
  if download_url
    databus_service = Helper.get_databus_service(
      artifact: artifact,
      publisher: publisher,
      repository: repository,
      databus_url: databus_url
    )

    response = databus_service.send(
      download_url: download_url,
      download_file: download_file,
      version: version,
      comment: comment,
      group: group,
      register_only: register_only,
      page_url: base_url
    )
    dataset = response[:dataset] || nil
    Helper.send_databus_notification(notification_instance, response)
  end

  if metadata_exists
    metadata_content['databus_id'] = dataset
    if graph.size == 0 && metadata_content['skip_crawl'] != "true"
      metadata_content['crawl_name'] = 'No Structured Data Found'
      metadata_content['crawl_description'] = 'This crawl resulted in an empty graph.'
    end
    metadata_graph = Helper.generate_metadata_file_content(metadata_content)
    download_file = "metadata/#{metadata_content['file_name']}"
    github_saver = Helper.get_github_saver(
      repository: repository,
      file_name: download_file,
      token: token,
    )

    github_saver.save_graph_to_file(file_name: download_file, graph: metadata_graph)
    download_url = github_saver.save(File.read(download_file))
  end
end

