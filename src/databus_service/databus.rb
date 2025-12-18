module DatabusService
  class Databus
    def initialize(artifact:, publisher:, repository:, databus_url:)
      @artifact = artifact
      @publisher = publisher
      @repository = repository
      @databus_url = databus_url
    end

    def send(download_url:, download_file:, version:, comment:, group:, register_only: false)
      group ||= @repository.split('/').last
      version ||= Time.now.strftime("%Y-%m-%dT%H:%M:%S").gsub(':', '_')
      comment ||= "Published by #{group} on #{version}"

      data_hash = {
        artifact: @artifact,
        publisher: @publisher,
        group: group,
        version: version,
        downloadUrl: download_url,
        downloadFile: download_file&.split('/')&.last || download_url.split('/')&.last, 
        comment: comment,
        register_only: register_only
      }

      data = JSON.generate(data_hash)

      puts "\nData (JSON payload): #{data}"

      uri = URI.parse(@databus_url)

      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = data
      request['Content-Type'] = 'application/json'
      begin
        response = http.request(request)
        response_body = JSON.parse(response.body)
        if response.code.to_i == 201
          puts("Data posted successfully.")
          puts "Response: #{response.body}"
          return { status: :success, message: response_body['message'] || 'Data posted successfully.', dataset: response_body['dataset'] }
        else
          puts("Error posting data: #{response.code} - #{response.body}")
          return { status: :error, code: response.code.to_i, message: response_body['message'] || 'Error posting data.' }
        end
      rescue StandardError => e
        puts("Exception occurred: #{e.message}")
        return { status: :exception, message: e.message }
      end
    end
  end
end