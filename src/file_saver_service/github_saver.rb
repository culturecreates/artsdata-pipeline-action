require 'octokit'
require 'base64'

module FileSaverService
  class GitHubSaverService < FileSaverService::FileSaver
    def initialize(repository:, path:, message:, access_token:, author_name:, author_email:)
      super(path: path)
      @repository = repository
      @message = message
      @access_token = access_token
      @client = Octokit::Client.new(access_token: @access_token)
      @author = {
        name: author_name,
        email: author_email
      }
    end

    def get_file_content(file_path)
      begin
        file = @client.contents(@repository, path: file_path)
        content = Base64.decode64(file.content)
        return content
      rescue Octokit::NotFound
        puts "File not found in the repository: #{file_path}"
        return nil
      rescue StandardError => e
        puts "Error fetching file from GitHub: #{e.message}"
        return nil
      end
    end

    def save(content)
      if(!@access_token)
        puts("Access token is not provided. Cannot save to GitHub.")
        exit(0)

      max_retries = 3
      retries = 0
      end
      begin
        existing_file = @client.contents(@repository, path: @path)
        sha = existing_file.sha
        response = @client.update_contents(
          @repository,
          @path,
          @message,
          sha,
          content,
          author: @author
        )
      rescue Octokit::NotFound
        response = @client.create_contents(
          @repository,
          @path,
          @message,
          content,
          author: @author
        )
      rescue Octokit::Conflict
        retries += 1
        if retries <= max_retries
          sleep(0.5)
          retry
        else
          raise
        end
      end

      owner, repo = @repository.split("/")
      branch = response[:content][:branch] || "main"
      "https://raw.githubusercontent.com/#{owner}/#{repo}/#{branch}/#{@path}"
    end
  end
end