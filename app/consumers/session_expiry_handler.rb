# frozen_string_literal: true

class SessionExpiryHandler < ApplicationConsumer
  def consume
    messages.each do |message|
      payload = message.payload
      Karafka.logger.info(
        "Processing expired session - User: #{payload['user_id']}, " \
        "Session: #{payload['session_id']}, " \
        "Last Activity: #{payload['activity_time']}"
      )

      # Implement the logic to handle the expired sessions
      # - logout user
      # - send notification
      # - revoke tokens
    end
  end
end
