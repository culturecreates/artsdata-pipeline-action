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

notification_service = Helper.get_notification_service(
  workflow_id: workflow_id, 
  actor: actor, 
  webhook_url: callback_url
)

if mode.include?('fetch')
  page_url, base_url = Helper.format_urls(page_url)
  headers = Helper.get_headers(custom_user_agent)
  download_file ||= "output/#{artifact}.jsonld"

  page_fetcher_for_urls = Helper.get_page_fetcher(is_headless: fetch_urls_headlessly, headers: headers)
  entity_fetcher = Helper.get_entity_fetcher(page_fetcher: page_fetcher_for_urls, base_url: base_url)

  page_fetcher_for_graph = Helper.get_page_fetcher(is_headless: headless, headers: headers)
  graph_fetcher = Helper.get_graph_fetcher(
    headers: headers,
    page_fetcher: page_fetcher_for_graph,
    sparql_path: "./sparql/"
  )

  github_saver = Helper.get_github_saver(
    repository: repository,
    file_name: download_file,
    token: token,
  )

  entity_urls = entity_fetcher.fetch_entity_urls(
    page_url: page_url, entity_identifier: entity_identifier,
    is_paginated: is_paginated, offset: offset
  )
  
  notification_service.send_notification(
    stage: 'entity_urls_fetched',
    message: 'generated list of urls to crawl , count: ' + entity_urls.length.to_s
  )

  graph = graph_fetcher.load_with_retry(entity_urls: entity_urls)

  notification_service.send_notification(
    stage: 'graph_fetched',
    message: 'crawl completed, triple count: ' + graph.size.to_s
  )
  github_saver.save_graph_to_file(file_name: download_file, graph: graph)
  download_url = github_saver.save(File.read(download_file))

  notification_service.send_notification(
    stage: 'file_saved',
    message: 'file saved to github'
  )
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
    notification_service.send_notification(stage: 'databus_push', message: response[:message])
  when :error
    notification_service.send_notification(stage: 'databus_push', message: "Error occurred: #{response[:message]}")
  when :exception
    notification_service.send_notification(stage: 'databus_push', message: "Exception occurred: #{response[:message]}")
  else
    notification_service.send_notification(stage: 'databus_push', message: "Unknown status: #{response[:status]}")
  end
end

