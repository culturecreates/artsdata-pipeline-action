module NotificationService
  class WebhookNotification < NotificationService::Notification
    @instance = nil

    class << self
      def setup(workflow_id:, actor:, webhook_url:)
        raise "NotificationService already initialized. Call `close` first." if @instance
        @instance = new(workflow_id: workflow_id, actor: actor, webhook_url: webhook_url)
      end

      def instance
        raise "NotificationService not initialized. Call `setup` first." unless @instance
        @instance
      end

      def close
        @instance = nil
      end
    end

    def initialize(workflow_id:, actor:, webhook_url:)
      super(workflow_id: workflow_id, actor: actor)
      @webhook_url = webhook_url
    end

    def send_notification(stage:, message:)
      if @webhook_url.nil? || @webhook_url.empty?
        puts "No webhook URL provided. Skipping notification."
        return
      end
      uri = URI.parse(@webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
    
      request = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
      payload = {
        stage: stage,
        timestamp: Time.now.utc,
        message: message,
        workflow_id: @workflow_id,
        actor: @actor
      }
      request.body = payload.to_json
      begin
        response = http.request(request)
        puts "Notification sent. Response: #{response.code} #{response.message}"
      rescue StandardError => e
        puts "Failed to send notification: #{e.message}"
      end
    end
  end
end