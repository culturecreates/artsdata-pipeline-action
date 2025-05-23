module NotificationService
  class Notification
    def initialize(workflow_id:, actor:)
      @workflow_id = workflow_id
      @actor = actor
    end

    def send_notification(stage:, message:)
      raise NotImplementedError, "Subclasses must implement the send_notification method"
    end
  end
end