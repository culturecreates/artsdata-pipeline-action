require_relative 'lib/helper'
require 'net/http'
require 'uri'
require 'yaml'

config_file = ARGV[0]
if config_file.nil? || config_file.empty?
  puts "Usage: ruby check_cloudflare_auth.rb <config_file>"
  exit(1)
end

config = YAML.load_file(config_file)
page_url = config['page_url']
private_key_content = config['cloudflare_private_key']

if page_url.nil? || page_url.empty?
  puts "page_url is missing from #{config_file}. Exiting..."
  exit(1)
end

if private_key_content.nil? || private_key_content.strip.empty?
  puts "cloudflare_private_key is missing from #{config_file}. Exiting..."
  exit(1)
end

uri = URI.parse(page_url)
headers = Helper.get_headers(uri.authority, private_key_content)

response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
  http.get(uri.request_uri, headers)
end

puts "Response: #{response.code} #{response.message}"
puts response.body

if response.code.to_i.between?(200, 299)
  puts "Signed request accepted by Cloudflare (2xx)."
  exit(0)
else
  puts "Signed request rejected by Cloudflare (#{response.code})."
  exit(1)
end
