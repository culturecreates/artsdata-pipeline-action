# lib/page_fetcher_service/cloudflare_signed_page_fetcher.rb

require 'net/http'
require 'uri'
require 'openssl'
require 'json'
require 'base64'
require 'time'

module PageFetcherService
  # Extends StaticPageFetcher to add Cloudflare Web Bot Auth signature support
  class CloudflareSignedPageFetcher < PageFetcherService::StaticPageFetcher
    def initialize(private_key_path:, key_directory_url:)
      authority = URI.parse(page_url).authority
      headers = Helper.get_headers(authority)
      super(headers: headers)
      @private_key_path = private_key_path
      @key_directory_url = key_directory_url
      @private_key = load_private_key
      @keyid = calculate_jwk_thumbprint
    end

    def fetch_page_data(page_url:, selector: 'body')
      puts "🔵 CloudflareSignedPageFetcher.fetch_page_data called for: #{page_url}"
      uri = URI.parse(page_url)
      
      # Check if we need to sign (only for Cloudflare-protected sites)
      if should_sign_request?(uri)
        puts "✅ Signing request"
        fetch_with_signature(uri)
      else
        puts "⚪ Normal fetch"
        response = URI.open(page_url, @headers)
        content_type = response.content_type
        charset = response.charset || 'utf-8'
        data = response.read
        if charset != 'utf-8'
          data = data.force_encoding(charset).encode("UTF-8")
        end
        [data, content_type]
      end
    end

    private

    def should_sign_request?(uri)
      # You can add logic to detect if a site needs signing
      # For now, sign all HTTPS requests (you can make this smarter)
      uri.scheme == 'https'
    end

    def load_private_key
      return nil unless @private_key_path && File.exist?(@private_key_path)
      OpenSSL::PKey.read(File.read(@private_key_path))
    rescue => e
      puts "Warning: Could not load private key: #{e.message}"
      nil
    end

    def calculate_jwk_thumbprint
      return nil unless @private_key
      
      public_key_der = @private_key.public_to_der
      x_bytes = public_key_der[-32..]
      
      jwk = {
        'crv' => 'Ed25519',
        'kty' => 'OKP',
        'x' => Base64.urlsafe_encode64(x_bytes, padding: false)
      }
      
      canonical_json = JSON.generate(jwk)
      digest = OpenSSL::Digest::SHA256.digest(canonical_json)
      Base64.urlsafe_encode64(digest, padding: false)
    end

    def create_signature_headers(uri)
      return {} unless @private_key && @keyid

      authority = uri.host
      created = Time.now.to_i
      expires = created + 60
      nonce = Base64.urlsafe_encode64(OpenSSL::Random.random_bytes(48), padding: false)

      # Create signature base
      signature_base = create_signature_base(authority, created, expires, nonce)
      
      # Sign
      signature_bytes = @private_key.sign(nil, signature_base)
      signature = Base64.strict_encode64(signature_bytes)

      {
        'Signature-Agent' => "\"#{@key_directory_url}\"",
        'Signature-Input' => "sig1=(\"@authority\" \"signature-agent\");created=#{created};keyid=\"#{@keyid}\";alg=\"ed25519\";expires=#{expires};nonce=\"#{nonce}\";tag=\"web-bot-auth\"",
        'Signature' => "sig1=:#{signature}:"
      }
    rescue => e
      puts "Warning: Could not create signature: #{e.message}"
      {}
    end

    def create_signature_base(authority, created, expires, nonce)
      lines = []
      lines << "\"@authority\": #{authority}"
      lines << "\"signature-agent\": \"#{@key_directory_url}\""
      
      params = "\"@authority\" \"signature-agent\""
      param_line = "(#{params})"
      param_line += ";created=#{created}"
      param_line += ";keyid=\"#{@keyid}\""
      param_line += ";alg=\"ed25519\""
      param_line += ";expires=#{expires}"
      param_line += ";nonce=\"#{nonce}\""
      param_line += ";tag=\"web-bot-auth\""
      
      lines << "\"@signature-params\": #{param_line}"
      lines.join("\n")
    end

    def fetch_with_signature(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      
      # Add standard headers
      @headers.each { |key, value| request[key] = value }
      
      # Add signature headers
      signature_headers = create_signature_headers(uri)
      signature_headers.each { |key, value| request[key] = value }

      response = http.request(request)
      
      # Check if we got blocked/unauthorized
      if response.code.to_i == 401 || response.code.to_i == 403
        puts "Warning: Request to #{uri} returned #{response.code} - bot may not be registered"
      end

      content_type = response['content-type']
      [response.body, content_type]
    end
  end
end