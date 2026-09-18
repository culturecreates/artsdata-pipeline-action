require 'octokit'
require 'base64'
require 'open-uri'
require 'json'

module FileSaverService
  class GitHubSaverService < FileSaverService::FileSaver
    # Commit SHA created by the most recent successful save (from the Contents
    # PUT response). nil if no write was performed (unchanged file skipped).
    attr_reader :last_commit_sha

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
      @last_commit_sha = nil

      # FIX: was `exit(0)` - a missing token is a real failure, not a
      # success. exit(0) hid this from any workflow-status-based check,
      # including CI and the workflow health report.
      if !@access_token
        puts("Access token is not provided. Cannot save to GitHub.")
        exit(1)
      end

      # FIX: these were previously declared *inside* the `if !@access_token`
      # block, after the exit call - meaning they were only ever assigned
      # on the dead branch and were undefined here whenever a token WAS
      # provided. Any Octokit::Conflict would then raise a NameError on
      # `retries += 1` instead of retrying.
      max_retries = 3
      retries = 0

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

      # Use commit.sha (the commit), NOT content.sha (the blob hash).
      @last_commit_sha =
        if response.respond_to?(:commit)          # Octokit-style object
          response.commit&.sha
        elsif response.is_a?(Hash)                 # raw JSON hash
          response.dig("commit", "sha") || response.dig(:commit, :sha)
        end

      owner, repo = @repository.split("/")
      branch = response[:content][:branch] || "main"
      "https://raw.githubusercontent.com/#{owner}/#{repo}/#{branch}/#{@path}"
    end

    # Default branch the Contents API writes to when no branch: is supplied.
    def default_branch
      @default_branch ||= begin
        api_uri = URI("https://api.github.com/repos/#{@repository}")
        headers = {
          "User-Agent" => "artsdata-pipeline-action",
          "Accept"     => "application/vnd.github+json"
        }
        headers["Authorization"] = "Bearer #{@access_token}" unless @access_token.to_s.strip.empty?
        JSON.parse(URI.open(api_uri, headers).read)["default_branch"]
      rescue StandardError => e
        puts "Warning: could not resolve default branch for #{@repository}: #{e.message}"
        nil
      end
    end
  end
end