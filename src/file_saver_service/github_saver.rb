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

      # Pin the URL to the commit this write created (commit.sha, NOT the
      # blob's content.sha) so each crawl keeps its own permanent downloadURL.
      commit = response[:commit]
      commit_sha = (commit && commit[:sha]) || last_commit_sha_for_path
      return nil if commit_sha.to_s.empty?

      "https://raw.githubusercontent.com/#{@repository}/#{commit_sha}/#{@path}"
    end

    private

    # Safety net in case the write response carries no commit: the last commit
    # that touched the file on the default branch (where the Contents API writes).
    def last_commit_sha_for_path
      default_branch = @client.repository(@repository).default_branch
      @client.commits(@repository, default_branch, path: @path, per_page: 1).first&.sha
    rescue Octokit::Error => e
      puts "Warning: could not resolve commit for #{@path}: #{e.message}"
      nil
    end
  end
end