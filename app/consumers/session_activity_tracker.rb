# frozen_string_literal: true

class SessionActivityTracker < ApplicationConsumer
  INACTIVITY_THRESHOLD = 3600  # for session inactivity threshold (1 hour)
  YIELD_INTERVAL = 3           # seconds between yields

  def initialize
    @buffer = Hash.new { |h, k| h[k] = {} }
    @last_yield_time = Time.now
  end

  def consume
    messages.each do |message|
      track_activity(message)
    end

    fetch_inactive_sessions do |inactive_sessions|
      flush_to_session_expiry_handler(inactive_sessions)
    end
  end

  private

  def track_activity(message)
    user_id = message.payload['user_id']
    session_id = message.payload['session_id']
    activity_time = message.payload['activity_time']

    # Update buffer with earliest activity time
    current_time = @buffer[user_id][session_id]
    @buffer[user_id][session_id] = if current_time.nil?
      activity_time
    else
      [current_time, activity_time].min
    end
  end

  def fetch_inactive_sessions
    current_time = Time.now
    inactive_sessions = Hash.new { |h, k| h[k] = {} }

    process_inactive_sessions(current_time, inactive_sessions)
    cleanup_empty_users

    # Yield inactive sessions every YIELD_INTERVAL seconds
    if should_yield?(inactive_sessions)
      yield inactive_sessions if block_given?
      @last_yield_time = Time.now
    end
  end

  def process_inactive_sessions(current_time, inactive_sessions)
    @buffer.each do |user_id, sessions|
      sessions.each do |session_id, activity_time|
        activity_time = parse_activity_time(activity_time)

        if activity_time < current_time - INACTIVITY_THRESHOLD
          inactive_sessions[user_id][session_id] = activity_time
          @buffer[user_id].delete(session_id)
        end
      end
    end
  end

  def parse_activity_time(activity_time)
    activity_time.is_a?(String) ? Time.parse(activity_time) : activity_time
  end

  def cleanup_empty_users
    @buffer.delete_if { |_, sessions| sessions.empty? }
  end

  def should_yield?(inactive_sessions)
    !inactive_sessions.empty? && Time.now - @last_yield_time >= YIELD_INTERVAL
  end

  def flush_to_session_expiry_handler(inactive_sessions)
    return if inactive_sessions.empty?

    total_sessions = inactive_sessions.values.map(&:size).sum
    Karafka.logger.info("--- Flushing #{total_sessions} inactive sessions ---")

    batched_messages = build_expired_session_messages(inactive_sessions)
    ::Karafka.producer.produce_many_async(batched_messages)
    @buffer.clear
  end

  def build_expired_session_messages(inactive_sessions)
    inactive_sessions.flat_map do |user_id, sessions|
      sessions.map do |session_id, activity_time|
        {
          topic: 'expired_sessions',
          key: user_id.to_s,
          payload: {
            user_id: user_id,
            session_id: session_id,
            activity_time: activity_time
          }.to_json
        }
      end
    end
  end
end
