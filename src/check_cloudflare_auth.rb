require_relative 'lib/helper'
require 'net/http'
require 'uri'

page_url = ARGV[0]
if page_url.nil? || page_url.empty?
  puts "Usage: ruby check_cloudflare_auth.rb <page_url>"
  exit(1)
end

private_key_content = ENV['CLOUDFLARE_PRIVATE_KEY']
if private_key_content.nil? || private_key_content.strip.empty?
  puts "CLOUDFLARE_PRIVATE_KEY is not set. Exiting..."
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
