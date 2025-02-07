# frozen_string_literal: true

require 'bundler'

ENV['KARAFKA_ENV'] ||= 'development'
Bundler.require(:default, ENV['KARAFKA_ENV'])

APP_LOADER = Zeitwerk::Loader.new
APP_LOADER.enable_reloading

%w[
  lib
  app/consumers
].each { |dir| APP_LOADER.push_dir(dir) }

APP_LOADER.setup
APP_LOADER.eager_load

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
    config.client_id = 'example_app'
    config.concurrency = 4
  end


  Karafka.monitor.subscribe(
    Karafka::Instrumentation::LoggerListener.new(
      log_polling: true
    )
  )

  Karafka.producer.monitor.subscribe(
    WaterDrop::Instrumentation::LoggerListener.new(
      Karafka.logger,
      log_messages: false
    )
  )

  Karafka.monitor.subscribe 'error.occurred' do |event|
    type = event[:type]
    error = event[:error]
    details = (error.backtrace || []).join("\n")
    ErrorTracker.send_error(error, type, details)
  end

  Karafka.producer.monitor.subscribe('error.occurred') do |event|
    type = event[:type]
    error = event[:error]
    details = (error.backtrace || []).join("\n")
    ErrorTracker.send_error(error, type, details)
  end

  routes.draw do
    topic :session_logs do
      config(partitions: 5, 'cleanup.policy': 'delete')
      consumer SessionActivityTracker
    end

    topic :expired_sessions do
      config(partitions: 5, 'cleanup.policy': 'delete')
      consumer SessionExpiryHandler
    end
  end
end

