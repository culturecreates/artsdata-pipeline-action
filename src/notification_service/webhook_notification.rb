module NotificationService
  class WebhookNotification < NotificationService::Notification
    def initialize(workflow_id:, actor:, webhook_url:)
      super(workflow_id: workflow_id, actor: actor)
      @webhook_url = webhook_url
    end

    def send_notification(stage:, message:)
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
    
      response = http.request(request)
    
      puts "Webhook notification sent. HTTP #{response.code}: #{response.message}"
    end
  end
end