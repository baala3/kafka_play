namespace :producer do
  task :produce_session_logs do
    at_exit { ::Karafka.producer.close }

    USER_RANGE = (1..10)
    SESSION_RANGE = (1..3)
    MAX_TIME_AGO = 36_000  # 10 hours in seconds
    SLEEP_INTERVAL = 1     # seconds between messages

    loop do
      payload = generate_session_payload
      produce_message(payload)
      log_message(payload)
      sleep(SLEEP_INTERVAL)
    end
  end

  private

  def generate_session_payload
    {
      user_id: rand(USER_RANGE),
      session_id: rand(SESSION_RANGE),
      activity_time: (Time.now - rand(0..MAX_TIME_AGO)).iso8601
    }
  end

  def produce_message(payload)
    ::Karafka.producer.produce_async(
      topic: 'session_logs',
      payload: payload.to_json,
      key: payload[:user_id].to_s
    )
  end

  def log_message(payload)
    puts "--- Produced: User #{payload[:user_id]}, " \
         "Session #{payload[:session_id]}, " \
         "Time: #{payload[:activity_time]} ---"
  end
end
