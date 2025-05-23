module DatabusService
  class Databus
    def initialize(artifact:, publisher:, repository:, reference:)
      @artifact = artifact
      @publisher = publisher
      @repository = repository
      @reference = reference
    end

    def send(download_url:, download_file:, version:, comment:, group:)
      group ||= @repository.split('/').last
      version ||= Time.now.strftime("%Y-%m-%dT%H:%M:%S").gsub(':', '_')
      comment ||= "Published by #{group} on #{version}"
      download_url ||= "https://raw.githubusercontent.com/#{@repository}/#{@reference}/output/#{download_file}"

      data_hash = {
        artifact: @artifact,
        publisher: @publisher,
        group: group,
        version: version,
        downloadUrl: download_url,
        downloadFile: download_file,
        comment: comment
      }

      data = JSON.generate(data_hash)

      puts "\nData (JSON payload): #{data}"

      uri = URI.parse("http://api.artsdata.ca/databus/")

      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = data
      request['Content-Type'] = 'application/json'
      begin
        response = http.request(request)
        if response.code.to_i == 200
          puts("Data posted successfully.")
          return { status: :success, message: "Data posted successfully." }
        else
          puts("Error posting data: #{response.code} - #{response.body}")
          return { status: :error, code: response.code.to_i, message: response.body }
        end
      rescue StandardError => e
        puts("Exception occurred: #{e.message}")
        return { status: :exception, message: e.message }
      end
    end
  end
end