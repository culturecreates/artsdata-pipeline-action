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

    def save(content)
      begin
        existing_file = @client.contents(@repository, path: @path)
        sha = existing_file.sha
        @client.update_contents(
          @repository,
          @path,
          @message,
          sha,
          content,
          author: @author
        )
      rescue Octokit::NotFound
        @client.create_contents(
          @repository,
          @path,
          @message,
          content,
          author: @author
        )
      end
    end
  end
end