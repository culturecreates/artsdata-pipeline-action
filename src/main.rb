require_relative 'lib/helper'
require 'yaml'

config_file = ARGV[0]
if config_file.nil?
  puts "Usage: ruby main.rb <config_file>"
  exit(1)
end

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

Helper.check_mode_requirements(mode, config)

NotificationService::WebhookNotification.setup(
  workflow_id: workflow_id,
  actor: actor,
  webhook_url: callback_url
)

notification_instance = NotificationService::WebhookNotification.instance

if mode.include?('fetch')
  page_url, base_url = Helper.format_urls(page_url)
  headers = Helper.get_headers(custom_user_agent)

  page_fetcher_for_urls = Helper.get_page_fetcher(is_headless: fetch_urls_headlessly, headers: headers)
  entity_fetcher = Helper.get_entity_fetcher(page_fetcher: page_fetcher_for_urls, base_url: base_url)

  entity_urls = entity_fetcher.fetch_entity_urls(
    page_url: page_url, 
    entity_identifier: entity_identifier,
    is_paginated: is_paginated, 
    offset: offset
  )

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

  page_fetcher_for_graph = Helper.get_page_fetcher(is_headless: headless, headers: headers)
  graph_fetcher = Helper.get_graph_fetcher(
    headers: headers,
    page_fetcher: page_fetcher_for_graph,
    sparql_path: "./sparql/"
  )

  graph = graph_fetcher.load_with_retry(entity_urls: entity_urls)

  notification_instance.send_notification(
    stage: 'graph_fetched',
    message: 'crawl completed, triple count: ' + graph.size.to_s
  )

  entity_types = graph_fetcher.fetch_types(graph: graph)
  notification_instance.send_notification(
    stage: 'entity_types_fetched',
    message: 'entity types fetched: ' + entity_types.map(&:to_s).join(', ')
  )

  if !mode.include?('test')
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
    group: group
  )

  case response[:status]
  when :success
    notification_instance.send_notification(stage: 'databus_push', message: response[:message])
  when :error
    notification_instance.send_notification(stage: 'databus_push', message: "Error occurred: #{response[:message]}")
  when :exception
    notification_instance.send_notification(stage: 'databus_push', message: "Exception occurred: #{response[:message]}")
  else
    notification_instance.send_notification(stage: 'databus_push', message: "Unknown status: #{response[:status]}")
  end
end

